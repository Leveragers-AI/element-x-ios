//
// Copyright 2026 Leveragers.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import CryptoKit
@testable import ElementX
import Foundation
import MatrixRustSDKMocks
import Synchronization
import Testing

// Serialized: the fake chat server below is shared by the tests of this suite.
@Suite(.serialized)
struct RecoveryKeyEscrowTests {
    // MARK: - Sealing
    
    @Test("Sealing with the vector's one-time key and IV gives the vector's copy")
    func sealMatchesVector() throws {
        let ephemeralKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: data(Vector.ephemeralPrivateScalar))
        let nonce = try AES.GCM.Nonce(data: data(Vector.iv))
        
        let sealed = try RecoveryKeySealer.seal(recoveryKey: Vector.recoveryKey,
                                                recipient: Vector.recipient,
                                                userID: Vector.userID,
                                                keyID: Vector.keyID,
                                                ephemeralKey: ephemeralKey,
                                                nonce: nonce)
        
        #expect(sealed == Vector.sealed)
    }
    
    @Test("A copy opens with the recipient's private key, and only for its account and key id")
    func sealOpensWithRecipientKey() throws {
        let sealed = try RecoveryKeySealer.seal(recoveryKey: Vector.recoveryKey, recipient: Vector.recipient, userID: Vector.userID, keyID: Vector.keyID)
        
        #expect(sealed.v == 1)
        #expect(try data(sealed.epk).count == 65)
        #expect(try data(sealed.iv).count == 12)
        #expect(try unseal(sealed, userID: Vector.userID, keyID: Vector.keyID) == Vector.recoveryKey)
        #expect(throws: (any Error).self) { try unseal(sealed, userID: "@autre:chat.leveragers.com", keyID: Vector.keyID) }
        #expect(throws: (any Error).self) { try unseal(sealed, userID: Vector.userID, keyID: "autre") }
    }
    
    @Test("The recipient built into the app is a valid P-256 public key", .enabled(if: !AppSettings.leveragersRecoveryKeyRecipient.isEmpty))
    func builtInRecipientIsValid() throws {
        let recipient = try data(AppSettings.leveragersRecoveryKeyRecipient)
        
        #expect(recipient.count == 65)
        _ = try P256.KeyAgreement.PublicKey(x963Representation: recipient)
    }
    
    @Test("Without a recipient in the build there is no escrow, as in Element X")
    func noRecipientNoEscrow() {
        let client = ClientSDKMock()
        
        #expect(RecoveryKeyEscrow(client: client, recipient: "") == nil)
        #expect(client.sessionCallsCount == 0)
    }
    
    // MARK: - Sending
    
    @Test("A 503 is retried after 2 s, then the copy is stored, with the key id read from the server")
    func retriesThen201() async throws {
        EscrowURLProtocol.reset(keyIDAnswers: [.keyID], copyAnswers: [.status(503), .status(201)])
        let sleeps = SleepRecorder()
        
        await makeEscrow(sleeps: sleeps).escrow(recoveryKey: Vector.recoveryKey)
        
        let requests = EscrowURLProtocol.requests
        #expect(requests.map(\.method) == ["GET", "POST", "POST"])
        #expect(requests.first?.url == "https://chat.example.com/_matrix/client/v3/user/%40essai-vecteur%3Achat.leveragers.com/account_data/m.secret_storage.default_key")
        #expect(requests.last?.url == "https://chat.example.com/_leveragers/keys/v1/recovery-key")
        #expect(requests.last?.contentType == "application/json")
        #expect(sleeps.delays == [.seconds(2)])
        
        let body = try #require(requests.last?.body)
        let jsonObject = try JSONSerialization.jsonObject(with: body)
        let json = try #require(jsonObject as? [String: Any])
        #expect(Set(json.keys) == ["key_id", "sealed"])
        #expect(Set((json["sealed"] as? [String: Any] ?? [:]).keys) == ["v", "epk", "iv", "ct"])
        
        let copy = try JSONDecoder().decode(CopyBody.self, from: body)
        #expect(copy.keyID == Vector.keyID)
        #expect(try unseal(copy.sealed, userID: Vector.userID, keyID: Vector.keyID) == Vector.recoveryKey)
    }
    
    @Test("Network errors, 429 and 5xx are retried after 2 s, 5 s, 15 s, 30 s, then every 60 s")
    func retrySchedule() async {
        EscrowURLProtocol.reset(keyIDAnswers: [.status(502), .keyID],
                                copyAnswers: [.networkError, .status(429), .status(500), .status(503), .networkError, .status(201)])
        let sleeps = SleepRecorder()
        
        await makeEscrow(sleeps: sleeps).escrow(recoveryKey: Vector.recoveryKey)
        
        #expect(EscrowURLProtocol.requests.map(\.method) == ["GET", "GET", "POST", "POST", "POST", "POST", "POST", "POST"])
        #expect(sleeps.delays == [.seconds(2), .seconds(5), .seconds(15), .seconds(30), .seconds(60), .seconds(60)])
    }
    
    @Test("A 401 ends the attempts")
    func givesUpOn401() async {
        EscrowURLProtocol.reset(keyIDAnswers: [.keyID], copyAnswers: [.status(401), .status(201)])
        let sleeps = SleepRecorder()
        
        await makeEscrow(sleeps: sleeps).escrow(recoveryKey: Vector.recoveryKey)
        
        #expect(EscrowURLProtocol.requests.map(\.method) == ["GET", "POST"])
        #expect(sleeps.delays.isEmpty)
    }
    
    @Test("A 404 (a chat server without the route) ends the attempts")
    func givesUpOn404() async {
        EscrowURLProtocol.reset(keyIDAnswers: [.keyID], copyAnswers: [.status(404), .status(201)])
        let sleeps = SleepRecorder()
        
        await makeEscrow(sleeps: sleeps).escrow(recoveryKey: Vector.recoveryKey)
        
        #expect(EscrowURLProtocol.requests.map(\.method) == ["GET", "POST"])
        #expect(sleeps.delays.isEmpty)
    }
    
    @Test("Without a default secret storage key on the server, nothing is sent")
    func noSendWithoutKeyID() async {
        EscrowURLProtocol.reset(keyIDAnswers: [.status(404)], copyAnswers: [.status(201)])
        await makeEscrow().escrow(recoveryKey: Vector.recoveryKey)
        #expect(EscrowURLProtocol.requests.map(\.method) == ["GET"])
        
        // After "Reset identity" the SDK leaves an empty default key.
        EscrowURLProtocol.reset(keyIDAnswers: [.json(200, "{}")], copyAnswers: [.status(201)])
        await makeEscrow().escrow(recoveryKey: Vector.recoveryKey)
        #expect(EscrowURLProtocol.requests.map(\.method) == ["GET"])
    }
    
    @Test("The access token is read again before each request")
    func tokenReadPerAttempt() async {
        EscrowURLProtocol.reset(keyIDAnswers: [.keyID], copyAnswers: [.networkError, .status(201)])
        let tokens = TokenSource()
        
        await makeEscrow(tokens: tokens).escrow(recoveryKey: Vector.recoveryKey)
        
        #expect(tokens.reads == 3)
        #expect(EscrowURLProtocol.requests.map(\.authorization) == ["Bearer token-1", "Bearer token-2", "Bearer token-3"])
    }
    
    @Test("Without an access token (signed out), nothing is sent")
    func noTokenNoRequest() async {
        EscrowURLProtocol.reset(keyIDAnswers: [.keyID], copyAnswers: [.status(201)])
        
        await makeEscrow(tokens: TokenSource(isSignedOut: true)).escrow(recoveryKey: Vector.recoveryKey)
        
        #expect(EscrowURLProtocol.requests.isEmpty)
    }
    
    @Test("An empty recovery key (a passphrase setup) is not sent")
    func emptyRecoveryKeyNotSent() async {
        EscrowURLProtocol.reset(keyIDAnswers: [.keyID], copyAnswers: [.status(201)])
        let tokens = TokenSource()
        
        await makeEscrow(tokens: tokens).escrow(recoveryKey: "")
        
        #expect(EscrowURLProtocol.requests.isEmpty)
        #expect(tokens.reads == 0)
    }
    
    // MARK: - Helpers
    
    private func makeEscrow(tokens: TokenSource = TokenSource(), sleeps: SleepRecorder = SleepRecorder()) -> RecoveryKeyEscrow {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EscrowURLProtocol.self]
        
        return RecoveryKeyEscrow(recipient: Vector.recipient,
                                 homeserverURL: "https://chat.example.com/",
                                 userID: Vector.userID,
                                 accessToken: { tokens.next() },
                                 session: URLSession(configuration: configuration),
                                 sleep: { sleeps.delays.append($0) })
    }
    
    /// Opens a copy the way hub2's reader does (`tools/recovery_key.py`), with the lab recipient's private key.
    private func unseal(_ sealed: SealedRecoveryKey, userID: String, keyID: String) throws -> String {
        let recipientKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: data(Vector.recipientPrivateScalar))
        let ephemeralPublicBytes = try data(sealed.epk)
        let sharedSecret = try recipientKey.sharedSecretFromKeyAgreement(with: P256.KeyAgreement.PublicKey(x963Representation: ephemeralPublicBytes))
        let key = try sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self,
                                                           salt: ephemeralPublicBytes + data(Vector.recipient),
                                                           sharedInfo: Data("leveragers-recovery-key-v1".utf8),
                                                           outputByteCount: 32)
        let ciphertextAndTag = try data(sealed.ct)
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: data(sealed.iv)),
                                              ciphertext: ciphertextAndTag.dropLast(16),
                                              tag: ciphertextAndTag.suffix(16))
        let plaintext = try AES.GCM.open(sealedBox, using: key, authenticating: Data("\(userID)\n\(keyID)".utf8))
        return String(decoding: plaintext, as: UTF8.self)
    }
    
    private func data(_ base64URL: String) throws -> Data {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64) else {
            throw InvalidBase64URL()
        }
        return data
    }
}

/// The lab test vector of format v1 (throwaway keys, not Leveragers' key), shared with the Android app, made with
/// Python's `cryptography` and opened by hub2's reader (`tools/recovery_key.py`).
private nonisolated enum Vector {
    static let recipientPrivateScalar = "7hwlRi8RtZZJPkFwETuSRAx-qnp1p93xAVJ44IXZsj0"
    static let recipient = "BJNxnRz4OxHM6yQnNKy4oGDPeIo-oKE6b-ELCmfN-b39QLBTJyiONkFkOFlHlyn6M2qwgEXxmKugjfmoD31mxbI"
    static let ephemeralPrivateScalar = "UxAGd9G18GRUfvL5Nqmlk8uRqbittPiohFoBqTmDRco"
    static let iv = "AQIDBAUGBwgJCgsM"
    static let userID = "@essai-vecteur:chat.leveragers.com"
    static let keyID = "Kq7bT0aZ3c9XvLmN2pQrS4uW"
    static let recoveryKey = "EsTc LW2K PGiF wKEA 3As5 g5c4 BXwk qeeJ ZJV8 Q9fu gUMN UE4d"
    static let sealed = SealedRecoveryKey(v: 1,
                                          epk: "BLS1IKF5RcveUgaHXSEKgfOn4Y1TjaEgcsUzZFFh_nYf7fOOaR_pKndui89lE78G8eq8whEBnj7jUFMhVe3vkNc",
                                          iv: "AQIDBAUGBwgJCgsM",
                                          ct: "Fyqgjg-NasDVDNAObD4wAS_lbuezjiibVv7KqJ6SE26DqORkO3NA5ExpqDMDQIWZYyTj7eqTeraSIRM23VNGn-3fevvz_1flFwJY")
}

private nonisolated struct InvalidBase64URL: Error { }

private nonisolated struct CopyBody: Decodable {
    let keyID: String
    let sealed: SealedRecoveryKey
    
    enum CodingKeys: String, CodingKey {
        case keyID = "key_id"
        case sealed
    }
}

/// Hands out `token-1`, `token-2`… and counts the reads.
private final class TokenSource {
    private let isSignedOut: Bool
    private(set) var reads = 0
    
    init(isSignedOut: Bool = false) {
        self.isSignedOut = isSignedOut
    }
    
    func next() -> String? {
        reads += 1
        return isSignedOut ? nil : "token-\(reads)"
    }
}

private final class SleepRecorder {
    var delays: [Duration] = []
}

/// A fake chat server: answers the account data requests (GET) and the copy requests (POST) from two scripts, and
/// records every request.
private nonisolated class EscrowURLProtocol: URLProtocol {
    nonisolated enum Answer: Sendable {
        case status(Int)
        case json(Int, String)
        case networkError
        
        static let keyID = Answer.json(200, #"{"key":"Kq7bT0aZ3c9XvLmN2pQrS4uW"}"#)
    }
    
    nonisolated struct Request: Sendable {
        let method: String
        let url: String
        let authorization: String?
        let contentType: String?
        let body: Data?
    }
    
    private nonisolated struct Script: Sendable {
        var keyIDAnswers: [Answer] = []
        var copyAnswers: [Answer] = []
        var requests: [Request] = []
    }
    
    private static let script = Mutex(Script())
    
    static var requests: [Request] {
        script.withLock { $0.requests }
    }
    
    static func reset(keyIDAnswers: [Answer], copyAnswers: [Answer]) {
        script.withLock { $0 = Script(keyIDAnswers: keyIDAnswers, copyAnswers: copyAnswers) }
    }
    
    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        
        let recorded = Request(method: request.httpMethod ?? "GET",
                               url: url.absoluteString,
                               authorization: request.value(forHTTPHeaderField: "Authorization"),
                               contentType: request.value(forHTTPHeaderField: "Content-Type"),
                               body: Self.body(of: request))
        // A request past the end of a script gets a 400, which ends the attempts.
        let answer = Self.script.withLock { script in
            script.requests.append(recorded)
            if recorded.method == "POST" {
                return script.copyAnswers.isEmpty ? Answer.status(400) : script.copyAnswers.removeFirst()
            } else {
                return script.keyIDAnswers.isEmpty ? Answer.status(400) : script.keyIDAnswers.removeFirst()
            }
        }
        
        let statusCode: Int
        let json: String
        switch answer {
        case .networkError:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        case .status(let code):
            statusCode = code
            json = "{}"
        case .json(let code, let body):
            statusCode = code
            json = body
        }
        
        guard let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"]) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(json.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() { }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }
    
    /// URLSession hands the body over as a stream.
    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        
        stream.open()
        defer { stream.close() }
        
        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: bufferSize)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
