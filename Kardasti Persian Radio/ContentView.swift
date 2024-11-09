//
//  ContentView.swift
//  Kardasti Persian Radio
//
//  Created by BEK Service GmbH on 09.11.24.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var audioPlayer = TVAudioPlayer.shared
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        ZStack {
            // Background gradient for tvOS
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.9),
                    Color.blue.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                Text("KARDASTI RADIO")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(2.0)
                
                Spacer()
                
                // Now Playing Display
                VStack(spacing: 20) {
                    Image(systemName: "radio")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                    
                    if audioPlayer.isPlaying {
                        // Live Label
                        Text("LIVE")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.red.opacity(0.2))
                            )
                            .transition(.scale.combined(with: .opacity))
                        
                        // Animated waveform
                        HStack(spacing: 8) {
                            ForEach(0..<5) { index in
                                TVWaveBar(delay: Double(index) * 0.2)
                            }
                        }
                        .frame(height: 40)
                        
                        // Current Track Info
                        if let title = audioPlayer.nowPlayingManager.currentTrack?.nowPlaying.song.title {
                            Text(title)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        if let artist = audioPlayer.nowPlayingManager.currentTrack?.nowPlaying.song.artist {
                            Text(artist)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    } else {
                        Text("Ready to Play")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                // Play/Pause Button
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 120))
                        .foregroundColor(audioPlayer.isPlaying ? .red : .green)
                }
                .buttonStyle(.card)
                
                Spacer()
            }
            .padding(60)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                audioPlayer.handleForegroundTransition()
            case .background:
                audioPlayer.handleBackgroundTransition()
            default:
                break
            }
        }
    }
}

// Waveform animation for tvOS
struct TVWaveBar: View {
    let delay: Double
    @State private var isAnimating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white)
            .frame(width: 8, height: isAnimating ? 40 : 8)
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

#Preview {
    ContentView()
}
