import XCTest
import CoreGraphics
import AppKit
import KeyboardShortcuts
@testable import Fluister

final class HotkeyShortcutTests: XCTestCase {

    func testMapsOptionSpace() {
        let shortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.option])
        let combo = HotkeyCombo(shortcut: shortcut)
        XCTAssertEqual(combo?.keyCode, 49)               // kVK_Space
        XCTAssertEqual(combo?.requiredFlags, .maskAlternate)
    }

    func testMapsCommandShiftD() {
        let shortcut = KeyboardShortcuts.Shortcut(.d, modifiers: [.command, .shift])
        let combo = HotkeyCombo(shortcut: shortcut)
        XCTAssertEqual(combo?.keyCode, CGKeyCode(KeyboardShortcuts.Key.d.rawValue))
        XCTAssertEqual(combo?.requiredFlags, [.maskCommand, .maskShift])
    }

    func testNilShortcutMapsToNil() {
        XCTAssertNil(HotkeyCombo(shortcut: nil))
    }

    func testCgFlagsMapsAllFourModifiers() {
        let flags = HotkeyCombo.cgFlags(from: [.command, .option, .control, .shift])
        XCTAssertEqual(flags, [.maskCommand, .maskAlternate, .maskControl, .maskShift])
    }
}
