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
    /// Whether the composer is a single floating capsule holding the attachment button, the text field and the send button.
    static let hasFloatingComposer = true
    /// Whether the timeline scrolls under the translucent navigation bar and composer (iOS 26).
    static let hasTranslucentRoomBars = true
    
    /// Overrides the Compound colours with the Leveragers palette in light appearance.
    static func apply() {
        // Both the SwiftUI and the UIKit colours, the timeline and the composer text field use the latter.
        for (keyPath, uiKeyPath, hex) in tokens {
            Color.compound.override(keyPath, with: lightOnly(hex, otherwise: Color.compound[dynamicMember: keyPath]))
            UIColor.compound.override(uiKeyPath, with: lightOnly(hex, otherwise: UIColor.compound[dynamicMember: uiKeyPath]))
        }
        for (keyPath, uiKeyPath, opacity) in subtleGradientStops {
            Color.compound.override(keyPath, with: lightOnly(0xEBE7E0, opacity: opacity, otherwise: Color.compound[dynamicMember: keyPath]))
            UIColor.compound.override(uiKeyPath, with: lightOnly(0xEBE7E0, opacity: opacity, otherwise: UIColor.compound[dynamicMember: uiKeyPath]))
        }

        Color.compound.overrideBubbles(incoming: lightOnly(0xF1EDE6, otherwise: Color.compound._bgBubbleIncoming),
                                       outgoing: lightOnly(0xE7EDF6, otherwise: Color.compound._bgBubbleOutgoing))
    }

    // Same values as the web theme's `colors`, mapped to their iOS token names.
    private static let tokens: [(KeyPath<CompoundColorTokens, Color>, KeyPath<CompoundUIColorTokens, UIColor> & Sendable, UInt32)] = [
        // Canvas: cream background, slightly darker grouped lists.
        (\.bgCanvasDefault, \.bgCanvasDefault, 0xFAF8F4),
        (\.bgCanvasDefaultLevel1, \.bgCanvasDefaultLevel1, 0xFAF8F4),
        (\.bgSubtlePrimary, \.bgSubtlePrimary, 0xEBE7E0),
        (\.bgSubtleSecondary, \.bgSubtleSecondary, 0xEFEBE5),
        (\.bgSubtleSecondaryLevel0, \.bgSubtleSecondaryLevel0, 0xEFEBE5),

        // Actions and accent: the web theme swaps Element's green for navy ink.
        (\.bgActionPrimaryRest, \.bgActionPrimaryRest, 0x0F1627),
        (\.bgActionPrimaryHovered, \.bgActionPrimaryHovered, 0x1D2840),
        (\.bgActionPrimaryPressed, \.bgActionPrimaryPressed, 0x0A0F1C),
        (\.bgActionSecondaryRest, \.bgActionSecondaryRest, 0xFAF8F4),
        (\.bgActionSecondaryHovered, \.bgActionSecondaryHovered, 0xF0EDE6),
        (\.bgActionSecondaryPressed, \.bgActionSecondaryPressed, 0xEBE7E0),
        (\.bgActionTertiaryHovered, \.bgActionTertiaryHovered, 0xF4F1EB),
        (\.bgActionTertiarySelected, \.bgActionTertiarySelected, 0xEDE9E2),
        (\.bgAccentRest, \.bgAccentRest, 0x0F1627),
        (\.bgAccentHovered, \.bgAccentHovered, 0x1D2840),
        (\.bgAccentPressed, \.bgAccentPressed, 0x0A0F1C),

        // The web theme replaces Element's blue and green palettes with navy and cream,
        // so success, info and badge colours follow the accent.
        (\.bgAccentSelected, \.bgAccentSelected, 0xEDE9E2),
        (\.bgAccentSubtle, \.bgAccentSubtle, 0xEFEBE5),
        (\.borderAccentSubtle, \.borderAccentSubtle, 0xE5E0D7),
        (\.bgBadgeAccent, \.bgBadgeAccent, 0xE4E3F3),
        (\.textBadgeAccent, \.textBadgeAccent, 0x0F1627),
        (\.bgBadgeInfo, \.bgBadgeInfo, 0xE4E3F3),
        (\.textBadgeInfo, \.textBadgeInfo, 0x0F1627),
        (\.bgInfoSubtle, \.bgInfoSubtle, 0xEFEBE5),
        (\.borderInfoSubtle, \.borderInfoSubtle, 0xE5E0D7),
        (\.textInfoPrimary, \.textInfoPrimary, 0x0F1627),
        (\.iconInfoPrimary, \.iconInfoPrimary, 0x0F1627),
        (\.bgSuccessRest, \.bgSuccessRest, 0x0F1627),
        (\.bgSuccessHovered, \.bgSuccessHovered, 0x1D2840),
        (\.bgSuccessPressed, \.bgSuccessPressed, 0x0A0F1C),
        (\.bgSuccessSubtle, \.bgSuccessSubtle, 0xEFEBE5),
        (\.borderSuccessPrimary, \.borderSuccessPrimary, 0x0F1627),
        (\.borderSuccessSubtle, \.borderSuccessSubtle, 0xE5E0D7),
        (\.textSuccessPrimary, \.textSuccessPrimary, 0x0F1627),
        (\.textActionSuccess, \.textActionSuccess, 0x0F1627),
        (\.iconSuccessPrimary, \.iconSuccessPrimary, 0x0F1627),

        // Gradients: navy for actions.
        (\.gradientActionStop1, \.gradientActionStop1, 0x25224F),
        (\.gradientActionStop2, \.gradientActionStop2, 0x1D2840),
        (\.gradientActionStop3, \.gradientActionStop3, 0x0F1627),
        (\.gradientActionStop4, \.gradientActionStop4, 0x0A082B),
        (\.gradientInfoStop1, \.gradientInfoStop1, 0xEFEBE5),
        (\.gradientInfoStop2, \.gradientInfoStop2, 0xFAF8F4),

        // Text and icons.
        (\.textPrimary, \.textPrimary, 0x0F1627),
        (\.textSecondary, \.textSecondary, 0x6A645B),
        (\.textActionPrimary, \.textActionPrimary, 0x0F1627),
        (\.textActionAccent, \.textActionAccent, 0x0F1627),
        (\.textLinkExternal, \.textLinkExternal, 0x0F1627),
        (\.iconPrimary, \.iconPrimary, 0x0F1627),
        (\.iconSecondary, \.iconSecondary, 0x6A645B),
        (\.iconTertiary, \.iconTertiary, 0x867F74),
        (\.iconAccentPrimary, \.iconAccentPrimary, 0x0F1627),
        (\.iconAccentTertiary, \.iconAccentTertiary, 0x0F1627),

        // Borders and separators.
        (\.borderInteractiveSecondary, \.borderInteractiveSecondary, 0xE5E0D7),
        (\.borderInteractiveHovered, \.borderInteractiveHovered, 0xD6CFC4),
        (\.borderAccentPrimary, \.borderAccentPrimary, 0x0F1627),
        (\.separatorPrimary, \.separatorPrimary, 0xE5E0D7),
        (\.separatorSecondary, \.separatorSecondary, 0xF0EDE6),

        // Avatars and usernames.
        (\.bgDecorative1, \.bgDecorative1, 0xE4E3F3),
        (\.textDecorative1, \.textDecorative1, 0x14115B),
        (\.bgDecorative2, \.bgDecorative2, 0xE1E8DF),
        (\.textDecorative2, \.textDecorative2, 0x44624A),
        (\.bgDecorative3, \.bgDecorative3, 0xF0E0D8),
        (\.textDecorative3, \.textDecorative3, 0x8A4B35),
        (\.bgDecorative4, \.bgDecorative4, 0xE0E5EE),
        (\.textDecorative4, \.textDecorative4, 0x3E5378),
        (\.bgDecorative5, \.bgDecorative5, 0xE9E0EA),
        (\.textDecorative5, \.textDecorative5, 0x6A4870),
        (\.bgDecorative6, \.bgDecorative6, 0xEDE6DA),
        (\.textDecorative6, \.textDecorative6, 0x6B5A3E)
    ]

    // Warm cream fading out, like Element's: the home screen bloom is drawn over the room list.
    private static let subtleGradientStops: [(KeyPath<CompoundColorTokens, Color>, KeyPath<CompoundUIColorTokens, UIColor> & Sendable, CGFloat)] = [
        (\.gradientSubtleStop1, \.gradientSubtleStop1, 0.9),
        (\.gradientSubtleStop2, \.gradientSubtleStop2, 0.7),
        (\.gradientSubtleStop3, \.gradientSubtleStop3, 0.5),
        (\.gradientSubtleStop4, \.gradientSubtleStop4, 0.3),
        (\.gradientSubtleStop5, \.gradientSubtleStop5, 0.1),
        (\.gradientSubtleStop6, \.gradientSubtleStop6, 0)
    ]
    
    // Screens forced dark (media previews) keep Element's colours.
    // Nonisolated: SwiftUI resolves the dynamic colour on its async render thread.
    private nonisolated static func lightOnly(_ hex: UInt32, opacity: CGFloat = 1, otherwise original: UIColor) -> UIColor {
        let light = UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                            green: CGFloat((hex >> 8) & 0xFF) / 255,
                            blue: CGFloat(hex & 0xFF) / 255,
                            alpha: opacity)
        return UIColor { $0.userInterfaceStyle == .dark ? original.resolvedColor(with: $0) : light }
    }
    
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

extension Font {
    /// Sora, the display font of the Leveragers brand, for titles. Scales with Dynamic Type like the given text style.
    static func leveragersDisplay(size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
        .custom("Sora", size: size, relativeTo: textStyle).weight(.semibold)
    }
}
