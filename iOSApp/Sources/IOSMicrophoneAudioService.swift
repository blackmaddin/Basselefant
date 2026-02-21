import AVFoundation
import Foundation

final class IOSMicrophoneAudioService {
    enum MicrophoneError: LocalizedError {
        case noInput
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noInput:
                return "Kein Mikrofon-Eingang verfuegbar."
            case .permissionDenied:
                return "Mikrofonzugriff wurde nicht erlaubt."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let analyzer = AudioAnalyzer()
    private let queue = DispatchQueue(label: "basselefant.ios.audio.analyzer")
    private var started = false

    var onFeature: @Sendable (AudioFeature) -> Void = { _ in }

    func start() async throws {
        guard !started else { return }
        let allowed = await requestPermission()
        guard allowed else { throw MicrophoneError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.mixWithOthers, .defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setPreferredIOBufferDuration(0.0058)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw MicrophoneError.noInput }

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let sampleRate = format.sampleRate
            queue.async {
                let feature = self.analyzer.analyze(buffer: buffer, at: sampleRate)
                self.onFeature(feature)
            }
        }

        engine.prepare()
        try engine.start()
        started = true
    }

    func stop() {
        guard started else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        started = false
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
