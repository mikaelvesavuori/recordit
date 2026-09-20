import Foundation
import AVFoundation

public final class AudioFileWriter: @unchecked Sendable {
    private let writeQueue = DispatchQueue(label: "com.recordit.writer", qos: .userInitiated)
    private var audioFile: AVAudioFile?
    private let outputURL: URL
    private let settings: [String: Any]
    private let inputFormat: AVAudioFormat
    private let lock = NSLock()

    public var onError: ((Error) -> Void)?

    public init(outputURL: URL, format: RecordingFormat, quality: RecordingQuality, inputFormat: AVAudioFormat) throws {
        self.outputURL = outputURL
        let sampleRate = inputFormat.sampleRate
        let channels = inputFormat.channelCount
        self.settings = format.fileSettings(sampleRate: sampleRate, channels: channels, quality: quality)
        self.inputFormat = inputFormat

        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
    }

    public func start() throws {
        let file = try AVAudioFile(
            forWriting: outputURL,
            settings: settings,
            commonFormat: inputFormat.commonFormat,
            interleaved: inputFormat.isInterleaved
        )
        lock.lock()
        self.audioFile = file
        lock.unlock()
    }

    public func write(buffer: AVAudioPCMBuffer) {
        writeQueue.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let file = self.audioFile
            self.lock.unlock()
            guard let file else { return }
            do {
                try file.write(from: buffer)
            } catch {
                self.onError?(error)
            }
        }
    }

    public func finish() {
        writeQueue.sync { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.audioFile = nil
            self.lock.unlock()
        }
    }

    public var outputFileURL: URL { outputURL }
}
