import SwiftUI
import AppKit

@main
struct JaviraApp: App {
    @StateObject private var assistantVM = AssistantViewModel()

    var body: some Scene {
        Window("Javira Assistant", id: "main") {
            ContentView()
                .environmentObject(assistantVM)
        }
        .defaultSize(width: 620, height: 760)

        MenuBarExtra("Javira", systemImage: assistantVM.isListening ? "waveform.badge.mic" : "waveform.circle") {
            MenuBarView()
                .environmentObject(assistantVM)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(assistantVM)
        }
    }
}
