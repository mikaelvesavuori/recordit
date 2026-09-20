import XCTest
@testable import RecordItCore

final class RecordingTests: XCTestCase {
    func testFormattedDurationRoundsToMinutesAndSeconds() {
        let recording = Recording(
            id: UUID(),
            title: "Test",
            sourceAppName: "Safari",
            sourceAppPID: 1,
            date: Date(),
            duration: 125,
            format: "alac",
            quality: "high",
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            fileSize: 1024
        )
        XCTAssertEqual(recording.formattedDuration, "2:05")
    }

    func testFormattedFileSizeUsesByteCountFormatter() {
        let recording = Recording(
            id: UUID(),
            title: "Test",
            sourceAppName: "Safari",
            sourceAppPID: 1,
            date: Date(),
            duration: 0,
            format: "alac",
            quality: "high",
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            fileSize: 2048
        )
        XCTAssertFalse(recording.formattedFileSize.isEmpty)
    }

    func testRecordingIsCodable() throws {
        let recording = Recording(
            id: UUID(),
            title: "Test",
            sourceAppName: "Safari",
            sourceAppPID: 123,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 42,
            format: "alac",
            quality: "high",
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            fileSize: 5000
        )
        let data = try JSONEncoder().encode(recording)
        let decoded = try JSONDecoder().decode(Recording.self, from: data)
        XCTAssertEqual(decoded.id, recording.id)
        XCTAssertEqual(decoded.duration, recording.duration)
        XCTAssertEqual(decoded.fileURL, recording.fileURL)
    }
}
