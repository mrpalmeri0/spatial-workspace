import SceneKit
import AppKit

enum SpatialLayout {
    // Disposizione ad arco: gli schermi stanno su una curva intorno a te, centrata davanti.
    // Con uno schermo è dritto davanti (stile RayNeo classico); con due o tre sono come monitor
    // affiancati che raggiungi girando la testa. "spacingDegrees" è la distanza angolare tra schermi vicini.
    static func apply(panels: [SCNNode], settings: WorkspaceSettings) {
        let count = panels.count
        guard count > 0 else { return }
        let tiltRadians = settings.tilt * .pi / 180
        let dim = NSColor(calibratedWhite: settings.brightness, alpha: 1)
        for (index, node) in panels.enumerated() {
            // Centra l'arco: per 2 schermi gli angoli sono ±spacing/2, per 3 sono -spacing, 0, +spacing.
            let angle = (Double(index) - Double(count - 1) / 2.0) * settings.spacingDegrees * .pi / 180
            node.position = SCNVector3(settings.distance * sin(angle), 0, -settings.distance * cos(angle))
            node.eulerAngles = SCNVector3(CGFloat(tiltRadians), CGFloat(-angle), 0)
            node.scale = SCNVector3(settings.scale, settings.scale, 1)
            // Luminosità: moltiplica il colore dello schermo (bianco = pieno, grigio = più scuro).
            node.geometry?.firstMaterial?.multiply.contents = dim
        }
    }
}
