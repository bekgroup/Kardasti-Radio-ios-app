import Foundation
import SwiftUI

@MainActor
class SleepTimerManager: ObservableObject {
    static let shared = SleepTimerManager()
    
    @Published var isTimerActive = false
    @Published var remainingTime: TimeInterval = 0
    private var timer: Timer?
    private var audioPlayer: AudioPlayer?
    
    private init() {}
    
    func startTimer(minutes: Int) {
        stopTimer()
        
        remainingTime = TimeInterval(minutes * 60)
        isTimerActive = true
        
        DispatchQueue.main.async { [weak self] in
            self?.createTimer()
        }
    }
    
    private func createTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                } else {
                    self.handleTimerCompletion()
                }
            }
        }
    }
    
    private func handleTimerCompletion() {
        Task { @MainActor in
            AudioPlayer.shared.pause()
            stopTimer()
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerActive = false
        remainingTime = 0
    }
    
    func formatRemainingTime() -> String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 