//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

/// The Leveragers palette, matching the "Leveragers" custom theme of our Element Web `config.json`.
enum LeveragersTheme {
    /// Overrides the Compound colours with the Leveragers palette in light appearance.
    static func apply() {
        for (keyPath, hex) in tokens {
            Color.compound.override(keyPath, with: lightOnly(hex, otherwise: Color.compound[dynamicMember: keyPath]))
        }
        for (keyPath, opacity) in subtleGradientStops {
            Color.compound.override(keyPath, with: lightOnly(0xEBE7E0, opacity: opacity, otherwise: Color.compound[dynamicMember: keyPath]))
        }

        Color.compound.overrideBubbles(incoming: lightOnly(0xF0EBE3, otherwise: Color.compound._bgBubbleIncoming),
                                       outgoing: lightOnly(0xE7EDF6, otherwise: Color.compound._bgBubbleOutgoing))
    }

    // Same values as the web theme's `colors`, mapped to their iOS token names.
    private static let tokens: [(KeyPath<CompoundColorTokens, Color>, UInt32)] = [
        // Canvas: cream background, slightly darker grouped lists.
        (\.bgCanvasDefault, 0xFAF8F4),
        (\.bgCanvasDefaultLevel1, 0xFAF8F4),
        (\.bgSubtlePrimary, 0xEBE7E0),
        (\.bgSubtleSecondary, 0xEFEBE5),
        (\.bgSubtleSecondaryLevel0, 0xEFEBE5),

        // Actions and accent: the web theme swaps Element's green for navy ink.
        (\.bgActionPrimaryRest, 0x0F1627),
        (\.bgActionPrimaryHovered, 0x1D2840),
        (\.bgActionPrimaryPressed, 0x0A0F1C),
        (\.bgActionSecondaryRest, 0xFAF8F4),
        (\.bgActionSecondaryHovered, 0xF0EDE6),
        (\.bgActionSecondaryPressed, 0xEBE7E0),
        (\.bgActionTertiaryHovered, 0xF4F1EB),
        (\.bgActionTertiarySelected, 0xEDE9E2),
        (\.bgAccentRest, 0x0F1627),
        (\.bgAccentHovered, 0x1D2840),
        (\.bgAccentPressed, 0x0A0F1C),

        // The web theme replaces Element's blue and green palettes with navy and cream,
        // so success, info and badge colours follow the accent.
        (\.bgAccentSelected, 0xEDE9E2),
        (\.bgAccentSubtle, 0xEFEBE5),
        (\.borderAccentSubtle, 0xE5E0D7),
        (\.bgBadgeAccent, 0xE4E3F3),
        (\.textBadgeAccent, 0x0F1627),
        (\.bgBadgeInfo, 0xE4E3F3),
        (\.textBadgeInfo, 0x0F1627),
        (\.bgInfoSubtle, 0xEFEBE5),
        (\.borderInfoSubtle, 0xE5E0D7),
        (\.textInfoPrimary, 0x0F1627),
        (\.iconInfoPrimary, 0x0F1627),
        (\.bgSuccessRest, 0x0F1627),
        (\.bgSuccessHovered, 0x1D2840),
        (\.bgSuccessPressed, 0x0A0F1C),
        (\.bgSuccessSubtle, 0xEFEBE5),
        (\.borderSuccessPrimary, 0x0F1627),
        (\.borderSuccessSubtle, 0xE5E0D7),
        (\.textSuccessPrimary, 0x0F1627),
        (\.textActionSuccess, 0x0F1627),
        (\.iconSuccessPrimary, 0x0F1627),

        // Gradients: navy for actions.
        (\.gradientActionStop1, 0x25224F),
        (\.gradientActionStop2, 0x1D2840),
        (\.gradientActionStop3, 0x0F1627),
        (\.gradientActionStop4, 0x0A082B),
        (\.gradientInfoStop1, 0xEFEBE5),
        (\.gradientInfoStop2, 0xFAF8F4),

        // Text and icons.
        (\.textPrimary, 0x0F1627),
        (\.textSecondary, 0x6A645B),
        (\.textActionPrimary, 0x0F1627),
        (\.textActionAccent, 0x0F1627),
        (\.textLinkExternal, 0x0F1627),
        (\.iconPrimary, 0x0F1627),
        (\.iconSecondary, 0x6A645B),
        (\.iconTertiary, 0x867F74),
        (\.iconAccentPrimary, 0x0F1627),
        (\.iconAccentTertiary, 0x0F1627),

        // Borders and separators.
        (\.borderInteractiveSecondary, 0xE5E0D7),
        (\.borderInteractiveHovered, 0xD6CFC4),
        (\.borderAccentPrimary, 0x0F1627),
        (\.separatorPrimary, 0xE5E0D7),
        (\.separatorSecondary, 0xF0EDE6),

        // Avatars and usernames.
        (\.bgDecorative1, 0xE4E3F3),
        (\.textDecorative1, 0x14115B),
        (\.bgDecorative2, 0xE1E8DF),
        (\.textDecorative2, 0x44624A),
        (\.bgDecorative3, 0xF0E0D8),
        (\.textDecorative3, 0x8A4B35),
        (\.bgDecorative4, 0xE0E5EE),
        (\.textDecorative4, 0x3E5378),
        (\.bgDecorative5, 0xE9E0EA),
        (\.textDecorative5, 0x6A4870),
        (\.bgDecorative6, 0xEDE6DA),
        (\.textDecorative6, 0x6B5A3E)
    ]

    // Warm cream fading out, like Element's: the home screen bloom is drawn over the room list.
    private static let subtleGradientStops: [(KeyPath<CompoundColorTokens, Color>, CGFloat)] = [
        (\.gradientSubtleStop1, 0.9),
        (\.gradientSubtleStop2, 0.7),
        (\.gradientSubtleStop3, 0.5),
        (\.gradientSubtleStop4, 0.3),
        (\.gradientSubtleStop5, 0.1),
        (\.gradientSubtleStop6, 0)
    ]
    
    // Screens forced dark (start screen on navy, media previews) keep Element's colours.
    // Nonisolated: SwiftUI resolves the dynamic colour on its async render thread.
    private nonisolated static func lightOnly(_ hex: UInt32, opacity: CGFloat = 1, otherwise original: Color) -> Color {
        let light = UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                            green: CGFloat((hex >> 8) & 0xFF) / 255,
                            blue: CGFloat(hex & 0xFF) / 255,
                            alpha: opacity)
        var darkEnvironment = EnvironmentValues()
        darkEnvironment.colorScheme = .dark
        let dark = UIColor(Color(original.resolve(in: darkEnvironment)))
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
