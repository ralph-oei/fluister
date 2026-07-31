import SwiftUI
import KeyboardShortcuts

/// Het Settings-venster (⌘,). Pickers binden op AppSettings (source of truth);
/// de sneltoets-recorder meldt wijzigingen via onHotkeyChange; het login-item
/// via de LaunchAtLoginController. De woordenlijst leest en schrijft direct op
/// de DictionaryStore, die de dicteer-keten meteen bijwerkt.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var launchAtLogin: LaunchAtLoginController
    @ObservedObject var dictionary: DictionaryStore
    let onHotkeyChange: (KeyboardShortcuts.Shortcut?) -> Void

    @State private var newWrong = ""
    @State private var newRight = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            Divider()

            Text("Woordenlijst")
                .font(.headline)
            Text("Woorden die Whisper vaak verkeerd spelt, en hoe ze moeten. Fluister past ze automatisch toe op elk dictaat.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if dictionary.entries.isEmpty {
                Text("Nog leeg. Corrigeer een dictaat via het menu, dan vult 'ie zichzelf.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(dictionary.entries, id: \.wrong) { e in
                            HStack {
                                Text(e.wrong).foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(e.right)
                                Spacer()
                                Button(role: .destructive) {
                                    dictionary.remove(wrong: e.wrong)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .frame(maxHeight: 140)
            }

            HStack {
                TextField("hoort als…", text: $newWrong)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                TextField("moet zijn…", text: $newRight)
                Button("Voeg toe") {
                    dictionary.add(wrong: newWrong, right: newRight)
                    newWrong = ""
                    newRight = ""
                }
                .disabled(newWrong.trimmingCharacters(in: .whitespaces).isEmpty
                          || newRight.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
