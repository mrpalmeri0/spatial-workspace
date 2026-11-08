import AppKit
import SceneKit

extension WorkspaceDelegate {
    // Contenuto dello sfondo corrente (tinta, sfumatura o immagine), condiviso da occhiali e anteprima.
    func backgroundContents() -> Any {
        switch settings.background {
        case 0: return NSColor.black
        case 1: return NSColor(calibratedWhite: 0.07, alpha: 1)
        case 2: return NSColor(calibratedRed: 0.03, green: 0.05, blue: 0.12, alpha: 1)
        case 4:
            if !settings.backgroundImagePath.isEmpty, let image = NSImage(contentsOfFile: settings.backgroundImagePath) { return image }
            return WorkspaceDelegate.gradientBackground()
        default: return WorkspaceDelegate.gradientBackground()
        }
    }
    // Applica lo sfondo sia alla scena degli occhiali sia a quella dell'anteprima.
    func applyBackground() {
        let contents = backgroundContents()
        view?.scene?.background.contents = contents
        previewView?.scene?.background.contents = contents
    }

    private static let previewFieldOfView: CGFloat = 78

    // Crea la vista di anteprima 3D dentro al contenitore dato (nel pannello di controllo).
    func buildPreview(in container: NSView) {
        // SwiftUI recreates this host after navigating away and back. Its nodes
        // must belong to the new scene even when the monitor count is unchanged.
        previewPanels.forEach { $0.removeFromParentNode() }
        previewPanels.removeAll()
        previewCamera.removeFromParentNode()
        let v = SCNView(frame: container.bounds)
        v.autoresizingMask = [.width, .height]
        v.scene = SCNScene()
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        v.rendersContinuously = false
        v.wantsLayer = true
        v.layer?.cornerRadius = 14
        v.layer?.masksToBounds = true
        previewCamera.camera = SCNCamera()
        previewCamera.camera?.projectionDirection = .horizontal
        // A wider field of view shows the layout outside the glasses' forward view.
        previewCamera.camera?.fieldOfView = Self.previewFieldOfView
        previewCamera.camera?.zNear = 0.1
        previewCamera.camera?.zFar = 50
        v.scene?.rootNode.addChildNode(previewCamera)
        v.pointOfView = previewCamera
        container.addSubview(v)
        previewView = v
        updatePreview()
    }

    func buildGlassesPreview(in container: NSView) {
        let options: [String: Any] = view?.device.map { [SCNView.Option.preferredDevice.rawValue: $0] } ?? [:]
        let liveView = SCNView(frame: .zero, options: options)
        liveView.preferredFramesPerSecond = 30
        liveView.antialiasingMode = view?.antialiasingMode ?? .none
        liveView.backgroundColor = .black
        liveView.isPlaying = false
        liveView.isHidden = true
        container.addSubview(liveView)
        glassesPreviewView = liveView

        let placeholder = NSTextField(labelWithString: L("Avvia una sessione per vedere la vista degli occhiali."))
        placeholder.textColor = .secondaryLabelColor
        placeholder.alignment = .center
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isHidden = true
        container.addSubview(placeholder)
        NSLayoutConstraint.activate([
            placeholder.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            placeholder.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12)
        ])
        glassesPreviewPlaceholder = placeholder
    }

    func updateGlassesPreview() {
        guard let liveView = glassesPreviewView, let container = liveView.superview else { return }
        let selected = previewView?.isHidden == true
        let visible = selected && controlWindow.isVisible && !controlWindow.isMiniaturized
            && controlWindow.occlusionState.contains(.visible)
        let running = !terminating && outputDisplayID != 0 && !starting && stopTask == nil
            && !virtualDisplays.isEmpty
        let active = visible && running
        if active {
            let output = view.bounds.size
            if output.width > 0 && output.height > 0 {
                let bounds = container.bounds
                let scale = min(bounds.width / output.width, bounds.height / output.height)
                let size = NSSize(width: output.width * scale, height: output.height * scale)
                let frame = NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                                   width: size.width, height: size.height)
                if liveView.frame != frame { liveView.frame = frame }
            }
        }
        if active != liveView.isPlaying {
            liveView.scene = active ? view.scene : nil
            liveView.pointOfView = active ? camera : nil
            liveView.isPlaying = active
        }
        liveView.isHidden = !active
        glassesPreviewPlaceholder?.isHidden = !selected || running
    }

    // Aggiorna l'anteprima in base alle impostazioni correnti (numero schermi, disposizione, sfondo).
    func updatePreview() {
        guard let scene = previewView?.scene else { return }
        scene.background.contents = backgroundContents()
        if previewPanels.count != settings.screenCount {
            previewPanels.forEach { $0.removeFromParentNode() }
            let colors: [NSColor] = [.systemBlue, .systemTeal, .systemPurple]
            previewPanels = (0..<settings.screenCount).map { index in
                let plane = SCNPlane(width: 2.5, height: 2.5 * 9 / 16)
                plane.cornerRadius = 0.045
                plane.firstMaterial?.diffuse.contents = WorkspaceDelegate.previewScreenTexture(index, color: colors[index])
                plane.firstMaterial?.lightingModel = .constant
                plane.firstMaterial?.isDoubleSided = true
                let node = SCNNode(geometry: plane)
                scene.rootNode.addChildNode(node)
                return node
            }
        }
        SpatialLayout.apply(panels: previewPanels, settings: settings)

        // Step back only as far as needed to keep the outer monitors inside the preview.
        let horizontalLimit = tan(Double(Self.previewFieldOfView) * .pi / 360) * 0.90
        var cameraDistance = 0.0
        for panel in previewPanels {
            for edge in [-1.25, 1.25] {
                for height in [-2.5 * 9 / 32, 2.5 * 9 / 32] {
                    let corner = panel.convertPosition(SCNVector3(edge, height, 0), to: nil)
                    cameraDistance = max(cameraDistance, Double(corner.z) + abs(Double(corner.x)) / horizontalLimit)
                }
            }
        }
        previewCamera.position.z = CGFloat(cameraDistance)
        previewView?.isPlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.previewView?.isPlaying = false
        }
    }

    // Illustrative desktops are independent of the live screen capture.
    static func previewScreenTexture(_ index: Int, color: NSColor) -> NSImage {
        let size = NSSize(width: 640, height: 360)
        return NSImage(size: size, flipped: false) { bounds in
            func tile(_ rect: NSRect, color: NSColor, radius: CGFloat = 8) {
                color.setFill()
                NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            }
            func caption(_ text: String, at point: NSPoint, size: CGFloat, color: NSColor) {
                (text as NSString).draw(at: point, withAttributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: size, weight: .semibold),
                    .foregroundColor: color
                ])
            }

            color.withAlphaComponent(0.9).setFill()
            bounds.fill()
            tile(bounds.insetBy(dx: 4, dy: 4), color: NSColor(srgbRed: 0.06, green: 0.08, blue: 0.14, alpha: 1), radius: 12)
            caption("SPATIAL WORKSPACE", at: NSPoint(x: 24, y: 322), size: 15, color: .white)
            caption(String(format: "%02d", index + 1), at: NSPoint(x: 566, y: 312), size: 26, color: color)

            let windowColor = NSColor(srgbRed: 0.10, green: 0.14, blue: 0.22, alpha: 1)
            tile(NSRect(x: 24, y: 44, width: 382, height: 252), color: windowColor)
            tile(NSRect(x: 420, y: 44, width: 196, height: 252), color: windowColor)
            for (dot, tint) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                tile(NSRect(x: 42 + CGFloat(dot) * 15, y: 272, width: 8, height: 8), color: tint, radius: 4)
            }
            for (row, width) in [114, 232, 187, 254, 158, 198].enumerated() {
                let tint = row.isMultiple(of: 3) ? color : NSColor.white
                tile(NSRect(x: 46 + CGFloat(row % 3) * 16, y: 235 - CGFloat(row) * 27,
                            width: CGFloat(width), height: 6), color: tint.withAlphaComponent(0.52), radius: 3)
            }
            for row in 0..<3 {
                tile(NSRect(x: 436, y: 223 - CGFloat(row) * 70, width: 164, height: 54),
                     color: color.withAlphaComponent(0.20), radius: 6)
            }
            return true
        }
    }

    // Sfumatura scura blu/viola, generata al volo, usata come sfondo predefinito.
    static func gradientBackground() -> NSImage {
        let size = NSSize(width: 32, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.015, green: 0.02, blue: 0.06, alpha: 1),
            NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.14, alpha: 1),
            NSColor(calibratedRed: 0.10, green: 0.06, blue: 0.13, alpha: 1)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 90)
        image.unlockFocus()
        return image
    }

    // (Ri)costruisce i pannelli-schermo in base al numero scelto dall'utente (1, 2 o 3).
    // Da chiamare solo a sessione ferma: cambia quanti desktop virtuali verranno mostrati.
    func rebuildPanels() {
        guard let scene = view?.scene else { return }
        panels.forEach { $0.removeFromParentNode() }
        panels.removeAll()
        let colors: [NSColor] = [.systemBlue, .systemTeal, .systemOrange]
        for i in 0..<screenCount {
            let title = screenCount == 1 ? L("Schermo") : LF("Schermo %d", i + 1)
            addPanel(scene, angle: 0, title: title,
                     lines: ["Desktop Mac \(i + 1)", "", L("Sposta qui le finestre:"), L("porta il mouse oltre"), L("il bordo destro del Mac.")],
                     color: colors[i % colors.count])
        }
        SpatialLayout.apply(panels: panels, settings: settings)
        panels.forEach { $0.isHidden = true }
        retainedFrames = Array(repeating: nil, count: screenCount)
    }

    func addPanel(_ scene: SCNScene, angle: Double, title: String, lines: [String], color: NSColor) {
        let texture = NSImage(size: NSSize(width: 1600, height: 900))
        texture.lockFocus()
        NSColor(calibratedRed: 0.035, green: 0.05, blue: 0.08, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: 1600, height: 900).fill()
        color.setFill(); NSRect(x: 0, y: 880, width: 1600, height: 20).fill()
        let titleStyle: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 68, weight: .bold), .foregroundColor: color]
        (title as NSString).draw(at: NSPoint(x: 80, y: 720), withAttributes: titleStyle)
        let bodyStyle: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 44, weight: .regular), .foregroundColor: NSColor.white]
        for (index, line) in lines.enumerated() {
            (line as NSString).draw(at: NSPoint(x: 80, y: 580 - index * 80), withAttributes: bodyStyle)
        }
        texture.unlockFocus()
        // At distance 3, 2*tan(46/2)*3 ~= 2.547 fills the horizontal view.
        // Leave 2% margin to keep the desktop edges visible.
        let panelWidth = 2.50
        let plane = SCNPlane(width: panelWidth, height: panelWidth * 9 / 16)
        plane.firstMaterial?.diffuse.contents = texture
        plane.firstMaterial?.lightingModel = .constant
        plane.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: plane)
        let radians = angle * .pi / 180
        node.position = SCNVector3(3 * sin(radians), 0, -3 * cos(radians))
        node.eulerAngles.y = CGFloat(-radians)
        scene.rootNode.addChildNode(node)
        panels.append(node)
    }
}
