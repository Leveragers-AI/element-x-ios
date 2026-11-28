//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

enum FrontDoorError: Error, Equatable {
    /// The domain of the address isn't valid: the person types it again.
    case invalidEmail
    /// The front door is unreachable, slow, refused the request or gave an invalid answer: the person tries again.
    /// Never a reason to fall back to the pro server.
    case frontDoorUnavailable
}

protocol FrontDoorServiceProtocol {
    /// The chat server (a Matrix server name) of an email address.
    func serverName(forEmail email: String) async -> Result<String, FrontDoorError>
}

/// Leveragers: the front door, which names the chat server of an email address before sign-in.
///
/// `d/<domain>.json` names the server of an enterprise domain. Without it, Microsoft's public discovery gives the
/// domain's tenant ID and `t/<tenant ID>.json` may name a server. Otherwise, the pro server.
/// The same rules in the web, iOS and Android apps.
final class FrontDoorService: FrontDoorServiceProtocol {
    typealias Fetch = (URLRequest) async throws -> (Data, URLResponse)
    
    /// The pro server, for every address the front door doesn't route elsewhere.
    static let proServerName = "chat.leveragers.com"
    
    static let requestTimeout: TimeInterval = 8
    
    private static let domainPattern = #"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$"#
    private static let leveragersServerPattern = #"^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*\.leveragers\.com$"#
    private static let microsoftIssuerPattern = #"^https://login\.microsoftonline\.com/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/v2\.0/?$"#
    
    private let baseURL: URL
    private let fetch: Fetch
    
    /// - Parameters:
    ///   - baseURL: The front door's address (`AppSettings.leveragersFrontDoorURL`).
    ///   - fetch: Sends a request, replaced in the tests. By default, without cache or cookies.
    init(baseURL: URL, fetch: Fetch? = nil) {
        self.baseURL = baseURL
        
        if let fetch {
            self.fetch = fetch
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = Self.requestTimeout
            configuration.timeoutIntervalForResource = Self.requestTimeout
            let session = URLSession(configuration: configuration)
            self.fetch = { request in try await session.data(for: request) }
        }
    }
    
    /// Whether the app may sign in to this chat server: the pro server or a server named under `.leveragers.com`.
    static func isAllowedServerName(_ serverName: String) -> Bool {
        serverName == proServerName || wholeMatch(of: leveragersServerPattern, in: serverName) != nil
    }
    
    func serverName(forEmail email: String) async -> Result<String, FrontDoorError> {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let atIndex = email.lastIndex(of: "@") else { return .failure(.invalidEmail) }
        let domain = email[email.index(after: atIndex)...].lowercased()
        
        guard domain.allSatisfy(\.isASCII) else { return .success(Self.proServerName) }
        guard Self.wholeMatch(of: Self.domainPattern, in: domain) != nil else { return .failure(.invalidEmail) }
        
        switch await serverFile(at: "d/\(domain).json") {
        case .server(let serverName):
            return .success(serverName)
        case .notFound:
            break
        case .unavailable:
            return .failure(.frontDoorUnavailable)
        }
        
        guard let tenantID = await microsoftTenantID(forDomain: domain) else { return .success(Self.proServerName) }
        
        switch await serverFile(at: "t/\(tenantID).json") {
        case .server(let serverName):
            return .success(serverName)
        case .notFound:
            return .success(Self.proServerName)
        case .unavailable:
            return .failure(.frontDoorUnavailable)
        }
    }
    
    // MARK: - Private
    
    private enum ServerFileResult {
        case server(String)
        case notFound
        case unavailable
    }
    
    /// The content of `d/<domain>.json` and `t/<tenant ID>.json`.
    private nonisolated struct ServerFile: Decodable {
        let v: Int
        let server: String
    }
    
    private nonisolated struct OpenIDConfiguration: Decodable {
        let issuer: String
    }
    
    private struct Response {
        let statusCode: Int
        let data: Data
    }
    
    private func serverFile(at path: String) async -> ServerFileResult {
        guard let response = await get(baseURL.appending(path: path)) else { return .unavailable }
        
        switch response.statusCode {
        case 200:
            guard let file = try? JSONDecoder().decode(ServerFile.self, from: response.data),
                  file.v == 1,
                  Self.isAllowedServerName(file.server) else {
                MXLog.error("The front door gave an invalid answer.")
                return .unavailable
            }
            return .server(file.server)
        case 404:
            return .notFound
        default:
            MXLog.error("The front door answered with the status \(response.statusCode).")
            return .unavailable
        }
    }
    
    /// The Microsoft tenant ID of a domain, lowercased, from Microsoft's public discovery. `nil` on any failure.
    private func microsoftTenantID(forDomain domain: String) async -> String? {
        guard let url = URL(string: "https://login.microsoftonline.com/\(domain)/v2.0/.well-known/openid-configuration"),
              let response = await get(url),
              response.statusCode == 200,
              let configuration = try? JSONDecoder().decode(OpenIDConfiguration.self, from: response.data),
              let match = Self.wholeMatch(of: Self.microsoftIssuerPattern, in: configuration.issuer, options: .caseInsensitive),
              let tenantIDRange = Range(match.range(at: 1), in: configuration.issuer) else {
            return nil
        }
        return configuration.issuer[tenantIDRange].lowercased()
    }
    
    private func get(_ url: URL) async -> Response? {
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.requestTimeout)
        
        do {
            let (data, response) = try await fetch(request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            return Response(statusCode: httpResponse.statusCode, data: data)
        } catch {
            // The error would contain the address, so only its code is logged.
            MXLog.error("Sign-in lookup request failed: \((error as NSError).code)")
            return nil
        }
    }
    
    /// The match of a pattern on the whole string, `nil` when only a part of it matches.
    private static func wholeMatch(of pattern: String, in string: String, options: NSRegularExpression.Options = []) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range), match.range == range else { return nil }
        return match
    }
}
