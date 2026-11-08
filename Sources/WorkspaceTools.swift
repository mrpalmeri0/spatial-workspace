import AppKit
import SwiftUI
import SceneKit
import Carbon

// Native input remains untouched. Pointer movement occurs only on an explicit command.

final class UtilityPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class WorkspaceTools: ObservableObject {
    @Published var fullKeyboard = false
    @Published var uppercase = false
    weak var engine: WorkspaceDelegate?
    var panel: UtilityPanel?
    var radar: NSTextField?
    var radarUntil = 0.0
    var focusLocked = false
    private var wasPaused = false
    private var recoveryWindows: [SavedWindow] = []
    struct SavedWindow {
        let pid: pid_t
        let element: AXUIElement
        let monitor: Int
        let relative: CGRect
    }

    var target: Int? {
        guard let e = engine, !e.starting, e.stopTask == nil else { return nil }
        return MonitorTarget.index(yaw: Double(e.camera.eulerAngles.y) * 180 / .pi,
                                   count: e.virtualDisplays.count, spacing: e.settings.spacingDegrees)
    }
    func bringCursor() {
        guard let e = engine, let index = target else { engine?.desktopStatus = L("Avvia prima una sessione"); return }
        let rect = CGDisplayBounds(e.virtualDisplays[index].displayID)
        let result = CGWarpMouseCursorPosition(CGPoint(x: rect.midX, y: rect.midY))
        e.desktopStatus = result == .success ? LF("Cursore sul monitor %d", index + 1) : L("Impossibile spostare il cursore")
        showRadar()
    }
    func toggleFocus() {
        guard let e = engine else { return }
        if focusLocked {
            focusLocked = false; e.paused = wasPaused
        } else if let index = target {
            wasPaused = e.paused
            e.camera.eulerAngles.y = -CGFloat(Double(index) - Double(e.virtualDisplays.count - 1) / 2) * CGFloat(e.settings.spacingDegrees) * .pi / 180
            e.paused = true; focusLocked = true
        }
        showRadar()
    }
    func showRadar() {
        guard let e = engine, let container = e.window?.contentView, !e.virtualDisplays.isEmpty else { return }
        if radar == nil {
            let label = NSTextField(labelWithString: "")
            label.font = .monospacedSystemFont(ofSize: 19, weight: .semibold)
            label.textColor = .white; label.alignment = .center
            label.drawsBackground = true; label.backgroundColor = NSColor.black.withAlphaComponent(0.8)
            label.frame = NSRect(x: container.bounds.midX - 300, y: 90, width: 600, height: 44)
            label.autoresizingMask = [.minXMargin, .maxXMargin, .maxYMargin]
            container.addSubview(label); radar = label
        }
        radarUntil = ProcessInfo.processInfo.systemUptime + 4
        updateRadar()
    }
    func updateRadar() {
        guard let e = engine, let radar else { return }
        radar.isHidden = ProcessInfo.processInfo.systemUptime > radarUntil || e.virtualDisplays.isEmpty
        guard !radar.isHidden else { return }
        let point = CGEvent(source: nil)?.location ?? .zero
        radar.stringValue = e.virtualDisplays.enumerated().map { index, display in
            let gaze = index == target ? "◉" : "○"
            let mouse = CGDisplayBounds(display.displayID).contains(point) ? " ↖" : ""
            return "\(gaze) Monitor \(index + 1)\(mouse)"
        }.joined(separator: "    ") + (focusLocked ? "  · Focus" : "")
    }
    func togglePanel() {
        if let panel, panel.isVisible { panel.orderOut(nil); return }
        guard let e = engine, let index = target,
              let screen = NSScreen.screens.first(where: { e.displayID($0) == e.virtualDisplays[index].displayID }) else { return }
        if panel == nil {
            let p = UtilityPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 196),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isFloatingPanel = true; p.becomesKeyOnlyIfNeeded = true
            p.isReleasedWhenClosed = false; p.level = .floating
            p.backgroundColor = .clear; p.isOpaque = false; p.hasShadow = true
            p.contentView = NSHostingView(rootView: QuickControls(tools: self))
            panel = p
        }
        panel?.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 310, y: screen.visibleFrame.minY + 48))
        panel?.orderFrontRegardless()
        bringCursor()
    }
    func toggleKeyboard() {
        fullKeyboard.toggle()
        if let panel {
            var frame = panel.frame
            frame.size.height = fullKeyboard ? 410 : 196
            panel.setFrame(frame, display: true, animate: false)
        }
    }
    func text(_ text: String) {
        guard AXIsProcessTrusted() else { key(53); return }
        let characters = Array(text.utf16)
        for pressed in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: pressed)
            characters.withUnsafeBufferPointer { event?.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: $0.baseAddress) }
            event?.post(tap: .cghidEventTap)
        }
    }
    func key(_ code: CGKeyCode) {
        guard AXIsProcessTrusted() else {
            _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            engine?.desktopStatus = L("Consenti Accessibilità per usare i tasti virtuali"); return
        }
        for pressed in [true, false] { CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: pressed)?.post(tap: .cghidEventTap) }
    }
    func rememberWindows() {
        guard let e = engine, !e.virtualDisplays.isEmpty, AXIsProcessTrusted() else { return }
        recoveryWindows.removeAll()
        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            let ax = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(ax, 0.1)
            var raw: CFTypeRef?
            guard AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &raw) == .success,
                  let windows = raw as? [AXUIElement] else { continue }
            for window in windows {
                var positionRaw: CFTypeRef?, sizeRaw: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRaw) == .success,
                      AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRaw) == .success,
                      let p = positionRaw, let s = sizeRaw, CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { continue }
                var point = CGPoint.zero, size = CGSize.zero
                guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { continue }
                let center = CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
                for (index, display) in e.virtualDisplays.enumerated() {
                    let bounds = CGDisplayBounds(display.displayID)
                    if bounds.contains(center) {
                        recoveryWindows.append(SavedWindow(pid: app.processIdentifier, element: window, monitor: index,
                            relative: CGRect(x: point.x - bounds.minX, y: point.y - bounds.minY, width: size.width, height: size.height)))
                        break
                    }
                }
            }
        }
    }
    func restoreWindows() {
        guard let e = engine, !e.virtualDisplays.isEmpty, AXIsProcessTrusted(), !recoveryWindows.isEmpty else { return }
        var restored = 0
        recoveryWindows = recoveryWindows.filter { saved in
            guard e.virtualDisplays.indices.contains(saved.monitor), NSRunningApplication(processIdentifier: saved.pid) != nil else { return true }
            let bounds = CGDisplayBounds(e.virtualDisplays[saved.monitor].displayID)
            var size = CGSize(width: min(saved.relative.width, bounds.width - 32), height: min(saved.relative.height, bounds.height - 64))
            var point = CGPoint(x: bounds.minX + max(0, min(saved.relative.minX, bounds.width - size.width)),
                                y: bounds.minY + max(32, min(saved.relative.minY, bounds.height - size.height)))
            if let value = AXValueCreate(.cgSize, &size) { AXUIElementSetAttributeValue(saved.element, kAXSizeAttribute as CFString, value) }
            if let value = AXValueCreate(.cgPoint, &point), AXUIElementSetAttributeValue(saved.element, kAXPositionAttribute as CFString, value) == .success { restored += 1; return false }
            return true
        }
        e.desktopStatus = LF("Ripristinate %d finestre della sessione precedente", restored)
    }
    func stop() {
        rememberWindows(); panel?.orderOut(nil); radar?.isHidden = true
        if focusLocked { engine?.paused = wasPaused; focusLocked = false }
    }
}

private struct QuickControls: View {
    @ObservedObject var tools: WorkspaceTools
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(L("Ricentra"), systemImage: "scope") { tools.engine?.recenter() }
                Button("Focus", systemImage: "viewfinder") { tools.toggleFocus() }
                Button(L("Cursore"), systemImage: "cursorarrow") { tools.bringCursor() }
                Button(L("Tastiera"), systemImage: "keyboard") { tools.toggleKeyboard() }
                Button(L("Chiudi"), systemImage: "xmark") { tools.panel?.orderOut(nil) }
            }
            HStack {
                ForEach(Array(zip(["Esc", "Tab", "↵", "←", "↑", "↓", "→", "⌫"], [53, 48, 36, 123, 126, 125, 124, 51])), id: \.0) { title, code in
                    Button(title) { tools.key(CGKeyCode(code)) }.frame(minWidth: 42)
                }
            }
            if tools.fullKeyboard {
                VStack(spacing: 8) {
                    ForEach(["1234567890", "qwertyuiop", "asdfghjkl", "zxcvbnm.,"], id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(Array(row).map(String.init), id: \.self) { key in
                                Button(tools.uppercase ? key.uppercased() : key) { tools.text(tools.uppercase ? key.uppercased() : key) }
                                    .frame(minWidth: 40)
                            }
                        }
                    }
                    HStack {
                        Button(tools.uppercase ? L("Maiuscole ✓") : L("Maiuscole")) { tools.uppercase.toggle() }
                        Button(L("Spazio")) { tools.text(" ") }.frame(minWidth: 180)
                        Button(L("Invio")) { tools.key(36) }
                    }
                }
            }
            Text(L("Seleziona prima un campo nell’app. I tasti mantengono il suo focus."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .buttonStyle(.glass).padding(20).frame(width: 620, height: tools.fullKeyboard ? 410 : 196)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
    }
}
