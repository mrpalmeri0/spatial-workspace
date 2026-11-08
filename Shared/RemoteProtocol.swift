import Foundation
import Network
import Security
import CryptoKit

struct RemoteMessage: Codable {
    var kind: String
    var number: Int?
    var x: Double?
    var y: Double?
    var text: String?
    var data: Data?
    var sps: Data?
    var pps: Data?
    var names: [String]?
    var modifiers: UInt64?
    init(_ kind: String) { self.kind = kind }
}

enum RemoteWire {
    static let maximumPayload = 8 * 1024 * 1024
    static func parameters(secret: String) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        let key = Data(SHA256.hash(data: Data(secret.utf8)))
        let identity = Data("RayNeoWorkspace-v1".utf8)
        key.withUnsafeBytes { keyBytes in
            identity.withUnsafeBytes { identityBytes in
                sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions,
                    DispatchData(bytes: keyBytes) as __DispatchData,
                    DispatchData(bytes: identityBytes) as __DispatchData)
            }
        }
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_set_max_tls_protocol_version(tls.securityProtocolOptions, .TLSv12)
        sec_protocol_options_append_tls_ciphersuite(tls.securityProtocolOptions, tls_ciphersuite_t(rawValue: 0x00A8)!)
        let tcp = NWProtocolTCP.Options(); tcp.noDelay = true
        return NWParameters(tls: tls, tcp: tcp)
    }
    static func randomSecret() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return UUID().uuidString + UUID().uuidString }
        return Data(bytes).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func payloadLength(_ header: Data) -> Int? {
        guard header.count == 4 else { return nil }
        let size = header.reduce(0) { ($0 << 8) | Int($1) }
        return (1...maximumPayload).contains(size) ? size : nil
    }
    static func frame(_ payload: Data) -> Data {
        let n = UInt32(payload.count)
        return Data([UInt8((n >> 24) & 255), UInt8((n >> 16) & 255), UInt8((n >> 8) & 255), UInt8(n & 255)]) + payload
    }
}

// All state and callbacks are confined to the main queue on both platforms.
@MainActor final class RemotePeer {
    let connection: NWConnection
    var onMessage: ((RemoteMessage) -> Void)?
    var onReady: (() -> Void)?
    var onClose: ((String) -> Void)?
    private(set) var sendingVideo = false
    private var closed = false
    private var pendingCommands = 0
    init(_ connection: NWConnection) { self.connection = connection }
    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                guard let self, !self.closed else { return }
                switch state {
                case .ready: self.onReady?(); self.receiveHeader()
                case .failed(let error): self.close(error.localizedDescription)
                case .cancelled: self.close(L("Connessione chiusa"))
                default: break
                }
            }
        }
        connection.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, self.connection.state != .ready else { return }
            self.close(L("Connessione scaduta: verifica indirizzo e codice di abbinamento"))
        }
    }
    @discardableResult func send(_ message: RemoteMessage) -> Bool {
        guard !closed, connection.state == .ready else { return false }
        let video = message.kind == "video"
        guard video ? !sendingVideo : pendingCommands < 64,
              let data = try? JSONEncoder().encode(message), data.count <= RemoteWire.maximumPayload else { return false }
        if video { sendingVideo = true } else { pendingCommands += 1 }
        connection.send(content: RemoteWire.frame(data), completion: .contentProcessed { [weak self] error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if video { self.sendingVideo = false } else { self.pendingCommands -= 1 }
                if let error { self.close(error.localizedDescription) }
            }
        })
        return true
    }
    private func receiveHeader() {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, done, error in
            MainActor.assumeIsolated {
                guard let self, !self.closed else { return }
                guard error == nil, !done, let data, data.count == 4 else { self.close(L("Connessione interrotta")); return }
                guard let size = RemoteWire.payloadLength(data) else { self.close(L("Pacchetto non valido")); return }
                self.receiveBody(size)
            }
        }
    }
    private func receiveBody(_ size: Int) {
        connection.receive(minimumIncompleteLength: size, maximumLength: size) { [weak self] data, _, done, error in
            MainActor.assumeIsolated {
                guard let self, !self.closed else { return }
                guard error == nil, let data, data.count == size,
                      let message = try? JSONDecoder().decode(RemoteMessage.self, from: data) else { self.close(L("Pacchetto incompleto")); return }
                self.onMessage?(message)
                if done { self.close(L("Connessione chiusa")) } else { self.receiveHeader() }
            }
        }
    }
    func close(_ reason: String = "Disconnesso") {
        guard !closed else { return }
        closed = true; connection.cancel(); onClose?(reason)
        onReady = nil; onMessage = nil; onClose = nil
    }
}
