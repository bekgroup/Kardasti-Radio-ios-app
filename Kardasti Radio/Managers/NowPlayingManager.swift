import Foundation
import SwiftUI

@MainActor
class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager()
    private let apiUrl = "https://stream.server5.de/api/nowplaying/farsi"
    private var timer: Timer?
    
    @Published var currentTrack: NowPlayingResponse?
    @Published var error: Error?
    
    init() {
        Task {
            await startPolling()
        }
    }
    
    func startPolling() async {
        // Sofort erste Abfrage starten
        await fetchNowPlaying()
        
        // Timer für regelmäßige Aktualisierung (alle 30 Sekunden)
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                Task {
                    await self?.fetchNowPlaying()
                }
            }
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    private func fetchNowPlaying() async {
        guard let url = URL(string: apiUrl) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(NowPlayingResponse.self, from: data)
            currentTrack = response
        } catch {
            self.error = error
        }
    }
} 