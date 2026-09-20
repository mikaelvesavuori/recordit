import SwiftUI

@main
struct RecordItApp: App {
    static let appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(Self.appState)
        } label: {
            MenuBarLabel()
                .environment(Self.appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(Self.appState)
        }
    }
}

private struct MenuBarLabel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Image(systemName: state.isRecording
            ? (state.isPaused ? "record.circle" : "record.circle.fill")
            : "waveform.circle")
    }
}
