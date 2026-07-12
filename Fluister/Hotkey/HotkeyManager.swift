import Foundation
import CoreGraphics
import ApplicationServices

// U3 — globale push-to-talk sneltoets.
//
// Twee lagen:
//  1. Pure logica (HotkeyCombo + HotkeyStateMachine) — testbaar zonder systeem.
//  2. HotkeyManager wrapt een CGEventTap die echte toetsaanslagen matcht en in
//     de state machine voert. De tap vereist Toegankelijkheid (zie U2).
//
// Default combo: ⌥Space (space = keycode 49). Instelbare sneltoets-recorder
// (KeyboardShortcuts-lib) volgt in U7/settings.

enum HotkeyMode {
    case hold      // ingedrukt = opnemen, loslaten = klaar
    case toggle    // druk 1 = start, druk 2 = stop
}

enum HotkeyEvent: Equatable {
    case keyDown(isRepeat: Bool)
    case keyUp
}

struct HotkeyCombo: Equatable {
    var keyCode: CGKeyCode
    var requiredFlags: CGEventFlags

    /// Activering vereist de juiste toets én alle vereiste modifiers.
    func matchesActivation(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        keyCode == self.keyCode && flags.contains(requiredFlags)
    }

    /// Loslaten matcht op de toets alleen (modifiers kunnen al los zijn) —
    /// voorkomt "blijft hangen in opname" als je ⌥ vóór Space loslaat.
    func matchesKey(keyCode: CGKeyCode) -> Bool {
        keyCode == self.keyCode
    }

    static let defaultPushToTalk = HotkeyCombo(keyCode: 49, requiredFlags: .maskAlternate) // ⌥Space
}

/// Pure state machine: vertaalt toets-events naar start/stop, met debounce
/// (key-repeat negeren) en hold/toggle-gedrag. Geen systeemcalls.
final class HotkeyStateMachine {
    enum State: Equatable { case idle, recording }

    private(set) var state: State = .idle
    var mode: HotkeyMode
    private let onStart: () -> Void
    private let onStop: () -> Void

    init(mode: HotkeyMode, onStart: @escaping () -> Void, onStop: @escaping () -> Void) {
        self.mode = mode
        self.onStart = onStart
        self.onStop = onStop
    }

    func handle(_ event: HotkeyEvent) {
        switch mode {
        case .hold:
            switch event {
            case .keyDown(let isRepeat):
                guard !isRepeat, state == .idle else { return }
                state = .recording
                onStart()
            case .keyUp:
                guard state == .recording else { return }
                state = .idle
                onStop()
            }
        case .toggle:
            switch event {
            case .keyDown(let isRepeat):
                guard !isRepeat else { return }
                if state == .idle {
                    state = .recording
                    onStart()
                } else {
                    state = .idle
                    onStop()
                }
            case .keyUp:
                break
            }
        }
    }
}

/// Pure router: beslist per ruw toets-event of het naar de state machine gaat
/// én of we het opslokken. Houdt bij of we de combo-keyDown consumeerden, zodat
/// een losse Space-keyUp (bv. zonder ⌥) NIET wordt opgeslokt — anders breekt
/// bijvoorbeeld Quick Look (Space) in Finder.
struct HotkeyEventRouter {
    let combo: HotkeyCombo
    let consumeMatchingEvents: Bool
    /// True zodra we een matchende combo-keyDown opslokten; bepaalt of de
    /// bijbehorende keyUp van óns is (modifiers kunnen dan al los zijn).
    private(set) var ownsComboKey = false

    struct Outcome: Equatable {
        var event: HotkeyEvent?   // nil = niet aan state machine voeren
        var consume: Bool         // true = event opslokken (tap geeft nil terug)
    }

    mutating func route(isKeyDown: Bool, keyCode: CGKeyCode, flags: CGEventFlags, isRepeat: Bool) -> Outcome {
        if isKeyDown {
            guard combo.matchesActivation(keyCode: keyCode, flags: flags) else {
                return Outcome(event: nil, consume: false)
            }
            ownsComboKey = true
            return Outcome(event: .keyDown(isRepeat: isRepeat), consume: consumeMatchingEvents)
        } else {
            // Alleen consumeren als dit de keyUp is van een door ons opgeslokte
            // keyDown. Zo blijft een gewone Space-toets ongemoeid.
            guard combo.matchesKey(keyCode: keyCode), ownsComboKey else {
                return Outcome(event: nil, consume: false)
            }
            ownsComboKey = false
            return Outcome(event: .keyUp, consume: consumeMatchingEvents)
        }
    }
}

// MARK: - Systeemlaag (CGEventTap)

private func hotkeyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.process(type: type, event: event)
}

final class HotkeyManager: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isActive = false        // tap geïnstalleerd?

    /// Externe hooks (U7 koppelt hier de opname/transcriptie-pijplijn aan).
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?

    var mode: HotkeyMode {
        didSet { machine.mode = mode }
    }

    private var combo: HotkeyCombo
    private var machine: HotkeyStateMachine!
    private var router: HotkeyEventRouter
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let consumeMatchingEvents: Bool

    init(combo: HotkeyCombo = .defaultPushToTalk, mode: HotkeyMode = .hold, consumeMatchingEvents: Bool = true) {
        self.combo = combo
        self.mode = mode
        self.consumeMatchingEvents = consumeMatchingEvents
        self.router = HotkeyEventRouter(combo: combo, consumeMatchingEvents: consumeMatchingEvents)
        self.machine = HotkeyStateMachine(
            mode: mode,
            onStart: { [weak self] in self?.setRecording(true) },
            onStop: { [weak self] in self?.setRecording(false) }
        )
    }

    private func setRecording(_ recording: Bool) {
        // Tap draait op de main-runloop; hou UI-updates op main.
        DispatchQueue.main.async {
            self.isRecording = recording
            recording ? self.onStart?() : self.onStop?()
        }
    }

    /// Installeert de globale tap. Vereist Toegankelijkheid; faalt netjes zonder.
    @discardableResult
    func start() -> Bool {
        guard AXIsProcessTrusted() else {
            isActive = false
            return false
        }
        guard eventTap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: hotkeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            isActive = false
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        isActive = true
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isActive = false
    }

    /// Testbare lezer van de actieve combo.
    var currentCombo: HotkeyCombo { combo }

    /// Wijzig de actieve sneltoets (bv. na aanpassing in Settings). Herbouwt de
    /// router zodat de consume-logica op de nieuwe combo draait en reset de
    /// "owns"-vlag, zodat een halve keyDown/keyUp niet wordt meegesleept.
    func updateCombo(_ newCombo: HotkeyCombo) {
        combo = newCombo
        router = HotkeyEventRouter(combo: newCombo, consumeMatchingEvents: consumeMatchingEvents)
    }

    /// Verwerkt een ruw tap-event; retourneert nil om 't te consumeren.
    fileprivate func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Tap kan door timeout/gebruikersinvoer uitvallen — heractiveren.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown || type == .keyUp else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        let outcome = router.route(
            isKeyDown: type == .keyDown,
            keyCode: keyCode,
            flags: flags,
            isRepeat: isRepeat
        )
        if let hotkeyEvent = outcome.event {
            machine.handle(hotkeyEvent)
        }
        return outcome.consume ? nil : Unmanaged.passUnretained(event)
    }
}
