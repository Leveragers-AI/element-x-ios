//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

@MainActor
struct FrontDoorServiceTests {
    private static let tenantID = "0a1b2c3d-4e5f-6789-abcd-ef0123456789"
    private static let microsoftURL = "https://login.microsoftonline.com/theseis.com/v2.0/.well-known/openid-configuration"
    private static let domainFileURL = "https://login.leveragers.com/d/theseis.com.json"
    private static let tenantFileURL = "https://login.leveragers.com/t/\(tenantID).json"
    private static let microsoftConfiguration = #"{"issuer":"https://login.microsoftonline.com/0A1B2C3D-4E5F-6789-ABCD-EF0123456789/v2.0","token_endpoint":"x"}"#
    
    private let network: FrontDoorNetworkStub
    private let service: FrontDoorService
    
    init() {
        let network = FrontDoorNetworkStub()
        self.network = network
        service = FrontDoorService(baseURL: "https://login.leveragers.com") { request in
            try await network.fetch(request)
        }
    }
    
    // MARK: - Front door
    
    @Test
    func enterpriseDomain() async throws {
        network.answers = [Self.domainFileURL: .status(200, #"{"v":1,"server":"theseis.chat.leveragers.com"}"#)]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .success("theseis.chat.leveragers.com"))
        #expect(network.requestedURLs == [Self.domainFileURL])
        
        let request = try #require(network.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.timeoutInterval == 8)
    }
    
    @Test
    func addressIsTrimmedAndDomainLowercased() async {
        network.answers = [Self.domainFileURL: .status(200, #"{"v":1,"server":"theseis.chat.leveragers.com"}"#)]
        
        #expect(await service.serverName(forEmail: "  Jane.Doe@Theseis.COM \n") == .success("theseis.chat.leveragers.com"))
        #expect(network.requestedURLs == [Self.domainFileURL])
    }
    
    @Test
    func domainFollowsTheLastAtSign() async {
        network.answers = [Self.domainFileURL: .status(200, #"{"v":1,"server":"theseis.chat.leveragers.com"}"#)]
        
        #expect(await service.serverName(forEmail: "\"jane@home\"@theseis.com") == .success("theseis.chat.leveragers.com"))
        #expect(network.requestedURLs == [Self.domainFileURL])
    }
    
    @Test
    func proServerFromTheFrontDoor() async {
        network.answers = [Self.domainFileURL: .status(200, #"{"v":1,"server":"chat.leveragers.com","note":"extra keys are ignored"}"#)]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .success("chat.leveragers.com"))
    }
    
    @Test
    func nonASCIIDomainGoesToTheProServer() async {
        #expect(await service.serverName(forEmail: "jane@exämple.com") == .success(FrontDoorService.proServerName))
        #expect(network.requests.isEmpty)
    }
    
    @Test(arguments: ["", "jane", "jane@", "jane@localhost", "jane@-theseis.com", "jane@theseis-.com", "jane@the seis.com",
                      "jane@theseis..com", "jane@.theseis.com", "jane@theseis.com.", "jane@the_seis.com", "jane@theseis.com/x"])
    func invalidEmail(email: String) async {
        #expect(await service.serverName(forEmail: email) == .failure(.invalidEmail))
        #expect(network.requests.isEmpty)
    }
    
    @Test(arguments: [FrontDoorAnswer.status(500, ""), .status(429, ""), .status(403, ""), .status(301, ""), .networkError])
    func frontDoorUnavailable(answer: FrontDoorAnswer) async {
        network.answers = [Self.domainFileURL: answer]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .failure(.frontDoorUnavailable))
        #expect(network.requestedURLs == [Self.domainFileURL])
    }
    
    @Test(arguments: [#"{"v":2,"server":"theseis.chat.leveragers.com"}"#,
                      #"{"v":"1","server":"theseis.chat.leveragers.com"}"#,
                      #"{"server":"theseis.chat.leveragers.com"}"#,
                      #"{"v":1}"#,
                      #"{"v":1,"server":5}"#,
                      #"{"v":1,"server":"evil.com"}"#,
                      #"{"v":1,"server":"leveragers.com"}"#,
                      #"{"v":1,"server":"chat.leveragers.com.evil.com"}"#,
                      #"{"v":1,"server":"evilleveragers.com"}"#,
                      #"{"v":1,"server":"Theseis.chat.leveragers.com"}"#,
                      #"{"v":1,"server":"https://theseis.chat.leveragers.com"}"#,
                      #"{"v":1,"server":"theseis.chat.leveragers.com:8448"}"#,
                      #"[{"v":1,"server":"theseis.chat.leveragers.com"}]"#,
                      "not json",
                      ""])
    func invalidServerFile(body: String) async {
        network.answers = [Self.domainFileURL: .status(200, body)]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .failure(.frontDoorUnavailable))
        #expect(network.requestedURLs == [Self.domainFileURL])
    }
    
    // MARK: - Microsoft tenant
    
    @Test
    func microsoftTenant() async {
        network.answers = [Self.domainFileURL: .status(404, ""),
                           Self.microsoftURL: .status(200, Self.microsoftConfiguration),
                           Self.tenantFileURL: .status(200, #"{"v":1,"server":"theseis.chat.leveragers.com"}"#)]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .success("theseis.chat.leveragers.com"))
        #expect(network.requestedURLs == [Self.domainFileURL, Self.microsoftURL, Self.tenantFileURL])
    }
    
    @Test
    func microsoftTenantWithoutFileGoesToTheProServer() async {
        network.answers = [Self.domainFileURL: .status(404, ""),
                           Self.microsoftURL: .status(200, Self.microsoftConfiguration),
                           Self.tenantFileURL: .status(404, "")]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .success(FrontDoorService.proServerName))
        #expect(network.requestedURLs == [Self.domainFileURL, Self.microsoftURL, Self.tenantFileURL])
    }
    
    @Test(arguments: [FrontDoorAnswer.status(500, ""), .networkError, .status(200, #"{"v":1,"server":"evil.com"}"#)])
    func tenantFileUnavailable(answer: FrontDoorAnswer) async {
        network.answers = [Self.domainFileURL: .status(404, ""),
                           Self.microsoftURL: .status(200, Self.microsoftConfiguration),
                           Self.tenantFileURL: answer]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .failure(.frontDoorUnavailable))
    }
    
    @Test(arguments: [FrontDoorAnswer.status(400, #"{"error":"invalid_tenant"}"#),
                      .status(500, ""),
                      .networkError,
                      .status(200, "not json"),
                      .status(200, #"{"token_endpoint":"x"}"#),
                      .status(200, #"{"issuer":"https://sts.windows.net/0a1b2c3d-4e5f-6789-abcd-ef0123456789/"}"#),
                      .status(200, #"{"issuer":"https://login.microsoftonline.com/0a1b2c3d-4e5f-6789-abcd-ef0123456789/v2.0/x"}"#),
                      .status(200, #"{"issuer":"https://login.microsoftonline.com/common/v2.0"}"#)])
    func microsoftFailureGoesToTheProServer(answer: FrontDoorAnswer) async {
        network.answers = [Self.domainFileURL: .status(404, ""),
                           Self.microsoftURL: answer]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .success(FrontDoorService.proServerName))
        #expect(network.requestedURLs == [Self.domainFileURL, Self.microsoftURL])
    }
    
    @Test
    func microsoftIssuerWithTrailingSlash() async {
        network.answers = [Self.domainFileURL: .status(404, ""),
                           Self.microsoftURL: .status(200, #"{"issuer":"https://login.microsoftonline.com/0a1b2c3d-4e5f-6789-abcd-ef0123456789/v2.0/"}"#),
                           Self.tenantFileURL: .status(200, #"{"v":1,"server":"theseis.chat.leveragers.com"}"#)]
        
        #expect(await service.serverName(forEmail: "jane@theseis.com") == .success("theseis.chat.leveragers.com"))
    }
    
    // MARK: - Allowed servers
    
    @Test
    func allowedServerNames() {
        for serverName in ["chat.leveragers.com", "theseis.chat.leveragers.com", "a.leveragers.com", "a-b.c-d.leveragers.com"] {
            #expect(FrontDoorService.isAllowedServerName(serverName), "\(serverName)")
        }
        for serverName in ["leveragers.com", ".leveragers.com", "evil.com", "leveragers.com.evil.com", "evilleveragers.com",
                           "-a.leveragers.com", "A.leveragers.com", "matrix.org", "chat.leveragers.com.", ""] {
            #expect(!FrontDoorService.isAllowedServerName(serverName), "\(serverName)")
        }
    }
}

// MARK: - Helpers

nonisolated enum FrontDoorAnswer: Sendable {
    case status(Int, String)
    case networkError
}

/// Answers the requests from a table of URLs, and records them.
@MainActor
final class FrontDoorNetworkStub {
    var answers: [String: FrontDoorAnswer] = [:]
    private(set) var requests: [URLRequest] = []
    
    var requestedURLs: [String] {
        requests.compactMap { $0.url?.absoluteString }
    }
    
    func fetch(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        
        guard let url = request.url, let answer = answers[url.absoluteString] else {
            Issue.record("Unexpected request: \(request.url?.absoluteString ?? "no URL")")
            throw URLError(.cannotConnectToHost)
        }
        
        switch answer {
        case .status(let statusCode, let body):
            guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
                throw URLError(.badServerResponse)
            }
            return (Data(body.utf8), response)
        case .networkError:
            throw URLError(.timedOut)
        }
    }
}
