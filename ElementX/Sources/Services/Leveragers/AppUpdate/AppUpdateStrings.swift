//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The update check's texts, in our own `Leveragers.strings` table: Element's tables are regenerated at each sync.
enum AppUpdateStrings {
    static let table = "Leveragers"
    static let keys = ["app_update_required_title", "app_update_required_message",
                       "app_update_available_title", "app_update_available_message",
                       "app_update_action_update", "app_update_action_later"]
    
    static var requiredTitle: String {
        text("app_update_required_title")
    }
    
    static var requiredMessage: String {
        text("app_update_required_message")
    }
    
    static var availableTitle: String {
        text("app_update_available_title")
    }
    
    static var availableMessage: String {
        text("app_update_available_message")
    }
    
    static var update: String {
        text("app_update_action_update")
    }
    
    static var later: String {
        text("app_update_action_later")
    }
    
    /// The text in the app's language, as Element's own texts pick it.
    private static func text(_ key: String) -> String {
        L10n.tr(table, key)
    }
}
