import Foundation

public enum RecordingPaths {
    public static var defaultOutputDirectory: URL {
        let musicDir = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        return musicDir.appendingPathComponent("RecordIt", isDirectory: true)
    }

    public static func fileName(sourceName: String, date: Date, fileExtension: String) -> String {
        let safeName = sourceName.replacingOccurrences(of: "/", with: "-")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HHmmss"
        return "\(safeName) - \(formatter.string(from: date)).\(fileExtension)"
    }

    public static func fileURL(sourceName: String, date: Date, fileExtension: String, directory: URL) -> URL {
        directory.appendingPathComponent(fileName(sourceName: sourceName, date: date, fileExtension: fileExtension))
    }
}

public enum DurationFormatter {
    public static func format(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let tenths = Int((duration * 10).truncatingRemainder(dividingBy: 10))
        return String(format: "%d:%02d.%d", mins, secs, tenths)
    }

    public static func formatClock(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
