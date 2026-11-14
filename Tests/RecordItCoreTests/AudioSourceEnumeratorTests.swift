import XCTest
import CoreAudio
@testable import RecordItCore

final class AudioSourceEnumeratorTests: XCTestCase {
    private var ownPID: pid_t {
        ProcessInfo.processInfo.processIdentifier
    }

    func testAllPIDsIncludesCurrentProcess() {
        let pids = AudioSourceEnumerator.allPIDs()
        XCTAssertFalse(pids.isEmpty)
        XCTAssertTrue(pids.contains(ownPID))
    }

    func testResponsiblePIDReturnsResolvablePID() {
        // A normally launched process is responsible for itself; regardless,
        // the call must resolve to a positive PID rather than fail.
        let responsible = AudioSourceEnumerator.responsiblePID(for: ownPID)
        XCTAssertNotNil(responsible)
        XCTAssertGreaterThan(responsible!, 0)
    }

    func testProcessObjectIDsNeverContainsUnknown() {
        // The test runner almost certainly has no Core Audio process object
        // of its own, so the result may legitimately be empty — but any IDs
        // returned must be valid.
        let objectIDs = AudioSourceEnumerator.processObjectIDs(forAppPID: ownPID)
        XCTAssertTrue(objectIDs.allSatisfy { $0 != kAudioObjectUnknown })
    }

    func testProcessesByResponsiblePIDStructure() {
        // Every entry must key on a positive PID and never attribute a
        // process to itself (self-attribution is excluded by contract).
        let map = AudioSourceEnumerator.processesByResponsiblePID()
        for (responsible, helpers) in map {
            XCTAssertGreaterThan(responsible, 0)
            XCTAssertFalse(helpers.contains(responsible))
        }
    }
}
