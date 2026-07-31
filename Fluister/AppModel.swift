import Foundation
import Combine
import KeyboardShortcuts

// Bezit en bedraadt alle onderdelen. AppSettings is de source of truth voor
// model + taal; wijzigingen daarin sturen de levende objecten aan. De sneltoets
// wordt via KeyboardShortcuts opgeslagen maar door onze eigen tap gedetecteerd.

@MainActor
final class AppModel: ObservableObject {
    let settings = AppSettings()
    /// Persoonlijke woordenlijst; voedt de dicteer-keten en de correctie-flow.
    let dictionary = DictionaryStore()
    let launchAtLogin = LaunchAtLoginController()
    let permissions = PermissionsManager()
    let hotkey = HotkeyManager()
    let recorder = AudioRecorder()
    let model: ModelManager
    let inserter = TextInserter()
    let controller: DictationController

    /// Tikt op bij ⌥Space terwijl het model nog niet klaar is. De UI gebruikt dit om
    /// het onboarding/voortgang-venster naar voren te halen, zodat de eerste-start-
    /// download zichtbaar wordt i.p.v. dat ⌥Space "kapot" lijkt.
    @Published private(set) var modelHintPulse = 0

    private var cancellables = Set<AnyCancellable>()

    /// Verwerkt een handmatige correctie op het laatste dictaat: leert de fout→goed-paren
    /// en vervangt de al-ingevoegde tekst (fix-now).
    func correctLastDictation(edited: String) {
        guard let old = controller.lastInsertedText else { return }
        DictionaryCorrection.apply(old: old, edited: edited, store: dictionary, inserter: inserter)
    }

    init() {
        // Small-only: het model heeft geen naam-voorkeur meer (KTD2).
        model = ModelManager()
        controller = DictationController(recorder: recorder, model: model, inserter: inserter)
        controller.language = settings.language
        controller.dictionaryPairs = dictionary.pairs

        // Opgeslagen sneltoets → onze tap (default ⌥Space als er niets/ongeldig is).
        applyHotkey(KeyboardShortcuts.getShortcut(for: .pushToTalk))

        // Sneltoets → controller (aanroepen komen al op de main-thread binnen).
        hotkey.onStart = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.controller.startDictation()
                // Model nog niet klaar (eerste-start download)? Laat de UI het
                // voortgang-venster tonen — anders lijkt ⌥Space niks te doen.
                if self.model.state != .ready { self.modelHintPulse += 1 }
            }
        }
        hotkey.onStop = { [weak self] in
            MainActor.assumeIsolated { self?.controller.stopDictation() }
        }

        // Settings sturen de levende objecten. dropFirst: de begintoestand is al
        // toegepast in init; alleen latere wijzigingen moeten iets doen.
        settings.$language
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] lang in
                self?.controller.language = lang
            }
            .store(in: &cancellables)

        // Woordenlijst wijzigt (toevoegen/verwijderen/leren) → keten meteen bij.
        dictionary.$entries
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.controller.dictionaryPairs = self?.dictionary.pairs ?? []
            }
            .store(in: &cancellables)

        // Auto-activeren zodra alles mag: sneltoets aan + model laden.
        permissions.$readiness
            .removeDuplicates()
            .sink { [weak self] readiness in
                guard let self, readiness == .ready else { return }
                self.hotkey.start()
                Task { await self.model.load() }
            }
            .store(in: &cancellables)
    }

    /// Map de gekozen sneltoets naar onze combo en voer 'm in de tap. nil/ongeldig
    /// → terug naar de default ⌥Space zodat de app altijd een werkende sneltoets houdt.
    func applyHotkey(_ shortcut: KeyboardShortcuts.Shortcut?) {
        hotkey.updateCombo(HotkeyCombo(shortcut: shortcut) ?? .defaultPushToTalk)
    }
}
