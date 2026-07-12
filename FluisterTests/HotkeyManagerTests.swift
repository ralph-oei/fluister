import XCTest
import CoreGraphics
@testable import Fluister

final class HotkeyManagerTests: XCTestCase {

    // MARK: - HotkeyCombo matching (puur)

    func testComboMatchesActivationWithKeyAndModifier() {
        let combo = HotkeyCombo.defaultPushToTalk // ⌥Space (49, .maskAlternate)
        XCTAssertTrue(combo.matchesActivation(keyCode: 49, flags: .maskAlternate))
    }

    func testComboActivationFailsWithoutModifier() {
        let combo = HotkeyCombo.defaultPushToTalk
        XCTAssertFalse(combo.matchesActivation(keyCode: 49, flags: []))
    }

    func testComboActivationFailsWithWrongKey() {
        let combo = HotkeyCombo.defaultPushToTalk
        XCTAssertFalse(combo.matchesActivation(keyCode: 48, flags: .maskAlternate))
    }

    func testComboKeyUpMatchesOnKeyOnly() {
        let combo = HotkeyCombo.defaultPushToTalk
        // Loslaten matcht ook als de modifier al los is.
        XCTAssertTrue(combo.matchesKey(keyCode: 49))
        XCTAssertFalse(combo.matchesKey(keyCode: 48))
    }

    func testComboActivationMatchesWhenExtraModifiersPresent() {
        let combo = HotkeyCombo.defaultPushToTalk
        let flags: CGEventFlags = [.maskAlternate, .maskNonCoalesced]
        XCTAssertTrue(combo.matchesActivation(keyCode: 49, flags: flags))
    }

    // MARK: - Consume-router (welke events slokken we op?)

    func testRouterPassesThroughPlainSpace() {
        // Regressie: gewone Space (zonder ⌥) mag NIET worden opgeslokt,
        // anders breekt bv. Quick Look in Finder.
        var router = HotkeyEventRouter(combo: .defaultPushToTalk, consumeMatchingEvents: true)

        let down = router.route(isKeyDown: true, keyCode: 49, flags: [], isRepeat: false)
        XCTAssertNil(down.event, "gewone Space-keyDown gaat niet naar de state machine")
        XCTAssertFalse(down.consume, "gewone Space-keyDown moet doorgelaten worden")

        let up = router.route(isKeyDown: false, keyCode: 49, flags: [], isRepeat: false)
        XCTAssertNil(up.event)
        XCTAssertFalse(up.consume, "gewone Space-keyUp mag niet geconsumeerd worden")
    }

    func testRouterConsumesOptionSpacePair() {
        var router = HotkeyEventRouter(combo: .defaultPushToTalk, consumeMatchingEvents: true)

        let down = router.route(isKeyDown: true, keyCode: 49, flags: .maskAlternate, isRepeat: false)
        XCTAssertEqual(down.event, .keyDown(isRepeat: false))
        XCTAssertTrue(down.consume, "⌥Space-keyDown hoort opgeslokt te worden")

        // ⌥ mag vóór Space losgelaten zijn: keyUp matcht op keycode en is van ons.
        let up = router.route(isKeyDown: false, keyCode: 49, flags: [], isRepeat: false)
        XCTAssertEqual(up.event, .keyUp)
        XCTAssertTrue(up.consume, "de bijbehorende Space-keyUp is van ons")
    }

    func testRouterKeyUpWithoutOwnedKeyDownPassesThrough() {
        // Space-keyUp terwijl we nooit een ⌥Space-keyDown consumeerden → doorlaten.
        var router = HotkeyEventRouter(combo: .defaultPushToTalk, consumeMatchingEvents: true)
        let up = router.route(isKeyDown: false, keyCode: 49, flags: .maskAlternate, isRepeat: false)
        XCTAssertNil(up.event)
        XCTAssertFalse(up.consume)
    }

    func testRouterNonComboKeysPassThrough() {
        var router = HotkeyEventRouter(combo: .defaultPushToTalk, consumeMatchingEvents: true)
        let down = router.route(isKeyDown: true, keyCode: 48, flags: .maskAlternate, isRepeat: false)
        XCTAssertNil(down.event)
        XCTAssertFalse(down.consume)
    }

    func testUpdateComboReplacesActiveCombo() {
        let manager = HotkeyManager(consumeMatchingEvents: true)
        XCTAssertEqual(manager.currentCombo.keyCode, 49) // default ⌥Space

        let newCombo = HotkeyCombo(keyCode: 2, requiredFlags: [.maskCommand, .maskShift]) // ⌘⇧D
        manager.updateCombo(newCombo)

        XCTAssertEqual(manager.currentCombo, newCombo)
    }

    // MARK: - State machine: hold-modus

    func testHoldStartsOnKeyDownAndStopsOnKeyUp() {
        var starts = 0, stops = 0
        let sm = HotkeyStateMachine(mode: .hold, onStart: { starts += 1 }, onStop: { stops += 1 })

        sm.handle(.keyDown(isRepeat: false))
        XCTAssertEqual(sm.state, .recording)
        XCTAssertEqual(starts, 1)

        sm.handle(.keyUp)
        XCTAssertEqual(sm.state, .idle)
        XCTAssertEqual(stops, 1)
    }

    func testHoldIgnoresKeyRepeat() {
        var starts = 0
        let sm = HotkeyStateMachine(mode: .hold, onStart: { starts += 1 }, onStop: {})

        sm.handle(.keyDown(isRepeat: false))
        sm.handle(.keyDown(isRepeat: true))   // auto-repeat tijdens ingedrukt houden
        sm.handle(.keyDown(isRepeat: true))
        XCTAssertEqual(starts, 1, "key-repeat mag opname niet opnieuw starten")
        XCTAssertEqual(sm.state, .recording)
    }

    func testHoldIgnoresKeyUpWhenIdle() {
        var stops = 0
        let sm = HotkeyStateMachine(mode: .hold, onStart: {}, onStop: { stops += 1 })

        sm.handle(.keyUp)   // losse keyUp zonder actieve opname
        XCTAssertEqual(sm.state, .idle)
        XCTAssertEqual(stops, 0)
    }

    // MARK: - State machine: toggle-modus

    func testTogglePressStartsThenSecondPressStops() {
        var starts = 0, stops = 0
        let sm = HotkeyStateMachine(mode: .toggle, onStart: { starts += 1 }, onStop: { stops += 1 })

        sm.handle(.keyDown(isRepeat: false)) // druk 1 → start
        sm.handle(.keyUp)                     // loslaten genegeerd in toggle
        XCTAssertEqual(sm.state, .recording)
        XCTAssertEqual(starts, 1)
        XCTAssertEqual(stops, 0)

        sm.handle(.keyDown(isRepeat: false)) // druk 2 → stop
        sm.handle(.keyUp)
        XCTAssertEqual(sm.state, .idle)
        XCTAssertEqual(stops, 1)
    }

    func testToggleIgnoresKeyUpAndRepeat() {
        var starts = 0, stops = 0
        let sm = HotkeyStateMachine(mode: .toggle, onStart: { starts += 1 }, onStop: { stops += 1 })

        sm.handle(.keyUp)                    // genegeerd
        sm.handle(.keyDown(isRepeat: true))  // repeat genegeerd
        XCTAssertEqual(sm.state, .idle)
        XCTAssertEqual(starts, 0)
        XCTAssertEqual(stops, 0)
    }
}
