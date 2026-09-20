import Foundation
import AVFoundation
import AppKit
import Observation
import RecordItCore

@MainActor
@Observable
final class AppState {
    var sources: [AudioSource] = []
    var selectedSource: AudioSource?
    var format: RecordingFormat = .alac
    var quality: RecordingQuality = .high
    var isRecording = false
    var isPaused = false
    var currentDuration: TimeInterval = 0
    var currentLevel: Float = 0
    var recordings: [Recording] = []
    var errorMessage: String?
    var customOutputDirectory: URL? {
        didSet {
            if let customOutputDirectory {
                UserDefaults.standard.set(customOutputDirectory.path, forKey: "outputDirectory")
            } else {
                UserDefaults.standard.removeObject(forKey: "outputDirectory")
            }
        }
    }

    var outputDirectory: URL {
        customOutputDirectory ?? RecordingPaths.defaultOutputDirectory
    }

    private let captureEngine = AudioCaptureEngine()
    private var fileWriter: AudioFileWriter?
    private let store = RecordingStore()
    private var currentRecording: Recording?
    private var timer: Timer?
    private var recordingStartTime: Date?

    init() {
        recordings = store.recordings
        if let savedPath = UserDefaults.standard.string(forKey: "outputDirectory") {
            customOutputDirectory = URL(fileURLWithPath: savedPath)
        }
        refreshSources()
        setupNotificationObservers()
    }

    func refreshSources() {
        sources = AudioSourceEnumerator.runningApps()
        if selectedSource == nil || !sources.contains(selectedSource!) {
            selectedSource = sources.first
        }
    }

    func startRecording() {
        guard let source = selectedSource else {
            errorMessage = "No audio source selected"
            return
        }

        errorMessage = nil
        currentDuration = 0

        do {
            try captureEngine.start(processObjectID: source.audioObjectID)

            guard let audioFormat = captureEngine.audioFormat else {
                throw AudioCaptureError.formatCreationFailed
            }

            let date = Date()
            let fileURL = RecordingPaths.fileURL(
                sourceName: source.name,
                date: date,
                fileExtension: format.fileExtension,
                directory: outputDirectory
            )
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

            let writer = try AudioFileWriter(
                outputURL: fileURL,
                format: format,
                quality: quality,
                inputFormat: audioFormat
            )
            try writer.start()
            writer.onError = { [weak self] error in
                DispatchQueue.main.async {
                    self?.errorMessage = "Write error: \(error.localizedDescription)"
                }
            }

            fileWriter = writer

            currentRecording = Recording(
                id: UUID(),
                title: fileURL.deletingPathExtension().lastPathComponent,
                sourceAppName: source.name,
                sourceAppPID: source.pid,
                date: date,
                duration: 0,
                format: format.rawValue,
                quality: quality.rawValue,
                fileURL: fileURL,
                fileSize: 0
            )

            captureEngine.onAudioBuffer = { [weak self] buffer in
                guard let self, !self.isPaused else { return }
                self.fileWriter?.write(buffer: buffer)
            }

            captureEngine.onLevelUpdate = { [weak self] level in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.currentLevel = self.currentLevel * 0.6 + level * 0.4
                }
            }

            isRecording = true
            isPaused = false
            recordingStartTime = date
            startTimer()
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            captureEngine.stop()
        }
    }

    func stopRecording() {
        captureEngine.stop()
        fileWriter?.finish()
        fileWriter = nil
        isRecording = false
        isPaused = false
        currentLevel = 0
        stopTimer()

        guard var recording = currentRecording else { return }
        recording.duration = currentDuration
        if let attrs = try? FileManager.default.attributesOfItem(atPath: recording.fileURL.path) {
            recording.fileSize = Int64((attrs[.size] as? Int) ?? 0)
        }
        store.add(recording)
        recordings = store.recordings
        currentRecording = nil
    }

    func togglePause() {
        isPaused.toggle()
    }

    func deleteRecording(_ recording: Recording) {
        store.remove(recording)
        recordings = store.recordings
    }

    func revealRecording(_ recording: Recording) {
        store.revealInFinder(recording)
    }

    func revealOutputFolder() {
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(outputDirectory)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func chooseOutputDirectory() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = outputDirectory
        panel.level = .floating

        let result = panel.runModal()

        NSApp.setActivationPolicy(.accessory)

        if result == .OK, let url = panel.url {
            customOutputDirectory = url
        }
    }

    func resetOutputDirectory() {
        customOutputDirectory = nil
    }

    private func setupNotificationObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshSources()
            }
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshSources()
            }
        }
    }

    private func startTimer() {
        let startTime = recordingStartTime ?? Date()
        recordingStartTime = startTime
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingStartTime = nil
    }
}
