import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()
    private var player: AVPlayer?
    @Published var isPlaying = false
    @Published var volume: Float = 1.0 {
        didSet {
            player?.volume = volume
        }
    }
    @Published var nowPlayingManager = NowPlayingManager.shared
    
    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
        setupNotifications()
    }
    
    private func setupAudioSession() {
        Task {
            do {
                try AVAudioSession.sharedInstance().setCategory(
                    .playback,
                    mode: .default,
                    options: [.mixWithOthers, .allowAirPlay, .defaultToSpeaker]
                )
                try AVAudioSession.sharedInstance().setActive(true)
                
                // Enable background modes
                UIApplication.shared.beginReceivingRemoteControlEvents()
                
                // Set audio session active with options
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to set audio session category: \(error)")
            }
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        Task { @MainActor in
            switch reason {
            case .oldDeviceUnavailable:
                pause()
            case .newDeviceAvailable:
                if isPlaying {
                    play()
                }
            default:
                break
            }
        }
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        Task { @MainActor in
            switch type {
            case .began:
                pause()
            case .ended:
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            @unknown default:
                break
            }
        }
    }
    
    func play() {
        if player == nil {
            let streamURL = URL(string: "https://stream.server5.de/listen/farsi/kardasti-radio.mp3")!
            let playerItem = AVPlayerItem(url: streamURL)
            player = AVPlayer(playerItem: playerItem)
            player?.volume = volume
            
            // Add periodic time observer
            player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.updateNowPlayingInfo()
                }
            }
        }
        
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        if let currentTrack = nowPlayingManager.currentTrack {
            // Titel und Künstler aus der API
            nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrack.nowPlaying.song.title
            nowPlayingInfo[MPMediaItemPropertyArtist] = currentTrack.nowPlaying.song.artist
            
            // Album Art laden und setzen (wenn verfügbar)
            if let artworkUrl = URL(string: currentTrack.nowPlaying.song.art) {
                loadArtwork(from: artworkUrl) { image in
                    if let image = image {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                    }
                }
            }
            
            // Wiedergabeinformationen
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTrack.nowPlaying.elapsed
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = currentTrack.nowPlaying.duration
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        } else {
            // Fallback wenn keine API-Daten verfügbar sind
            nowPlayingInfo[MPMediaItemPropertyTitle] = "Kardasti Radio"
            nowPlayingInfo[MPMediaItemPropertyArtist] = "Live Stream"
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func loadArtwork(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                if let data = data, error == nil {
                    completion(UIImage(data: data))
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
} 
