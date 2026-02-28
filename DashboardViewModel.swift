import Foundation
import Observation

enum DashboardLiveConnectionState: Sendable {
    case idle
    case connecting
    case connected
    case reconnecting
}

@MainActor
@Observable
final class DashboardViewModel {
    var dashboard: LookupResponse?
    var isLoading = false
    var errorMessage: String?
    var liveConnectionState: DashboardLiveConnectionState = .idle
    private var streamTask: Task<Void, Never>?
    private var streamApiKey: String?

    func fetchDashboard(apiKey: String) async {
        let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedApiKey.isEmpty else {
            dashboard = nil
            errorMessage = "Vui lòng nhập API key trong Settings."
            stopLiveUpdates()
            UserDefaults.standard.removeObject(forKey: AppConfig.latestBalanceStorageKey)
            NotificationCenter.default.post(name: .latestBalanceDidChange, object: nil)
            return
        }

        startLiveUpdatesIfNeeded(apiKey: trimmedApiKey)
        isLoading = true
        errorMessage = nil

        do {
            let result = try await DashboardService.lookup(apiKey: trimmedApiKey)
            dashboard = result
            UserDefaults.standard.set(result.balance, forKey: AppConfig.latestBalanceStorageKey)
            NotificationCenter.default.post(name: .latestBalanceDidChange, object: nil)
        } catch {
            errorMessage = "Không tải được dữ liệu API: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func stopStreaming() {
        stopLiveUpdates()
    }

    private func startLiveUpdatesIfNeeded(apiKey: String) {
        if streamApiKey == apiKey, streamTask != nil {
            return
        }

        stopLiveUpdates()
        streamApiKey = apiKey

        streamTask = Task { [weak self] in
            await Self.streamUpdates(
                apiKey: apiKey,
                onStateChange: { [weak self] state in
                    guard let model = self else { return }
                    await model.handleStreamState(state, apiKey: apiKey)
                },
                onMessage: { [weak self] message in
                guard let model = self else { return }
                await model.handleStreamMessage(message, apiKey: apiKey)
                }
            )
        }
    }

    private func stopLiveUpdates() {
        streamTask?.cancel()
        streamTask = nil
        streamApiKey = nil
        liveConnectionState = .idle
    }

    private static func streamUpdates(
        apiKey: String,
        onStateChange: @escaping @Sendable (DashboardLiveConnectionState) async -> Void,
        onMessage: @escaping @Sendable (DashboardWebSocketMessage) async -> Void
    ) async {
        var isFirstAttempt = true
        while !Task.isCancelled {
            await onStateChange(isFirstAttempt ? .connecting : .reconnecting)

            do {
                let socket = try DashboardService.makeDashboardWebSocketTask(apiKey: apiKey)
                socket.resume()
                await onStateChange(.connected)
                try await consumeWebSocketMessages(from: socket, onMessage: onMessage)
            } catch {
                if Task.isCancelled {
                    break
                }
            }

            isFirstAttempt = false
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private static func consumeWebSocketMessages(
        from socket: URLSessionWebSocketTask,
        onMessage: @escaping @Sendable (DashboardWebSocketMessage) async -> Void
    ) async throws {
        while !Task.isCancelled {
            guard let text = try await DashboardService.receiveTextMessage(from: socket) else {
                continue
            }

            let message = try DashboardService.decodeWebSocketMessage(from: text)
            guard message.type == "usage_update" else {
                continue
            }

            await onMessage(message)
        }
    }

    private func apply(message: DashboardWebSocketMessage) {
        if var current = dashboard {
            let newUsage = message.data.usage.asUsageItem()
            var mergedUsage = current.usage
            mergedUsage.insert(newUsage, at: 0)
            mergedUsage.sort { $0.createdAt > $1.createdAt }
            mergedUsage = Array(mergedUsage.prefix(50))

            current.balance = message.data.balance
            current.lastUsed = max(current.lastUsed, newUsage.createdAt)
            current.usage = mergedUsage
            current.stats.totalRequests += 1
            current.stats.promptTokens += newUsage.promptTokens
            current.stats.completionTokens += newUsage.completionTokens
            current.stats.totalCost += newUsage.costUSD

            dashboard = current
        }

        UserDefaults.standard.set(message.data.balance, forKey: AppConfig.latestBalanceStorageKey)
        NotificationCenter.default.post(name: .latestBalanceDidChange, object: nil)
    }

    private func handleStreamMessage(_ message: DashboardWebSocketMessage, apiKey: String) {
        guard streamApiKey == apiKey else { return }
        apply(message: message)
    }

    private func handleStreamState(_ state: DashboardLiveConnectionState, apiKey: String) {
        guard streamApiKey == apiKey else { return }
        liveConnectionState = state
    }
}
