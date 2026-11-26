//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The room that opens in place of the page of a joined space, as on Element Web.
enum SpaceFirstRoom {
    /// The first room of the space in the home screen's order, a private chat only when the space has no other room.
    ///
    /// `nil` when the space or its rooms aren't known yet, or it has none: the space's page shows as before.
    static func roomID(inSpace spaceID: String, userSession: UserSessionProtocol) -> String? {
        let clientProxy = userSession.clientProxy
        guard let spaceFilter = clientProxy.spaceService.spaceFilterPublisher.value.first(where: { $0.room.id == spaceID }) else {
            return nil
        }
        
        let rooms = clientProxy.staticRoomSummaryProvider.roomListPublisher.value
            .filter { !$0.isSpace }
            .map { HomeScreenRoom(summary: $0) }
        let webSections = userSession.userSettings.account.webRoomListSectionsData
            .flatMap { try? JSONDecoder().decode(WebRoomListSections.self, from: $0) } ?? .empty
        
        return roomID(in: spaceFilter, rooms: rooms, webSections: webSections)
    }
    
    static func roomID(in spaceFilter: SpaceServiceFilter, rooms: [HomeScreenRoom], webSections: WebRoomListSections) -> String? {
        // Without its rooms, the space would list every room.
        guard !spaceFilter.descendants.isEmpty else { return nil }
        
        let joinedRooms = HomeScreenRoomSection.sections(from: rooms, in: spaceFilter, webSections: webSections)
            .flatMap(\.rooms)
            .filter { $0.type == .room }
        return (joinedRooms.first { !$0.isDirect } ?? joinedRooms.first)?.roomID
    }
}
