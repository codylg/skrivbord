import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService.mainApp for the "Launch at Login" toggle.
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled: Bool

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("LaunchAtLoginManager: failed to \(enabled ? "register" : "unregister"): \(error)")
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
