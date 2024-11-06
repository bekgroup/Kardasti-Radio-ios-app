import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayer: ObservableObject {
    @MainActor static let shared = AudioPlayer()
    @Published var isPlaying = false
    @Published var nowPlayingManager = NowPlayingManager.shared
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    private init() {
        setupPlayer()
        setupNotifications()
    }
    
    private func setupPlayer() {
        guard let url = URL(string: "https://stream.server5.de/listen/farsi/kardasti-radio.mp3") else {
            print("Failed to create URL")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 1.0
        
        setupAudioSession()
        setupRemoteCommandCenter()
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlaying()
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil)
    }
    
    @objc private func handleInterruption(notification: Notification) {
        Task { @MainActor in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            
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
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player?.play()
            isPlaying = true
            updateNowPlaying()
        } catch {
            print("Failed to play: \(error)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }
    
    func handleForegroundTransition() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            if isPlaying {
                player?.play()
            }
        } catch {
            print("Failed to handle foreground transition: \(error)")
        }
    }
    
    func handleBackgroundTransition() {
        if isPlaying {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to handle background transition: \(error)")
            }
        }
    }
    
    private func updateNowPlaying() {
        let title = nowPlayingManager.currentTrack?.nowPlaying.song.title ?? "Kardasti Radio"
        let artist = nowPlayingManager.currentTrack?.nowPlaying.song.artist ?? "Live Stream"
        
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = title
        nowPlayingInfo[MPMediaItemPropertyArtist] = artist
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteCommandCenter() {
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
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
    }
} 