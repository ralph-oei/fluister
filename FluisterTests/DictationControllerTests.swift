import XCTest
@testable import Fluister

final class FakeRecorder: AudioRecording, @unchecked Sendable {
    var started = false
    var stopped = false
    var startError: Error?
    var samplesToReturn: [Float] = []

    func start() throws {
        if let startError { throw startError }
        started = true
    }
    func stop() -> [Float] {
        stopped = true
        return samplesToReturn
    }
}

final class FakeInserter: TextInserting, @unchecked Sendable {
    private(set) var inserted: [String] = []
    private(set) var replaced: [(old: String, new: String)] = []
    func insert(_ text: String) { inserted.append(text) }
    func replaceLast(oldText: String, with newText: String) { replaced.append((oldText, newText)) }
}

@MainActor
final class DictationControllerTests: XCTestCase {

    private func makeReadyModel(text: String = "hallo") -> ModelManager {
        let fakeT = FakeTranscriber(result: text)
        let m = ModelManager(makeTranscriber: { _ in fakeT })
        return m
    }

    func testStartBlockedWhenModelNotLoaded() {
        let rec = FakeRecorder()
        let model = ModelManager(makeTranscriber: { _ in FakeTranscriber() }) // niet geladen
        let c = DictationController(recorder: rec, model: model, inserter: FakeInserter())

        c.startDictation()

        if case .blocked(let m) = c.phase {
            XCTAssertTrue(m.contains("voorbereid"),
                          "blocked-bericht moet uitleggen dat het model nog laadt, kreeg: \(m)")
        } else { XCTFail("verwacht .blocked, kreeg \(c.phase)") }
        XCTAssertFalse(rec.started, "opname mag niet starten zonder geladen model")
    }

    func testStartRecordingWhenModelReady() async {
        let rec = FakeRecorder()
        let model = makeReadyModel()
        await model.load()
        let c = DictationController(recorder: rec, model: model, inserter: FakeInserter())

        c.startDictation()

        XCTAssertEqual(c.phase, .recording)
        XCTAssertTrue(rec.started)
    }

    func testFinishTranscribesAndInserts() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "dit is een test")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000)) // ~0,5s

        XCTAssertEqual(inserter.inserted, ["dit is een test"])
        XCTAssertEqual(c.phase, .idle)
    }

    func testFinishSkipsWhenAudioTooShort() async {
        let rec = FakeRecorder()
        let model = makeReadyModel()
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)

        await c.finish(samples: Array(repeating: Float(0.1), count: 100)) // veel te kort

        XCTAssertTrue(inserter.inserted.isEmpty, "te korte opname mag niet ingevoegd worden")
        XCTAssertEqual(c.phase, .idle)
    }

    func testFinishSkipsEmptyTranscript() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "   ") // alleen witruimte
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertTrue(inserter.inserted.isEmpty, "lege/witruimte-transcriptie mag niet ingevoegd worden")
        XCTAssertEqual(c.phase, .idle)
    }

    func testFinishBlocksOnTranscriberError() async {
        let rec = FakeRecorder()
        let fakeT = FakeTranscriber()
        fakeT.transcribeError = FakeError()
        let model = ModelManager(makeTranscriber: { _ in fakeT })
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        if case .blocked = c.phase {} else { XCTFail("verwacht .blocked bij transcriptiefout") }
        XCTAssertTrue(inserter.inserted.isEmpty)
    }

    func testStopIgnoredWhenNotRecording() {
        let rec = FakeRecorder()
        let model = ModelManager(makeTranscriber: { _ in FakeTranscriber() })
        let c = DictationController(recorder: rec, model: model, inserter: FakeInserter())

        c.stopDictation() // niet aan het opnemen

        XCTAssertFalse(rec.stopped)
        XCTAssertEqual(c.phase, .idle)
    }

    // MARK: - Personal dictionary (task 4)

    func testFinishPastWoordenlijstToe() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "ik gebruik naslak")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)
        c.dictionaryPairs = [("naslak", "Naslag")]

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(inserter.inserted, ["ik gebruik Naslag"])
    }

    func testFinishZonderParenOngewijzigd() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "ik gebruik naslak")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(inserter.inserted, ["ik gebruik naslak"])
    }

    // MARK: - Laatste dictaat onthouden (task 5)

    func testFinishOnthoudtLaatsteTekst() async {
        let rec = FakeRecorder()
        let model = makeReadyModel(text: "ik gebruik naslak")
        await model.load()
        let inserter = FakeInserter()
        let c = DictationController(recorder: rec, model: model, inserter: inserter)
        c.dictionaryPairs = [("naslak", "Naslag")]

        await c.finish(samples: Array(repeating: Float(0.1), count: 8_000))

        XCTAssertEqual(c.lastInsertedText, "ik gebruik Naslag")
    }

    func testLaatsteTekstNilVoorEersteDictaat() {
        let rec = FakeRecorder()
        let model = makeReadyModel()
        let c = DictationController(recorder: rec, model: model, inserter: FakeInserter())
        XCTAssertNil(c.lastInsertedText)
    }
}
