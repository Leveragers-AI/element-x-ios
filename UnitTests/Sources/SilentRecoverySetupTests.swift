//
// Copyright 2026 Leveragers.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Combine
@testable import ElementX
import Foundation
import Testing

@MainActor
struct SilentRecoverySetupTests {
    private let securityStates = CurrentValueSubject<SessionSecurityState, Never>(.init(verificationState: .unknown, recoveryState: .unknown))
    private let secureBackupController = SecureBackupControllerMock(.init(recoveryState: .disabled))
    
    @Test("A sign-in whose first known state is \"verified\" created the identity: recovery is set up silently")
    func newIdentitySetsUpRecovery() async throws {
        let setup = makeSetup()
        setup.startAfterSignIn(isNewLogin: true)
        #expect(setup.isPending.value)
        
        let deferred = deferFulfillment(setup.isPending) { !$0 }
        securityStates.send(.init(verificationState: .verified, recoveryState: .unknown))
        securityStates.send(.init(verificationState: .verified, recoveryState: .disabled))
        try await deferred.fulfill()
        
        #expect(secureBackupController.generateRecoveryKeyWithPassphraseReceivedInvocations == [nil])
    }
    
    @Test("An account that had an identity starts \"not verified\" and is left alone, even once the device is confirmed")
    func existingIdentityIsLeftAlone() async throws {
        let setup = makeSetup()
        setup.startAfterSignIn(isNewLogin: true)
        
        let deferred = deferFulfillment(setup.isPending) { !$0 }
        securityStates.send(.init(verificationState: .unverified, recoveryState: .unknown))
        try await deferred.fulfill()
        
        securityStates.send(.init(verificationState: .verified, recoveryState: .disabled))
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(!secureBackupController.generateRecoveryKeyWithPassphraseCalled)
        #expect(!setup.isPending.value)
    }
    
    @Test("Recovery already set up is left alone")
    func recoveryAlreadySetUpIsLeftAlone() async throws {
        let setup = makeSetup()
        setup.startAfterSignIn(isNewLogin: true)
        
        let deferred = deferFulfillment(setup.isPending) { !$0 }
        securityStates.send(.init(verificationState: .verified, recoveryState: .enabled))
        try await deferred.fulfill()
        
        #expect(!secureBackupController.generateRecoveryKeyWithPassphraseCalled)
    }
    
    @Test("A session restored at launch is not a new sign-in: left alone")
    func restoredSessionIsLeftAlone() async throws {
        let setup = makeSetup()
        setup.startAfterSignIn(isNewLogin: false)
        #expect(!setup.isPending.value)
        
        securityStates.send(.init(verificationState: .verified, recoveryState: .disabled))
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(!secureBackupController.generateRecoveryKeyWithPassphraseCalled)
    }
    
    @Test("After \"Reset identity\", recovery is set up silently")
    func identityResetSetsUpRecovery() async throws {
        let setup = makeSetup()
        setup.startAfterIdentityReset()
        #expect(setup.isPending.value)
        
        try await deferFulfillment(setup.isPending) { !$0 }.fulfill()
        
        #expect(secureBackupController.generateRecoveryKeyWithPassphraseReceivedInvocations == [nil])
    }
    
    @Test("Without a recipient in the build, nothing happens, as in Element X")
    func disabledDoesNothing() async throws {
        let setup = makeSetup(isEnabled: false)
        setup.startAfterSignIn(isNewLogin: true)
        setup.startAfterIdentityReset()
        #expect(!setup.isPending.value)
        
        securityStates.send(.init(verificationState: .verified, recoveryState: .disabled))
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(!secureBackupController.generateRecoveryKeyWithPassphraseCalled)
    }
    
    @Test("The \"Set up recovery\" banner waits until it is known whether this sign-in created the identity")
    func bannerHeldBackWhilePending() async throws {
        let setup = makeSetup()
        let bannerRecoveryStates = setup.securityStateForBanner(securityStates.asCurrentValuePublisher()).map(\.recoveryState)
        setup.startAfterSignIn(isNewLogin: true)
        
        var deferred = deferFulfillment(bannerRecoveryStates) { $0 == .settingUp }
        securityStates.send(.init(verificationState: .unknown, recoveryState: .disabled))
        try await deferred.fulfill()
        
        // An existing identity: Element's banner as usual.
        deferred = deferFulfillment(bannerRecoveryStates) { $0 == .disabled }
        securityStates.send(.init(verificationState: .unverified, recoveryState: .disabled))
        try await deferred.fulfill()
    }
    
    @Test("Each user session has its own silent setup", .enabled(if: !AppSettings.leveragersRecoveryKeyRecipient.isEmpty))
    func oneSetupPerUserSession() async throws {
        let userSession = UserSessionMock(.init())
        userSession.sessionSecurityStatePublisher = securityStates.asCurrentValuePublisher()
        let otherUserSession = UserSessionMock(.init())
        otherUserSession.sessionSecurityStatePublisher = securityStates.asCurrentValuePublisher()
        
        SilentRecoverySetup.startAfterSignIn(isNewLogin: true, userSession: userSession)
        securityStates.send(.init(verificationState: .unknown, recoveryState: .disabled))
        
        try await deferFulfillment(SilentRecoverySetup.securityStateForBanner(of: userSession).map(\.recoveryState)) { $0 == .settingUp }.fulfill()
        try await deferFulfillment(SilentRecoverySetup.securityStateForBanner(of: otherUserSession).map(\.recoveryState)) { $0 == .disabled }.fulfill()
    }
    
    // MARK: - Helpers
    
    private func makeSetup(isEnabled: Bool = true) -> SilentRecoverySetup {
        SilentRecoverySetup(securityStates: securityStates.asCurrentValuePublisher(),
                            secureBackupController: secureBackupController,
                            isEnabled: isEnabled)
    }
}
