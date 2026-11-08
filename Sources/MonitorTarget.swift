import Foundation

enum MonitorTarget {
    static func index(yaw: Double, count: Int, spacing: Double) -> Int? {
        guard yaw.isFinite, spacing.isFinite, spacing > 0, count > 0 else { return nil }
        let indices = 0..<count
        return indices.min { a, b in
            abs(wrapped(yaw + (Double(a) - Double(count - 1) / 2) * spacing)) <
            abs(wrapped(yaw + (Double(b) - Double(count - 1) / 2) * spacing))
        }
    }
    private static func wrapped(_ degrees: Double) -> Double {
        atan2(sin(degrees * .pi / 180), cos(degrees * .pi / 180)) * 180 / .pi
    }
}

