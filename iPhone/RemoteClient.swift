import UIKit
import Combine
import CoreMedia
import Network

@MainActor final class RemoteClient: ObservableObject {
    @Published var pairing = ""
    @Published var status = L("Incolla il codice mostrato sul Mac")
    @Published var connected = false
    @Published var connecting = false
    @Published var displays: [String] = []
    @Published var selected = 0
    @Published var externalConnected = false
    private var peer: RemotePeer?
    private let decoder = RemoteVideoDecoder()
    private var outputs = NSHashTable<RemoteVideoView>.weakObjects()
    private var lastSample: CMSampleBuffer?
    func connect() {
        disconnect()
        let code = pairing.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let hash = code.lastIndex(of: "#"), let colon = code[..<hash].lastIndex(of: ":"),
              let portValue = UInt16(code[code.index(after: colon)..<hash]), let port = NWEndpoint.Port(rawValue: portValue) else {
            status = L("Codice non valido: usa indirizzo:porta#codice"); return
        }
        let secret = String(code[code.index(after: hash)...]), host = String(code[..<colon])
        guard secret.count >= 32, !host.isEmpty else { status = L("Codice incompleto"); return }
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: RemoteWire.parameters(secret: secret))
        let client = RemotePeer(connection); peer = client
        connecting = true; status = L("Connessione al Mac…")
        client.onReady = { [weak self] in
            self?.connected = true; self?.connecting = false; self?.status = L("Mac collegato · in attesa del desktop")
            UIApplication.shared.isIdleTimerDisabled = true
        }
        client.onMessage = { [weak self] message in self?.handle(message) }
        client.onClose = { [weak self] reason in
            guard let self else { return }
            self.connected = false; self.connecting = false; self.status = reason
            self.peer = nil; self.decoder.reset(); self.lastSample = nil; self.displays = []
            self.outputs.allObjects.forEach { $0.displayLayer.flushAndRemoveImage() }
            UIApplication.shared.isIdleTimerDisabled = false
        }
        client.start()
    }
    func disconnect() {
        peer?.close(); peer = nil; connected = false; connecting = false
        UIApplication.shared.isIdleTimerDisabled = false
    }
    func register(_ view: RemoteVideoView) { outputs.add(view); if let lastSample { view.display(lastSample) } }
    func unregister(_ view: RemoteVideoView) { outputs.remove(view) }
    private func handle(_ message: RemoteMessage) {
        switch message.kind {
        case "displays":
            displays = message.names ?? []; selected = message.number ?? 0
            decoder.reset(); lastSample = nil; outputs.allObjects.forEach { $0.displayLayer.flushAndRemoveImage() }
        case "video":
            if let sample = decoder.sample(message) {
                lastSample = sample; outputs.allObjects.forEach { $0.display(sample) }
                if status != L("Desktop remoto attivo") { status = L("Desktop remoto attivo") }
            }
        default: break
        }
    }
    func chooseDisplay(_ index: Int) { var m = RemoteMessage("display"); m.number = index; peer?.send(m) }
    func move(x: Double, y: Double) { var m = RemoteMessage("move"); m.x = x; m.y = y; peer?.send(m) }
    func click() { peer?.send(RemoteMessage("click")) }
    func scroll(_ y: Double) { var m = RemoteMessage("scroll"); m.y = y; peer?.send(m) }
    func key(_ code: Int, modifiers: UInt64 = 0) { var m = RemoteMessage("key"); m.number = code; m.modifiers = modifiers; peer?.send(m) }
    func text(_ text: String) {
        // Limit Unicode chunks without splitting surrogate pairs.
        var chunk = ""
        for character in text {
            if chunk.utf16.count + String(character).utf16.count > 1000 { var m = RemoteMessage("text"); m.text = chunk; peer?.send(m); chunk = "" }
            chunk.append(character)
        }
        if !chunk.isEmpty { var m = RemoteMessage("text"); m.text = chunk; peer?.send(m) }
    }
}
