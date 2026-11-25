//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import Foundation
import UIKit

enum HomeScreenViewModelAction {
    case presentRoom(roomIdentifier: String)
    case detachRoom(roomIdentifier: String)
    case presentRoomDetails(roomIdentifier: String)
    case presentReportRoom(roomIdentifier: String)
    case presentDeclineAndBlock(userID: String, roomID: String)
    case presentSpace(SpaceRoomListProxyProtocol)
    case roomLeft(roomIdentifier: String)
    case transferOwnership(roomIdentifier: String)
    case presentSecureBackupSettings
    case presentRecoveryKeyScreen
    case presentEncryptionResetScreen
    case presentSettingsScreen
    case presentFeedbackScreen
    case presentStartChatScreen
    case logout
}

enum HomeScreenViewAction {
    case selectRoom(roomIdentifier: String)
    case detachRoom(roomIdentifier: String)
    case showRoomDetails(roomIdentifier: String)
    case leaveRoom(roomIdentifier: String)
    case confirmLeaveRoom(roomIdentifier: String)
    case reportRoom(roomIdentifier: String)
    case showSettings
    case startChat
    case setupRecovery
    case confirmRecoveryKey
    case resetEncryption
    case skipRecoveryKeyConfirmation
    case selectSpaceFilter(SpaceServiceFilter)
    case dismissNewSoundBanner
    case screenAppeared
    case multiAccountAnnouncementAppeared
    case dismissMultiAccountAnnouncement
    case addAccount
    case updateVisibleItemRange(Range<Int>)
    case spaceFilters
    case markRoomAsUnread(roomIdentifier: String)
    case markRoomAsRead(roomIdentifier: String)
    case markRoomAsFavourite(roomIdentifier: String, isFavourite: Bool)
    
    case acceptInvite(roomIdentifier: String)
    case declineInvite(roomIdentifier: String)
}

enum HomeScreenRoomListMode: CustomStringConvertible {
    /// Shows nothing briefly on launch as the cached rooms usually publish in time to go straight to them.
    case awaitingCachedRooms
    case skeletons
    case empty
    case rooms
    
    var description: String {
        switch self {
        case .awaitingCachedRooms:
            return "Awaiting cached rooms"
        case .skeletons:
            return "Showing placeholders"
        case .empty:
            return "Showing empty state"
        case .rooms:
            return "Showing rooms"
        }
    }
}

enum HomeScreenSecurityBannerMode: Equatable {
    case none
    case dismissed
    case show(HomeScreenRecoveryKeyConfirmationBanner.State)
    
    var isDismissed: Bool {
        switch self {
        case .dismissed: true
        default: false
        }
    }
    
    var isShown: Bool {
        switch self {
        case .show: true
        default: false
        }
    }
}

struct HomeScreenViewState: BindableState {
    var userProfile: UserProfile
    
    var securityBannerMode = HomeScreenSecurityBannerMode.none
    var shouldShowNewSoundBanner = false
    
    var rooms: [HomeScreenRoom] = []
    var roomListMode: HomeScreenRoomListMode = .awaitingCachedRooms
    
    var hasPendingInvitations = false
    
    var selectedRoomID: String?
    
    var hideInviteAvatars = false
    
    var reportRoomEnabled = false
    
    var shouldShowSpaceFilters = false
    var selectedSpaceFilter: SpaceServiceFilter?
    /// The top level spaces offered by the title menu of the simplified home screen.
    var spaceMenuFilters: [SpaceServiceFilter] = []
    /// The rooms grouped like the Element Web room list. Empty when the list isn't sectioned.
    var roomSections: [HomeScreenRoomSection] = []
    
    /// Inline room list search is disabled when the dedicated global search tab is shown instead (see `UserSessionFlowCoordinator`).
    var isRoomListSearchEnabled = true
    /// Whether the room list filters (Unread, Favourites…) are shown above the rooms.
    var areFiltersEnabled = true
    /// Whether the navigation bar only holds the settings and new room buttons.
    var hasSimplifiedHeader = false
    
    var visibleRooms: [HomeScreenRoom] {
        if roomListMode == .skeletons || roomListMode == .awaitingCachedRooms {
            return placeholderRooms
        }
        
        return rooms
    }
    
    var bindings: HomeScreenViewStateBindings
    
    var placeholderRooms: [HomeScreenRoom] {
        (1...10).map { _ in
            HomeScreenRoom.placeholder()
        }
    }
    
    /// Used to hide all the rooms when the search field is focused and the query is empty
    var shouldHideRoomList: Bool {
        bindings.isSearchFieldFocused && bindings.searchQuery.isEmpty
    }
    
    var shouldShowEmptyFilterState: Bool {
        !bindings.isSearchFieldFocused &&
            (bindings.filtersState.isFiltering || selectedSpaceFilter != nil) &&
            visibleRooms.isEmpty
    }
    
    var shouldShowFilters: Bool {
        areFiltersEnabled && !bindings.isSearchFieldFocused && roomListMode == .rooms
    }
    
    var shouldShowBanner: Bool {
        securityBannerMode.isShown || shouldShowNewSoundBanner
    }
}

struct HomeScreenViewStateBindings {
    var filtersState: RoomListFiltersState
    var searchQuery = ""
    var isSearchFieldFocused = false
    
    var alertInfo: AlertInfo<UUID>?
    var leaveRoomAlertItem: LeaveRoomAlertItem?
    
    var spaceFiltersViewModel: ChatsSpaceFiltersScreenViewModel?
    var isPresentingMultiAccountAnnouncement = false
}

enum CallBadgeType {
    case voice, video, none
}

struct HomeScreenRoom: Identifiable, Equatable {
    enum RoomType: Equatable {
        case placeholder
        case room
        case invite(inviterDetails: RoomInviterDetails?)
        case knock
    }
    
    static let placeholderLastMessage = AttributedString("Hidden last message")
    
    /// The list item identifier is it's room identifier.
    let id: String
    
    /// The real room identifier this item points to
    let roomID: String?
    
    let type: RoomType
    
    var inviter: RoomInviterDetails? {
        if case .invite(let inviter) = type {
            return inviter
        }
        return nil
    }
    
    let badges: Badges
    struct Badges: Equatable {
        let isDotShown: Bool
        let notificationCount: UInt
        let isMentionShown: Bool
        let isMuteShown: Bool
        let callBadgeType: CallBadgeType
    }
    
    let name: String
    
    let isDirect: Bool
    
    let isHighlighted: Bool
    
    let isFavourite: Bool
    
    let timestamp: String?
    
    let lastMessage: AttributedString?
    
    enum LastMessageState { case sending, failed }
    let lastMessageState: LastMessageState?
    
    let avatar: RoomAvatar
    
    let statusEmoji: Character?
    
    let canonicalAlias: String?
    
    let isTombstoned: Bool
    
    var isLowPriority = false
    
    var displayedLastMessage: AttributedString? {
        if isTombstoned {
            AttributedString(L10n.screenRoomlistTombstonedRoomDescription)
        } else if lastMessageState == .failed {
            AttributedString(L10n.commonMessageFailedToSend)
        } else {
            lastMessage
        }
    }
    
    static func placeholder() -> HomeScreenRoom {
        HomeScreenRoom(id: UUID().uuidString,
                       roomID: nil,
                       type: .placeholder,
                       badges: .init(isDotShown: false, notificationCount: 0, isMentionShown: false, isMuteShown: false, callBadgeType: .none),
                       name: "Placeholder room name",
                       isDirect: false,
                       isHighlighted: false,
                       isFavourite: false,
                       timestamp: "Now",
                       lastMessage: placeholderLastMessage,
                       lastMessageState: nil,
                       avatar: .room(id: "", name: "", avatarURL: nil),
                       statusEmoji: nil,
                       canonicalAlias: nil,
                       isTombstoned: false)
    }
}

/// A group of rooms on the simplified home screen, in the same order as the Element Web room list.
struct HomeScreenRoomSection: Identifiable, Equatable {
    enum Kind: Hashable {
        case invites, favourites, directMessages, rooms, lowPriority
        /// A section created in Element Web.
        case custom(tag: String, name: String)
    }
    
    let kind: Kind
    let rooms: [HomeScreenRoom]
    
    var id: Kind {
        kind
    }
    
    var title: String {
        switch kind {
        case .invites: L10n.screenRoomlistFilterInvites
        case .favourites: L10n.screenRoomlistFilterFavourites
        // Leveragers: looked up like translated strings so that the French "Messages privés" of
        // fr.lproj/Untranslated.strings is used until Localazy has the key (UntranslatedL10n is English only).
        case .directMessages: L10n.tr("Untranslated", "screen_roomlist_section_direct_messages")
        case .rooms: L10n.screenRoomlistFilterRooms
        case .lowPriority: L10n.screenRoomlistFilterLowPriority
        case .custom(_, let name): name
        }
    }
    
    /// Groups the rooms of the given space into Element Web's sections, each sorted alphabetically.
    ///
    /// Invites and direct messages are shown whatever the space, as they don't belong to one.
    static func sections(from rooms: [HomeScreenRoom],
                         in spaceFilter: SpaceServiceFilter?,
                         webSections: WebRoomListSections) -> [HomeScreenRoomSection] {
        let kinds = orderedKinds(for: webSections)
        let grouped = Dictionary(grouping: rooms.filter { isRoom($0, in: spaceFilter) }) { kind(of: $0, among: kinds, webSections: webSections) }
        
        return kinds.compactMap { kind in
            guard let rooms = grouped[kind], !rooms.isEmpty else { return nil }
            return HomeScreenRoomSection(kind: kind, rooms: rooms.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        }
    }
    
    // Invites and Favourites are pinned at the top and Low priority at the bottom, as on Element Web.
    private static func orderedKinds(for webSections: WebRoomListSections) -> [Kind] {
        let reorderable: [Kind] = webSections.orderedTags.compactMap { tag in
            switch tag {
            case WebRoomListSections.chatsTag: .rooms
            case WebRoomListSections.directMessagesTag: .directMessages
            default: webSections.customSectionNames[tag].map { .custom(tag: tag, name: $0) }
            }
        }
        return [.invites, .favourites] + reorderable + [.lowPriority]
    }
    
    private static func isRoom(_ room: HomeScreenRoom, in spaceFilter: SpaceServiceFilter?) -> Bool {
        // A space whose rooms aren't known yet (its state is still syncing) hides nothing,
        // rather than every room.
        guard let spaceFilter, !spaceFilter.descendants.isEmpty, room.type == .room, !room.isDirect else { return true }
        return spaceFilter.descendants.contains(room.roomID ?? room.id)
    }
    
    // Same rule as Element Web: an invite wins, then the first section in display order whose tag
    // the room carries, then direct messages, then Rooms.
    private static func kind(of room: HomeScreenRoom, among kinds: [Kind], webSections: WebRoomListSections) -> Kind {
        switch room.type {
        case .invite, .knock:
            return .invites
        case .placeholder, .room:
            break
        }
        
        let customTags = webSections.roomTags[room.roomID ?? room.id] ?? []
        let taggedKind = kinds.first { kind in
            switch kind {
            case .favourites: room.isFavourite
            case .lowPriority: room.isLowPriority
            case .custom(let tag, _): customTags.contains(tag)
            case .invites, .directMessages, .rooms: false
            }
        }
        
        return taggedKind ?? (room.isDirect ? .directMessages : .rooms)
    }
}

extension HomeScreenRoom {
    init(summary: RoomSummary,
         showAllActivity: Bool = true,
         seenInvites: Set<String> = []) {
        let roomID = summary.id
        
        let isUnseenInvite = summary.joinRequestType?.isInvite == true && !seenInvites.contains(roomID)
        
        let isDotShown = if showAllActivity {
            summary.hasUnreadMessages || summary.hasUnreadMentions || summary.hasUnreadNotifications || summary.isMarkedUnread || isUnseenInvite
        } else {
            (!summary.isMuted && (summary.hasUnreadNotifications || summary.hasUnreadMentions)) || summary.isMarkedUnread || isUnseenInvite
        }
        
        let isMentionShown = summary.hasUnreadMentions && !summary.isMuted
        let isMuteShown = summary.isMuted
        let isHighlighted = summary.isMarkedUnread || (!summary.isMuted && (summary.hasUnreadNotifications || summary.hasUnreadMentions)) || isUnseenInvite
        
        let callBadge = if summary.hasOngoingCall {
            summary.activeCallIntent == .audio ? CallBadgeType.voice : CallBadgeType.video
        } else {
            CallBadgeType.none
        }
        
        let type: HomeScreenRoom.RoomType = switch summary.joinRequestType {
        case .invite(let inviter): .invite(inviterDetails: inviter.map(RoomInviterDetails.init))
        case .knock: .knock
        case .none: .room
        }
        
        self.init(id: roomID,
                  roomID: summary.id,
                  type: type,
                  badges: .init(isDotShown: isDotShown,
                                notificationCount: summary.unreadNotificationsCount,
                                isMentionShown: isMentionShown,
                                isMuteShown: isMuteShown,
                                callBadgeType: callBadge),
                  name: summary.name,
                  isDirect: summary.isDirect,
                  isHighlighted: isHighlighted,
                  isFavourite: summary.isFavourite,
                  timestamp: summary.lastMessageDate?.formattedMinimal(),
                  lastMessage: summary.lastMessage,
                  lastMessageState: summary.homeScreenLastMessageState,
                  avatar: summary.avatar,
                  statusEmoji: summary.statusEmoji,
                  canonicalAlias: summary.canonicalAlias,
                  isTombstoned: summary.isTombstoned,
                  isLowPriority: summary.isLowPriority)
    }
}

private extension RoomSummary {
    var homeScreenLastMessageState: HomeScreenRoom.LastMessageState? {
        if isTombstoned {
            nil
        } else {
            switch lastMessageState {
            case .sending: .sending
            case .failed: .failed
            case .none: .none
            }
        }
    }
}
