import AVFoundation
import CoreAudio
import Foundation

final class MicrophoneAudioService {
    struct InputDevice: Identifiable, Equatable, Sendable {
        let id: String
        let name: String
        let isDefault: Bool
    }

    enum MicrophoneError: LocalizedError {
        case noInput
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .noInput:
                return "Kein Mikrofon-Eingang verfügbar."
            case .permissionDenied:
                return "Mikrofonzugriff wurde nicht erlaubt."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let analyzer = AudioAnalyzer()
    private let queue = DispatchQueue(label: "basselefant.audio.analyzer")
    private var started = false

    var onFeature: @Sendable (AudioFeature) -> Void = { _ in }

    func start() async throws {
        guard !started else { return }
        let allowed = await requestPermission()
        guard allowed else { throw MicrophoneError.permissionDenied }

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
        started = false
    }

    func restart() async throws {
        stop()
        try await start()
    }

    func availableInputDevices() -> [InputDevice] {
        let currentDefault = defaultInputDeviceID()
        return allDeviceIDs()
            .filter { hasInputChannels(deviceID: $0) }
            .map { id in
                InputDevice(
                    id: "\(id)",
                    name: deviceName(deviceID: id),
                    isDefault: currentDefault == id
                )
            }
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault {
                    return lhs.isDefault && !rhs.isDefault
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    func currentInputDeviceID() -> String? {
        guard let id = defaultInputDeviceID() else { return nil }
        return "\(id)"
    }

    func selectInputDevice(id: String) -> Bool {
        guard let parsed = UInt32(id) else { return false }
        let rawID = AudioDeviceID(parsed)
        return setDefaultInputDevice(rawID)
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func allDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func hasInputChannels(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else { return false }

        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, raw) == noErr else { return false }
        let bufferList = raw.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        let channelCount = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
        return channelCount > 0
    }

    private func deviceName(deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameBuffer = [CChar](repeating: 0, count: 256)
        var size = UInt32(nameBuffer.count)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &nameBuffer)
        if status == noErr, let name = String(validatingCString: nameBuffer), !name.isEmpty {
            return name
        }
        return "Input \(deviceID)"
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &id) == noErr else { return nil }
        return id
    }

    private func setDefaultInputDevice(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableID = id
        let system = AudioObjectID(kAudioObjectSystemObject)
        return AudioObjectSetPropertyData(
            system,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableID
        ) == noErr
    }
}
