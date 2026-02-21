import AppKit
import Foundation

final class DirectNowPlayingService {
    private enum ScriptRunResult {
        case success(String)
        case failure(code: Int, message: String)
    }

    private let queue = DispatchQueue(label: "basselefant.direct.nowplaying.poll")
    private let separator = Character(UnicodeScalar(31))
    private var timer: DispatchSourceTimer?
    private var lastDiagnostic: String?

    var onTrackUpdate: @Sendable (TrackInfo?) -> Void = { _ in }
    var onDiagnosticUpdate: @Sendable (String?) -> Void = { _ in }

    deinit {
        stop()
    }

    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(250))
        t.setEventHandler { [weak self] in
            self?.poll()
        }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
        publish(track: nil, diagnostic: nil)
    }

    func requestAuthorizationPrompt() {
        queue.async { [weak self] in
            guard let self else { return }
            _ = self.run(
                """
                tell application "Spotify"
                    if player state is playing then
                        return name of current track
                    end if
                end tell
                return ""
                """
            )
            _ = self.run(
                """
                tell application "Music"
                    if player state is playing then
                        return name of current track
                    end if
                end tell
                return ""
                """
            )
        }
    }

    private func poll() {
        var diagnostics: [String] = []
        if let spotify = fetchSpotify(diagnostics: &diagnostics) {
            publish(track: spotify, diagnostic: nil)
            return
        }
        if let music = fetchMusicApp(diagnostics: &diagnostics) {
            publish(track: music, diagnostic: nil)
            return
        }
        publish(track: nil, diagnostic: diagnostics.first)
    }

    private func fetchSpotify(diagnostics: inout [String]) -> TrackInfo? {
        guard isRunning(bundleID: "com.spotify.client") else { return nil }
        let script = """
        tell application "Spotify"
            if player state is playing or player state is paused then
                set pState to player state as text
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                return pState & "\(separator)" & tName & "\(separator)" & tArtist & "\(separator)" & tAlbum
            end if
        end tell
        return ""
        """

        switch run(script) {
        case let .success(raw):
            return parseTrack(raw: raw, source: .spotify, appName: "Spotify")
        case let .failure(code, message):
            if let hint = diagnosticHint(appName: "Spotify", code: code, message: message) {
                diagnostics.append(hint)
            }
            return nil
        }
    }

    private func fetchMusicApp(diagnostics: inout [String]) -> TrackInfo? {
        guard isRunning(bundleID: "com.apple.Music") else { return nil }
        let script = """
        tell application "Music"
            if player state is playing or player state is paused then
                set pState to player state as text
                set tName to name of current track
                set tArtist to artist of current track
                set tAlbum to album of current track
                return pState & "\(separator)" & tName & "\(separator)" & tArtist & "\(separator)" & tAlbum
            end if
        end tell
        return ""
        """

        switch run(script) {
        case let .success(raw):
            return parseTrack(raw: raw, source: .appleMusic, appName: "Music.app")
        case let .failure(code, message):
            if let hint = diagnosticHint(appName: "Music.app", code: code, message: message) {
                diagnostics.append(hint)
            }
            return nil
        }
    }

    private func parseTrack(raw: String, source: TrackInfo.Source, appName: String) -> TrackInfo? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4 else { return nil }

        let state = parts[0].lowercased()
        let isPaused = state.contains("pause")
        let descriptorSuffix = isPaused ? " (pausiert)" : ""
        return TrackInfo(
            title: parts[1],
            artist: parts[2],
            album: parts[3],
            source: source,
            confidence: isPaused ? 0.9 : 0.97,
            bpm: nil,
            descriptor: "Direkt aus \(appName) gelesen\(descriptorSuffix)"
        )
    }

    private func run(_ source: String) -> ScriptRunResult {
        guard let script = NSAppleScript(source: source) else {
            return .failure(code: -1, message: "AppleScript konnte nicht erzeugt werden.")
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? -1
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "Unbekannter AppleScript-Fehler"
            return .failure(code: code, message: message)
        }

        let output = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return .success(output)
    }

    private func isRunning(bundleID: String) -> Bool {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty == false
    }

    private func diagnosticHint(appName: String, code: Int, message: String) -> String? {
        switch code {
        case -1743:
            return "Automation fuer \(appName) blockiert. In macOS: Datenschutz & Sicherheit -> Automation -> Basselefant erlauben."
        case -1712:
            return "\(appName) antwortet nicht (Timeout). App neu starten und erneut testen."
        case -600:
            return nil
        default:
            if message.localizedCaseInsensitiveContains("not authorized") || message.localizedCaseInsensitiveContains("nicht berechtigt") {
                return "Automation fuer \(appName) nicht erlaubt. Bitte Automation-Rechte fuer Basselefant aktivieren."
            }
            return "Direktzugriff \(appName) Fehler (\(code)): \(message)"
        }
    }

    private func publish(track: TrackInfo?, diagnostic: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let deduped = normalizeDiagnostic(diagnostic)
            if self.lastDiagnostic != deduped {
                self.lastDiagnostic = deduped
                self.onDiagnosticUpdate(deduped)
            }
            self.onTrackUpdate(track)
        }
    }

    private func normalizeDiagnostic(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
