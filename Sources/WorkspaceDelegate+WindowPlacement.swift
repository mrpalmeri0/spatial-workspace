import AppKit

extension WorkspaceDelegate {
    func moveFocusedWindow(_ index: Int) {
        guard AXIsProcessTrusted() else {
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            desktopStatus = L("Spostare le finestre richiede il permesso Accessibilità: consenti Spatial Workspace e riprova"); return
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard let pid = (frontPID != ownPID ? frontPID : lastExternalPID) else {
            desktopStatus = L("Seleziona prima la finestra dell'app da spostare, poi premi ⌘⌥1 / 2 / 3"); return
        }
        let displayID: CGDirectDisplayID
        if index == 3 {
            guard let screen = NSScreen.screens.first(where: { screen in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
                return CGDisplayIsBuiltin(id.uint32Value) != 0
            }), let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
            displayID = id.uint32Value
        } else {
            guard virtualDisplays.indices.contains(index) else { desktopStatus = L("Avvia prima gli schermi"); return }
            displayID = virtualDisplays[index].displayID
        }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 1)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            desktopStatus = L("Questa app non ha finestre normali spostabili; seleziona prima una finestra"); return
        }
        let focused = unsafeBitCast(value, to: AXUIElement.self)
        var fullScreen: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, "AXFullScreen" as CFString, &fullScreen) == .success,
           (fullScreen as? Bool) == true {
            desktopStatus = L("Esci prima dalla modalità a schermo intero dell'app, poi sposta la finestra"); return
        }
        let bounds = CGDisplayBounds(displayID)
        var size = CGSize(width: min(1280, bounds.width - 80), height: min(850, bounds.height - 100))
        var existingSize: CFTypeRef?
        if AXUIElementCopyAttributeValue(focused, kAXSizeAttribute as CFString, &existingSize) == .success,
           let existingSize, CFGetTypeID(existingSize) == AXValueGetTypeID() {
            var original = CGSize.zero
            if AXValueGetValue(unsafeBitCast(existingSize, to: AXValue.self), .cgSize, &original) {
                size.width = min(original.width, bounds.width - 80)
                size.height = min(original.height, bounds.height - 100)
            }
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) { _ = AXUIElementSetAttributeValue(focused, kAXSizeAttribute as CFString, sizeValue) }
        var position = CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2)
        guard let positionValue = AXValueCreate(.cgPoint, &position) else { return }
        let result = AXUIElementSetAttributeValue(focused, kAXPositionAttribute as CFString, positionValue)
        let destinations = [L("schermo sinistro"), L("schermo centrale"), L("schermo destro"), "Mac"]
        desktopStatus = result == .success
            ? LF("Finestra spostata su %@", destinations[index])
            : LF("Spostamento della finestra non riuscito (%d); l'app potrebbe limitare la posizione delle finestre", result.rawValue)
    }
}
