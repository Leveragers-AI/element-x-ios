//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// The update thresholds of the iOS app, published by Leveragers on the front door (`app/agents.json`).
///
/// The file reads `{"v":1,"ios":{"min_build":N,"recommended_build":N,"update_url":"https://…"},"android":{…}}`
/// and its builds are compared with the app's own `CFBundleVersion`.
nonisolated struct AppUpdatePolicy: Equatable, Sendable {
    /// Below this build the app is blocked until it is updated.
    let minBuild: Int
    /// Below this build the app offers the update in a dialog.
    let recommendedBuild: Int
    /// Where the update is installed from (TestFlight or the App Store).
    let updateURL: URL
}

nonisolated extension AppUpdatePolicy {
    /// The iOS thresholds of an update file, `nil` unless the file is version 1 with non-negative builds and an https link.
    init?(fileData: Data) {
        guard let file = try? JSONDecoder().decode(UpdateFile.self, from: fileData),
              file.version == 1,
              let ios = file.ios,
              ios.minBuild >= 0,
              ios.recommendedBuild >= 0,
              let updateURL = URL(string: ios.updateURL),
              updateURL.scheme?.lowercased() == "https",
              updateURL.host()?.isEmpty == false else {
            return nil
        }
        
        self.init(minBuild: ios.minBuild, recommendedBuild: ios.recommendedBuild, updateURL: updateURL)
    }
}

/// The JSON of the front door's update file.
private nonisolated struct UpdateFile: Decodable {
    nonisolated struct Platform: Decodable {
        let minBuild: Int
        let recommendedBuild: Int
        let updateURL: String
        
        enum CodingKeys: String, CodingKey {
            case minBuild = "min_build"
            case recommendedBuild = "recommended_build"
            case updateURL = "update_url"
        }
    }
    
    let version: Int
    let ios: Platform?
    
    enum CodingKeys: String, CodingKey {
        case version = "v"
        case ios
    }
}
