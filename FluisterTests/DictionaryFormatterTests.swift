import XCTest
@testable import Fluister

final class DictionaryFormatterTests: XCTestCase {

    func testVervangtHeelWoord() {
        XCTAssertEqual(
            DictionaryFormatter.apply("ik gebruik naslak elke dag", pairs: [("naslak", "Naslag")]),
            "ik gebruik Naslag elke dag")
    }

    func testCaseOngevoeligeMatch() {
        XCTAssertEqual(
            DictionaryFormatter.apply("NASLAK werkt", pairs: [("naslak", "Naslag")]),
            "Naslag werkt")
    }

    func testHoofdletterBehoud() {
        // match begint met hoofdletter, right is kleine letter → right krijgt hoofdletter
        XCTAssertEqual(
            DictionaryFormatter.apply("Naslak hier", pairs: [("naslak", "naslag")]),
            "Naslag hier")
    }

    func testGeenDeelwoord() {
        // 'naslakken' bevat 'naslak' maar mag niet geraakt worden (woordgrens)
        XCTAssertEqual(
            DictionaryFormatter.apply("naslakken zijn traag", pairs: [("naslak", "Naslag")]),
            "naslakken zijn traag")
    }

    func testLangstePaarEerst() {
        let pairs = [("dis", "Dis"), ("van dis", "Van Dis")]
        XCTAssertEqual(
            DictionaryFormatter.apply("boeken van dis", pairs: pairs),
            "boeken Van Dis")
    }

    func testMeerdereVoorkomens() {
        XCTAssertEqual(
            DictionaryFormatter.apply("naslak en naslak", pairs: [("naslak", "Naslag")]),
            "Naslag en Naslag")
    }

    func testLegePairsOngewijzigd() {
        XCTAssertEqual(DictionaryFormatter.apply("gewoon een zin", pairs: []), "gewoon een zin")
    }
}
