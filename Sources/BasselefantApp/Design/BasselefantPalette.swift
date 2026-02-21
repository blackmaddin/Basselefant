import SwiftUI

enum BasselefantPalette {
    static func backgroundColors(for feature: AudioFeature) -> [Color] {
        let bass = feature.bass
        let top = Color(
            red: 0.03 + bass * 0.22,
            green: 0.04 + feature.mid * 0.12,
            blue: 0.07 + feature.treble * 0.18
        )
        let bottom = Color(
            red: 0.25 + bass * 0.35,
            green: 0.08 + feature.energy * 0.18,
            blue: 0.12 + feature.centroid * 0.22
        )
        return [top, bottom]
    }

    static func accent(for feature: AudioFeature, offset: Double = 0) -> Color {
        let hue = (0.03 + feature.centroid * 0.25 + offset).truncatingRemainder(dividingBy: 1)
        let sat = 0.55 + feature.mid * 0.35
        let bri = 0.7 + feature.energy * 0.28
        return Color(hue: hue, saturation: sat, brightness: bri)
    }
}
