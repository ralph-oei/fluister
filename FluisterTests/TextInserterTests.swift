import XCTest
import AppKit
@testable import Fluister

final class TextInserterTests: XCTestCase {

    // Eigen (privé) pasteboard zodat de tests het echte klembord van de gebruiker
    // niet aanraken.
    private func makePasteboard(_ name: String) -> NSPasteboard {
        let pb = NSPasteboard(name: NSPasteboard.Name("FluisterTest-\(name)"))
        pb.clearContents()
        return pb
    }

    func testSetPasteboardWritesText() {
        let pb = makePasteboard("set")
        let inserter = TextInserter(pasteboard: pb)
        inserter.setPasteboard("hallo wereld")
        XCTAssertEqual(pb.string(forType: .string), "hallo wereld")
    }

    func testCaptureAndRestoreRoundTripsText() {
        let pb = makePasteboard("roundtrip")
        pb.setString("oorspronkelijk", forType: .string)

        let inserter = TextInserter(pasteboard: pb)
        let snapshot = inserter.capturePasteboard()

        inserter.setPasteboard("tijdelijk")
        XCTAssertEqual(pb.string(forType: .string), "tijdelijk")

        inserter.restorePasteboard(snapshot)
        XCTAssertEqual(pb.string(forType: .string), "oorspronkelijk")
    }

    func testRestoreEmptyPasteboardClears() {
        let pb = makePasteboard("empty")
        let inserter = TextInserter(pasteboard: pb)

        // Leeg klembord vastleggen
        let snapshot = inserter.capturePasteboard()
        XCTAssertTrue(snapshot.isEmpty)

        inserter.setPasteboard("iets")
        XCTAssertEqual(pb.string(forType: .string), "iets")

        inserter.restorePasteboard(snapshot)
        XCTAssertNil(pb.string(forType: .string), "na herstel van leeg klembord mag er geen tekst zijn")
    }

    func testCaptureRestoresNonTextData() {
        let pb = makePasteboard("binary")
        // Zet niet-tekst data (bijv. een 'afbeelding') op het klembord.
        let blob = Data([0x01, 0x02, 0x03, 0x04])
        let type = NSPasteboard.PasteboardType("public.tiff")
        pb.clearContents()
        pb.setData(blob, forType: type)

        let inserter = TextInserter(pasteboard: pb)
        let snapshot = inserter.capturePasteboard()

        inserter.setPasteboard("tekst ertussen")
        XCTAssertEqual(pb.string(forType: .string), "tekst ertussen")

        inserter.restorePasteboard(snapshot)
        XCTAssertEqual(pb.data(forType: type), blob, "niet-tekst data moet exact hersteld worden")
    }
}
