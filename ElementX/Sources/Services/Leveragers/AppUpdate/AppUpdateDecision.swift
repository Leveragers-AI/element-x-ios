//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// What the update check shows.
nonisolated enum AppUpdatePrompt: Equatable, Sendable {
    case nothing
    /// The full-screen "Update required" screen, with no way past it but the update.
    case blocking(updateURL: URL)
    /// The "Update available" dialog, which "Later" hides for a while.
    case dialog(updateURL: URL)
}

/// What the update check remembers between launches, besides the last good update file.
nonisolated struct AppUpdateState: Codable, Equatable, Sendable {
    /// The first time the app saw its build below the recommended one, `nil` while it isn't behind.
    var firstBehindDate: Date?
    /// "Later" hides the dialog until this date.
    var snoozedUntil: Date?
}

/// The rules of the update check, apart from the network, the storage and the screens.
nonisolated enum AppUpdateDecision {
    /// How long "Later" hides the dialog.
    static let snoozeDuration: TimeInterval = 3 * 24 * 60 * 60
    /// How long "Later" hides the dialog once the app has been behind for `lateDelay`.
    static let lateSnoozeDuration: TimeInterval = 24 * 60 * 60
    /// How long the app stays behind the recommended build before "Later" hides the dialog for a shorter time.
    static let lateDelay: TimeInterval = 14 * 24 * 60 * 60
    
    /// What to show for the app's build and the thresholds, with the state noting the first time the app is seen behind.
    ///
    /// Nothing shows and the state is unchanged without thresholds or without a readable build.
    static func evaluate(ownBuild: Int?, policy: AppUpdatePolicy?, now: Date, state: AppUpdateState) -> (prompt: AppUpdatePrompt, state: AppUpdateState) {
        guard let ownBuild, let policy else {
            return (.nothing, state)
        }
        
        var state = state
        let isBehind = ownBuild < policy.recommendedBuild
        state.firstBehindDate = isBehind ? state.firstBehindDate ?? now : nil
        
        if ownBuild < policy.minBuild {
            return (.blocking(updateURL: policy.updateURL), state)
        }
        
        let isSnoozed = state.snoozedUntil.map { now < $0 } ?? false
        if isBehind, !isSnoozed {
            return (.dialog(updateURL: policy.updateURL), state)
        }
        
        return (.nothing, state)
    }
    
    /// The state after "Later": the dialog hides for 3 days, or for 1 day once the app has been behind for 14 days.
    static func snooze(now: Date, state: AppUpdateState) -> AppUpdateState {
        var state = state
        let behindDuration = state.firstBehindDate.map { now.timeIntervalSince($0) } ?? 0
        state.snoozedUntil = now.addingTimeInterval(behindDuration >= lateDelay ? lateSnoozeDuration : snoozeDuration)
        return state
    }
}
