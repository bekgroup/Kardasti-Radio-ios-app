import AVFoundation
import MediaPlayer

@MainActor
class KardastiAudioPlayer: NSObject, ObservableObject {
    @MainActor static let shared = KardastiAudioPlayer()
    @Published var isPlaying = false
    @Published var nowPlayingManager = NowPlayingManager.shared
    private var player: AVPlayer?
    private var timeObserver: Any?
    
    private override init() {
        super.init()
        setupPlayer()
        setupNotifications()
    }
    
    private func setupPlayer() {
        guard let url = URL(string: "https://stream.server5.de/listen/farsi/kardasti-radio.mp3") else {
            print("Failed to create URL")
            return
        }
        
        // Erweiterte Streaming-Konfiguration
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 4.0
        
        player = AVPlayer(playerItem: playerItem)
        player?.automaticallyWaitsToMinimizeStalling = true
        player?.volume = 1.0
        
        // Status-Überwachung
        playerItem.addObserver(
            self, 
            forKeyPath: #keyPath(AVPlayerItem.status),
            options: [.new],
            context: nil
        )
        
        setupAudioSession()
        setupRemoteCommandCenter()
        setupNowPlaying() // Sofort Now Playing initialisieren
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // Einfache Grundkonfiguration
            try session.setCategory(.playback)
            try session.setActive(true)
            
            // Warte kurz und versuche dann die erweiterten Optionen
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                do {
                    try session.setCategory(
                        .playback,
                        mode: .default,
                        options: [.allowBluetooth, .allowBluetoothA2DP]
                    )
                } catch {
                    print("Failed to set extended audio options: \(error)")
                }
            }
        } catch {
            print("Basic audio session setup failed: \(error)")
        }
    }
    
    private func setupNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        
        // Grundlegende Informationen
        nowPlayingInfo[MPMediaItemPropertyTitle] = nowPlayingManager.currentTrack?.nowPlaying.song.title ?? "Kardasti Radio"
        nowPlayingInfo[MPMediaItemPropertyArtist] = nowPlayingManager.currentTrack?.nowPlaying.song.artist ?? "Live Stream"
        nowPlayingInfo[MPNowPlayingInfoPropertyIsLiveStream] = true
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        
        // Artwork mit korrekter Größe und Format
        if let image = UIImage(named: "RadioLogo") {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { size in
                let renderer = UIGraphicsImageRenderer(size: size)
                return renderer.image { context in
                    // Weißer Hintergrund
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    
                    // Bild zentriert zeichnen
                    let rect = CGRect(origin: .zero, size: size)
                    image.draw(in: rect)
                }
            }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        // Now Playing Info aktualisieren
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        // Remote Control Events aktivieren
        UIApplication.shared.beginReceivingRemoteControlEvents()
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
            let session = AVAudioSession.sharedInstance()
            
            // Vereinfachte Session-Aktivierung
            if !session.isOtherAudioPlaying {
                try session.setActive(true)
            }
            
            // Stelle sicher, dass der Player existiert
            if player == nil || player?.currentItem?.status == .failed {
                setupPlayer()
            }
            
            // Verzögertes Abspielen
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                player?.play()
                isPlaying = true
                await updateNowPlaying()
            }
        } catch {
            print("Play failed: \(error)")
            
            // Neuinitialisierung bei Fehler
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                setupPlayer()
                player?.play()
                isPlaying = true
            }
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        
        Task {
            await updateNowPlaying()
        }
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
                let session = AVAudioSession.sharedInstance()
                // Vereinfachte Background-Konfiguration
                try session.setCategory(.playback)
                try session.setActive(true)
                player?.play()
                
                Task {
                    await updateNowPlaying()
                }
            } catch {
                print("Background transition failed: \(error)")
            }
        }
    }
    
    private func updateNowPlaying() async {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        
        // Aktualisiere Titel und Artist
        nowPlayingInfo[MPMediaItemPropertyTitle] = nowPlayingManager.currentTrack?.nowPlaying.song.title ?? "Kardasti Radio"
        nowPlayingInfo[MPMediaItemPropertyArtist] = nowPlayingManager.currentTrack?.nowPlaying.song.artist ?? "Live Stream"
        
        // Stelle sicher, dass das Artwork vorhanden ist
        if nowPlayingInfo[MPMediaItemPropertyArtwork] == nil,
           let image = UIImage(named: "RadioLogo") {
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
        
        // Aktualisiere die Anzeige
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Vorherige Targets entfernen
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
        // Lautstärkeregelung aktivieren
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        
        // Grundlegende Befehle aktivieren
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        
        // Play Command
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause Command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Toggle Play/Pause Command
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true {
                self?.pause()
            } else {
                self?.play()
            }
            return .success
        }
    }
    
    // Neue Methode für Lautstärkeregelung
    private func adjustVolume(by delta: Float) {
        guard let player = player else { return }
        let newVolume = max(0, min(1, player.volume + delta))
        player.volume = newVolume
        
        // Update Now Playing Info ohne Lautstärke
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        nowPlayingInfo[MPMediaItemPropertyTitle] = nowPlayingManager.currentTrack?.nowPlaying.song.title ?? "Kardasti Radio"
        nowPlayingInfo[MPMediaItemPropertyArtist] = nowPlayingManager.currentTrack?.nowPlaying.song.artist ?? "Live Stream"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
        
        // Cleanup
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
    
    // KVO Methode für Player Status
    override public func observeValue(forKeyPath keyPath: String?,
                                    of object: Any?,
                                    change: [NSKeyValueChangeKey : Any]?,
                                    context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            switch status {
            case .readyToPlay:
                print("Player ist bereit zum Abspielen")
            case .failed:
                if let error = player?.currentItem?.error {
                    print("Player Fehler: \(error.localizedDescription)")
                    handlePlaybackError()
                }
            case .unknown:
                print("Player Status unbekannt")
            @unknown default:
                break
            }
        }
    }
    
    private func handlePlaybackError() {
        Task { @MainActor in
            print("Handling playback error...")
            
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setActive(false)
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Minimale Neukonfiguration
                try session.setCategory(.playback)
                try session.setActive(true)
                
                // Player neu initialisieren
                player = nil
                setupPlayer()
                
                if isPlaying {
                    player?.play()
                }
            } catch {
                print("Recovery failed: \(error)")
            }
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }
        
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
    
    @objc private func handlePlaybackStall() {
        print("Playback stalled, attempting recovery...")
        Task { @MainActor in
            // Längere Pause vor dem Neuversuch für bessere Pufferung
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            if isPlaying {
                // Sanftere Wiederherstellung
                player?.pause()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // Stelle sicher, dass genug gepuffert wurde
                if let player = player, 
                   let currentItem = player.currentItem,
                   currentItem.status == .readyToPlay {
                    player.play()
                    print("Playback resumed after buffering")
                } else {
                    // Kompletter Neustart wenn nötig
                    setupPlayer()
                    player?.play()
                }
            }
        }
    }
} 