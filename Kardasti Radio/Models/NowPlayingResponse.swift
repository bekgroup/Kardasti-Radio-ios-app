struct NowPlayingResponse: Codable {
    let station: Station
    let nowPlaying: NowPlaying
    let listeners: Listeners
    let isOnline: Bool
    
    enum CodingKeys: String, CodingKey {
        case station
        case nowPlaying = "now_playing"
        case listeners
        case isOnline = "is_online"
    }
}

struct Station: Codable {
    let name: String
    let description: String
    let listenUrl: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case listenUrl = "listen_url"
    }
}

struct NowPlaying: Codable {
    let playedAt: Int
    let duration: Int
    let playlist: String
    let song: Song
    let elapsed: Int
    let remaining: Int
    
    enum CodingKeys: String, CodingKey {
        case playedAt = "played_at"
        case duration
        case playlist
        case song
        case elapsed
        case remaining
    }
}

struct Song: Codable {
    let art: String
    let text: String
    let artist: String
    let title: String
}

struct Listeners: Codable {
    let total: Int
    let unique: Int
    let current: Int
} 