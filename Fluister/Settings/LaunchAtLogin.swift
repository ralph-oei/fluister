import Foundation
import ServiceManagement

/// Naad zodat de login-item-logica testbaar is zonder echte SMAppService-call.
protocol LoginItemControlling {
    var isEnabled: Bool { get }
    func enable() throws
    func disable() throws
}

/// Echte implementatie op SMAppService.mainApp (macOS 13+).
struct SystemLoginItem: LoginItemControlling {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func enable() throws { try SMAppService.mainApp.register() }
    func disable() throws { try SMAppService.mainApp.unregister() }
}

/// Vertaalt een toggle-intentie naar enable/disable en publiceert de werkelijke
/// status. Bij een fout blijft de status wat het systeem zegt — geen valse "aan".
@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled: Bool
    private let item: LoginItemControlling

    init(item: LoginItemControlling = SystemLoginItem()) {
        self.item = item
        self.isEnabled = item.isEnabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try item.enable() } else { try item.disable() }
        } catch {
            // Bewust stil: de UI toont hieronder de werkelijke systeemstatus.
        }
        isEnabled = item.isEnabled
    }
}
