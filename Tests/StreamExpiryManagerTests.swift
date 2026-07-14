import XCTest
@testable import MyMoThErWoUlDnTaDoPtMe

final class StreamExpiryManagerTests: XCTestCase {

    func testRegisterStreamMakesItNotExpired() {
        var manager = StreamExpiryManager()
        manager.registerStream(for: "track1")
        XCTAssertFalse(manager.isStreamExpired(for: "track1"))
    }

    func testUnregisteredStreamIsExpired() {
        let manager = StreamExpiryManager()
        XCTAssertTrue(manager.isStreamExpired(for: "unknown"))
    }

    func testRemoveStreamMakesItExpired() {
        var manager = StreamExpiryManager()
        manager.registerStream(for: "track1")
        XCTAssertFalse(manager.isStreamExpired(for: "track1"))
        manager.removeStream(for: "track1")
        XCTAssertTrue(manager.isStreamExpired(for: "track1"))
    }

    func testRefreshStreamResetsExpiry() {
        var manager = StreamExpiryManager()
        manager.registerStream(for: "track1")
        manager.refreshStream(for: "track1")
        XCTAssertFalse(manager.isStreamExpired(for: "track1"))
    }

    func testCleanupExpiredRemovesOldEntries() {
        var manager = StreamExpiryManager()
        manager.registerStream(for: "track1")
        manager.registerStream(for: "track2")
        manager.cleanupExpired()
        XCTAssertFalse(manager.isStreamExpired(for: "track1"))
        XCTAssertFalse(manager.isStreamExpired(for: "track2"))
    }

    func testMultipleTracks() {
        var manager = StreamExpiryManager()
        manager.registerStream(for: "track1")
        manager.registerStream(for: "track2")
        manager.registerStream(for: "track3")
        XCTAssertFalse(manager.isStreamExpired(for: "track1"))
        XCTAssertFalse(manager.isStreamExpired(for: "track2"))
        XCTAssertFalse(manager.isStreamExpired(for: "track3"))
        manager.removeStream(for: "track2")
        XCTAssertFalse(manager.isStreamExpired(for: "track1"))
        XCTAssertTrue(manager.isStreamExpired(for: "track2"))
        XCTAssertFalse(manager.isStreamExpired(for: "track3"))
    }
}
