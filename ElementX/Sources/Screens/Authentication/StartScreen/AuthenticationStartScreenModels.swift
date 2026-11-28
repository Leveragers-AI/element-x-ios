//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

enum AuthenticationStartScreenViewModelAction: Equatable {
    case loginWithQR
    case login
    case register
    
    case loginDirectlyWithOAuth(data: OAuthAuthorizationDataProxy, window: UIWindow)
    case loginDirectlyWithPassword(loginHint: String?)
    
    case reportProblem
    case developerOptions
}

struct AuthenticationStartScreenViewState: BindableState {
    enum Mode: Equatable {
        case welcome
        case addAccount
        case classicAppWelcomeBack(ClassicAppAccount)
        case classicAppOtherOptions(ClassicAppAccount)
    }
    
    var mode: Mode
    
    let serverNameOrBaseURL: String?
    let showCreateAccountButton: Bool
    let showQRCodeLoginButton: Bool
    let hideBrandChrome: Bool
    /// Leveragers: the screen asks for an email address, the front door names its chat server.
    let signsInWithEmail: Bool
    
    /// The presentation anchor used for OAuth authentication.
    var window: UIWindow?
    
    /// Leveragers: why the email address didn't lead to a chat server.
    var emailError: FrontDoorError?
    
    var bindings = AuthenticationStartScreenViewStateBindings()
    
    var navigationTitle: String {
        switch mode {
        case .welcome, .classicAppWelcomeBack, .classicAppOtherOptions:
            L10n.screenOnboardingWelcomeBack
        case .addAccount:
            L10n.commonAddAnotherAccount
        }
    }
    
    var navigationBarHidden: Bool {
        switch mode {
        case .welcome:
            true
        case .addAccount, .classicAppWelcomeBack, .classicAppOtherOptions:
            false
        }
    }
    
    var loginButtonTitle: String {
        if signsInWithEmail {
            LeveragersL10n.signInContinue
        } else if let serverNameOrBaseURL {
            L10n.screenOnboardingSignInTo(serverNameOrBaseURL)
        } else if showQRCodeLoginButton {
            L10n.screenOnboardingSignInManually
        } else {
            L10n.actionContinue
        }
    }
    
    var canContinue: Bool {
        !signsInWithEmail || !bindings.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var emailFooterText: String? {
        switch emailError {
        case .invalidEmail: LeveragersL10n.signInErrorInvalidEmail
        case .frontDoorUnavailable: LeveragersL10n.signInErrorFrontDoorUnavailable
        case nil: nil
        }
    }
}

struct AuthenticationStartScreenViewStateBindings {
    /// Leveragers: pre-filled with the last email address used to sign in.
    var email = ""
    var alertInfo: AlertInfo<AuthenticationStartScreenAlertType>?
    var showClassicAppBackupInstructions = false
}

enum AuthenticationStartScreenAlertType {
    case genericError
}

enum AuthenticationStartScreenViewAction {
    /// Updates the window used as the OAuth presentation anchor.
    case updateWindow(UIWindow)
    /// Leveragers: the email address changed.
    case clearEmailError
    case developerOptions
    case reportProblem
    
    case loginWithQR
    case login
    case register
    
    case continueWithClassic(ClassicAppAccount)
    case otherOptions(ClassicAppAccount)
    case closeOtherOptions(ClassicAppAccount)
    case openClassicApp
}
