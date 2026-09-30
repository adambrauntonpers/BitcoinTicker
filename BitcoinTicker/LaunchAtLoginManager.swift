import Foundation
import Combine
import ServiceManagement

/// Wraps `SMAppService.mainApp` (macOS 13+) to toggle Launch at Login.
final class LaunchAtLoginManager: ObservableObject {

    @Published private(set) var isEnabled: Bool = false

    init() {
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update Launch at Login:", error)
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
