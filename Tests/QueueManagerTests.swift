import XCTest
@testable import MyMoThErWoUlDnTaDoPtMe

@MainActor
final class QueueManagerTests: XCTestCase {

    private func makeTrack(id: String = "t1", title: String = "Song", streamURL: URL? = nil) -> SearchResult {
        SearchResult(
            id: id,
            title: title,
            artist: "Artist",
            duration: 180,
            source: .youtube,
            thumbnailURL: nil,
            streamURL: streamURL
        )
    }

    private func makeItem(id: String = "t1", streamURL: URL? = nil) -> QueueItem {
        QueueItem(id: id, track: makeTrack(id: id, streamURL: streamURL), source: "youtube")
    }

    func testAddItem() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        let item = makeItem()
        qm.add(item)
        XCTAssertEqual(qm.items.count, 1)
        XCTAssertEqual(qm.items.first?.id, "t1")
    }

    func testRemoveItem() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.remove(at: 0)
        XCTAssertEqual(qm.items.count, 1)
        XCTAssertEqual(qm.items.first?.id, "t2")
    }

    func testSetCurrent() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.setCurrent(index: 1)
        XCTAssertEqual(qm.currentIndex, 1)
        XCTAssertEqual(qm.currentItem?.id, "t2")
    }

    func testNext() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.setCurrent(index: 0)
        qm.next()
        XCTAssertEqual(qm.currentIndex, 1)
    }

    func testNextAtEnd() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.setCurrent(index: 0)
        qm.next()
        XCTAssertNil(qm.currentIndex)
    }

    func testPrevious() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.setCurrent(index: 1)
        qm.previous()
        XCTAssertEqual(qm.currentIndex, 0)
    }

    func testPreviousAtStart() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.setCurrent(index: 0)
        qm.previous()
        XCTAssertEqual(qm.currentIndex, 0)
    }

    func testClear() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.setCurrent(index: 0)
        qm.clear()
        XCTAssertTrue(qm.items.isEmpty)
        XCTAssertNil(qm.currentIndex)
    }

    func testAdvance() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.setCurrent(index: 0)
        qm.advance()
        XCTAssertEqual(qm.currentIndex, 1)
    }

    func testAdvanceAtEnd() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.setCurrent(index: 0)
        qm.advance()
        XCTAssertNil(qm.currentIndex)
    }

    func testSetError() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.setError(on: 0)
        XCTAssertEqual(qm.items[0].state, .error)
    }

    func testAdvanceSkippingErrors() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.add(makeItem(id: "t3"))
        qm.setCurrent(index: 0)
        qm.setError(on: 1)
        qm.advanceSkippingErrors()
        XCTAssertEqual(qm.currentIndex, 2)
    }

    func testAdvanceSkippingErrorsAtEnd() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.setCurrent(index: 0)
        qm.setError(on: 1)
        qm.advanceSkippingErrors()
        XCTAssertNil(qm.currentIndex)
    }

    func testNeedsStreamRefreshNoURL() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        let track = makeTrack(id: "t1", streamURL: nil)
        XCTAssertTrue(qm.needsStreamRefresh(for: track))
    }

    func testNeedsStreamRefreshWithValidURL() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        let url = URL(string: "https://example.com/stream")!
        let track = makeTrack(id: "t1", streamURL: url)
        qm.registerStream(for: "t1", url: url)
        XCTAssertFalse(qm.needsStreamRefresh(for: track))
    }

    func testMove() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.add(makeItem(id: "t2"))
        qm.add(makeItem(id: "t3"))
        qm.setCurrent(index: 0)
        qm.move(from: IndexSet(integer: 0), to: 3)
        XCTAssertEqual(qm.items.map(\.id), ["t2", "t3", "t1"])
        XCTAssertEqual(qm.currentIndex, 2)
    }

    func testInsertAfterCurrent() {
        let qm = QueueManager(streamExpiry: StreamExpiryManager())
        qm.add(makeItem(id: "t1"))
        qm.setCurrent(index: 0)
        qm.insertAfterCurrent(makeItem(id: "t2"))
        XCTAssertEqual(qm.items.map(\.id), ["t1", "t2"])
        XCTAssertEqual(qm.currentIndex, 0)
    }
}
