//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import SwiftUI

/// Shows the update check's screen and dialog in a window of its own, above Element's windows.
///
/// No Element screen changes: the window sits above them and stays hidden while there's nothing to show,
/// which lets every touch through to them.
final class AppUpdateGate {
    private let service: AppUpdateService
    private var window: UIWindow?
    /// What the window shows right now.
    private var shownPrompt: AppUpdatePrompt = .nothing
    private var refreshTask: Task<Void, Never>?
    private var foregroundObserver: AnyCancellable?
    
    init(service: AppUpdateService) {
        self.service = service
    }
    
    /// Creates the window on the app's scene, shows what the last good update file asks for, then refreshes the file,
    /// again each time the app comes back to the foreground.
    func start(in scene: UIWindowScene) {
        guard window?.windowScene !== scene else { return }
        
        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.tintColor = .compound.textActionPrimary
        window.backgroundColor = .clear
        window.rootViewController = UIViewController()
        window.isHidden = true
        self.window = window
        shownPrompt = .nothing
        
        foregroundObserver = NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.refresh()
            }
        
        show(service.prompt())
        refresh()
    }
    
    // MARK: - Private
    
    private func refresh() {
        guard refreshTask == nil else { return }
        
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await service.refreshIfDue()
            show(service.prompt())
            refreshTask = nil
        }
    }
    
    private func show(_ prompt: AppUpdatePrompt) {
        guard let window, prompt != shownPrompt else { return }
        // The dialog stays until it is answered, unless the app is now blocked.
        if case .dialog = shownPrompt, prompt == .nothing {
            return
        }
        
        window.rootViewController?.presentedViewController?.dismiss(animated: false)
        shownPrompt = prompt
        
        switch prompt {
        case .nothing:
            window.rootViewController = UIViewController()
            window.isHidden = true
        case .blocking(let updateURL):
            // Nothing behind the screen stays reachable, the keyboard included.
            window.windowScene?.windows.forEach { $0.endEditing(true) }
            let hostingController = UIHostingController(rootView: AppUpdateBlockingScreen(updateURL: updateURL))
            hostingController.view.accessibilityViewIsModal = true
            window.rootViewController = hostingController
            window.isHidden = false
        case .dialog(let updateURL):
            window.rootViewController = UIViewController()
            window.isHidden = false
            window.rootViewController?.present(makeDialog(updateURL: updateURL), animated: true)
        }
    }
    
    private func makeDialog(updateURL: URL) -> UIAlertController {
        let alert = UIAlertController(title: AppUpdateStrings.availableTitle,
                                      message: AppUpdateStrings.availableMessage,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: AppUpdateStrings.later, style: .cancel) { [weak self] _ in
            self?.service.snooze()
            self?.dialogAnswered()
        })
        let updateAction = UIAlertAction(title: AppUpdateStrings.update, style: .default) { [weak self] _ in
            UIApplication.shared.open(updateURL)
            self?.dialogAnswered()
        }
        alert.addAction(updateAction)
        alert.preferredAction = updateAction
        return alert
    }
    
    private func dialogAnswered() {
        guard case .dialog = shownPrompt else { return }
        shownPrompt = .nothing
        window?.isHidden = true
    }
}
