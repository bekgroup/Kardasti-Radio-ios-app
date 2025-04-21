//
//  ContentView.swift
//  Kardasti Radio App Watch Watch App
//
//  Created by BEK Service GmbH on 07.11.24.
//

import SwiftUI
import AVFoundation
import WatchKit

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayer()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            // Hintergrund-Gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.8), Color.blue.opacity(0.3)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // Header mit Logo
                Image(systemName: "radio.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding(.top, 5)
                
                Text("KARDASTI")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.2)
                
                Spacer()
                
                // Now Playing Anzeige
                if audioPlayer.isPlaying {
                    VStack(spacing: 6) {
                        // Pulsierende Wellenform
                        HStack(spacing: 3) {
                            ForEach(0..<5) { index in
                                WaveBar(delay: Double(index) * 0.2)
                            }
                        }
                        .frame(height: 20)
                        
                        Text("LIVE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.2))
                            )
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                // Play/Pause Button
                Button(action: {
                    withAnimation {
                        audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
                    }
                }) {
                    ZStack {
                        // Äußerer Ring
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 4)
                            .frame(width: 70, height: 70)
                        
                        // Innerer Button
                        Circle()
                            .fill(audioPlayer.isPlaying ? Color.red : Color.green)
                            .frame(width: 60, height: 60)
                            .shadow(color: audioPlayer.isPlaying ? .red.opacity(0.5) : .green.opacity(0.5), radius: 10)
                        
                        // Play/Pause Icon
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: audioPlayer.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Status Text
                Text(audioPlayer.isBuffering ? "Buffering..." : (audioPlayer.isPlaying ? "On Air" : "Tap to Play"))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            audioPlayer.handleForegroundTransition()
        }
        .onDisappear {
            audioPlayer.handleBackgroundTransition()
        }
    }
}

// Wellenform-Animation
struct WaveBar: View {
    let delay: Double
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color.white)
            .frame(width: 3, height: isAnimating ? 20 : 4)
            .animation(
                Animation
                    .easeInOut(duration: 0.5)
                    .repeatForever()
                    .delay(delay),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

class AudioPlayer: NSObject, ObservableObject {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    @Published var isPlaying = false
    @Published var isBuffering = false
    private var timeObserver: Any?
    private var retryCount = 0
    private let maxRetries = 3
    
    override init() {
        super.init()
        setupAudioSession()
        createPlayerItem()
        setupNotifications()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func createPlayerItem() {
        guard let url = URL(string: "https://stream.server5.de/listen/farsi/kardasti-radio.mp3") else {
            print("Failed to create URL")
            return
        }
        
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 1.0
        
        print("Setting up player with URL: \(url)")
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
            self?.handlePlaybackStatus()
        }
        
        observePlayerItem()
    }
    
    private func observePlayerItem() {
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStalled),
            name: NSNotification.Name.AVPlayerItemPlaybackStalled,
            object: playerItem
        )
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            handlePlayerItemStatus(status)
        }
    }
    
    private func handlePlayerItemStatus(_ status: AVPlayerItem.Status) {
        DispatchQueue.main.async {
            switch status {
            case .readyToPlay:
                print("PlayerItem ist bereit zum Abspielen")
                self.isBuffering = false
                if self.isPlaying {
                    self.player?.play()
                }
            case .failed:
                if let error = self.player?.currentItem?.error {
                    print("PlayerItem Fehler: \(error)")
                }
                self.handlePlaybackError()
            case .unknown:
                print("PlayerItem Status unbekannt")
                self.isBuffering = true
            @unknown default:
                break
            }
        }
    }
    
    @objc private func handlePlaybackStalled() {
        handlePlaybackError()
    }
    
    private func handlePlaybackError() {
        DispatchQueue.main.async {
            if self.retryCount < self.maxRetries {
                self.retryCount += 1
                print("Attempting to reconnect... (Attempt \(self.retryCount)/\(self.maxRetries))")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.recreatePlayer()
                }
            } else {
                print("Max retry attempts reached")
                self.isPlaying = false
                self.isBuffering = false
                self.retryCount = 0
            }
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
    
    private func handlePlaybackStatus() {
        // Überprüfe den aktuellen Wiedergabestatus
        if let currentItem = player?.currentItem {
            if currentItem.isPlaybackBufferEmpty {
                isBuffering = true
            } else if currentItem.isPlaybackLikelyToKeepUp {
                isBuffering = false
            }
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
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        DispatchQueue.main.async {
            switch type {
            case .began:
                self.pause()
            case .ended:
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    self.play()
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
        } catch {
            print("Failed to play: \(error)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        isBuffering = false
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
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to handle background transition: \(error)")
            }
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        playerItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        NotificationCenter.default.removeObserver(self)
    }
}

// Vereinfachte Preview für moderne watchOS Versionen
#Preview("Kardasti Radio Watch") {
    ContentView()
}
