import XCTest
@testable import Fluister

@MainActor
final class AppModelDictionaryTests: XCTestCase {

    private func tempStore() -> DictionaryStore {
        DictionaryStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("dict-\(UUID().uuidString).json"))
    }

    func testCorrectieLeertPaarEnDoetFixNow() {
        let store = tempStore()
        let inserter = FakeInserter()

        DictionaryCorrection.apply(old: "ik ga naar naslak", edited: "ik ga naar Naslag",
                                   store: store, inserter: inserter)

        XCTAssertEqual(store.entries, [DictionaryEntry(wrong: "naslak", right: "Naslag")])
        XCTAssertEqual(inserter.replaced.first?.old, "ik ga naar naslak")
        XCTAssertEqual(inserter.replaced.first?.new, "ik ga naar Naslag")
    }

    func testCorrectieZonderWijzigingDoetNiets() {
        let store = tempStore()
        let inserter = FakeInserter()

        DictionaryCorrection.apply(old: "alles klopt", edited: "alles klopt",
                                   store: store, inserter: inserter)

        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertTrue(inserter.replaced.isEmpty)
    }

    func testHoofdletterCorrectieWordtGeleerd() {
        // Het hoofdgeval: Whisper schrijft een eigennaam met kleine letter.
        let store = tempStore()
        let inserter = FakeInserter()

        DictionaryCorrection.apply(old: "we werken met zelesta", edited: "we werken met Zelesta",
                                   store: store, inserter: inserter)

        XCTAssertEqual(store.entries, [DictionaryEntry(wrong: "zelesta", right: "Zelesta")])
    }

    func testGeleerdPaarWerktMeteenOpVolgendDictaat() {
        // Einde-tot-einde over de pure units: leren → toepassen.
        let store = tempStore()
        DictionaryCorrection.apply(old: "ik gebruik naslak", edited: "ik gebruik Naslag",
                                   store: store, inserter: FakeInserter())

        let volgende = DictionaryFormatter.apply("naslak is handig", pairs: store.pairs)

        XCTAssertEqual(volgende, "Naslag is handig")
    }
}
