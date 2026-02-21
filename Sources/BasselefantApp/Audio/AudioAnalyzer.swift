import Accelerate
import AVFoundation
import Foundation

final class AudioAnalyzer {
    private let eqEdges: [Double] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 12000]

    private var previousEnergy: Double = 0
    private var previousBass: Double = 0
    private var previousFlux: Double = 0
    private var previousBands: [Double] = Array(repeating: 0, count: 8)
    private var onsetTimes: [Double] = []
    private let startTime = CACurrentMediaTime()

    // Adaptive normalization state
    private var energyFloor: Double = 0.0008
    private var energyPeak: Double = 0.02
    private var bandNoiseFloor: [Double] = Array(repeating: 0.0001, count: 8)
    private var bandPeakHold: [Double] = Array(repeating: 0.002, count: 8)

    func analyze(buffer: AVAudioPCMBuffer, at sampleRate: Double) -> AudioFeature {
        guard let floatData = buffer.floatChannelData else { return .zero }
        let frameCount = Int(buffer.frameLength)
        if frameCount < 512 { return .zero }

        let channel = floatData[0]
        var samples = Array(UnsafeBufferPointer(start: channel, count: frameCount))

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(frameCount))
        let rawEnergy = Double(rms)
        let energy = normalizeEnergy(rawEnergy)

        let fftSize = 1 << Int(log2(Double(frameCount)).rounded(.down))
        samples = Array(samples.prefix(fftSize))
        if fftSize < 512 { return .zero }
        let halfCount = fftSize / 2

        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(samples, 1, window, 1, &samples, 1, vDSP_Length(fftSize))

        let log2n = vDSP_Length(log2(Double(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return AudioFeature(energy: energy)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var real = [Float](repeating: 0, count: halfCount)
        var imag = [Float](repeating: 0, count: halfCount)
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                samples.withUnsafeBufferPointer { inputPtr in
                    inputPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfCount) { typedPtr in
                        vDSP_ctoz(typedPtr, 2, &split, 1, vDSP_Length(halfCount))
                    }
                }
                vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        var mags = [Float](repeating: 0, count: halfCount)
        mags.withUnsafeMutableBufferPointer { magPtr in
            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    vDSP_zvmags(&split, 1, magPtr.baseAddress!, 1, vDSP_Length(halfCount))
                }
            }
        }

        let nyquist = sampleRate / 2
        let binHz = nyquist / Double(halfCount)

        let eqBands = analyzeEQBands(mags: mags, binHz: binHz, nyquist: nyquist)
        let bass = weightedBass(eqBands)
        let mid = weightedMid(eqBands)
        let treble = weightedTreble(eqBands)

        let centroid = spectralCentroid(mags: mags, binHz: binHz, nyquist: nyquist)
        let spectralFlux = detectSpectralFlux(currentBands: eqBands)
        let pulse = detectPulse(currentEnergy: energy, bass: bass, spectralFlux: spectralFlux)
        let tempo = estimateTempo(currentPulse: pulse)

        return AudioFeature(
            energy: energy,
            bass: bass,
            mid: mid,
            treble: treble,
            centroid: centroid,
            pulse: pulse,
            tempoEstimate: tempo,
            eqBands: eqBands,
            spectralFlux: spectralFlux
        )
    }

    private func analyzeEQBands(mags: [Float], binHz: Double, nyquist: Double) -> [Double] {
        var result = [Double](repeating: 0, count: 8)
        for i in 0..<8 {
            let low = eqEdges[i]
            let high = min(eqEdges[i + 1], nyquist * 0.98)
            let raw = bandEnergyRaw(mags: mags, binHz: binHz, low: low, high: high)
            result[i] = normalizeBand(raw: raw, index: i)
        }
        return result
    }

    private func bandEnergyRaw(mags: [Float], binHz: Double, low: Double, high: Double) -> Double {
        let start = max(0, Int(low / binHz))
        let end = min(mags.count - 1, Int(high / binHz))
        guard end > start else { return 0 }

        let band = mags[start...end]
        let meanPower = band.reduce(0.0) { $0 + Double($1) } / Double(band.count)
        return sqrt(max(meanPower, 0))
    }

    private func normalizeEnergy(_ raw: Double) -> Double {
        energyFloor = energyFloor * 0.996 + raw * 0.004
        energyPeak = max(raw, energyPeak * 0.997)
        let floor = energyFloor * 1.1
        let span = max(energyPeak - floor, 0.00001)
        let normalized = clamp((raw - floor) / span, 0, 1)
        return clamp(pow(normalized, 0.72), 0, 1)
    }

    private func normalizeBand(raw: Double, index: Int) -> Double {
        bandNoiseFloor[index] = bandNoiseFloor[index] * 0.995 + raw * 0.005
        bandPeakHold[index] = max(raw, bandPeakHold[index] * 0.996)
        let floor = bandNoiseFloor[index] * 1.08
        let span = max(bandPeakHold[index] - floor, 0.00001)
        let normalized = clamp((raw - floor) / span, 0, 1)
        return clamp(pow(normalized, 0.78), 0, 1)
    }

    private func weightedBass(_ bands: [Double]) -> Double {
        guard bands.count >= 3 else { return 0 }
        return clamp(bands[0] * 0.42 + bands[1] * 0.36 + bands[2] * 0.22, 0, 1)
    }

    private func weightedMid(_ bands: [Double]) -> Double {
        guard bands.count >= 6 else { return 0 }
        return clamp(bands[3] * 0.3 + bands[4] * 0.4 + bands[5] * 0.3, 0, 1)
    }

    private func weightedTreble(_ bands: [Double]) -> Double {
        guard bands.count >= 8 else { return 0 }
        return clamp(bands[6] * 0.52 + bands[7] * 0.48, 0, 1)
    }

    private func spectralCentroid(mags: [Float], binHz: Double, nyquist: Double) -> Double {
        var weighted: Double = 0
        var total: Double = 0
        for (index, mag) in mags.enumerated() {
            let m = Double(mag)
            let freq = Double(index) * binHz
            weighted += freq * m
            total += m
        }
        guard total > 0 else { return 0 }
        return clamp((weighted / total) / nyquist, 0, 1)
    }

    private func detectSpectralFlux(currentBands: [Double]) -> Double {
        guard currentBands.count == previousBands.count else {
            previousBands = currentBands
            return 0
        }

        var flux: Double = 0
        for i in 0..<currentBands.count {
            flux += max(0, currentBands[i] - previousBands[i])
        }
        flux /= Double(currentBands.count)
        previousBands = currentBands

        let amplified = clamp(flux * 2.4, 0, 1)
        let smoothed = previousFlux * 0.38 + amplified * 0.62
        previousFlux = smoothed
        return smoothed
    }

    private func detectPulse(currentEnergy: Double, bass: Double, spectralFlux: Double) -> Double {
        let energyDelta = currentEnergy - previousEnergy
        let bassRise = bass - previousBass

        previousEnergy = currentEnergy * 0.72 + previousEnergy * 0.28
        previousBass = bass * 0.7 + previousBass * 0.3

        let energySpike = clamp(energyDelta * 4.0, 0, 1)
        let bassSpike = clamp(bassRise * 3.1, 0, 1)
        let fluxSpike = clamp(spectralFlux * 1.4, 0, 1)
        let composite = clamp(energySpike * 0.42 + bassSpike * 0.36 + fluxSpike * 0.22, 0, 1)

        if composite > 0.35 {
            onsetTimes.append(CACurrentMediaTime() - startTime)
            if onsetTimes.count > 48 {
                onsetTimes.removeFirst(onsetTimes.count - 48)
            }
        }
        return composite
    }

    private func estimateTempo(currentPulse: Double) -> Double {
        guard onsetTimes.count > 6 else { return 120 + currentPulse * 20 }
        let intervals = zip(onsetTimes.dropFirst(), onsetTimes).map(-)
        let filtered = intervals.filter { $0 > 0.2 && $0 < 1.2 }
        guard !filtered.isEmpty else { return 120 }
        let avg = filtered.reduce(0, +) / Double(filtered.count)
        let bpm = 60.0 / avg
        return clamp(bpm, 68, 176)
    }
}

private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}
