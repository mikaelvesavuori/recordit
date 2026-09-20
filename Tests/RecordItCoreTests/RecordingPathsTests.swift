import XCTest
@testable import RecordItCore

final class RecordingPathsTests: XCTestCase {
    func testFileNameContainsSourceAndDateAndExtension() {
        let date = makeDate(year: 2026, month: 9, day: 20, hour: 13, minute: 5, second: 1)
        let name = RecordingPaths.fileName(sourceName: "Apple Music", date: date, fileExtension: "m4a")
        XCTAssertTrue(name.hasPrefix("Apple Music - "), "Expected source name prefix, got: \(name)")
        XCTAssertTrue(name.hasSuffix(".m4a"), "Expected m4a extension, got: \(name)")
        XCTAssertTrue(name.contains("2026"), "Expected year in filename, got: \(name)")
    }

    func testFileNameSanitizesSlashes() {
        let date = makeDate(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        let name = RecordingPaths.fileName(sourceName: "a/b", date: date, fileExtension: "m4a")
        XCTAssertFalse(name.contains("/"))
    }

    func testFileURLAppendsToDirectory() {
        let dir = URL(fileURLWithPath: "/tmp/RecordIt")
        let date = makeDate(year: 2026, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        let url = RecordingPaths.fileURL(sourceName: "Safari", date: date, fileExtension: "m4a", directory: dir)
        XCTAssertEqual(url.deletingLastPathComponent().path, "/tmp/RecordIt")
        XCTAssertEqual(url.pathExtension, "m4a")
    }

    func testDefaultOutputDirectoryIsMusicRecordIt() {
        let dir = RecordingPaths.defaultOutputDirectory
        XCTAssertEqual(dir.lastPathComponent, "RecordIt")
        XCTAssertEqual(dir.deletingLastPathComponent().lastPathComponent, "Music")
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}
