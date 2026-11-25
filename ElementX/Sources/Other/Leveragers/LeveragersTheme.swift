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
        for token in tokens {
            Color.compound.override(token.keyPath, with: lightOnly(token.value, otherwise: Color.compound[dynamicMember: token.keyPath]))
            UIColor.compound.override(token.uiKeyPath, with: lightOnly(token.value, otherwise: UIColor.compound[dynamicMember: token.uiKeyPath]))
        }
        for stop in subtleGradientStops {
            Color.compound.override(stop.keyPath, with: lightOnly(0xEBE7E0, opacity: stop.value, otherwise: Color.compound[dynamicMember: stop.keyPath]))
            UIColor.compound.override(stop.uiKeyPath, with: lightOnly(0xEBE7E0, opacity: stop.value, otherwise: UIColor.compound[dynamicMember: stop.uiKeyPath]))
        }
        
        Color.compound.overrideBubbles(incoming: lightOnly(0xF1EDE6, otherwise: Color.compound._bgBubbleIncoming),
                                       outgoing: lightOnly(0xE7EDF6, otherwise: Color.compound._bgBubbleOutgoing))
    }
    
    /// A colour token, by its SwiftUI and UIKit key paths (which share their names), with its value.
    private struct Token<Value> {
        let keyPath: KeyPath<CompoundColorTokens, Color>
        let uiKeyPath: KeyPath<CompoundUIColorTokens, UIColor> & Sendable
        let value: Value
        
        init(_ keyPath: KeyPath<CompoundColorTokens, Color>, _ uiKeyPath: KeyPath<CompoundUIColorTokens, UIColor> & Sendable, _ value: Value) {
            self.keyPath = keyPath
            self.uiKeyPath = uiKeyPath
            self.value = value
        }
    }
    
    // Same values as the web theme's `colors`, mapped to their iOS token names.
    private static let tokens: [Token<UInt32>] = [
        // Canvas: cream background, slightly darker grouped lists.
        .init(\.bgCanvasDefault, \.bgCanvasDefault, 0xFAF8F4),
        .init(\.bgCanvasDefaultLevel1, \.bgCanvasDefaultLevel1, 0xFAF8F4),
        .init(\.bgSubtlePrimary, \.bgSubtlePrimary, 0xEBE7E0),
        .init(\.bgSubtleSecondary, \.bgSubtleSecondary, 0xEFEBE5),
        .init(\.bgSubtleSecondaryLevel0, \.bgSubtleSecondaryLevel0, 0xEFEBE5),
        
        // Actions and accent: the web theme swaps Element's green for navy ink.
        .init(\.bgActionPrimaryRest, \.bgActionPrimaryRest, 0x0F1627),
        .init(\.bgActionPrimaryHovered, \.bgActionPrimaryHovered, 0x1D2840),
        .init(\.bgActionPrimaryPressed, \.bgActionPrimaryPressed, 0x0A0F1C),
        .init(\.bgActionSecondaryRest, \.bgActionSecondaryRest, 0xFAF8F4),
        .init(\.bgActionSecondaryHovered, \.bgActionSecondaryHovered, 0xF0EDE6),
        .init(\.bgActionSecondaryPressed, \.bgActionSecondaryPressed, 0xEBE7E0),
        .init(\.bgActionTertiaryHovered, \.bgActionTertiaryHovered, 0xF4F1EB),
        .init(\.bgActionTertiarySelected, \.bgActionTertiarySelected, 0xEDE9E2),
        .init(\.bgAccentRest, \.bgAccentRest, 0x0F1627),
        .init(\.bgAccentHovered, \.bgAccentHovered, 0x1D2840),
        .init(\.bgAccentPressed, \.bgAccentPressed, 0x0A0F1C),
        
        // The web theme replaces Element's blue and green palettes with navy and cream,
        // so success, info and badge colours follow the accent.
        .init(\.bgAccentSelected, \.bgAccentSelected, 0xEDE9E2),
        .init(\.bgAccentSubtle, \.bgAccentSubtle, 0xEFEBE5),
        .init(\.borderAccentSubtle, \.borderAccentSubtle, 0xE5E0D7),
        .init(\.bgBadgeAccent, \.bgBadgeAccent, 0xE4E3F3),
        .init(\.textBadgeAccent, \.textBadgeAccent, 0x0F1627),
        .init(\.bgBadgeInfo, \.bgBadgeInfo, 0xE4E3F3),
        .init(\.textBadgeInfo, \.textBadgeInfo, 0x0F1627),
        .init(\.bgInfoSubtle, \.bgInfoSubtle, 0xEFEBE5),
        .init(\.borderInfoSubtle, \.borderInfoSubtle, 0xE5E0D7),
        .init(\.textInfoPrimary, \.textInfoPrimary, 0x0F1627),
        .init(\.iconInfoPrimary, \.iconInfoPrimary, 0x0F1627),
        .init(\.bgSuccessRest, \.bgSuccessRest, 0x0F1627),
        .init(\.bgSuccessHovered, \.bgSuccessHovered, 0x1D2840),
        .init(\.bgSuccessPressed, \.bgSuccessPressed, 0x0A0F1C),
        .init(\.bgSuccessSubtle, \.bgSuccessSubtle, 0xEFEBE5),
        .init(\.borderSuccessPrimary, \.borderSuccessPrimary, 0x0F1627),
        .init(\.borderSuccessSubtle, \.borderSuccessSubtle, 0xE5E0D7),
        .init(\.textSuccessPrimary, \.textSuccessPrimary, 0x0F1627),
        .init(\.textActionSuccess, \.textActionSuccess, 0x0F1627),
        .init(\.iconSuccessPrimary, \.iconSuccessPrimary, 0x0F1627),
        
        // Gradients: navy for actions.
        .init(\.gradientActionStop1, \.gradientActionStop1, 0x25224F),
        .init(\.gradientActionStop2, \.gradientActionStop2, 0x1D2840),
        .init(\.gradientActionStop3, \.gradientActionStop3, 0x0F1627),
        .init(\.gradientActionStop4, \.gradientActionStop4, 0x0A082B),
        .init(\.gradientInfoStop1, \.gradientInfoStop1, 0xEFEBE5),
        .init(\.gradientInfoStop2, \.gradientInfoStop2, 0xFAF8F4),
        
        // Text and icons.
        .init(\.textPrimary, \.textPrimary, 0x0F1627),
        .init(\.textSecondary, \.textSecondary, 0x6A645B),
        .init(\.textActionPrimary, \.textActionPrimary, 0x0F1627),
        .init(\.textActionAccent, \.textActionAccent, 0x0F1627),
        .init(\.textLinkExternal, \.textLinkExternal, 0x0F1627),
        .init(\.iconPrimary, \.iconPrimary, 0x0F1627),
        .init(\.iconSecondary, \.iconSecondary, 0x6A645B),
        .init(\.iconTertiary, \.iconTertiary, 0x867F74),
        .init(\.iconAccentPrimary, \.iconAccentPrimary, 0x0F1627),
        .init(\.iconAccentTertiary, \.iconAccentTertiary, 0x0F1627),
        
        // Borders and separators.
        .init(\.borderInteractiveSecondary, \.borderInteractiveSecondary, 0xE5E0D7),
        .init(\.borderInteractiveHovered, \.borderInteractiveHovered, 0xD6CFC4),
        .init(\.borderAccentPrimary, \.borderAccentPrimary, 0x0F1627),
        .init(\.separatorPrimary, \.separatorPrimary, 0xE5E0D7),
        .init(\.separatorSecondary, \.separatorSecondary, 0xF0EDE6),
        
        // Avatars and usernames.
        .init(\.bgDecorative1, \.bgDecorative1, 0xE4E3F3),
        .init(\.textDecorative1, \.textDecorative1, 0x14115B),
        .init(\.bgDecorative2, \.bgDecorative2, 0xE1E8DF),
        .init(\.textDecorative2, \.textDecorative2, 0x44624A),
        .init(\.bgDecorative3, \.bgDecorative3, 0xF0E0D8),
        .init(\.textDecorative3, \.textDecorative3, 0x8A4B35),
        .init(\.bgDecorative4, \.bgDecorative4, 0xE0E5EE),
        .init(\.textDecorative4, \.textDecorative4, 0x3E5378),
        .init(\.bgDecorative5, \.bgDecorative5, 0xE9E0EA),
        .init(\.textDecorative5, \.textDecorative5, 0x6A4870),
        .init(\.bgDecorative6, \.bgDecorative6, 0xEDE6DA),
        .init(\.textDecorative6, \.textDecorative6, 0x6B5A3E)
    ]
    
    // Warm cream fading out, like Element's: the home screen bloom is drawn over the room list.
    private static let subtleGradientStops: [Token<CGFloat>] = [
        .init(\.gradientSubtleStop1, \.gradientSubtleStop1, 0.9),
        .init(\.gradientSubtleStop2, \.gradientSubtleStop2, 0.7),
        .init(\.gradientSubtleStop3, \.gradientSubtleStop3, 0.5),
        .init(\.gradientSubtleStop4, \.gradientSubtleStop4, 0.3),
        .init(\.gradientSubtleStop5, \.gradientSubtleStop5, 0.1),
        .init(\.gradientSubtleStop6, \.gradientSubtleStop6, 0)
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
