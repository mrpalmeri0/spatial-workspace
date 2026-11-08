import Foundation
import Network
import VideoToolbox

@main struct RemoteTests {
    @MainActor static func main() async {
        do { try await run() }
        catch { fputs("FAIL: \(error.localizedDescription)\n", stderr); exit(1) }
    }
    @MainActor static func run() async throws {
        let secret = RemoteWire.randomSecret()
        precondition(secret.count >= 43 && secret != RemoteWire.randomSecret())
        let data = Data((0..<8192).map { UInt8($0 % 256) })
        let frame = RemoteWire.frame(data)
        precondition(RemoteWire.payloadLength(Data(frame.prefix(4))) == data.count)
        precondition(Data(frame.dropFirst(4)) == data)
        precondition(RemoteWire.payloadLength(Data([0, 0, 0, 0])) == nil)
        precondition(RemoteWire.payloadLength(Data([255, 255, 255, 255])) == nil)
        precondition(RemoteWire.payloadLength(Data([0, 0])) == nil)
        var message = RemoteMessage("video"); message.data = data; message.sps = Data([1, 2]); message.pps = Data([3])
        let restored = try JSONDecoder().decode(RemoteMessage.self, from: JSONEncoder().encode(message))
        precondition(restored.kind == "video" && restored.data == data && restored.sps == message.sps)
        let decoder = RemoteVideoDecoder()
        precondition(decoder.sample(RemoteMessage("video")) == nil)
        print("PASS: remote framing bounds, pairing entropy, message roundtrip, missing-video rejection")

        let integration = CommandLine.arguments.contains("--integration")
        guard integration || CommandLine.arguments.contains("--codec") else { return }
        if integration {
        // A real TLS handshake checks that both sides agree on the pairing protocol.
        let listener = try NWListener(using: RemoteWire.parameters(secret: secret), on: .any)
        var server: RemotePeer?, client: RemotePeer?
        var received = false
        var failure: String?
        listener.newConnectionHandler = { connection in MainActor.assumeIsolated {
            let peer = RemotePeer(connection); server = peer
            peer.onMessage = { packet in
                precondition(packet.kind == "test" && packet.text == "RayNeo")
                peer.send(RemoteMessage("ack"))
            }
            peer.onClose = { failure = $0 }
            peer.start()
        } }
        listener.stateUpdateHandler = { state in MainActor.assumeIsolated {
            if case .ready = state, let port = listener.port {
                let connection = NWConnection(host: "127.0.0.1", port: port, using: RemoteWire.parameters(secret: secret))
                let peer = RemotePeer(connection); client = peer
                peer.onReady = { var packet = RemoteMessage("test"); packet.text = "RayNeo"; peer.send(packet) }
                peer.onMessage = { packet in if packet.kind == "ack" { received = true } }
                peer.onClose = { failure = $0 }
                peer.start()
            }
            if case .failed(let error) = state { failure = error.localizedDescription }
        } }
        listener.start(queue: .main)
        let deadline = Date().addingTimeInterval(15)
        while !received && failure == nil && Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        listener.cancel(); server?.close(); client?.close()
        guard received else { throw NSError(domain: "RemoteTLS", code: 1, userInfo: [NSLocalizedDescriptionKey: failure ?? "TLS handshake timed out"]) }
        print("PASS: real loopback TLS pairing and bidirectional framed messages")

        }
        let encoder = try RemoteVideoEncoder()
        var buffer: CVPixelBuffer?
        precondition(CVPixelBufferCreate(nil, 1920, 1080, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer) == kCVReturnSuccess)
        guard let buffer else { fatalError("No pixel buffer") }
        CVPixelBufferLockBaseAddress(buffer, [])
        memset(CVPixelBufferGetBaseAddress(buffer), 128, CVPixelBufferGetDataSize(buffer))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let packet: RemoteMessage? = try await AsyncDeadline.run(seconds: 8, label: "roundtrip H.264") {
            await withCheckedContinuation { continuation in encoder.encode(buffer) { continuation.resume(returning: $0) } }
        }
        guard let packet, let sample = decoder.sample(packet), let format = CMSampleBufferGetFormatDescription(sample) else { throw NSError(domain: "VideoToolbox", code: 1, userInfo: [NSLocalizedDescriptionKey: "Codec roundtrip failed"]) }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        precondition(dimensions.width == 1920 && dimensions.height == 1080)
        print("PASS: VideoToolbox H.264 encoding and client sample reconstruction at 1080p")
    }
}
