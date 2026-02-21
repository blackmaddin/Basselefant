import Foundation

struct TrackInfo: Equatable, Sendable {
    enum Source: String, Sendable {
        case appleMusic = "Music.app"
        case spotify = "Spotify"
        case microphone = "Mikrofon"
        case loopback = "Loopback"
        case unknown = "Unbekannt"
    }

    var title: String
    var artist: String
    var album: String
    var source: Source
    var confidence: Double
    var bpm: Double?
    var descriptor: String

    static let empty = TrackInfo(
        title: "Warte auf Musik",
        artist: "Basselefant",
        album: "",
        source: .unknown,
        confidence: 0,
        bpm: nil,
        descriptor: "Kein aktiver Stream erkannt"
    )
}
