import Foundation

enum AppConfig {
    static let apiKeychainService = "com.claudiable.status"
    static let apiKeychainAccount = "claudible_api_key"
    static let latestBalanceStorageKey = "latest_balance"
    static let dashboardWebSocketEndpoint = "wss://claudible.io/dashboard/ws"
    static let dashboardDisplayModeStorageKey = "dashboard_display_mode"
    static let githubRepoOwner = "pdong15dth"
    static let githubRepoName = "claudiable_status"
    static let lastUpdateCheckVersionKey = "last_update_check_version"
    static let lastUpdateCheckTimeKey = "last_update_check_time"
    static let updateCheckIntervalSeconds: TimeInterval = 4 * 60 * 60 // 4 hours
}

enum DashboardDisplayMode: String, CaseIterable {
    case compact
    case full

    var title: String {
        switch self {
        case .compact:
            return "Compact"
        case .full:
            return "Full"
        }
    }

    static func loadFromDefaults() -> DashboardDisplayMode {
        guard
            let rawValue = UserDefaults.standard.string(forKey: AppConfig.dashboardDisplayModeStorageKey),
            let mode = DashboardDisplayMode(rawValue: rawValue)
        else {
            return .full
        }

        return mode
    }

    func saveToDefaults() {
        UserDefaults.standard.set(rawValue, forKey: AppConfig.dashboardDisplayModeStorageKey)
    }
}

extension Notification.Name {
    static let latestBalanceDidChange = Notification.Name("latest_balance_did_change")
    static let apiKeyDidChange = Notification.Name("api_key_did_change")
    static let dashboardDisplayModeDidChange = Notification.Name("dashboard_display_mode_did_change")
    static let updateAvailable = Notification.Name("update_available")
}
