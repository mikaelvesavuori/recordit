import Foundation
import AppKit

public final class RecordingStore: @unchecked Sendable {
    private let storageURL: URL
    private let lock = NSLock()
    public private(set) var recordings: [Recording] = []

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageURL = appSupport.appendingPathComponent("RecordIt/recordings.json", isDirectory: false)
        load()
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([Recording].self, from: data) else { return }
        recordings = decoded.sorted { $0.date > $1.date }
    }

    public func save() {
        lock.lock()
        defer { lock.unlock() }
        do {
            let dir = storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(recordings)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save recordings: \(error)")
        }
    }

    public func add(_ recording: Recording) {
        lock.lock()
        recordings.insert(recording, at: 0)
        lock.unlock()
        save()
    }

    public func remove(_ recording: Recording) {
        lock.lock()
        try? FileManager.default.removeItem(at: recording.fileURL)
        recordings.removeAll { $0.id == recording.id }
        lock.unlock()
        save()
    }

    public func revealInFinder(_ recording: Recording) {
        NSWorkspace.shared.activateFileViewerSelecting([recording.fileURL])
    }
}
