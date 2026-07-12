import SwiftUI
import KeyboardShortcuts

/// Het Settings-venster (⌘,). Pickers binden op AppSettings (source of truth);
/// de sneltoets-recorder meldt wijzigingen via onHotkeyChange; het login-item
/// via de LaunchAtLoginController.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    let onHotkeyChange: (KeyboardShortcuts.Shortcut?) -> Void

    var body: some View {
        Form {
            Picker("Taal", selection: $settings.language) {
                Text("Nederlands").tag("nl")
                Text("Engels").tag("en")
            }

            KeyboardShortcuts.Recorder("Sneltoets", name: .pushToTalk) { shortcut in
                onHotkeyChange(shortcut)
            }

            Toggle("Start bij inloggen", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
        }
        .padding(20)
        .frame(width: 360)
    }
}
