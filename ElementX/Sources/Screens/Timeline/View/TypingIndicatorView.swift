//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import SwiftUI

struct TypingIndicatorView: View {
    @ObservedObject var typingMembers: TypingMembersObservableObject
    @State private var didShowTextOnce = false
    
    @Environment(\.timelineContext) private var context
    
    private let bubbleHeight: CGFloat = 28
    private let bubbleVerticalPadding: CGFloat = 4
    
    var body: some View {
        if AppSettings.showsTypingBubble {
            bubble
                .animation(.elementDefault, value: typingMembers.members.isEmpty)
                .onChange(of: typingMembers.members) { _, newValue in
                    if !newValue.isEmpty {
                        didShowTextOnce = true
                    }
                }
        } else {
            label
        }
    }
    
    /// Leveragers: the avatars of the people typing and Element Web's typing dots, the names read by VoiceOver.
    @ViewBuilder
    private var bubble: some View {
        if typingMembers.members.isEmpty {
            // Once shown, the bubble's room stays so that the timeline doesn't jump each time someone types.
            // Otherwise, together with the margins and minSize on the contentConfiguration, keeps the cell small.
            Color.clear
                .frame(height: didShowTextOnce ? bubbleHeight + 2 * bubbleVerticalPadding : 1)
        } else {
            HStack(spacing: 9) {
                avatars
                TypingDotsView()
                    .padding(.horizontal, 14)
                    .frame(height: bubbleHeight)
                    .background(.compound._bgBubbleIncoming, in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.vertical, bubbleVerticalPadding)
            .transition(.opacity.combined(with: .offset(y: 6)))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityText))
        }
    }
    
    private var avatars: some View {
        HStack(spacing: -6) {
            ForEach(typingMembers.members.prefix(3), id: \.self) { name in
                let member = member(named: name)
                LoadableAvatarImage(url: member?.value.avatarURL,
                                    name: name,
                                    contentID: member?.key ?? name,
                                    avatarSize: .user(on: .typingIndicator),
                                    mediaProvider: context?.mediaProvider)
                    .overlay {
                        Circle()
                            .inset(by: -1)
                            .stroke(.compound.bgCanvasDefault, lineWidth: 2)
                    }
            }
        }
    }
    
    private var label: some View {
        content
            .font(.compound.bodySM)
            .foregroundColor(.compound.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, 4)
            .animation(.elementDefault, value: typingMembers.members)
            .onChange(of: typingMembers.members) { _, newValue in
                if !newValue.isEmpty {
                    didShowTextOnce = true
                }
            }
    }
    
    @ViewBuilder
    private var content: some View {
        // Plurals with string arguments aren't generated correctly by so we need to work around that
        // https://github.com/SwiftGen/SwiftGen/issues/1089
        
        switch typingMembers.members.count {
        case 1:
            let firstMember = typingMembers.members[0]
            
            Text(firstMember).bold() +
                Text(L10n.screenRoomTypingNotificationSingularIos)
        case 2:
            let firstMember = typingMembers.members[0]
            let lastMember = typingMembers.members[1]
            
            Text(L10n.screenRoomTypingTwoMembers(firstMember, lastMember)).bold() +
                Text(L10n.screenRoomTypingNotificationPluralIos)
        case 3...:
            let firstMember = typingMembers.members[0]
            let lastMember = typingMembers.members[1]
            
            Text(L10n.tr("Localizable", "screen_room_typing_many_members_first_component_ios", firstMember, lastMember)).bold() +
                Text(L10n.tr("Localizable", "common_many_members", typingMembers.members.count - 2)).bold() +
                Text(L10n.screenRoomTypingNotificationPluralIos)
        default:
            if didShowTextOnce {
                Text(L10n.screenRoomTypingNotificationSingularIos)
                    .opacity(0)
            } else {
                // Together with the margins and minSize on the contentConfiguration forces the tableView cell to be small
                Rectangle()
                    .frame(height: 1)
                    .opacity(0)
            }
        }
    }
    
    // The typing members are display names: the members are matched on them to find the avatars.
    private func member(named name: String) -> (key: String, value: RoomMemberState)? {
        context?.viewState.members.first { ($0.value.displayName ?? $0.key) == name }
    }
    
    private var accessibilityText: String {
        let members = typingMembers.members
        switch members.count {
        case 1:
            return members[0] + L10n.screenRoomTypingNotificationSingularIos
        case 2:
            return L10n.screenRoomTypingTwoMembers(members[0], members[1]) + L10n.screenRoomTypingNotificationPluralIos
        default:
            return L10n.tr("Localizable", "screen_room_typing_many_members_first_component_ios", members[0], members[1]) +
                L10n.tr("Localizable", "common_many_members", members.count - 2) +
                L10n.screenRoomTypingNotificationPluralIos
        }
    }
}

/// Leveragers: Element Web's typing dots, a wave that lifts, enlarges and darkens each dot in turn.
private struct TypingDotsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Element Web's `lv-frappe` animation: dots 6 pt wide, 10 pt apart, one wave every 1.33 s.
    private let period = 1.33
    private let peaks: [Double] = [0.5, 2 / 3, 5 / 6]
    private let restingOpacities = [0.35, 0.6, 0.85]
    
    var body: some View {
        if reduceMotion {
            dots { index in (opacity: restingOpacities[index], lift: 0) }
        } else {
            SwiftUI.TimelineView(.animation) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                dots { index in
                    let lift = lift(at: phase, peak: peaks[index])
                    return (opacity: 0.45 + 0.55 * lift, lift: lift)
                }
            }
        }
    }
    
    private func dots(_ style: @escaping (Int) -> (opacity: Double, lift: Double)) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                let style = style(index)
                Circle()
                    .fill(.compound.textPrimary)
                    .frame(width: 6, height: 6)
                    .opacity(style.opacity)
                    .scaleEffect(1 + 0.25 * style.lift)
                    .offset(y: 0.75 - 1.5 * style.lift)
            }
        }
    }
    
    /// How far a dot is in its wave, from 0 (resting) to 1 (top), matching the keyframes of Element Web.
    private func lift(at phase: Double, peak: Double) -> Double {
        var distance = abs(phase - peak)
        distance = min(distance, 1 - distance)
        return pow((1 + cos(2 * .pi * distance)) / 2, 1.5)
    }
}

struct TypingIndicatorView_Previews: PreviewProvider, TestablePreview {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16.0) {
            TypingIndicatorView(typingMembers: TypingMembersObservableObject(members: ["Alice"]))
            TypingIndicatorView(typingMembers: TypingMembersObservableObject(members: ["Alice", "Bob"]))
            TypingIndicatorView(typingMembers: TypingMembersObservableObject(members: ["Alice", "Bob", "Charlie"]))
            TypingIndicatorView(typingMembers: TypingMembersObservableObject(members: ["Alice", "Bob", "Charlie", "Dan"]))
            TypingIndicatorView(typingMembers: TypingMembersObservableObject(members: ["Alice", "Bob", "Charlie", "Dan", "Frannie"]))
            TypingIndicatorView(typingMembers: TypingMembersObservableObject(members: ["Alice with her very long display name", "Bob", "Charlie", "Dan", "Frannie"]))
        }
        .frame(width: 300)
    }
}
