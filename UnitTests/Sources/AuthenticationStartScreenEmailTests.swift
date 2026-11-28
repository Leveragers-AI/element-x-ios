//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDKMocks
import Testing
import UIKit

/// Leveragers: the start screen asks for an email address and signs in to the chat server the front door names for it.
@MainActor
final class AuthenticationStartScreenEmailTests {
    private let appSettings = AppSettings.volatile()
    private let network = FrontDoorNetworkStub()
    private var client: ClientSDKMock!
    private var clientFactory: ClientFactoryMock!
    private var viewModel: AuthenticationStartScreenViewModel!
    
    private var context: AuthenticationStartScreenViewModel.Context {
        viewModel.context
    }
    
    @Test
    func emailFieldIsPrefilledWithTheLastAddress() {
        appSettings.lastSignInEmail = "jane@theseis.com"
        setupViewModel()
        
        #expect(context.viewState.signsInWithEmail)
        #expect(context.viewState.bindings.email == "jane@theseis.com")
        #expect(context.viewState.loginButtonTitle == LeveragersL10n.signInContinue)
        #expect(context.viewState.canContinue)
    }
    
    @Test
    func continueNeedsAnAddress() {
        setupViewModel()
        #expect(context.viewState.bindings.email.isEmpty)
        #expect(!context.viewState.canContinue)
        
        context.email = "   "
        #expect(!context.viewState.canContinue)
        
        context.email = "jane@theseis.com"
        #expect(context.viewState.canContinue)
    }
    
    @Test
    func signsInToTheServerOfTheAddress() async throws {
        network.answers = ["https://login.leveragers.com/d/theseis.com.json": .status(200, #"{"v":1,"server":"theseis.chat.leveragers.com"}"#)]
        setupViewModel()
        
        context.email = "  jane@theseis.com "
        let deferred = deferFulfillment(viewModel.actions) { $0.isLoginDirectlyWithOAuth }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksReceivedArguments?.serverNameOrBaseURL == "theseis.chat.leveragers.com")
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesReceivedArguments?.loginHint == "jane@theseis.com")
        #expect(appSettings.lastSignInEmail == "jane@theseis.com")
    }
    
    @Test
    func invalidAddressIsAskedAgain() async throws {
        setupViewModel()
        
        context.email = "jane"
        let deferred = deferFulfillment(context.observe(\.viewState.emailError)) { $0 == .invalidEmail }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(context.viewState.emailFooterText == LeveragersL10n.signInErrorInvalidEmail)
        #expect(context.viewState.bindings.email == "jane")
        #expect(network.requests.isEmpty)
        #expect(clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 0)
        #expect(appSettings.lastSignInEmail == nil)
        
        context.send(viewAction: .clearEmailError)
        #expect(context.viewState.emailError == nil)
        #expect(context.viewState.emailFooterText == nil)
    }
    
    @Test
    func unreachableFrontDoorKeepsTheAddressAndNeverUsesTheProServer() async throws {
        network.answers = ["https://login.leveragers.com/d/theseis.com.json": .status(503, "")]
        setupViewModel()
        
        context.email = "jane@theseis.com"
        let deferred = deferFulfillment(context.observe(\.viewState.emailError)) { $0 == .frontDoorUnavailable }
        context.send(viewAction: .login)
        try await deferred.fulfill()
        
        #expect(context.viewState.emailFooterText == LeveragersL10n.signInErrorFrontDoorUnavailable)
        #expect(context.viewState.bindings.email == "jane@theseis.com")
        #expect(clientFactory.makeAuthenticationClientServerNameOrBaseURLSessionDirectoriesPassphraseClientSessionDelegateAppSettingsAppHooksCallsCount == 0)
        #expect(client.urlForOauthOauthConfigurationPromptLoginHintDeviceIdAdditionalScopesCallsCount == 0)
        #expect(appSettings.lastSignInEmail == nil)
    }
    
    // MARK: - Helpers
    
    private func setupViewModel() {
        client = ClientSDKMock(.init(serverName: "theseis.chat.leveragers.com",
                                     homeserverURL: "https://theseis.chat.leveragers.com",
                                     oAuthLoginURL: "https://theseis.chat.leveragers.com/authorize",
                                     supportsOAuthCreatePrompt: false,
                                     supportsPasswordLogin: false))
        clientFactory = ClientFactoryMock(.init(homeserverClients: ["theseis.chat.leveragers.com": client]))
        
        let authenticationService = AuthenticationService(userSessionManager: UserSessionManagerMock(.init()),
                                                          encryptionKeyProvider: EncryptionKeyProvider(),
                                                          classicAppManager: nil,
                                                          clientFactory: clientFactory,
                                                          appSettings: appSettings,
                                                          appHooks: AppHooks())
        let frontDoorService = FrontDoorService(baseURL: appSettings.leveragersFrontDoorURL) { [network] request in
            try await network.fetch(request)
        }
        
        viewModel = AuthenticationStartScreenViewModel(authenticationService: authenticationService,
                                                       provisioningParameters: nil,
                                                       isAddingAccount: false,
                                                       isBugReportServiceEnabled: false,
                                                       appMediator: AppMediatorMock(),
                                                       appSettings: appSettings,
                                                       mediaProvider: nil,
                                                       frontDoorService: frontDoorService,
                                                       userIndicatorController: UserIndicatorControllerMock())
        
        // The OAuth flow needs a window to continue.
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            Issue.record("The test host is missing a window scene.")
            return
        }
        viewModel.context.send(viewAction: .updateWindow(UIWindow(windowScene: scene)))
    }
}
