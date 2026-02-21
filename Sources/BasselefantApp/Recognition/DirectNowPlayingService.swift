import AppKit
import Foundation

final class DirectNowPlayingService {
    private var timer: Timer?
    var onTrackUpdate: @Sendable (TrackInfo?) -> Void = { _ in }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 0.3
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        if let spotify = fetchSpotify() {
            onTrackUpdate(spotify)
            return
        }
        if let music = fetchMusicApp() {
            onTrackUpdate(music)
            return
        }
        onTrackUpdate(nil)
    }

    private func fetchSpotify() -> TrackInfo? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                if player state is playing then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    return tName & "||" & tArtist & "||" & tAlbum
                end if
            end tell
        end if
        return ""
        """
        guard let raw = run(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 3 else { return nil }
        return TrackInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            source: .spotify,
            confidence: 0.97,
            bpm: nil,
            descriptor: "Direkt aus Spotify gelesen"
        )
    }

    private func fetchMusicApp() -> TrackInfo? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                if player state is playing then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    return tName & "||" & tArtist & "||" & tAlbum
                end if
            end tell
        end if
        return ""
        """
        guard let raw = run(script), !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "||")
        guard parts.count >= 3 else { return nil }
        return TrackInfo(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            source: .appleMusic,
            confidence: 0.96,
            bpm: nil,
            descriptor: "Direkt aus Music.app gelesen"
        )
    }

    private func run(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let output = script?.executeAndReturnError(&error).stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if error != nil { return nil }
        return output
    }
}
