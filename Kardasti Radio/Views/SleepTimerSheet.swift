import SwiftUI

struct SleepTimerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var sleepTimer = SleepTimerManager.shared
    
    let timerOptions = [5, 15, 30, 45, 60, 90]
    
    var body: some View {
        NavigationView {
            List {
                if sleepTimer.isTimerActive {
                    Section {
                        HStack {
                            Text("Verbleibende Zeit")
                            Spacer()
                            Text(sleepTimer.formatRemainingTime())
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            sleepTimer.stopTimer()
                            dismiss()
                        }) {
                            Text("Timer deaktivieren")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    ForEach(timerOptions, id: \.self) { minutes in
                        Button(action: {
                            sleepTimer.startTimer(minutes: minutes)
                            dismiss()
                        }) {
                            HStack {
                                Text("\(minutes) Minuten")
                                Spacer()
                                if sleepTimer.isTimerActive && Int(sleepTimer.remainingTime) == minutes * 60 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    }
                } header: {
                    Text("Timer einstellen")
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }
} 