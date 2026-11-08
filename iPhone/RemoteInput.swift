import UIKit
import SwiftUI

final class RemoteTrackpadView: UIView {
    weak var client: RemoteClient?
    init(client: RemoteClient) {
        self.client = client; super.init(frame: .zero)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(pan(_:))); pan.maximumNumberOfTouches = 1
        let scroll = UIPanGestureRecognizer(target: self, action: #selector(scroll(_:))); scroll.minimumNumberOfTouches = 2
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap)); tap.require(toFail: pan)
        addGestureRecognizer(pan); addGestureRecognizer(scroll); addGestureRecognizer(tap)
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 20; isAccessibilityElement = true
        accessibilityLabel = L("Trackpad remoto"); accessibilityHint = L("Un dito per muovere il puntatore, tocca per cliccare, due dita per scorrere")
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
        let delta = recognizer.translation(in: self); recognizer.setTranslation(.zero, in: self)
        if recognizer.state == .changed { client?.move(x: Double(delta.x) * 2, y: Double(delta.y) * 2) }
    }
    @objc private func scroll(_ recognizer: UIPanGestureRecognizer) {
        let delta = recognizer.translation(in: self); recognizer.setTranslation(.zero, in: self)
        if recognizer.state == .changed { client?.scroll(Double(delta.y) * 2) }
    }
    @objc private func tap() { client?.click() }
}
struct RemoteTrackpad: UIViewRepresentable {
    let client: RemoteClient
    func makeUIView(context: Context) -> RemoteTrackpadView { RemoteTrackpadView(client: client) }
    func updateUIView(_ view: RemoteTrackpadView, context: Context) {}
}

final class RemoteKeyboardView: UIView, UIKeyInput {
    weak var client: RemoteClient?
    var hasText: Bool { true }
    override var canBecomeFirstResponder: Bool { true }
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var keyboardType: UIKeyboardType = .asciiCapable
    func insertText(_ text: String) { if text == "\n" { client?.key(36) } else { client?.text(text) } }
    func deleteBackward() { client?.key(51) }
    override var keyCommands: [UIKeyCommand]? {
        var commands = [(UIKeyCommand.inputEscape, 53, UIKeyModifierFlags()), ("\t", 48, UIKeyModifierFlags()),
                        (UIKeyCommand.inputLeftArrow, 123, UIKeyModifierFlags()), (UIKeyCommand.inputRightArrow, 124, UIKeyModifierFlags()),
                        (UIKeyCommand.inputUpArrow, 126, UIKeyModifierFlags()), (UIKeyCommand.inputDownArrow, 125, UIKeyModifierFlags())]
        for (letter, code) in [("a", 0), ("s", 1), ("z", 6), ("x", 7), ("c", 8), ("v", 9), ("b", 11), ("r", 15), ("f", 3)] {
            commands.append((letter, code, .command))
            commands.append((letter, code, [.command, .shift]))
        }
        return commands.map { input, code, flags in
            let command = UIKeyCommand(input: input, modifierFlags: flags, action: #selector(special(_:)))
            command.title = String(code); command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }
    @objc private func special(_ command: UIKeyCommand) {
        var flags: UInt64 = 0
        if command.modifierFlags.contains(.command) { flags |= 1 << 20 }
        if command.modifierFlags.contains(.shift) { flags |= 1 << 17 }
        if let code = Int(command.title) { client?.key(code, modifiers: flags) }
    }
}
struct RemoteKeyboard: UIViewRepresentable {
    let client: RemoteClient
    @Binding var active: Bool
    func makeUIView(context: Context) -> RemoteKeyboardView {
        let view = RemoteKeyboardView(); view.client = client; return view
    }
    func updateUIView(_ view: RemoteKeyboardView, context: Context) {
        if active && !view.isFirstResponder { view.becomeFirstResponder() }
        else if !active && view.isFirstResponder { view.resignFirstResponder() }
    }
}
