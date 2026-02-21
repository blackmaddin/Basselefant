import Foundation

@MainActor
final class IOSAppModel: ObservableObject {
    @Published var feature: AudioFeature = .zero
    @Published var statusText: String = "Initialisiere Mikrofon..."
    @Published var visualStyle: VisualStyle = .denseMonolith
    @Published var dynamicsPreset: VisualDynamicsPreset = .cinematic
    @Published var audioMapProfile: VisualAudioMapProfile = .balanced
    @Published var dynamicsTuning: VisualDynamicsTuning = .neutral
    @Published var autoGainEnabled: Bool = true

    private let microphone = IOSMicrophoneAudioService()
    private var previousFeature: AudioFeature = .zero
    private var running = false
    private var gain: Double = 1.0

    init() {
        microphone.onFeature = { [weak self] incoming in
            Task { @MainActor in
                guard let self else { return }
                let gained = self.applyAutoGainIfNeeded(incoming)
                let blended = self.blendFeature(previous: self.previousFeature, incoming: gained)
                self.previousFeature = blended
                self.feature = blended
            }
        }
    }

    func start() {
        guard !running else { return }
        running = true
        statusText = "Mikrofon wird gestartet..."
        Task {
            do {
                try await microphone.start()
                statusText = "Mikrofon aktiv"
            } catch {
                running = false
                statusText = "Audiofehler: \(error.localizedDescription)"
            }
        }
    }

    func stop() {
        guard running else { return }
        microphone.stop()
        running = false
    }

    private func blendFeature(previous: AudioFeature, incoming: AudioFeature) -> AudioFeature {
        var pulse = incoming.pulse
        let bassDelta = max(0, incoming.bass - previous.bass)
        pulse = max(pulse, bassDelta * 2.2)

        let bandCount = max(previous.eqBands.count, incoming.eqBands.count)
        var blendedBands = [Double](repeating: 0, count: bandCount)
        if bandCount > 0 {
            for i in 0..<bandCount {
                let prev = previous.eqBands.indices.contains(i) ? previous.eqBands[i] : 0
                let next = incoming.eqBands.indices.contains(i) ? incoming.eqBands[i] : 0
                blendedBands[i] = mix(prev, next, 0.46)
            }
        }

        return AudioFeature(
            energy: mix(previous.energy, incoming.energy, 0.34),
            bass: mix(previous.bass, incoming.bass, 0.44),
            mid: mix(previous.mid, incoming.mid, 0.36),
            treble: mix(previous.treble, incoming.treble, 0.4),
            centroid: mix(previous.centroid, incoming.centroid, 0.28),
            pulse: min(1, mix(previous.pulse, pulse, 0.55)),
            tempoEstimate: mix(previous.tempoEstimate, incoming.tempoEstimate, 0.22),
            eqBands: blendedBands,
            spectralFlux: mix(previous.spectralFlux, incoming.spectralFlux, 0.45)
        )
    }

    private func applyAutoGainIfNeeded(_ feature: AudioFeature) -> AudioFeature {
        guard autoGainEnabled else { return feature }

        let targetEnergy = 0.45
        let error = targetEnergy - feature.energy
        gain += error * 0.085
        if feature.energy > 0.9 { gain *= 0.95 }
        if feature.energy < 0.08 { gain *= 1.03 }
        gain = clamp(gain, 0.45, 2.8)

        let bandGain = pow(gain, 0.88)
        let pulseGain = min(1.4, 0.75 + gain * 0.42)
        let fluxGain = min(1.45, 0.78 + gain * 0.46)
        return AudioFeature(
            energy: clamp(feature.energy * gain, 0, 1),
            bass: clamp(feature.bass * bandGain, 0, 1),
            mid: clamp(feature.mid * bandGain, 0, 1),
            treble: clamp(feature.treble * bandGain, 0, 1),
            centroid: feature.centroid,
            pulse: clamp(feature.pulse * pulseGain, 0, 1),
            tempoEstimate: feature.tempoEstimate,
            eqBands: feature.eqBands.map { clamp($0 * bandGain, 0, 1) },
            spectralFlux: clamp(feature.spectralFlux * fluxGain, 0, 1)
        )
    }

    private func mix(_ a: Double, _ b: Double, _ alpha: Double) -> Double {
        a * (1 - alpha) + b * alpha
    }

    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
