import Foundation

struct UpdateInfo {
    let version: String
    let releaseURL: URL
}

enum UpdateChecker {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()

    /// Check GitHub Releases for a newer version than the current bundle version.
    static func checkForUpdate() async -> UpdateInfo? {
        let owner = AppConfig.githubRepoOwner
        let repo = AppConfig.githubRepoName

        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let htmlURL = json["html_url"] as? String,
              let releaseURL = URL(string: htmlURL) else {
            return nil
        }

        let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }

        guard isVersion(remoteVersion, newerThan: currentVersion) else {
            return nil
        }

        return UpdateInfo(version: remoteVersion, releaseURL: releaseURL)
    }

    /// Semantic version comparison. Returns true if `a` is strictly newer than `b`.
    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let partsA = a.split(separator: ".").compactMap { Int($0) }
        let partsB = b.split(separator: ".").compactMap { Int($0) }

        let count = max(partsA.count, partsB.count)
        for i in 0..<count {
            let valA = i < partsA.count ? partsA[i] : 0
            let valB = i < partsB.count ? partsB[i] : 0
            if valA > valB { return true }
            if valA < valB { return false }
        }
        return false
    }

    /// Whether enough time has passed since the last auto-check.
    static var shouldAutoCheck: Bool {
        let lastCheck = UserDefaults.standard.double(forKey: AppConfig.lastUpdateCheckTimeKey)
        guard lastCheck > 0 else { return true }
        return Date().timeIntervalSince1970 - lastCheck >= AppConfig.updateCheckIntervalSeconds
    }

    /// Record that an auto-check just happened.
    static func recordCheckTime() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppConfig.lastUpdateCheckTimeKey)
    }

    /// The version the user was last notified about. Avoids repeated toasts for the same version.
    static var lastNotifiedVersion: String? {
        get { UserDefaults.standard.string(forKey: AppConfig.lastUpdateCheckVersionKey) }
        set { UserDefaults.standard.set(newValue, forKey: AppConfig.lastUpdateCheckVersionKey) }
    }
}
