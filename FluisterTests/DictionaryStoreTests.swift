import XCTest
import Combine
@testable import Fluister

@MainActor
final class DictionaryStoreTests: XCTestCase {

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fluister-dict-\(UUID().uuidString).json")
    }

    func testLeegBijStart() {
        let s = DictionaryStore(url: tempURL())
        XCTAssertTrue(s.entries.isEmpty)
    }

    func testAddEnPersistentie() {
        let url = tempURL()
        let s = DictionaryStore(url: url)
        s.add(wrong: "naslak", right: "Naslag")
        // verse instance leest hetzelfde bestand terug
        let s2 = DictionaryStore(url: url)
        XCTAssertEqual(s2.entries, [DictionaryEntry(wrong: "naslak", right: "Naslag")])
    }

    func testDedupOpWrong() {
        let s = DictionaryStore(url: tempURL())
        s.add(wrong: "naslak", right: "Naslag")
        s.add(wrong: "NASLAK", right: "Naslag2") // zelfde wrong, case-ongevoelig
        XCTAssertEqual(s.entries.count, 1)
        XCTAssertEqual(s.entries.first?.right, "Naslag2") // laatste wint
    }

    func testRemove() {
        let s = DictionaryStore(url: tempURL())
        s.add(wrong: "naslak", right: "Naslag")
        s.remove(wrong: "naslak")
        XCTAssertTrue(s.entries.isEmpty)
    }

    func testPairs() {
        let s = DictionaryStore(url: tempURL())
        s.add(wrong: "naslak", right: "Naslag")
        XCTAssertEqual(s.pairs.first?.wrong, "naslak")
        XCTAssertEqual(s.pairs.first?.right, "Naslag")
    }

    /// Documenteert waarom AppModel de meegeleverde waarde gebruikt en niet de property
    /// opnieuw uitleest: @Published publiceert in willSet, dus tijdens de sink houdt
    /// `entries` nog de oude lijst vast. Een abonnee die de property leest loopt achter.
    func testPublisherLevertNieuweLijstTerwijlPropertyNogOudIs() {
        let s = DictionaryStore(url: tempURL())
        var uitPublisher: [DictionaryEntry] = []
        var uitProperty: [DictionaryEntry] = []

        let c = s.$entries.dropFirst().sink { nieuw in
            uitPublisher = nieuw
            uitProperty = s.entries   // bewust: dit is de val
        }
        s.add(wrong: "ralf.oei@gmail.com", right: "ralph.oei@gmail.com")
        c.cancel()

        XCTAssertEqual(uitPublisher.count, 1, "de publisher levert de nieuwe lijst")
        XCTAssertTrue(uitProperty.isEmpty, "de property loopt achter tijdens de sink")
    }
}
