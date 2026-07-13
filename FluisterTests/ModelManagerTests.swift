import XCTest
@testable import Fluister

// Fake transcriber zodat we ModelManager testen zonder echte WhisperKit/model.
final class FakeTranscriber: SpeechTranscribing, @unchecked Sendable {
    var prepareError: Error?
    var transcribeError: Error?
    var result: String
    /// Optionele download-fracties die prepare() doorgeeft aan de progress-callback.
    var progressSteps: [Double] = []
    private(set) var prepareCount = 0

    init(result: String = "hallo wereld") {
        self.result = result
    }

    func prepare(onDownloadProgress: @escaping @Sendable (Double) -> Void) async throws {
        prepareCount += 1
        for step in progressSteps { onDownloadProgress(step) }
        if let prepareError { throw prepareError }
    }

    func transcribe(samples: [Float], language: String?) async throws -> String {
        if let transcribeError { throw transcribeError }
        return result
    }
}

struct FakeError: Error {}

final class ModelManagerTests: XCTestCase {

    // MARK: - Pure taalcode-mapping

    func testLanguageCodeMapping() {
        XCTAssertNil(whisperLanguageCode(for: "auto"))
        XCTAssertNil(whisperLanguageCode(for: ""))
        XCTAssertEqual(whisperLanguageCode(for: "nl"), "nl")
        XCTAssertEqual(whisperLanguageCode(for: "EN"), "en")
    }

    // MARK: - Small-only (KTD2)

    func testModelIsSmall() {
        XCTAssertEqual(ModelManager.modelName, "small")
    }

    @MainActor
    func testLoadUsesSmallModel() async {
        var requestedModel: String?
        let m = ModelManager(makeTranscriber: { name in
            requestedModel = name
            return FakeTranscriber()
        })
        await m.load()
        XCTAssertEqual(requestedModel, "small")
    }

    // MARK: - ModelManager met fake

    @MainActor
    func testLoadSuccessSetsReadyAndTranscriber() async {
        let fake = FakeTranscriber()
        let m = ModelManager(makeTranscriber: { _ in fake })

        XCTAssertEqual(m.state, .notLoaded)
        await m.load()

        XCTAssertEqual(m.state, .ready)
        XCTAssertNotNil(m.transcriber)
        XCTAssertEqual(fake.prepareCount, 1)
    }

    @MainActor
    func testLoadWithDownloadProgressEndsReady() async {
        let fake = FakeTranscriber()
        fake.progressSteps = [0.25, 0.5, 1.0]   // download tot 100%, dan compileren
        let m = ModelManager(makeTranscriber: { _ in fake })

        await m.load()

        XCTAssertEqual(m.state, .ready)
        XCTAssertNotNil(m.transcriber)
        XCTAssertEqual(fake.prepareCount, 1)
    }

    @MainActor
    func testLoadFailureSetsFailed() async {
        let fake = FakeTranscriber()
        fake.prepareError = FakeError()
        let m = ModelManager(makeTranscriber: { _ in fake })

        await m.load()

        if case .failed = m.state {} else {
            XCTFail("verwacht .failed, kreeg \(m.state)")
        }
        XCTAssertNil(m.transcriber)
    }

    @MainActor
    func testLoadIsIdempotentWhenReady() async {
        let fake = FakeTranscriber()
        let m = ModelManager(makeTranscriber: { _ in fake })

        await m.load()
        await m.load() // tweede keer moet niets opnieuw laden

        XCTAssertEqual(fake.prepareCount, 1)
        XCTAssertEqual(m.state, .ready)
    }

    @MainActor
    func testTranscriberReturnsText() async throws {
        let fake = FakeTranscriber(result: "dit is een test")
        let m = ModelManager(makeTranscriber: { _ in fake })
        await m.load()

        let text = try await m.transcriber?.transcribe(samples: [0, 0, 0], language: "nl")
        XCTAssertEqual(text, "dit is een test")
    }
}
