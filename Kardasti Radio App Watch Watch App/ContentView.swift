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
                Text(audioPlayer.isPlaying ? "On Air" : "Tap to Play")
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
    @Published var isPlaying = false
    private var timeObserver: Any?
    
    override init() {
        super.init()
        setupAudioSession()
        setupPlayer()
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
    
    private func setupPlayer() {
        guard let url = URL(string: "https://stream.server5.de/listen/farsi/kardasti-radio.mp3") else {
            print("Failed to create URL")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 1.0
        
        print("Setting up player with URL: \(url)")
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] _ in
            self?.handlePlaybackStatus()
        }
        
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            
            switch status {
            case .readyToPlay:
                print("PlayerItem ist bereit zum Abspielen")
            case .failed:
                if let error = player?.currentItem?.error {
                    print("PlayerItem Fehler: \(error)")
                }
            case .unknown:
                print("PlayerItem Status unbekannt")
            @unknown default:
                break
            }
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil)
    }
    
    private func handlePlaybackStatus() {
        if let player = player {
            DispatchQueue.main.async {
                self.isPlaying = player.rate != 0
            }
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
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
    
    func play() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player?.play()
            isPlaying = true
        } catch {
            print("Failed to play: \(error)")
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func handleBackgroundTransition() {
        if isPlaying {
            play()
        }
    }
    
    func handleForegroundTransition() {
        setupAudioSession()
        if isPlaying {
            play()
        }
    }
    
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        NotificationCenter.default.removeObserver(self)
        player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
    }
}

// Vereinfachte Preview für moderne watchOS Versionen
#Preview("Kardasti Radio Watch") {
    ContentView()
}
