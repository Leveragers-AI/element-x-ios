//
// Copyright 2026 Leveragers.
//
// SPDX-License-Identifier: AGPL-3.0-only
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation

/// Leveragers: recovery is set up without asking anything, in place of Element's "Set up recovery" banner, when this
/// app has just created the account's encryption identity:
/// - at the first sign-in of an account that had none: the SDK creates the identity itself, so the first known
///   verification state of this sign-in is "verified" while recovery is off;
/// - after "Reset identity".
///
/// `SecureBackupController.generateRecoveryKey` then sends a sealed copy of the new key (RecoveryKeyEscrow.swift). An
/// account that had an identity before this sign-in starts "not verified" and is left as in Element X, even once the
/// device is confirmed. Nothing happens without a recipient in `AppSettings.leveragersRecoveryKeyRecipient`.
final class SilentRecoverySetup {
    private let securityStates: CurrentValuePublisher<SessionSecurityState, Never>
    private let secureBackupController: SecureBackupControllerProtocol
    private let isEnabled: Bool
    
    /// True from a new sign-in until it is known whether it created the identity, and while recovery is being set up:
    /// Element's "Set up recovery" banner waits for it.
    private let isPendingSubject = CurrentValueSubject<Bool, Never>(false)
    var isPending: CurrentValuePublisher<Bool, Never> {
        isPendingSubject.asCurrentValuePublisher()
    }
    
    private var signInCancellable: AnyCancellable?
    private var firstKnownVerificationState: SessionVerificationState?
    
    init(securityStates: CurrentValuePublisher<SessionSecurityState, Never>,
         secureBackupController: SecureBackupControllerProtocol,
         isEnabled: Bool) {
        self.securityStates = securityStates
        self.secureBackupController = secureBackupController
        self.isEnabled = isEnabled
    }
    
    /// Watches the start of a session: on a new sign-in whose first known verification state is "verified" (the SDK
    /// has just created the identity), sets up recovery if it is off.
    func startAfterSignIn(isNewLogin: Bool) {
        guard isEnabled, isNewLogin, signInCancellable == nil else { return }
        
        isPendingSubject.send(true)
        signInCancellable = securityStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.signInSecurityStateChanged(state)
            }
    }
    
    /// "Reset identity" has completed: the SDK turned recovery off, set it up again on the new identity.
    func startAfterIdentityReset() {
        guard isEnabled else { return }
        
        MXLog.info("Leveragers: identity reset, setting up recovery silently.")
        setUpRecovery()
    }
    
    /// Element's session security state for the home screen banner, with recovery shown as being set up (no "Set up
    /// recovery" banner) while a silent setup is pending or running.
    func securityStateForBanner(_ securityStates: CurrentValuePublisher<SessionSecurityState, Never>) -> AnyPublisher<SessionSecurityState, Never> {
        securityStates
            .combineLatest(isPendingSubject.removeDuplicates())
            .map { state, isPending in
                guard isPending, state.recoveryState == .disabled else { return state }
                return SessionSecurityState(verificationState: state.verificationState, recoveryState: .settingUp)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private
    
    private func signInSecurityStateChanged(_ state: SessionSecurityState) {
        if firstKnownVerificationState == nil, state.verificationState != .unknown {
            firstKnownVerificationState = state.verificationState
        }
        
        guard let firstKnownVerificationState else { return } // Not known yet.
        
        let createdIdentity = firstKnownVerificationState == .verified
        if createdIdentity, state.recoveryState == .unknown {
            return // Not known yet.
        }
        
        signInCancellable = nil
        
        if createdIdentity, state.recoveryState == .disabled {
            MXLog.info("Leveragers: this sign-in created the account's identity, setting up recovery silently.")
            setUpRecovery()
        } else {
            // The account had an identity before this sign-in, or recovery is already set up: as in Element X.
            MXLog.info("Leveragers: no silent recovery setup for this sign-in (\(firstKnownVerificationState), \(state.recoveryState)).")
            isPendingSubject.send(false)
        }
    }
    
    private func setUpRecovery() {
        isPendingSubject.send(true)
        
        Task {
            switch await secureBackupController.generateRecoveryKey(withPassphrase: nil) {
            case .success:
                MXLog.info("Leveragers: recovery set up silently.")
            case .failure(let error):
                MXLog.error("Leveragers: failed setting up recovery silently with error: \(error)")
            }
            
            isPendingSubject.send(false)
        }
    }
}

// MARK: - One per user session

extension SilentRecoverySetup {
    /// At the start of a user session (`OnboardingFlowCoordinator`).
    static func startAfterSignIn(isNewLogin: Bool, userSession: UserSessionProtocol) {
        of(userSession).startAfterSignIn(isNewLogin: isNewLogin)
    }
    
    /// When "Reset identity" has completed (`EncryptionResetFlowCoordinator`).
    static func startAfterIdentityReset(userSession: UserSessionProtocol) {
        of(userSession).startAfterIdentityReset()
    }
    
    /// The session security state for the home screen banner (`HomeScreenViewModel`).
    static func securityStateForBanner(of userSession: UserSessionProtocol) -> AnyPublisher<SessionSecurityState, Never> {
        of(userSession).securityStateForBanner(userSession.sessionSecurityStatePublisher)
    }
    
    private static var associationKey: UInt8 = 0
    
    /// The silent setup of a user session, made on first use and kept with the session object.
    private static func of(_ userSession: UserSessionProtocol) -> SilentRecoverySetup {
        let session = userSession as AnyObject
        if let setup = objc_getAssociatedObject(session, &associationKey) as? SilentRecoverySetup {
            return setup
        }
        
        let setup = SilentRecoverySetup(securityStates: userSession.sessionSecurityStatePublisher,
                                        secureBackupController: userSession.clientProxy.secureBackupController,
                                        isEnabled: !AppSettings.leveragersRecoveryKeyRecipient.isEmpty)
        objc_setAssociatedObject(session, &associationKey, setup, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return setup
    }
}
