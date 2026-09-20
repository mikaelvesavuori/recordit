import SwiftUI
import AppKit
import RecordItCore

struct PopoverView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 0) {
            if state.isRecording {
                recordingView
            } else {
                idleView(state: $state)
            }

            if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            footerBar(state: $state)
        }
        .padding(.vertical, 16)
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white)
        .onAppear {
            state.refreshSources()
        }
    }

    // MARK: - Idle

    private func idleView(state: Bindable<AppState>) -> some View {
        VStack(spacing: 16) {
            header

            sectionCard {
                sourceMenu(state: state)
            }

            HStack(spacing: 8) {
                sectionCard {
                    formatPicker(state: state)
                }
                sectionCard {
                    qualityPicker(state: state)
                }
            }

            sectionCard {
                saveLocationRow(state: state)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)
            Text("RecordIt")
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
        }
    }

    // MARK: - Source menu

    private func sourceMenu(state: Bindable<AppState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Source")

            Menu {
                ForEach(state.wrappedValue.sources) { source in
                    Button(source.name) {
                        state.selectedSource.wrappedValue = source
                    }
                }
                if state.wrappedValue.sources.isEmpty {
                    Text("No apps available")
                }
            } label: {
                if let selected = state.selectedSource.wrappedValue {
                    HStack(spacing: 10) {
                        if let icon = selected.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        } else {
                            Image(systemName: "app")
                                .font(.body)
                                .frame(width: 20, height: 20)
                        }
                        Text(selected.name)
                            .font(.body)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                } else {
                    Text("Select a source…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: - Format & Quality

    private func formatPicker(state: Bindable<AppState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Format")
            Picker("", selection: state.format) {
                ForEach(RecordingFormat.allCases) { f in
                    Text(f.displayName).tag(f)
                }
            }
            .labelsHidden()
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func qualityPicker(state: Bindable<AppState>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Quality")
            Picker("", selection: state.quality) {
                ForEach(RecordingQuality.allCases) { q in
                    Text(q.displayName).tag(q)
                }
            }
            .labelsHidden()
            .menuStyle(.borderlessButton)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Save location

    private func saveLocationRow(state: Bindable<AppState>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Save to")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(state.wrappedValue.outputDirectory.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: state.wrappedValue.chooseOutputDirectory) {
                Text("Change")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: state.wrappedValue.revealOutputFolder) {
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Reveal in Finder")
        }
    }

    // MARK: - Recording

    private var recordingView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: state.isPaused ? "pause.circle.fill" : "circle.fill")
                    .foregroundStyle(state.isPaused ? Color.secondary : Color.red)
                    .font(.caption)
                Text(state.selectedSource?.name ?? "")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Text(DurationFormatter.format(state.currentDuration))
                .font(.system(size: 44, weight: .ultraLight, design: .monospaced))
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)

            levelMeter
                .padding(.horizontal, 16)
                .padding(.bottom, 4)

            HStack(spacing: 10) {
                Button(action: state.stopRecording) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button(action: state.togglePause) {
                    HStack(spacing: 6) {
                        Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                        Text(state.isPaused ? "Resume" : "Pause")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Level meter

    private var levelMeter: some View {
        HStack(spacing: 2) {
            ForEach(0..<28, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(levelColor(for: i, level: state.currentLevel))
                    .frame(height: 5)
                    .animation(.easeOut(duration: 0.15), value: state.currentLevel)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func levelColor(for index: Int, level: Float) -> Color {
        let threshold = Float(index) / 28.0
        let scaledLevel = min(level * 5, 1.0)
        if scaledLevel > threshold {
            if index < 18 { return .green }
            if index < 23 { return .yellow }
            return .red
        }
        return Color(nsColor: .controlColor)
    }

    // MARK: - Footer

    private func footerBar(state: Bindable<AppState>) -> some View {
        HStack(spacing: 10) {
            if !state.wrappedValue.isRecording {
                Button(action: state.wrappedValue.startRecording) {
                    HStack(spacing: 6) {
                        Image(systemName: "record.circle.fill")
                        Text("Record")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(state.selectedSource.wrappedValue == nil)

                Button(action: state.wrappedValue.quit) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                        Text("Quit")
                            .fontWeight(.medium)
                    }
                    .frame(height: 36)
                }
                .buttonStyle(.bordered)
                .help("Quit RecordIt")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func sectionCard<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }
}
