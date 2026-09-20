import Foundation

public struct Recording: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let sourceAppName: String
    public let sourceAppPID: pid_t
    public let date: Date
    public var duration: TimeInterval
    public let format: String
    public let quality: String
    public let fileURL: URL
    public var fileSize: Int64

    public init(
        id: UUID,
        title: String,
        sourceAppName: String,
        sourceAppPID: pid_t,
        date: Date,
        duration: TimeInterval,
        format: String,
        quality: String,
        fileURL: URL,
        fileSize: Int64
    ) {
        self.id = id
        self.title = title
        self.sourceAppName = sourceAppName
        self.sourceAppPID = sourceAppPID
        self.date = date
        self.duration = duration
        self.format = format
        self.quality = quality
        self.fileURL = fileURL
        self.fileSize = fileSize
    }

    public var formattedDuration: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    public var formattedDate: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
