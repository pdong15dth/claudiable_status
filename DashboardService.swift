import Foundation

enum DashboardService {
    private static let endpoint = URL(string: "https://claudible.io/dashboard/lookup")!

    static func lookup(apiKey: String) async throws -> LookupResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LookupRequest(key: apiKey))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        guard !data.isEmpty else {
            throw DashboardServiceError.emptyBody(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder.lookupDecoder.decode(LookupResponse.self, from: data)
        } catch let error as DecodingError {
            throw DashboardServiceError.decodingFailed(error.localizedDescription)
        } catch {
            throw error
        }
    }

    static func makeDashboardWebSocketTask(apiKey: String) throws -> URLSessionWebSocketTask {
        guard var components = URLComponents(string: AppConfig.dashboardWebSocketEndpoint) else {
            throw URLError(.badURL)
        }

        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = components.url else {
            throw URLError(.badURL)
        }

        return URLSession.shared.webSocketTask(with: url)
    }

    static func receiveTextMessage(from task: URLSessionWebSocketTask) async throws -> String? {
        let message = try await task.receive()
        switch message {
        case .string(let text):
            return text
        case .data(let data):
            return String(data: data, encoding: .utf8)
        @unknown default:
            return nil
        }
    }

    static func decodeWebSocketMessage(from text: String) throws -> DashboardWebSocketMessage {
        guard let data = text.data(using: .utf8) else {
            throw DashboardServiceError.decodingFailed("WebSocket payload is not valid UTF-8")
        }

        do {
            return try JSONDecoder.lookupDecoder.decode(DashboardWebSocketMessage.self, from: data)
        } catch let error as DecodingError {
            throw DashboardServiceError.decodingFailed(error.localizedDescription)
        } catch {
            throw error
        }
    }
}

enum DashboardServiceError: LocalizedError {
    case emptyBody(statusCode: Int)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyBody(let statusCode):
            return "API trả body rỗng (status \(statusCode))."
        case .decodingFailed(let details):
            return "Không parse được dữ liệu API: \(details)"
        }
    }
}

private extension JSONDecoder {
    static let lookupDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = DashboardDateParser.parse(value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(value)"
            )
        }
        return decoder
    }()
}

private enum DashboardDateParser {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let basicFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func parse(_ value: String) -> Date? {
        fractionalFormatter.date(from: value) ?? basicFormatter.date(from: value)
    }
}
