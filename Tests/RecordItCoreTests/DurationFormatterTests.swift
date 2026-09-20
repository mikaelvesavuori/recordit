import XCTest
@testable import RecordItCore

final class DurationFormatterTests: XCTestCase {
    func testFormatIncludesMinutesSecondsAndTenths() {
        XCTAssertEqual(DurationFormatter.format(0), "0:00.0")
        XCTAssertEqual(DurationFormatter.format(5.4), "0:05.4")
        XCTAssertEqual(DurationFormatter.format(65.5), "1:05.5")
        XCTAssertEqual(DurationFormatter.format(125.9), "2:05.9")
    }

    func testFormatClockIsMinutesAndSecondsOnly() {
        XCTAssertEqual(DurationFormatter.formatClock(0), "0:00")
        XCTAssertEqual(DurationFormatter.formatClock(5), "0:05")
        XCTAssertEqual(DurationFormatter.formatClock(65), "1:05")
    }
}
