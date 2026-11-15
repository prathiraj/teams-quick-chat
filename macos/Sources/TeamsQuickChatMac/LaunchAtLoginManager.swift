import AppKit
import Foundation
import ServiceManagement

public enum LaunchAtLoginError: LocalizedError {
    case registrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .registrationFailed(let detail):
            return "Could not update Login Items setting: \(detail)"
        }
    }
}

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false
    @Published private(set) var requiresApproval: Bool = false

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        let status = SMAppService.mainApp.status
        isEnabled = (status == .enabled || status == .requiresApproval)
        requiresApproval = (status == .requiresApproval)
    }

    func setEnabled(_ enabled: Bool) throws {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                    try SMAppService.mainApp.unregister()
                }
            }
            refreshStatus()
        } catch {
            refreshStatus()
            throw LaunchAtLoginError.registrationFailed(error.localizedDescription)
        }
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
