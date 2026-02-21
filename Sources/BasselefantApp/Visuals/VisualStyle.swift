import Foundation

enum VisualStyle: String, CaseIterable, Identifiable {
    case denseMonolith
    case ultraMinimal
    case industrialEmblem

    var id: String { rawValue }

    var title: String {
        switch self {
        case .denseMonolith:
            return "Dense Monolith"
        case .ultraMinimal:
            return "Ultra Minimal"
        case .industrialEmblem:
            return "Industrial Emblem"
        }
    }

    var menuSymbol: String {
        switch self {
        case .denseMonolith:
            return "mountain.2"
        case .ultraMinimal:
            return "circle.dotted"
        case .industrialEmblem:
            return "hexagon"
        }
    }
}
