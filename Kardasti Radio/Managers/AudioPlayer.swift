import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayer: ObservableObject {
    @MainActor static let shared = AudioPlayer()
    @Published var isPlaying = false
    @Published var isBuffering = false
    @Published var nowPlayingManager = NowPlayingManager.shared
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var itemStatusObserver: NSKeyValueObservation?
    private var retryCount = 0
    private let maxRetries = 3
    
    private init() {
        setupPlayer()
        setupNotifications()
    }
    
    private func setupPlayer() {
        createPlayerItem()
    }
    
    private func createPlayerItem() {
        guard let url = URL(string: "https://stream.server5.de/listen/farsi/kardasti-radio.mp3") else {
            print("Failed to create URL")
            return
        }
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 1.0
        
        setupAudioSession()
        setupRemoteCommandCenter()
        observePlayerItem()
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlaying()
            }
        }
    }
    
    private func observePlayerItem() {
        itemStatusObserver?.invalidate()
        
        itemStatusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                self?.handlePlayerItemStatus(item.status)
            }
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStalled),
            name: NSNotification.Name.AVPlayerItemPlaybackStalled,
            object: playerItem
        )
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status) {
        switch status {
        case .readyToPlay:
            isBuffering = false
            if isPlaying {
                player?.play()
            }
        case .failed:
            handlePlaybackError()
        case .unknown:
            isBuffering = true
        @unknown default:
            break
        }
    }
    
    @objc private func handlePlaybackStalled() {
        handlePlaybackError()
    }
    
    private func handlePlaybackError() {
        if retryCount < maxRetries {
            retryCount += 1
            print("Attempting to reconnect... (Attempt \(retryCount)/\(maxRetries))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.recreatePlayer()
            }
        } else {
            print("Max retry attempts reached")
            isPlaying = false
            isBuffering = false
            retryCount = 0
        }
    }
    
    private func recreatePlayer() {
        player?.pause()
        player = nil
        playerItem = nil
        createPlayerItem()
        if isPlaying {
            play()
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
            
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil)
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            pause()
        default:
            break
        }
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
            isBuffering = true
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
        isBuffering = false
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
        itemStatusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
} 