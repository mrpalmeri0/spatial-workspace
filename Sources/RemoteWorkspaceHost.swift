import AppKit
import Network
import ScreenCaptureKit

@MainActor final class RemoteWorkspaceHost {
    private var listener: NWListener?
    private var peer: RemotePeer?
    private var capture: DesktopCapture?
    private var encoder: RemoteVideoEncoder?
    private var encoding = false
    private var generation = 0
    private var displayIDs: [CGDirectDisplayID] = []
    private var selectedDisplay = 0
    private var activity: NSObjectProtocol?
    private(set) var enabled = false
    private(set) var pairing = ""
    private(set) var status = L("Condivisione disattivata")
    func start() {
        guard !enabled else { return }
        do {
            let secret = RemoteWire.randomSecret()
            let server = try NWListener(using: RemoteWire.parameters(secret: secret), on: 9847)
            listener = server; enabled = true
            pairing = "\(ProcessInfo.processInfo.hostName):9847#\(secret)"
            status = L("In attesa di iPhone · porta 9847")
            server.newConnectionHandler = { [weak self, weak server] connection in MainActor.assumeIsolated {
                guard let self, let server, self.listener === server else { connection.cancel(); return }
                self.accept(connection)
            } }
            server.stateUpdateHandler = { [weak self, weak server] state in MainActor.assumeIsolated {
                guard let self, let server, self.listener === server else { return }
                if case .failed(let error) = state { self.stop(); self.status = error.localizedDescription }
            } }
            server.start(queue: .main)
        } catch { status = error.localizedDescription }
    }
    func stop() {
        generation += 1; enabled = false
        listener?.cancel(); listener = nil
        peer?.close(); peer = nil
        endCapture(); pairing = ""; status = L("Condivisione disattivata")
    }
    private func endCapture() {
        let old = capture; capture = nil; old?.invalidate()
        Task { _ = await old?.stop() }
        encoder = nil; encoding = false
        if let activity { ProcessInfo.processInfo.endActivity(activity); self.activity = nil }
    }
    private func accept(_ connection: NWConnection) {
        guard peer == nil, enabled else { connection.cancel(); return }
        let client = RemotePeer(connection); peer = client
        client.onReady = { [weak self] in
            guard let self else { return }
            self.status = L("iPhone collegato · preparazione video")
            self.activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled], reason: L("Sessione Spatial remota"))
            self.selectDisplay(0)
        }
        client.onMessage = { [weak self] message in self?.handle(message) }
        client.onClose = { [weak self] reason in
            guard let self else { return }
            self.generation += 1; self.peer = nil; self.endCapture()
            self.status = self.enabled ? LF("%@ · in attesa di riconnessione", reason) : L("Condivisione disattivata")
        }
        client.start()
    }
    private func selectDisplay(_ index: Int) {
        generation += 1; let ticket = generation
        let old = capture; capture = nil; old?.invalidate()
        encoder = nil; encoding = false
        Task { [self] in
            _ = await old?.stop()
            do {
                let content = try await AsyncDeadline.run(seconds: 8, label: L("schermi remoti")) {
                    try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                }
                guard generation == ticket, enabled, peer != nil else { return }
                let displays = content.displays.filter { CGDisplayIsActive($0.displayID) != 0 }
                guard !displays.isEmpty else { throw NSError(domain: "RayNeo", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Nessun monitor disponibile")]) }
                displayIDs = displays.map(\.displayID); selectedDisplay = min(max(0, index), displays.count - 1)
                var list = RemoteMessage("displays")
                list.names = displays.map { display in NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID })?.localizedName ?? "Monitor \(display.displayID)" }
                list.number = selectedDisplay; peer?.send(list)
                let videoEncoder = try RemoteVideoEncoder(); encoder = videoEncoder
                var settings = WorkspaceSettings(); settings.captureFPS = 30; settings.useGPUTextures = true
                let stream = DesktopCapture(settings: settings, device: nil); capture = stream
                stream.onFrame = { [weak self, weak videoEncoder] frame in
                    guard let self, self.generation == ticket, let pixel = frame.pixelBuffer,
                          let videoEncoder, self.peer?.sendingVideo == false, !self.encoding else { return }
                    self.encoding = true
                    videoEncoder.encode(pixel) { [weak self] packet in
                        DispatchQueue.main.async {
                            guard let self, self.generation == ticket else { return }
                            self.encoding = false
                            if let packet { self.peer?.send(packet) }
                            else { self.status = L("Errore codifica H.264") }
                        }
                    }
                }
                stream.onError = { [weak self] error in self?.status = error; self?.peer?.close(error) }
                try await AsyncDeadline.run(seconds: 8, label: L("video remoto")) { try await stream.start(displays[min(max(0, index), displays.count - 1)]) }
                guard generation == ticket else { _ = await stream.stop(); return }
                status = L("Sessione remota attiva · 1080p / 30 fps · H.264")
            } catch {
                guard generation == ticket else { return }
                status = error.localizedDescription; peer?.close(error.localizedDescription)
            }
        }
    }
    private func handle(_ message: RemoteMessage) {
        if message.kind == "display", let index = message.number, displayIDs.indices.contains(index) { selectDisplay(index); return }
        guard AXIsProcessTrusted() else { status = L("Video attivo · consenti Accessibilità sul Mac per il controllo"); return }
        guard displayIDs.indices.contains(selectedDisplay) else { return }
        let bounds = CGDisplayBounds(displayIDs[selectedDisplay])
        switch message.kind {
        case "move":
            guard let x = message.x, let y = message.y, x.isFinite, y.isFinite else { return }
            let current = CGEvent(source: nil)?.location ?? CGPoint(x: bounds.midX, y: bounds.midY)
            let point = CGPoint(x: min(bounds.maxX - 1, max(bounds.minX, current.x + max(-500, min(500, x)))),
                                y: min(bounds.maxY - 1, max(bounds.minY, current.y + max(-500, min(500, y)))))
            CGWarpMouseCursorPosition(point)
            CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        case "click":
            let point = CGEvent(source: nil)?.location ?? CGPoint(x: bounds.midX, y: bounds.midY)
            for type: CGEventType in [.leftMouseDown, .leftMouseUp] { CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap) }
        case "scroll":
            guard let y = message.y, y.isFinite else { return }
            CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: Int32(max(-1000, min(1000, y))), wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
        case "key":
            guard let code = message.number, [53, 48, 36, 123, 124, 125, 126, 51, 0, 1, 6, 7, 8, 9, 11, 15, 3].contains(code) else { return }
            let allowedFlags: UInt64 = CGEventFlags.maskCommand.rawValue | CGEventFlags.maskShift.rawValue | CGEventFlags.maskAlternate.rawValue | CGEventFlags.maskControl.rawValue
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: down)
                event?.flags = CGEventFlags(rawValue: (message.modifiers ?? 0) & allowedFlags)
                event?.post(tap: .cghidEventTap)
            }
        case "text":
            guard let text = message.text, text.utf16.count <= 1024 else { return }
            let chars = Array(text.utf16)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)
                chars.withUnsafeBufferPointer { buffer in event?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: buffer.baseAddress) }
                event?.post(tap: .cghidEventTap)
            }
        default: break
        }
    }
}
