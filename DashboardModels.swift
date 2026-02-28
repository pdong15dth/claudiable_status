import Foundation

struct LookupRequest: Codable {
    let key: String
}

struct LookupResponse: Codable {
    var valid: Bool
    var balance: Double
    var status: String
    var lastUsed: Date
    var createdAt: Date
    var stats: UsageStats
    var usage: [UsageItem]
    var accountType: String
    var dailyQuota: Double
    var subscriptionExpiresAt: Date
    var subscriptionActive: Bool
    var userName: String
    var analytics: Analytics

    var welcomeText: String {
        "Welcome back, \(userName)"
    }
}

struct UsageStats: Codable {
    var completionTokens: Int
    var promptTokens: Int
    var totalCost: Double
    var totalRequests: Int
}

struct UsageItem: Codable {
    let completionTokens: Int
    let costUSD: Double
    let createdAt: Date
    let id: Int?
    let model: String
    let promptTokens: Int

    var stableID: String {
        if let id {
            return "usage-\(id)"
        }

        return "usage-\(model)-\(createdAt.timeIntervalSince1970)-\(promptTokens)-\(completionTokens)-\(costUSD)"
    }
}

struct DashboardWebSocketMessage: Decodable {
    let type: String
    let timestamp: Date
    let data: DashboardLiveUsageData
}

struct DashboardLiveUsageData: Decodable {
    let balance: Double
    let usage: DashboardLiveUsageItem
}

struct DashboardLiveUsageItem: Decodable {
    let completionTokens: Int
    let costUSD: Double
    let createdAt: Date
    let model: String
    let promptTokens: Int

    func asUsageItem() -> UsageItem {
        UsageItem(
            completionTokens: completionTokens,
            costUSD: costUSD,
            createdAt: createdAt,
            id: nil,
            model: model,
            promptTokens: promptTokens
        )
    }
}

struct Analytics: Codable {
    let dailyUsage: [DailyUsage]
    let modelBreakdown: [ModelBreakdown]
    let hourlyDistribution: [HourlyUsage]
    let daysRemaining: DaysRemaining
}

struct ModelBreakdown: Codable {
    let model: String
    let totalCost: Double

    enum CodingKeys: String, CodingKey {
        case model
        case totalCost = "totalCostUSD"
    }
}

struct DaysRemaining: Codable {
    let runwayMinutes: Double
    let avgCostPerMinute: Double
    let avgDailyCost7d: Double
}

struct HourlyUsage: Codable {
    let hourOfDay: Int
    let totalRequests: Int
    let totalCostUSD: Double
}
struct DailyUsage: Codable {
    let date: String
    let totalRequests: Int
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCostUSD: Double
}
