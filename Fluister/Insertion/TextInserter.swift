import AppKit
import CoreGraphics
import Carbon.HIToolbox

// U6 — voegt getranscribeerde tekst in op de cursorpositie in de actieve app.
//
// Strategie (KTD2): klembord-paste. Het bestaande klembord wordt bewaard, de
// tekst erop gezet, ⌘V gesynthetiseerd (CGEvent), en het klembord hersteld.
// Paste werkt betrouwbaar over vrijwel alle apps (ook Electron/web), waar directe
// Accessibility-schrijfacties vaak falen.
//
// De klembord-helpers zijn testbaar (injecteerbare NSPasteboard); de ⌘V-injectie
// is systeemwerk en wordt handmatig geverifieerd.

/// Naad voor de orkestratie (U7), zodat DictationController met een fake test.
protocol TextInserting: AnyObject {
    func insert(_ text: String)
}

final class TextInserter: TextInserting {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    /// Voegt tekst in op de cursor via klembord-paste, met behoud van het klembord.
    func insert(_ text: String) {
        guard !text.isEmpty else { return }
        // Wachtwoordvelden blokkeren synthetische events: netjes niets doen.
        guard !IsSecureEventInputEnabled() else {
            NSLog("Fluister: secure input actief, insertie overgeslagen")
            return
        }

        let saved = capturePasteboard()
        setPasteboard(text)
        postPasteShortcut()

        // Klembord herstellen ná de paste (kleine vertraging zodat ⌘V verwerkt is).
        // STERKE self-capture: de inserter moet blijven leven tot het herstel klaar
        // is, ook als 'ie een tijdelijk object is (anders gaat het klembord verloren).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.restorePasteboard(saved)
        }
    }

    // MARK: - Testbare klembord-helpers

    /// Maakt onafhankelijke kopieën van de huidige klembord-items (alle types).
    func capturePasteboard() -> [NSPasteboardItem] {
        var copies: [NSPasteboardItem] = []
        for item in pasteboard.pasteboardItems ?? [] {
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            copies.append(copy)
        }
        return copies
    }

    func setPasteboard(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func restorePasteboard(_ items: [NSPasteboardItem]) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    // MARK: - Systeem: ⌘V synthetiseren (niet unit-getest)

    private func postPasteShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09 // 'v'
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
