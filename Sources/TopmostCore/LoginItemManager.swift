import Foundation
import ServiceManagement

/// Controls launch-at-login behavior using SMAppService (macOS 13+)
public final class LoginItemManager: ObservableObject {
    public static let shared = LoginItemManager()

    @Published public private(set) var isEnabled: Bool = false

    public init() {
        checkStatus()
    }

    public func checkStatus() {
        if #available(macOS 13.0, *) {
            isEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }

    public func setEnabled(_ enable: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enable {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
                checkStatus()
            } catch {
                NSLog("[Topmost] Error updating login item status: %@", error.localizedDescription)
            }
        }
    }
}
