import Foundation

enum VisualDynamicsPreset: String, CaseIterable, Identifiable {
    case cinematic
    case balanced
    case kinetic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cinematic:
            return "Cinematic"
        case .balanced:
            return "Balanced"
        case .kinetic:
            return "Kinetic"
        }
    }

    var cameraDriftScale: Double {
        switch self {
        case .cinematic: return 0.7
        case .balanced: return 1.0
        case .kinetic: return 1.35
        }
    }

    var cameraBeatScale: Double {
        switch self {
        case .cinematic: return 0.55
        case .balanced: return 1.0
        case .kinetic: return 1.25
        }
    }

    var elephantDanceScale: Double {
        switch self {
        case .cinematic: return 0.95
        case .balanced: return 1.0
        case .kinetic: return 1.3
        }
    }

    var cameraFollowScale: Double {
        switch self {
        case .cinematic: return 0.7
        case .balanced: return 1.0
        case .kinetic: return 1.2
        }
    }

    var breathSpeedScale: Double {
        switch self {
        case .cinematic: return 0.82
        case .balanced: return 1.0
        case .kinetic: return 1.2
        }
    }

    var secondaryLayerDensityScale: Double {
        switch self {
        case .cinematic: return 0.86
        case .balanced: return 1.0
        case .kinetic: return 1.22
        }
    }

    var secondaryLayerOpacityScale: Double {
        switch self {
        case .cinematic: return 0.75
        case .balanced: return 1.0
        case .kinetic: return 1.15
        }
    }
}

enum VisualAudioMapProfile: String, CaseIterable, Identifiable {
    case bassDrive
    case balanced
    case highSpark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bassDrive:
            return "Bass Drive"
        case .balanced:
            return "Balanced"
        case .highSpark:
            return "High Spark"
        }
    }

    func map(low: Double, mid: Double, high: Double, flux: Double) -> (low: Double, mid: Double, high: Double) {
        switch self {
        case .bassDrive:
            return (
                clamp(low * 0.86 + mid * 0.14 + flux * 0.16, 0, 1),
                clamp(low * 0.24 + mid * 0.62 + high * 0.14 + flux * 0.1, 0, 1),
                clamp(mid * 0.28 + high * 0.72 + flux * 0.18, 0, 1)
            )
        case .balanced:
            return (
                clamp(low * 0.72 + mid * 0.22 + high * 0.06 + flux * 0.1, 0, 1),
                clamp(low * 0.2 + mid * 0.64 + high * 0.16 + flux * 0.1, 0, 1),
                clamp(low * 0.08 + mid * 0.28 + high * 0.64 + flux * 0.16, 0, 1)
            )
        case .highSpark:
            return (
                clamp(low * 0.58 + mid * 0.28 + high * 0.14 + flux * 0.1, 0, 1),
                clamp(low * 0.16 + mid * 0.56 + high * 0.28 + flux * 0.14, 0, 1),
                clamp(mid * 0.24 + high * 0.76 + flux * 0.24, 0, 1)
            )
        }
    }
}

struct VisualDynamicsTuning: Sendable {
    var cameraDrift: Double = 50
    var cameraBeat: Double = 50
    var elephantDance: Double = 50
    var breathSpeed: Double = 50
    var layer2Depth: Double = 50

    static let neutral = VisualDynamicsTuning()

    var cameraDriftMultiplier: Double { centeredScale(cameraDrift, min: 0.35, max: 1.9) }
    var cameraBeatMultiplier: Double { centeredScale(cameraBeat, min: 0.3, max: 1.9) }
    var elephantDanceMultiplier: Double { centeredScale(elephantDance, min: 0.45, max: 1.9) }
    var breathSpeedMultiplier: Double { centeredScale(breathSpeed, min: 0.55, max: 1.8) }
    var layer2DepthMultiplier: Double { centeredScale(layer2Depth, min: 0.3, max: 1.85) }

    private func centeredScale(_ value: Double, min: Double, max: Double) -> Double {
        let v = clamp(value, 0, 100)
        if v >= 50 {
            let t = (v - 50) / 50
            return 1 + t * (max - 1)
        }
        let t = (50 - v) / 50
        return 1 - t * (1 - min)
    }
}

private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}
