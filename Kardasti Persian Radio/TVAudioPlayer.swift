import AVFoundation
import MediaPlayer

@MainActor
class TVAudioPlayer: NSObject, ObservableObject {
    static let shared = TVAudioPlayer()
    @Published var isPlaying = false
    @Published var nowPlayingManager = NowPlayingManager.shared
    private var player: AVPlayer?
    
    private override init() {
        super.init()
        setupPlayer()
        setupNowPlaying()
    }
    
    private func setupPlayer() {
        guard let url = URL(string: "https://stream.server5.de/listen/farsi/kardasti-radio.mp3") else {
            print("Failed to create URL")
            return
        }
        
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10.0
        
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.volume = 1.0
        
        playerItem.addObserver(
            self,
            forKeyPath: #keyPath(AVPlayerItem.status),
            options: [.new],
            context: nil
        )
        
        setupAudioSession()
    }
    
    private func setupNowPlaying() {
        updateNowPlayingInfo()
    }
    
    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        // Use current track information
        nowPlayingInfo[MPMediaItemPropertyTitle] = nowPlayingManager.currentTrack?.nowPlaying.song.title ?? "Kardasti Radio"
        nowPlayingInfo[MPMediaItemPropertyArtist] = nowPlayingManager.currentTrack?.nowPlaying.song.artist ?? "Live Stream"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        if let image = UIImage(named: "RadioLogo") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { size in
                let renderer = UIGraphicsImageRenderer(size: size)
                return renderer.image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback)
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func handleForegroundTransition() {
        if isPlaying {
            player?.play()
            updateNowPlayingInfo()
        }
    }
    
    func handleBackgroundTransition() {
        updateNowPlayingInfo()
    }
    
    private func handlePlaybackError() {
        Task { @MainActor in
            print("Handling playback error...")
            player = nil
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            setupPlayer()
            setupNowPlaying()
            if isPlaying {
                player?.play()
                updateNowPlayingInfo()
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                             of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?,
                             context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            if let statusNumber = change?[.newKey] as? NSNumber,
               let status = AVPlayerItem.Status(rawValue: statusNumber.intValue) {
                switch status {
                case .readyToPlay:
                    print("TV Player ready to play")
                case .failed:
                    print("TV Player failed")
                    handlePlaybackError()
                case .unknown:
                    print("TV Player status unknown")
                @unknown default:
                    break
                }
            }
        }
    }
    
    deinit {
        player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
    }
} 