import XCTest
@testable import Fluister

final class DictionaryDiffTests: XCTestCase {

    func testEenWoordGewijzigd() {
        let p = DictionaryDiff.pairs(old: "ik ga naar naslak", new: "ik ga naar Naslag")
        XCTAssertEqual(p.count, 1)
        XCTAssertEqual(p.first?.wrong, "naslak")
        XCTAssertEqual(p.first?.right, "Naslag")
    }

    func testTweeWoordenGewijzigd() {
        let p = DictionaryDiff.pairs(old: "zelesta en naslak", new: "Zelesta en Naslag")
        XCTAssertEqual(p.count, 2)
    }

    func testGeenWijziging() {
        XCTAssertTrue(DictionaryDiff.pairs(old: "alles klopt", new: "alles klopt").isEmpty)
    }

    func testRandinterpunctieEraf() {
        // 'naslak.' → 'Naslag.' levert het paar zonder de punt
        let p = DictionaryDiff.pairs(old: "hallo naslak.", new: "hallo Naslag.")
        XCTAssertEqual(p.first?.wrong, "naslak")
        XCTAssertEqual(p.first?.right, "Naslag")
    }

    func testAlleenInterpunctieVerschil() {
        // 'test' vs 'test.' → geen woord-verschil na trimmen → geen paar
        XCTAssertTrue(DictionaryDiff.pairs(old: "een test", new: "een test.").isEmpty)
    }

    func testVerschillendAantalWoordenGeeftNiets() {
        XCTAssertTrue(DictionaryDiff.pairs(old: "ik ga", new: "ik ga naar huis").isEmpty)
    }
}
