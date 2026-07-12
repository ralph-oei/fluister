import XCTest
@testable import Fluister

final class AudioRecorderTests: XCTestCase {

    func testBufferIsEmptyInitially() {
        let b = RecordingBuffer(maxSeconds: 1)
        XCTAssertTrue(b.isEmpty)
        XCTAssertEqual(b.samples.count, 0)
        XCTAssertFalse(b.didHitLimit)
    }

    func testAppendAccumulatesSamples() {
        let b = RecordingBuffer(maxSeconds: 10)
        XCTAssertTrue(b.append([0.1, 0.2, 0.3]))
        XCTAssertTrue(b.append([0.4, 0.5]))
        XCTAssertEqual(b.samples, [0.1, 0.2, 0.3, 0.4, 0.5])
        XCTAssertFalse(b.didHitLimit)
    }

    func testAppendCapsAtMaxAndFlagsLimit() {
        // 0.001 s @ 16kHz = 16 samples limiet.
        let b = RecordingBuffer(maxSeconds: 0.001)
        XCTAssertEqual(b.maxSamples, 16)
        let ok = b.append(Array(repeating: Float(1), count: 20)) // meer dan limiet
        XCTAssertFalse(ok, "append moet false geven bij bereiken limiet")
        XCTAssertEqual(b.samples.count, 16, "buffer moet exact op maxSamples afkappen")
        XCTAssertTrue(b.didHitLimit)
    }

    func testAppendAfterLimitIsIgnored() {
        let b = RecordingBuffer(maxSeconds: 0.001) // 16 samples
        b.append(Array(repeating: Float(1), count: 16))
        XCTAssertTrue(b.didHitLimit)
        let ok = b.append([2, 2, 2])
        XCTAssertFalse(ok)
        XCTAssertEqual(b.samples.count, 16, "na de limiet mag er niets meer bij")
    }

    func testResetClearsBufferAndLimit() {
        let b = RecordingBuffer(maxSeconds: 0.001)
        b.append(Array(repeating: Float(1), count: 20))
        XCTAssertTrue(b.didHitLimit)
        b.reset()
        XCTAssertTrue(b.isEmpty)
        XCTAssertFalse(b.didHitLimit)
        XCTAssertTrue(b.append([1, 2, 3]))
    }

    func testDurationReflectsSampleCount() {
        let b = RecordingBuffer(maxSeconds: 10)
        b.append(Array(repeating: Float(0), count: 8_000)) // 0,5 s @16kHz
        XCTAssertEqual(b.duration, 0.5, accuracy: 0.0001)
    }
}
