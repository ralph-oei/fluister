import Foundation
import CoreGraphics
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Push-to-talk sneltoets. Default ⌥Space; opgeslagen door KeyboardShortcuts.
    static let pushToTalk = Self("pushToTalk", default: .init(.space, modifiers: [.option]))
}

extension HotkeyCombo {
    /// Pure mapping van een KeyboardShortcuts-shortcut naar onze CGEventTap-combo.
    /// nil-shortcut (recorder leeggemaakt) → nil; de caller valt dan terug op de
    /// default ⌥Space.
    init?(shortcut: KeyboardShortcuts.Shortcut?) {
        guard let shortcut, let key = shortcut.key else { return nil }
        self.init(
            keyCode: CGKeyCode(key.rawValue),
            requiredFlags: HotkeyCombo.cgFlags(from: shortcut.modifiers)
        )
    }

    /// NSEvent.ModifierFlags → CGEventFlags (alleen de vier relevante modifiers).
    static func cgFlags(from modifiers: NSEvent.ModifierFlags) -> CGEventFlags {
        var flags: CGEventFlags = []
        if modifiers.contains(.command) { flags.insert(.maskCommand) }
        if modifiers.contains(.option)  { flags.insert(.maskAlternate) }
        if modifiers.contains(.control) { flags.insert(.maskControl) }
        if modifiers.contains(.shift)   { flags.insert(.maskShift) }
        return flags
    }
}
