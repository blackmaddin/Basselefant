import Foundation

struct AudioFeature: Sendable {
    var energy: Double = 0
    var bass: Double = 0
    var mid: Double = 0
    var treble: Double = 0
    var centroid: Double = 0
    var pulse: Double = 0
    var tempoEstimate: Double = 120
    var eqBands: [Double] = Array(repeating: 0, count: 8)
    var spectralFlux: Double = 0

    static let zero = AudioFeature()
}

extension AudioFeature {
    func eqBand(_ index: Int) -> Double {
        guard eqBands.indices.contains(index) else { return 0 }
        return eqBands[index]
    }

    var eqLow: Double {
        if eqBands.isEmpty { return bass }
        return (eqBand(0) + eqBand(1) + eqBand(2)) / 3
    }

    var eqMid: Double {
        if eqBands.isEmpty { return mid }
        return (eqBand(3) + eqBand(4) + eqBand(5)) / 3
    }

    var eqHigh: Double {
        if eqBands.isEmpty { return treble }
        return (eqBand(6) + eqBand(7)) / 2
    }
}
