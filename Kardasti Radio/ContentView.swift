//
//  ContentView.swift
//  Kardasti Radio
//
//  Created by BEK Service GmbH on 30.10.24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Hintergrundfarbe basierend auf Dark/Light Mode
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "radio")
                    .imageScale(.large)
                    .font(.system(size: 100))
                    .foregroundColor(colorScheme == .dark ? .white : .blue)
                
                Text("Kardasti Radio")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                
                Button(action: {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                }) {
                    Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(colorScheme == .dark ? .white : .blue)
                }
                .padding()
                
                // Lautstärkeregler hinzufügen
                HStack {
                    Image(systemName: "speaker.fill")
                        .foregroundColor(colorScheme == .dark ? .white : .blue)
                    Slider(value: $audioPlayer.volume, in: 0...1)
                        .accentColor(colorScheme == .dark ? .white : .blue)
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(colorScheme == .dark ? .white : .blue)
                }
                .padding(.horizontal)
                
                Button(action: {
                    shareApp()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20))
                        Text("Teilen")
                            .font(.headline)
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(colorScheme == .dark ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
    }
    
    private func shareApp() {
        let text = "Höre Kardasti Radio - Dein persischer Radiosender!"
        let url = URL(string: "https://kardasti24.de")!
        
        let activityViewController = UIActivityViewController(
            activityItems: [text, url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityViewController, animated: true)
        }
    }
}

#Preview {
    ContentView()
}
