import SwiftUI
import RecordItCore

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Form {
            Section("Recording") {
                Picker("Format", selection: $state.format) {
                    ForEach(RecordingFormat.allCases) { f in
                        Text(f.displayName).tag(f)
                    }
                }

                Picker("Quality", selection: $state.quality) {
                    ForEach(RecordingQuality.allCases) { q in
                        Text(q.displayName).tag(q)
                    }
                }
            }

            Section("Output") {
                LabeledContent("Save location") {
                    HStack {
                        Text(state.outputDirectory.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose…") {
                            state.chooseOutputDirectory()
                        }
                        if state.customOutputDirectory != nil {
                            Button("Reset") {
                                state.resetOutputDirectory()
                            }
                        }
                    }
                }
            }

            Section {
                Text("RecordIt captures audio from other apps using Core Audio process taps. Files are saved as .m4a (ALAC lossless or AAC lossy).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 340)
    }
}
