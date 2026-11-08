import AppKit
import SceneKit
import IOKit.hid
import ScreenCaptureKit
import CoreImage
import CoreMedia
import Carbon

// Explicit workspace commands only. Ordinary mouse input stays native.
final class WindowShortcuts {
    var requestAction: ((Int) -> Void)?
    var requestMove: ((Int) -> Void)?
    private var hotkeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    func install() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        guard InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == 0x47544D53, id.id < 8 else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<WindowShortcuts>.fromOpaque(context).takeUnretainedValue()
            if id.id < 4 { owner.requestMove?(Int(id.id)) } else { owner.requestAction?(Int(id.id) - 4) }
            return noErr
        }, 1, &type, context, &handler) == noErr else { return }
        for (index, key) in [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_0, kVK_ANSI_P, kVK_ANSI_M, kVK_ANSI_K, kVK_ANSI_F].enumerated() {
            var ref: EventHotKeyRef?
            if RegisterEventHotKey(UInt32(key), UInt32(cmdKey | optionKey), EventHotKeyID(signature: 0x47544D53, id: UInt32(index)), GetApplicationEventTarget(), 0, &ref) == noErr, let ref { hotkeys.append(ref) }
        }
    }
    deinit {
        hotkeys.forEach { UnregisterEventHotKey($0) }
        if let handler { RemoveEventHandler(handler) }
    }
}

