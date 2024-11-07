//
//  ContentView.swift
//  Kardasti Radio
//
//  Created by BEK Service GmbH on 30.10.24.
//

import SwiftUI
import Network

class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    @Published var isConnected = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}

struct ContentView: View {
    @StateObject private var audioPlayer = KardastiAudioPlayer.shared
    @StateObject private var networkMonitor = NetworkMonitor()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    
    @State private var isAnimating = false
    @State private var showNoInternetAlert = false
    @State private var isLoading = true
    @State private var hasAppeared = false
    
    @StateObject private var sleepTimer = SleepTimerManager.shared
    @State private var showingSleepTimerSheet = false
    
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    @State private var showShareSheet = false
    @State private var isRotating = false
    @State private var showPulse = false
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            if !networkMonitor.isConnected {
                showNoInternetAlert = true
            }
            KardastiAudioPlayer.shared.handleForegroundTransition()
        case .background:
            KardastiAudioPlayer.shared.handleBackgroundTransition()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
    
    private func setupInitialState() {
        isLoading = true
        
        if !networkMonitor.isConnected {
            showNoInternetAlert = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isLoading = false
            }
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    isDarkMode ? Color.black.opacity(0.9) : Color.blue.opacity(0.1),
                    isDarkMode ? Color.blue.opacity(0.3) : Color.white
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoading {
                PreloaderView()
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
                    .overlay(
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                isDarkMode.toggle()
                            }
                        }) {
                            Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 22))
                                .foregroundColor(isDarkMode ? .white : .black)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                        .shadow(color: isDarkMode ? .clear : .black.opacity(0.1), radius: 5)
                                )
                        }
                        .padding([.top, .trailing], 20)
                        , alignment: .topTrailing
                    )
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
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
        .sheet(isPresented: $showingSleepTimerSheet) {
            SleepTimerSheet()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: ["Listen to Kardasti Radio!", "https://kardasti24.de"])
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 30) {
            Text("KARDASTI RADIO")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundColor(isDarkMode ? .white : .black)
                .padding(.top, 20)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear { isAnimating = true }
            
            ZStack {
                if audioPlayer.isPlaying {
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1), lineWidth: 1)
                            .frame(width: 280 + CGFloat(index * 20), height: 280 + CGFloat(index * 20))
                            .scaleEffect(showPulse ? 1.2 : 0.8)
                            .opacity(showPulse ? 0 : 1)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: showPulse
                            )
                    }
                }
                
                Circle()
                    .stroke(
                        isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1),
                        lineWidth: 2
                    )
                    .frame(width: 280, height: 280)
                    .rotationEffect(.degrees(isRotating && audioPlayer.isPlaying ? 360 : 0))
                    .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isRotating)
                
                if let artUrl = audioPlayer.nowPlayingManager.currentTrack?.nowPlaying.song.art,
                   let url = URL(string: artUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 260, height: 260)
                            .clipShape(Circle())
                            .shadow(color: isDarkMode ? .blue.opacity(0.3) : .black.opacity(0.2), radius: 10)
                            .rotationEffect(.degrees(isRotating && audioPlayer.isPlaying ? 360 : 0))
                    } placeholder: {
                        RadioWaveAnimation(isPlaying: audioPlayer.isPlaying)
                            .frame(width: 260, height: 260)
                    }
                } else {
                    RadioWaveAnimation(isPlaying: audioPlayer.isPlaying)
                        .frame(width: 260, height: 260)
                }
                
                if audioPlayer.isPlaying {
                    LiveBadge()
                        .offset(y: -140)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                isRotating = true
                showPulse = true
            }
            
            VStack(spacing: 8) {
                if let currentTrack = audioPlayer.nowPlayingManager.currentTrack {
                    Text(currentTrack.nowPlaying.song.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(currentTrack.nowPlaying.song.artist)
                        .font(.title3)
                        .foregroundColor(.secondary)
                } else {
                    Text("Kardasti Radio")
                        .font(.title2.bold())
                    Text("Live Stream")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 40) {
                Button(action: { showingSleepTimerSheet = true }) {
                    ControlButton(
                        icon: "timer",
                        isDarkMode: isDarkMode,
                        size: 60
                    )
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
                    }
                }) {
                    PlayPauseButton(
                        isPlaying: audioPlayer.isPlaying,
                        isDarkMode: isDarkMode
                    )
                }
                
                Button(action: { showShareSheet = true }) {
                    ControlButton(
                        icon: "square.and.arrow.up",
                        isDarkMode: isDarkMode,
                        size: 60
                    )
                }
            }
            .padding(.top, 20)
            
            Spacer()
        }
        .padding()
    }
}

struct LiveBadge: View {
    @State private var isAnimating = false
    
    var body: some View {
        Text("LIVE")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.red)
                    .shadow(color: .red.opacity(0.3), radius: 5)
            )
            .scaleEffect(isAnimating ? 1.1 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
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
                .animation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true),
                    value: animation
                )
        }
        .onChange(of: isPlaying) { oldValue, newValue in
            animation = newValue
        }
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
                    .linear(duration: 1)
                    .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            VStack {
                Image(systemName: "radio")
                    .font(.system(size: 24))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.5)
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

struct ControlButton: View {
    let icon: String
    let isDarkMode: Bool
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .frame(width: size, height: size)
            
            Image(systemName: icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(isDarkMode ? .white : .black)
        }
        .scaleEffect(1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: true)
    }
}

struct PlayPauseButton: View {
    let isPlaying: Bool
    let isDarkMode: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.1), lineWidth: 4)
                .frame(width: 80, height: 80)
            
            Circle()
                .fill(isPlaying ? Color.red : Color.green)
                .frame(width: 70, height: 70)
                .shadow(color: isPlaying ? .red.opacity(0.3) : .green.opacity(0.3), radius: 10)
            
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 35, weight: .bold))
                .foregroundColor(.white)
                .offset(x: isPlaying ? 0 : 2)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
