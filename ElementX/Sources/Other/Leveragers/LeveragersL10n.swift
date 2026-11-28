//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Leveragers: our own texts, in `Leveragers.strings` (English and French), kept apart from Element's string files
/// that each sync replaces.
nonisolated enum LeveragersL10n {
    /// Email
    static var signInEmailLabel: String {
        tr("screen_sign_in_email_label")
    }
    
    /// Continue
    static var signInContinue: String {
        tr("screen_sign_in_continue")
    }
    
    /// Enter a valid email address.
    static var signInErrorInvalidEmail: String {
        tr("screen_sign_in_error_invalid_email")
    }
    
    /// Can't reach sign-in. Check your connection and try again.
    static var signInErrorFrontDoorUnavailable: String {
        tr("screen_sign_in_error_front_door_unavailable")
    }
    
    private static func tr(_ key: String) -> String {
        L10n.tr("Leveragers", key)
    }
}
