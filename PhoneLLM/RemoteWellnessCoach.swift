import Foundation
import WellnessCore

struct RemoteCoachConfiguration: Equatable, Sendable {
    let baseURL: URL

    static func parse(_ input: String) throws -> RemoteCoachConfiguration {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RemoteCoachError.invalidURL }

        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: candidate) else {
            throw RemoteCoachError.invalidURL
        }
        components.scheme = components.scheme?.lowercased()
        components.path = ""
        components.query = nil
        components.fragment = nil

        guard
            let scheme = components.scheme,
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            let url = components.url
        else {
            throw RemoteCoachError.invalidURL
        }

        let isLoopback = host == "localhost" || host == "127.0.0.1" || host == "::1"
        let isTailscaleHost = host.lowercased().hasSuffix(".ts.net")
        guard
            (scheme == "https" && isTailscaleHost)
                || (scheme == "http" && isLoopback)
        else {
            throw RemoteCoachError.insecureURL
        }
        return RemoteCoachConfiguration(baseURL: url)
    }

    static func parseConnectionLink(_ url: URL) throws -> RemoteCoachConfiguration {
        guard
            url.scheme?.lowercased() == "lessofaloser",
            url.host?.lowercased() == "connect",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let server = components.queryItems?.first(where: { $0.name == "server" })?.value
        else {
            throw RemoteCoachError.invalidConnectionLink
        }
        return try parse(server)
    }
}

enum RemoteCoachConfigurationStore {
    private static let baseURLKey = "remoteCoach.baseURL"

    static func load() -> RemoteCoachConfiguration? {
        guard let value = UserDefaults.standard.string(forKey: baseURLKey) else { return nil }
        return try? RemoteCoachConfiguration.parse(value)
    }

    static func save(_ configuration: RemoteCoachConfiguration) {
        UserDefaults.standard.set(configuration.baseURL.absoluteString, forKey: baseURLKey)
    }

    static func remove() {
        UserDefaults.standard.removeObject(forKey: baseURLKey)
    }
}

enum RemoteCoachError: LocalizedError {
    case invalidURL
    case insecureURL
    case invalidConnectionLink
    case unavailable
    case incompatibleServer
    case invalidResponse
    case serverRejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Enter a valid computer address."
        case .insecureURL:
            "Computer Coach requires Tailscale HTTPS."
        case .invalidConnectionLink:
            "That Computer Coach connection link is invalid."
        case .unavailable:
            "The computer model is not reachable. Check Tailscale and try again."
        case .incompatibleServer:
            "The computer is running an incompatible gateway version."
        case .invalidResponse:
            "The computer returned an invalid response."
        case let .serverRejected(message):
            message
        }
    }
}

struct RemoteCoachHealth: Decodable, Equatable, Sendable {
    let ok: Bool
    let service: String
    let apiVersion: Int
    let model: String
    let provider: String
}

actor RemoteWellnessCoach {
    private static let maxResponseBytes = 64 * 1024
    private static let fixedCaution = "General wellness information only; not medical advice."
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 190
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        session = URLSession(
            configuration: configuration,
            delegate: NoRedirectSessionDelegate(),
            delegateQueue: nil
        )
    }

    func checkHealth(at configuration: RemoteCoachConfiguration) async throws -> RemoteCoachHealth {
        var request = URLRequest(url: endpoint("v1/ready", at: configuration.baseURL))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await perform(request)
        guard response.statusCode == 200 else { throw RemoteCoachError.unavailable }
        let health = try JSONDecoder().decode(RemoteCoachHealth.self, from: data)
        guard health.ok else { throw RemoteCoachError.unavailable }
        guard
            health.apiVersion == 1,
            health.service == "LessOfALoser Computer Coach",
            health.provider == "ollama",
            !health.model.isEmpty,
            health.model.count <= 120
        else {
            throw RemoteCoachError.incompatibleServer
        }
        return health
    }

    func makeBrief(
        from summary: WellnessTrendSummary,
        using configuration: RemoteCoachConfiguration
    ) async throws -> CoachingBrief {
        var request = URLRequest(url: endpoint("v1/coach", at: configuration.baseURL))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(RemoteCoachRequest(summary: summary))

        let (data, response) = try await perform(request)
        guard response.statusCode == 200 else {
            if let rejection = try? JSONDecoder().decode(RemoteCoachRejection.self, from: data) {
                throw RemoteCoachError.serverRejected(rejection.message)
            }
            throw RemoteCoachError.unavailable
        }

        guard let result = try? JSONDecoder().decode(RemoteCoachResponse.self, from: data) else {
            throw RemoteCoachError.invalidResponse
        }
        guard result.schemaVersion == 1 else { throw RemoteCoachError.incompatibleServer }
        let headline = result.brief.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let observation = result.brief.observation.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestedAction = result.brief.suggestedAction.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            !headline.isEmpty,
            headline.count <= 120,
            !observation.isEmpty,
            observation.count <= 320,
            !suggestedAction.isEmpty,
            suggestedAction.count <= 320
        else {
            throw RemoteCoachError.invalidResponse
        }
        return CoachingBrief(
            headline: headline,
            observation: observation,
            suggestedAction: suggestedAction,
            caution: Self.fixedCaution,
            source: .remoteComputer
        )
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RemoteCoachError.invalidResponse
            }
            guard data.count <= Self.maxResponseBytes else {
                throw RemoteCoachError.invalidResponse
            }
            return (data, httpResponse)
        } catch let error as RemoteCoachError {
            throw error
        } catch {
            throw RemoteCoachError.unavailable
        }
    }

    private func endpoint(_ path: String, at baseURL: URL) -> URL {
        baseURL.appendingPathComponent(path)
    }
}

private final class NoRedirectSessionDelegate: NSObject, URLSessionTaskDelegate,
    @unchecked Sendable
{
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

private struct RemoteCoachRequest: Encodable {
    let schemaVersion = 1
    let summary: WellnessTrendSummary
}

private struct RemoteCoachResponse: Decodable {
    let schemaVersion: Int
    let requestID: String
    let model: String
    let brief: RemoteBrief
}

private struct RemoteBrief: Decodable {
    let headline: String
    let observation: String
    let suggestedAction: String
    let caution: String
}

private struct RemoteCoachRejection: Decodable {
    let message: String
}
