//
// Copyright 2026 Leveragers.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import CryptoKit
import Foundation
import MatrixRustSDK

// Leveragers: a copy of every recovery key this app creates is sealed on the phone (CryptoKit, to a P-256 public key
// whose private half only Leveragers holds) and sent to the chat server, so that Leveragers can give it back to its
// owner. Same format and route as our Element Web build (format v1). Nothing here runs without a recipient in
// `AppSettings.leveragersRecoveryKeyRecipient`.
//
// Never log the recovery key, the sealed copy nor the access token: HTTP statuses only.

/// A sealed recovery key, format v1: base64url (unpadded) of the one-time P-256 public key (uncompressed point), of
/// the AES-GCM IV, and of the AES-GCM ciphertext followed by its tag.
nonisolated struct SealedRecoveryKey: Codable, Equatable, Sendable {
    let v: Int
    let epk: String
    let iv: String
    let ct: String
}

nonisolated enum RecoveryKeySealer {
    enum SealError: Error {
        case invalidRecipient
    }
    
    /// `info` of the HKDF step of format v1, which also names the format.
    static let info = "leveragers-recovery-key-v1"
    
    /// Seals a recovery key (`EsT…`, as the SDK returns it) to the recipient's P-256 public key, format v1: ECDH with
    /// a one-time P-256 key pair, HKDF-SHA-256 (salt = one-time public key ‖ recipient public key) to an AES-256-GCM
    /// key, then AES-GCM with a 12-byte IV and, as additional data, `<user_id>\n<key_id>`, so that a copy moved onto
    /// another account or key does not open.
    ///
    /// The one-time key and the IV are only passed by the tests.
    static func seal(recoveryKey: String,
                     recipient: String,
                     userID: String,
                     keyID: String,
                     ephemeralKey: P256.KeyAgreement.PrivateKey = .init(),
                     nonce: AES.GCM.Nonce = .init()) throws -> SealedRecoveryKey {
        guard let recipientBytes = Data(base64URLEncoded: recipient) else {
            throw SealError.invalidRecipient
        }
        
        let recipientKey = try P256.KeyAgreement.PublicKey(x963Representation: recipientBytes)
        let ephemeralPublicBytes = ephemeralKey.publicKey.x963Representation
        let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientKey)
        let key = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self,
                                                       salt: ephemeralPublicBytes + recipientBytes,
                                                       sharedInfo: Data(info.utf8),
                                                       outputByteCount: 32)
        let sealedBox = try AES.GCM.seal(Data(recoveryKey.utf8),
                                         using: key,
                                         nonce: nonce,
                                         authenticating: Data("\(userID)\n\(keyID)".utf8))
        
        return SealedRecoveryKey(v: 1,
                                 epk: ephemeralPublicBytes.base64URLEncodedString(),
                                 iv: nonce.withUnsafeBytes { Data($0) }.base64URLEncodedString(),
                                 ct: (sealedBox.ciphertext + sealedBox.tag).base64URLEncodedString())
    }
}

/// Sends a sealed copy of a new recovery key to the chat server, `POST /_leveragers/keys/v1/recovery-key`, with the id
/// of the account's default secret storage key read from the server just before.
final class RecoveryKeyEscrow {
    /// Waits between the attempts, then ``laterRetryDelay`` between all later ones.
    static let retryDelays: [Duration] = [.seconds(2), .seconds(5), .seconds(15), .seconds(30)]
    static let laterRetryDelay: Duration = .seconds(60)
    private static let requestTimeout: TimeInterval = 30
    
    private let recipient: String
    private let homeserverURL: URL
    private let userID: String
    private let accessToken: @MainActor () -> String?
    private let session: URLSession
    private let sleep: @MainActor (Duration) async -> Void
    
    /// - Parameters:
    ///   - accessToken: Read before each request: the SDK may have refreshed it in the meantime.
    ///   - sleep: Waits between the attempts (the tests don't wait).
    init(recipient: String,
         homeserverURL: URL,
         userID: String,
         accessToken: @escaping @MainActor () -> String?,
         session: URLSession = .shared,
         sleep: @escaping @MainActor (Duration) async -> Void = { try? await Task.sleep(for: $0) }) {
        self.recipient = recipient
        self.homeserverURL = homeserverURL
        self.userID = userID
        self.accessToken = accessToken
        self.session = session
        self.sleep = sleep
    }
    
    /// The escrow of a signed-in client, `nil` when this build has no recipient: the app then behaves as Element X.
    convenience init?(client: ClientProtocol, recipient: String = AppSettings.leveragersRecoveryKeyRecipient) {
        guard !recipient.isEmpty else {
            MXLog.info("Leveragers: no recovery key recipient in this build, new recovery keys aren't copied.")
            return nil
        }
        guard let session = try? client.session(), let homeserverURL = URL(string: session.homeserverUrl) else {
            MXLog.error("Leveragers: no session, new recovery keys aren't copied.")
            return nil
        }
        
        self.init(recipient: recipient, homeserverURL: homeserverURL, userID: session.userId) { [client] in
            try? client.session().accessToken
        }
    }
    
    /// Seals a recovery key that the SDK has just created and saved, and sends it, retrying on network errors, 429 and
    /// 5xx (after 2 s, 5 s, 15 s, 30 s, then every 60 s) while the app runs, and giving up on any other answer.
    /// Does nothing for an empty key (a passphrase-based setup). Never throws.
    func escrow(recoveryKey: String) async {
        guard !recoveryKey.isEmpty else {
            MXLog.info("Leveragers: no recovery key text, no copy to send.")
            return
        }
        
        var body: Data?
        var failedAttempts = 0
        
        while !Task.isCancelled {
            let outcome: Outcome
            if let body {
                outcome = await send(body)
            } else {
                switch await fetchDefaultKeyID() {
                case .found(let keyID):
                    do {
                        let sealed = try RecoveryKeySealer.seal(recoveryKey: recoveryKey, recipient: recipient, userID: userID, keyID: keyID)
                        body = try JSONEncoder().encode(CopyRequestBody(keyID: keyID, sealed: sealed))
                    } catch {
                        MXLog.error("Leveragers: could not seal the recovery key copy (invalid recipient?): giving up.")
                        return
                    }
                    continue // Send it right away.
                case .unavailable(let failure):
                    outcome = failure
                }
            }
            
            switch outcome {
            case .done:
                return
            case .retry(let reason):
                let delay = failedAttempts < Self.retryDelays.count ? Self.retryDelays[failedAttempts] : Self.laterRetryDelay
                failedAttempts += 1
                MXLog.info("Leveragers: recovery key copy not sent (\(reason)), next attempt in \(delay).")
                await sleep(delay)
            }
        }
    }
    
    // MARK: - Private
    
    private nonisolated enum Outcome {
        /// Stored, or refused for good: no more attempts.
        case done
        /// A network error, a timeout, 429 or 5xx: try again later.
        case retry(String)
    }
    
    private nonisolated enum KeyIDLookup {
        case found(String)
        case unavailable(Outcome)
    }
    
    private nonisolated struct CopyRequestBody: Encodable {
        let keyID: String
        let sealed: SealedRecoveryKey
        
        enum CodingKeys: String, CodingKey {
            case keyID = "key_id"
            case sealed
        }
    }
    
    private var homeserverBase: String {
        var base = homeserverURL.absoluteString
        while base.hasSuffix("/") {
            base.removeLast()
        }
        return base
    }
    
    /// The id of the account's default secret storage key, read from the server rather than from the SDK's cache:
    /// the SDK has saved the new one before returning it, and the server checks that the copy names the current one.
    private func fetchDefaultKeyID() async -> KeyIDLookup {
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encodedUserID = userID.addingPercentEncoding(withAllowedCharacters: unreserved),
              let url = URL(string: "\(homeserverBase)/_matrix/client/v3/user/\(encodedUserID)/account_data/m.secret_storage.default_key") else {
            MXLog.error("Leveragers: invalid account data URL, recovery key copy not sent.")
            return .unavailable(.done)
        }
        
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        guard authorize(&request) else { return .unavailable(.done) }
        
        let data: Data
        let status: Int
        do {
            let (responseData, response) = try await session.data(for: request)
            data = responseData
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
        } catch {
            return .unavailable(.retry("network error"))
        }
        
        switch status {
        case 200:
            guard let content = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let keyID = content["key"] as? String, !keyID.isEmpty else {
                MXLog.warning("Leveragers: the account has no default secret storage key, recovery key copy not sent.")
                return .unavailable(.done)
            }
            return .found(keyID)
        case 429, 500...:
            return .unavailable(.retry("account data HTTP \(status)"))
        default:
            MXLog.warning("Leveragers: account data refused (HTTP \(status)), recovery key copy not sent.")
            return .unavailable(.done)
        }
    }
    
    private func send(_ body: Data) async -> Outcome {
        guard let url = URL(string: "\(homeserverBase)/_leveragers/keys/v1/recovery-key") else {
            return .done
        }
        
        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        guard authorize(&request) else { return .done }
        
        let status: Int
        do {
            let (_, response) = try await session.data(for: request)
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
        } catch {
            return .retry("network error")
        }
        
        switch status {
        case 200..<300:
            MXLog.info("Leveragers: recovery key copy stored (HTTP \(status)).")
            return .done
        case 429, 500...:
            return .retry("HTTP \(status)")
        default:
            MXLog.warning("Leveragers: recovery key copy refused (HTTP \(status)): giving up.")
            return .done
        }
    }
    
    /// Adds the session's current access token, `false` when there is none (signed out).
    private func authorize(_ request: inout URLRequest) -> Bool {
        guard let token = accessToken(), !token.isEmpty else {
            MXLog.warning("Leveragers: no access token, recovery key copy not sent.")
            return false
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return true
    }
}

private nonisolated extension Data {
    /// Unpadded base64url.
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    /// From base64url, padded or not.
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
