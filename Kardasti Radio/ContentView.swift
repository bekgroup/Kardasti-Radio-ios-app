//
//  ContentView.swift
//  Kardasti Radio
//
//  Created by BEK Service GmbH on 30.10.24.
//

import SwiftUI
import Network

struct ContentView: View {
    @StateObject private var audioPlayer = AudioPlayer.shared
    @StateObject private var networkMonitor = NetworkMonitor()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isAnimating = false
    @State private var showNoInternetAlert = false
    @State private var isLoading = true
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            if isLoading {
                PreloaderView()
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .alert("No Internet Connection 😅", isPresented: $showNoInternetAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("No radio without internet 🎵\nPlease check your connection 📡")
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                setupInitialState()
            }
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 20) {
            RadioWaveAnimation(isPlaying: audioPlayer.isPlaying)
                .frame(width: 200, height: 200)
            
            Text("Kardasti Radio")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            playPauseButton
            volumeControls
            shareButton
        }
        .padding()
    }
    
    private var playPauseButton: some View {
        Button(action: handlePlayPause) {
            Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(colorScheme == .dark ? .white : .blue)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), 
                         value: isAnimating)
        }
        .padding()
        .disabled(!networkMonitor.isConnected)
    }
    
    private var volumeControls: some View {
        HStack {
            Image(systemName: "speaker.fill")
                .foregroundColor(colorScheme == .dark ? .white : .blue)
            Slider(value: $audioPlayer.volume, in: 0...1)
                .accentColor(colorScheme == .dark ? .white : .blue)
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(colorScheme == .dark ? .white : .blue)
        }
        .padding(.horizontal)
    }
    
    private var shareButton: some View {
        Button(action: shareApp) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
                Text("Share")
                    .font(.headline)
            }
            .padding()
            .foregroundColor(.white)
            .background(colorScheme == .dark ? Color.gray : Color.blue)
            .cornerRadius(10)
        }
    }
    
    private func setupInitialState() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                isLoading = false
            }
        }
    }
    
    private func handlePlayPause() {
        guard networkMonitor.isConnected else {
            showNoInternetAlert = true
            return
        }
        
        withAnimation {
            if audioPlayer.isPlaying {
                audioPlayer.pause()
            } else {
                audioPlayer.play()
            }
            isAnimating.toggle()
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if audioPlayer.isPlaying {
                audioPlayer.play()
            }
        case .background:
            if !audioPlayer.isPlaying {
                audioPlayer.pause()
            }
        case .inactive:
            break
        @unknown default:
            break
        }
    }
    
    private func shareApp() {
        let text = "Listen to Kardasti Radio - Your Persian Radio Station!"
        let url = URL(string: "https://kardasti24.de")!
        
        let activityViewController = UIActivityViewController(
            activityItems: [text, url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = window
                popoverController.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            DispatchQueue.main.async {
                rootViewController.present(activityViewController, animated: true)
            }
        }
    }
}

struct RadioWaveAnimation: View {
    let isPlaying: Bool
    @State private var animation = false
    
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(lineWidth: 2)
                    .scale(animation ? 1 + Double(index) * 0.2 : 0.2)
                    .opacity(animation ? 0 : 1)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.2),
                        value: animation
                    )
            }
            
            Image(systemName: "radio")
                .font(.system(size: 50))
                .foregroundColor(.blue)
                .scaleEffect(animation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                         value: animation)
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            animation = newValue
        }
    }
}

class NetworkMonitor: ObservableObject {
    @Published var isConnected = true
    private let monitor = NWPathMonitor()
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

struct PreloaderView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .frame(width: 60, height: 60)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .opacity(0.3)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(lineWidth: 4)
                .frame(width: 60, height: 60)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 1)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            VStack {
                Image(systemName: "radio")
                    .font(.system(size: 24))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ContentView()
}
