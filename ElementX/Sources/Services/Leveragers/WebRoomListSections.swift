//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The room list sections created in Element Web, read from the account so that the app shows the same ones.
///
/// Element Web stores the sections in its `im.vector.web.settings` account data
/// (`RoomList.CustomSectionData` and `RoomList.OrderedCustomSections`) and adds each room
/// to a section with an `element.io.section.<id>` room tag.
nonisolated struct WebRoomListSections: Equatable, Sendable {
    static let settingsEventType = "im.vector.web.settings"
    static let customTagPrefix = "element.io.section."
    /// Element Web's synthetic tag for the section holding every other room.
    static let chatsTag = "chats"
    /// Element Web's synthetic tag for the direct messages section.
    static let directMessagesTag = "im.vector.fake.direct"
    
    static let empty = WebRoomListSections(orderedTags: [directMessagesTag, chatsTag], customSectionNames: [:])
    
    /// The sections shown between Favourites and Low priority, in display order:
    /// custom section tags, `chatsTag` and `directMessagesTag`.
    let orderedTags: [String]
    /// The names of the custom sections, by tag.
    let customSectionNames: [String: String]
    /// The custom section tags of each room, by room ID.
    var roomTags: [String: Set<String>] = [:]
    /// The rooms whose tags couldn't be read this time, so their sections aren't known.
    var unreadableRoomIDs: Set<String> = []
    
    init(orderedTags: [String], customSectionNames: [String: String], roomTags: [String: Set<String>] = [:]) {
        self.orderedTags = orderedTags
        self.customSectionNames = customSectionNames
        self.roomTags = roomTags
    }
    
    /// Reads the sections from the content of the `im.vector.web.settings` account data, like Element Web does.
    init(settingsJSON: String) {
        let settings = (try? JSONSerialization.jsonObject(with: Data(settingsJSON.utf8))) as? [String: Any] ?? [:]
        let sectionData = settings["RoomList.CustomSectionData"] as? [String: Any] ?? [:]
        
        var names = [String: String]()
        for (tag, value) in sectionData {
            guard tag.hasPrefix(Self.customTagPrefix),
                  let section = value as? [String: Any],
                  section["tag"] as? String == tag,
                  let name = section["name"] as? String else {
                continue
            }
            names[tag] = name
        }
        
        let storedOrder = settings["RoomList.OrderedCustomSections"] as? [String] ?? []
        var orderedTags = storedOrder.filter { $0 == Self.chatsTag || $0 == Self.directMessagesTag || names[$0] != nil }
        // Same defaults as Element Web: custom sections above Chats, direct messages above everything.
        if !orderedTags.contains(Self.chatsTag) {
            orderedTags.append(Self.chatsTag)
        }
        if !orderedTags.contains(Self.directMessagesTag) {
            orderedTags.insert(Self.directMessagesTag, at: 0)
        }
        
        self.init(orderedTags: orderedTags, customSectionNames: names)
    }
    
    /// Keeps only the custom section tags from the content of a room's `m.tag` account data.
    static func customTags(fromTagsJSON data: Data) -> Set<String> {
        let content = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let tags = content?["tags"] as? [String: Any] ?? [:]
        return Set(tags.keys.filter { $0.hasPrefix(customTagPrefix) })
    }
}
