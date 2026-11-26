//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import MatrixRustSDKMocks
import Testing

struct SpaceFirstRoomTests {
    @Test("The first room of the space in the home screen's order opens")
    func firstRoomInHomeOrder() {
        let rooms = [room("!b", name: "Bravo"), room("!other", name: "Alpha"), room("!a", name: "Charlie")]
        
        #expect(SpaceFirstRoom.roomID(in: space(["!a", "!b"]), rooms: rooms, webSections: .empty) == "!b")
    }
    
    @Test("A private chat only opens when the space has no other room")
    func directMessageLast() {
        let rooms = [room("!dm", name: "Agent", isDirect: true), room("!room", name: "Zulu")]
        
        #expect(SpaceFirstRoom.roomID(in: space(["!room"]), rooms: rooms, webSections: .empty) == "!room")
        #expect(SpaceFirstRoom.roomID(in: space(["!unknown"]), rooms: rooms, webSections: .empty) == "!dm")
    }
    
    @Test("Invites never open in place of the space")
    func invitesSkipped() {
        let rooms = [room("!invite", name: "Alpha", isInvite: true), room("!room", name: "Bravo")]
        
        #expect(SpaceFirstRoom.roomID(in: space(["!invite", "!room"]), rooms: rooms, webSections: .empty) == "!room")
    }
    
    @Test("The space's page shows while its rooms aren't known, or when it has none")
    func noRoom() {
        #expect(SpaceFirstRoom.roomID(in: space([]), rooms: [room("!room", name: "Alpha")], webSections: .empty) == nil)
        #expect(SpaceFirstRoom.roomID(in: space(["!room"]), rooms: [], webSections: .empty) == nil)
    }
    
    // MARK: - Helpers
    
    private func space(_ descendants: Set<String>) -> SpaceServiceFilter {
        SpaceServiceFilter(room: [SpaceServiceRoom].mockJoinedSpaces[0], level: 0, descendants: descendants)
    }
    
    private func room(_ id: String, name: String, isDirect: Bool = false, isInvite: Bool = false) -> HomeScreenRoom {
        HomeScreenRoom(summary: RoomSummary(room: RoomSDKMock(.init()),
                                            id: id,
                                            joinRequestType: isInvite ? .invite(inviter: nil) : nil,
                                            isJoined: !isInvite,
                                            name: name,
                                            isDirect: isDirect,
                                            isSpace: false,
                                            avatarURL: nil,
                                            heroes: [],
                                            activeMembersCount: 0,
                                            lastMessage: nil,
                                            lastMessageDate: nil,
                                            lastMessageState: nil,
                                            unreadMessagesCount: 0,
                                            unreadMentionsCount: 0,
                                            unreadNotificationsCount: 0,
                                            notificationMode: nil,
                                            canonicalAlias: nil,
                                            alternativeAliases: [],
                                            hasOngoingCall: false,
                                            activeCallIntent: nil,
                                            isMarkedUnread: false,
                                            isFavourite: false,
                                            isTombstoned: false))
    }
}
