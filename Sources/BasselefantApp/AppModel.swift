import AppKit
import Foundation
import SwiftUI

enum RecognitionSourceMode: String, CaseIterable, Identifiable {
    case hybrid
    case directOnly
    case microphoneOnly
    case loopbackOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hybrid:
            return "Hybrid (Direkt + Mikro)"
        case .directOnly:
            return "Nur Direkt (Spotify/Music, Mikro aus)"
        case .microphoneOnly:
            return "Nur Mikrofon"
        case .loopbackOnly:
            return "System Output (Loopback)"
        }
    }
}

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
    // 0...100, where 50 = neutral
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

@MainActor
final class AppModel: ObservableObject {
    @Published var feature: AudioFeature = .zero
    @Published var track: TrackInfo = .empty
    @Published var statusText: String = "Initialisiere Audio..."
    @Published var sourceMode: RecognitionSourceMode = .hybrid
    @Published var visualStyle: VisualStyle = .denseMonolith
    @Published var dynamicsPreset: VisualDynamicsPreset = .cinematic
    @Published var audioMapProfile: VisualAudioMapProfile = .balanced
    @Published var dynamicsTuning: VisualDynamicsTuning = .neutral
    @Published var autoGainEnabled: Bool = true
    @Published var autoUpdateEnabled: Bool = false
    @Published var updateInProgress: Bool = false
    @Published var audioInputs: [MicrophoneAudioService.InputDevice] = []
    @Published var selectedAudioInputID: String?
    @Published var displayTargets: [DisplayTarget] = []
    @Published var activeDisplayID: String?

    private let microphone = MicrophoneAudioService()
    private let directService = DirectNowPlayingService()
    private let externalDisplay = ExternalDisplayCoordinator()
    private let gainStoreKey = "basselefant.autoGainProfiles.v1"
    private let updaterRepoURL = "https://github.com/blackmaddin/Basselefant.git"
    private let updaterBranch = "main"
    private let updaterLaunchAgentLabel = "com.basselefant.autoupdate"
    private var lastDirectTrackDate: Date?
    private var observers: [NSObjectProtocol] = []
    private var previousFeature: AudioFeature = .zero
    private var gainProfiles: [String: Double] = [:]
    private var lastGainPersistDate: Date = .distantPast

    init() {
        loadGainProfiles()
        configurePipelines()
        configureDisplayMonitoring()
        boot()
    }

    private func configurePipelines() {
        microphone.onFeature = { [weak self] newFeature in
            Task { @MainActor in
                guard let self else { return }
                let gained = self.applyAutoGainIfNeeded(newFeature)
                let blended = self.blendFeature(previous: self.previousFeature, incoming: gained)
                self.previousFeature = blended
                self.feature = blended
                switch self.sourceMode {
                case .hybrid, .microphoneOnly, .loopbackOnly:
                    self.refreshMicFallbackTrack(with: blended)
                case .directOnly:
                    break
                }
            }
        }
        directService.onTrackUpdate = { [weak self] update in
            Task { @MainActor in
                guard let self else { return }
                guard self.sourceMode != .microphoneOnly else { return }
                if let update {
                    self.track = update
                    self.lastDirectTrackDate = Date()
                    self.statusText = "Direkter Track erkannt (\(update.source.rawValue))"
                } else {
                    if self.sourceMode == .directOnly {
                        self.track = self.waitingDirectTrack()
                        self.statusText = "Kein direkter Player gefunden (Spotify/Music inaktiv)"
                    } else {
                        self.statusText = "Kein direkter Player gefunden, Mikrofon-Fallback aktiv"
                    }
                }
            }
        }
    }

    private func boot() {
        refreshAudioInputs()
        refreshDisplays()
        refreshAutoUpdateState()
        directService.start()
        if sourceMode == .directOnly {
            statusText = "Direktmodus aktiv (Spotify/Music, Mikrofon aus)"
        } else {
            startMicrophone()
        }
    }

    private func refreshMicFallbackTrack(with feature: AudioFeature) {
        guard sourceMode != .directOnly else { return }
        if let lastDirectTrackDate, Date().timeIntervalSince(lastDirectTrackDate) < 6 {
            return
        }

        let descriptor = styleDescriptor(from: feature)
        let source: TrackInfo.Source = (sourceMode == .loopbackOnly) ? .loopback : .microphone
        let artist = sourceMode == .loopbackOnly ? "Loopback Input (\(activeInputName()))" : "Live Input"
        let title = sourceMode == .loopbackOnly ? "System Output Groove" : "Unidentified Groove"
        track = TrackInfo(
            title: title,
            artist: artist,
            album: "Signal Flow",
            source: source,
            confidence: clamp(0.45 + feature.energy * 0.45, 0.3, 0.88),
            bpm: feature.tempoEstimate,
            descriptor: descriptor
        )
    }

    func setSourceMode(_ mode: RecognitionSourceMode) {
        sourceMode = mode
        switch mode {
        case .hybrid:
            startMicrophone()
            statusText = "Hybrid-Modus aktiv (Direkt + Mikrofon)"
            refreshMicFallbackTrack(with: feature)
        case .directOnly:
            stopMicrophoneForDirectMode()
            if isDirectSource(track.source) == false {
                track = waitingDirectTrack()
            }
            statusText = "Direktmodus aktiv (Spotify/Music, Mikrofon aus)"
        case .microphoneOnly:
            startMicrophone()
            lastDirectTrackDate = nil
            refreshMicFallbackTrack(with: feature)
            statusText = "Mikrofonmodus aktiv"
        case .loopbackOnly:
            startMicrophone()
            lastDirectTrackDate = nil
            if activatePreferredLoopbackInput() {
                refreshMicFallbackTrack(with: feature)
                statusText = "Loopback-Modus aktiv (\(activeInputName()))"
            } else {
                statusText = "Kein Loopback-Device gefunden (z. B. BlackHole/Loopback/Soundflower)"
            }
        }
    }

    func setDynamicsPreset(_ preset: VisualDynamicsPreset) {
        dynamicsPreset = preset
        statusText = "Dynamics preset: \(preset.title)"
    }

    func setAudioMapProfile(_ profile: VisualAudioMapProfile) {
        audioMapProfile = profile
        statusText = "Audio map: \(profile.title)"
    }

    func resetDynamicsTuning() {
        dynamicsTuning = .neutral
        statusText = "Dynamics fine tuning reset"
    }

    func resetAutoGainProfiles() {
        gainProfiles = [:]
        persistGainProfiles()
        statusText = "Auto gain profiles reset"
    }

    func runUpdateNowForDummies() {
        guard !updateInProgress else { return }
        updateInProgress = true
        statusText = "Update laeuft..."

        Task {
            do {
                let scriptURL = try ensureUpdaterScript()
                _ = try await Self.runProcess(executable: "/bin/zsh", arguments: [scriptURL.path])
                updateInProgress = false
                statusText = "Update installiert, starte neu..."
                relaunchInstalledApp()
            } catch {
                updateInProgress = false
                statusText = "Update fehlgeschlagen: \(error.localizedDescription)"
            }
        }
    }

    func setAutoUpdateEnabledForDummies(_ enabled: Bool) {
        guard autoUpdateEnabled != enabled else { return }
        if enabled {
            statusText = "Auto-Update wird aktiviert..."
        } else {
            statusText = "Auto-Update wird deaktiviert..."
        }

        Task {
            do {
                if enabled {
                    let plistURL = try ensureAutoUpdateAgent()
                    _ = try? await Self.runProcess(executable: "/bin/launchctl", arguments: ["unload", "-w", plistURL.path])
                    _ = try await Self.runProcess(executable: "/bin/launchctl", arguments: ["load", "-w", plistURL.path])
                    autoUpdateEnabled = true
                    statusText = "Auto-Update aktiv (alle 6h)"
                } else {
                    let plistURL = updaterLaunchAgentURL()
                    _ = try? await Self.runProcess(executable: "/bin/launchctl", arguments: ["unload", "-w", plistURL.path])
                    autoUpdateEnabled = false
                    statusText = "Auto-Update deaktiviert"
                }
            } catch {
                autoUpdateEnabled = false
                statusText = "Auto-Update Fehler: \(error.localizedDescription)"
            }
        }
    }

    func refreshAudioInputs() {
        audioInputs = microphone.availableInputDevices()
        selectedAudioInputID = microphone.currentInputDeviceID()
    }

    func selectAudioInput(id: String) {
        guard microphone.selectInputDevice(id: id) else {
            statusText = "Konnte Mikrofon nicht umstellen"
            return
        }

        selectedAudioInputID = id
        refreshAudioInputs()
        statusText = sourceMode == .directOnly ? "Mikrofon-Auswahl gespeichert (Direktmodus aktiv)" : "Mikrofon umgestellt"

        guard sourceMode != .directOnly else { return }

        Task {
            do {
                try await microphone.restart()
                statusText = "Audioeingang aktiv (\(activeInputName()))"
            } catch {
                statusText = "Audiofehler nach Mikrofonwechsel: \(error.localizedDescription)"
            }
        }
    }

    private func activatePreferredLoopbackInput() -> Bool {
        refreshAudioInputs()
        guard let loopback = audioInputs.first(where: { isLikelyLoopbackName($0.name) }) else {
            return false
        }
        if selectedAudioInputID != loopback.id {
            selectAudioInput(id: loopback.id)
        }
        return true
    }

    private func isLikelyLoopbackName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let tokens = ["blackhole", "loopback", "soundflower", "vb-cable", "cable output", "virtual", "aggregate"]
        return tokens.contains(where: { lower.contains($0) })
    }

    private func startMicrophone() {
        Task {
            guard sourceMode != .directOnly else { return }
            do {
                try await microphone.start()
                if sourceMode == .directOnly {
                    microphone.stop()
                    return
                }
                refreshAudioInputs()
                statusText = "Audioeingang aktiv (\(activeInputName()))"
            } catch {
                statusText = "Audiofehler: \(error.localizedDescription)"
            }
        }
    }

    private func stopMicrophoneForDirectMode() {
        microphone.stop()
        previousFeature = .zero
        feature = .zero
    }

    func activeInputName() -> String {
        if let selectedAudioInputID,
           let input = audioInputs.first(where: { $0.id == selectedAudioInputID }) {
            return input.name
        }
        return "System Standard"
    }

    private func styleDescriptor(from feature: AudioFeature) -> String {
        let bpm = Int(feature.tempoEstimate.rounded())
        let bright = feature.treble > 0.55
        let bassHeavy = feature.bass > 0.58
        let pulse = feature.pulse > 0.35

        if bassHeavy && pulse {
            return "Treibender Peak-House, ca. \(bpm) BPM"
        }
        if bassHeavy && !bright {
            return "Druckvoller Techno-Unterbau, ca. \(bpm) BPM"
        }
        if bright && feature.mid > 0.4 {
            return "Elektro-Hybrid mit offenem Top-End, ca. \(bpm) BPM"
        }
        return "Abstrakter Clubflow, ca. \(bpm) BPM"
    }

    private func configureDisplayMonitoring() {
        let token = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDisplays()
            }
        }
        observers.append(token)
    }

    func refreshDisplays() {
        displayTargets = NSScreen.screens.map { screen in
            let name = screen.localizedName
            let isAirPlay = name.localizedCaseInsensitiveContains("airplay")
                || name.localizedCaseInsensitiveContains("apple tv")
            return DisplayTarget(
                id: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")].map { "\($0)" } ?? UUID().uuidString,
                name: name,
                size: "\(Int(screen.frame.width))x\(Int(screen.frame.height))",
                isAirPlay: isAirPlay
            )
        }
        guard let activeDisplayID else { return }
        if displayTargets.contains(where: { $0.id == activeDisplayID }) == false {
            stopExternalPresentation()
        }
    }

    func presentOnDisplay(id: String) {
        guard let screen = screenFor(id: id) else { return }
        externalDisplay.present(on: screen, model: self)
        activeDisplayID = id
        statusText = "Visuals auf externem Display aktiv"
    }

    func stopExternalPresentation() {
        externalDisplay.dismiss()
        activeDisplayID = nil
        statusText = "Externe Ausgabe beendet"
    }

    func openDisplaySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.Displays-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.displays"
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private func screenFor(id: String) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")].map { "\($0)" } ?? "") == id
        }
    }

    private func refreshAutoUpdateState() {
        autoUpdateEnabled = FileManager.default.fileExists(atPath: updaterLaunchAgentURL().path)
    }

    private func relaunchInstalledApp() {
        let appURL = URL(fileURLWithPath: "/Applications/Basselefant.app")
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if error == nil {
                NSApplication.shared.terminate(nil)
            } else {
                Task { @MainActor in
                    self.statusText = "Update installiert. Bitte manuell neu starten."
                }
            }
        }
    }

    private func ensureAutoUpdateAgent() throws -> URL {
        let scriptURL = try ensureUpdaterScript()
        let plistURL = updaterLaunchAgentURL()
        let logsURL = updaterLogsURL()

        try FileManager.default.createDirectory(
            at: logsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(xmlEscape(updaterLaunchAgentLabel))</string>
          <key>ProgramArguments</key>
          <array>
            <string>/bin/zsh</string>
            <string>\(xmlEscape(scriptURL.path))</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>StartInterval</key>
          <integer>21600</integer>
          <key>StandardOutPath</key>
          <string>\(xmlEscape(logsURL.path))</string>
          <key>StandardErrorPath</key>
          <string>\(xmlEscape(logsURL.path))</string>
        </dict>
        </plist>
        """
        try plist.write(to: plistURL, atomically: true, encoding: .utf8)
        return plistURL
    }

    private func ensureUpdaterScript() throws -> URL {
        let scriptURL = updaterScriptURL()
        try FileManager.default.createDirectory(
            at: scriptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let script = """
        #!/bin/zsh
        set -euo pipefail

        REPO_DIR="$HOME/.basselefant/repo"
        if [ ! -d "$REPO_DIR/.git" ]; then
          mkdir -p "$(dirname "$REPO_DIR")"
          git clone "\(updaterRepoURL)" "$REPO_DIR"
        fi

        cd "$REPO_DIR"
        git fetch origin "\(updaterBranch)"
        git pull --ff-only origin "\(updaterBranch)"
        "$REPO_DIR/scripts/build_app.sh"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: scriptURL.path)
        return scriptURL
    }

    private func updaterScriptURL() -> URL {
        let base = NSString(string: "~/Library/Application Support/Basselefant").expandingTildeInPath
        return URL(fileURLWithPath: base).appendingPathComponent("update.sh")
    }

    private func updaterLaunchAgentURL() -> URL {
        let path = NSString(string: "~/Library/LaunchAgents/\(updaterLaunchAgentLabel).plist").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    private func updaterLogsURL() -> URL {
        let path = NSString(string: "~/Library/Logs/BasselefantUpdater.log").expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    private func xmlEscape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func waitingDirectTrack() -> TrackInfo {
        TrackInfo(
            title: "Warte auf Spotify/Music",
            artist: "Direkter Input",
            album: "",
            source: .unknown,
            confidence: 0,
            bpm: nil,
            descriptor: "Starte Wiedergabe in Spotify oder Music.app"
        )
    }

    private func isDirectSource(_ source: TrackInfo.Source) -> Bool {
        source == .spotify || source == .appleMusic
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
            energy: mix(previous.energy, incoming.energy, 0.32),
            bass: mix(previous.bass, incoming.bass, 0.42),
            mid: mix(previous.mid, incoming.mid, 0.35),
            treble: mix(previous.treble, incoming.treble, 0.38),
            centroid: mix(previous.centroid, incoming.centroid, 0.28),
            pulse: min(1, mix(previous.pulse, pulse, 0.55)),
            tempoEstimate: mix(previous.tempoEstimate, incoming.tempoEstimate, 0.2),
            eqBands: blendedBands,
            spectralFlux: mix(previous.spectralFlux, incoming.spectralFlux, 0.45)
        )
    }

    private func mix(_ a: Double, _ b: Double, _ alpha: Double) -> Double {
        a * (1 - alpha) + b * alpha
    }

    private func applyAutoGainIfNeeded(_ feature: AudioFeature) -> AudioFeature {
        guard autoGainEnabled else { return feature }

        let key = gainProfileKey()
        let oldGain = gainProfiles[key] ?? 1.0
        let targetEnergy = (sourceMode == .loopbackOnly) ? 0.5 : 0.42
        let error = targetEnergy - feature.energy
        var gain = oldGain + error * 0.085
        if feature.energy > 0.9 { gain *= 0.95 }
        if feature.energy < 0.08 { gain *= 1.03 }
        gain = clamp(gain, 0.45, 2.8)
        gainProfiles[key] = gain
        persistGainProfilesIfNeeded()

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

    private func gainProfileKey() -> String {
        let input = selectedAudioInputID ?? "default"
        switch sourceMode {
        case .hybrid:
            return "hybrid:\(input)"
        case .directOnly:
            return "direct"
        case .microphoneOnly:
            return "mic:\(input)"
        case .loopbackOnly:
            return "loopback:\(input)"
        }
    }

    private func loadGainProfiles() {
        if let saved = UserDefaults.standard.dictionary(forKey: gainStoreKey) as? [String: Double] {
            gainProfiles = saved
        }
    }

    private func persistGainProfilesIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastGainPersistDate) > 1.5 else { return }
        persistGainProfiles()
        lastGainPersistDate = now
    }

    private func persistGainProfiles() {
        UserDefaults.standard.set(gainProfiles, forKey: gainStoreKey)
    }

    private nonisolated static func runProcess(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe
            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: UpdaterProcessError.failed(status: proc.terminationStatus, output: output))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private enum UpdaterProcessError: LocalizedError {
    case failed(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case let .failed(status, output):
            let clean = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.isEmpty {
                return "Process fehlgeschlagen (Exit \(status))."
            }
            return "Process fehlgeschlagen (Exit \(status)): \(clean)"
        }
    }
}

private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
    min(max(value, minValue), maxValue)
}
