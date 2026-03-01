import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var balanceObserver: NSObjectProtocol?
    private var apiKeyObserver: NSObjectProtocol?
    private var displayModeObserver: NSObjectProtocol?
    private var updateCheckTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = statusTitle()
            button.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        balanceObserver = NotificationCenter.default.addObserver(
            forName: .latestBalanceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStatusTitle()
        }

        apiKeyObserver = NotificationCenter.default.addObserver(
            forName: .apiKeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleAPIKeyChange()
        }

        displayModeObserver = NotificationCenter.default.addObserver(
            forName: .dashboardDisplayModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePopoverContentSize()
        }

        // Configure popover with SwiftUI content
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PopoverContentView(onQuit: { [weak self] in
            self?.quit()
        }))
        self.popover = popover
        updatePopoverContentSize()

        Task {
            await refreshBalanceAtLaunch()
        }

        // Schedule update check: once after 5s delay, then every 4 hours
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.performAutoUpdateCheck()
            self?.updateCheckTimer = Timer.scheduledTimer(
                withTimeInterval: AppConfig.updateCheckIntervalSeconds,
                repeats: true
            ) { [weak self] _ in
                self?.performAutoUpdateCheck()
            }
        }
    }

    deinit {
        updateCheckTimer?.invalidate()
        if let balanceObserver {
            NotificationCenter.default.removeObserver(balanceObserver)
        }
        if let apiKeyObserver {
            NotificationCenter.default.removeObserver(apiKeyObserver)
        }
        if let displayModeObserver {
            NotificationCenter.default.removeObserver(displayModeObserver)
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateStatusTitle() {
        statusItem.button?.title = statusTitle()
    }

    private func statusTitle() -> String {
        guard UserDefaults.standard.object(forKey: AppConfig.latestBalanceStorageKey) != nil else {
            return "Balance: --"
        }
        let balance = UserDefaults.standard.double(forKey: AppConfig.latestBalanceStorageKey)
        var title = "Balance: \(balance.usd)"
        if UserDefaults.standard.object(forKey: AppConfig.latestCostStorageKey) != nil {
            let cost = UserDefaults.standard.double(forKey: AppConfig.latestCostStorageKey)
            title += " (-\(cost.usdPrecise))"
        }
        return title
    }

    private func updatePopoverContentSize() {
        let mode = DashboardDisplayMode.loadFromDefaults()
        let size: NSSize

        switch mode {
        case .compact:
            size = NSSize(width: 420, height: 320)
        case .full:
            size = NSSize(width: 620, height: 760)
        }

        popover.contentSize = size
    }

    private func refreshBalanceAtLaunch() async {
        let apiKey = APIKeyStore.load()
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        do {
            let dashboard = try await DashboardService.lookup(apiKey: apiKey)
            UserDefaults.standard.set(dashboard.balance, forKey: AppConfig.latestBalanceStorageKey)
            updateStatusTitle()
        } catch {
            // Keep cached value if network is unavailable at startup.
        }
    }

    private func handleAPIKeyChange() {
        let apiKey = APIKeyStore.load().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !apiKey.isEmpty else {
            UserDefaults.standard.removeObject(forKey: AppConfig.latestBalanceStorageKey)
            UserDefaults.standard.removeObject(forKey: AppConfig.latestCostStorageKey)
            updateStatusTitle()
            return
        }

        Task {
            await refreshBalanceAtLaunch()
        }
    }

    private func performAutoUpdateCheck() {
        guard UpdateChecker.shouldAutoCheck else { return }

        Task {
            UpdateChecker.recordCheckTime()
            guard let update = await UpdateChecker.checkForUpdate() else { return }

            // Don't re-notify about a version the user already saw
            guard update.version != UpdateChecker.lastNotifiedVersion else { return }
            UpdateChecker.lastNotifiedVersion = update.version

            await MainActor.run {
                NotificationCenter.default.post(
                    name: .updateAvailable,
                    object: nil,
                    userInfo: ["version": update.version, "url": update.releaseURL]
                )
            }
        }
    }
}
