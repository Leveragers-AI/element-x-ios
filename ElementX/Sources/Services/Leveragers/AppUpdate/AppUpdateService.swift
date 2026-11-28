//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

/// Reads the update thresholds from the front door, keeps the last good copy on the device and decides what to show.
///
/// A missing or unreadable file, a network error or an unreadable own build change nothing: the last good copy
/// stays (so a blocked app stays blocked offline) and a fresh install that never read a file shows nothing.
final class AppUpdateService {
    /// The file is fetched at launch and when the app comes back to the foreground, at most this often.
    static let fetchInterval: TimeInterval = 60 * 60
    static let fetchTimeout: TimeInterval = 8
    
    private let fileURL: URL
    private let ownBuild: Int?
    private let store: UserDefaultsProtocol
    private let fetch: (URLRequest) async throws -> (Data, URLResponse)
    /// The dialog shows at most once per launch.
    private var hasShownDialog = false
    
    /// The thresholds of the last good update file, if any.
    var policy: AppUpdatePolicy? {
        store.data(forKey: Key.file).flatMap(AppUpdatePolicy.init(fileData:))
    }
    
    private var state: AppUpdateState {
        get { store[Key.state] ?? AppUpdateState() }
        set { store[Key.state] = newValue }
    }
    
    /// - Parameters:
    ///   - frontDoorURL: The front door, whose `app/agents.json` holds the thresholds.
    ///   - ownBuild: The app's build number (`CFBundleVersion`), `nil` when it can't be read.
    ///   - store: Where the last good file and the state are kept between launches.
    ///   - fetch: Loads a request, `URLSession.shared` by default.
    init(frontDoorURL: URL,
         ownBuild: Int?,
         store: UserDefaultsProtocol,
         fetch: @escaping (URLRequest) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(for: $0) }) {
        fileURL = frontDoorURL.appending(path: "app/agents.json")
        self.ownBuild = ownBuild
        self.store = store
        self.fetch = fetch
    }
    
    /// Fetches the update file unless it was fetched less than an hour ago, and keeps it only when it is valid.
    func refreshIfDue(now: Date = .now) async {
        if let lastFetchDate = store.object(forKey: Key.lastFetchDate) as? Date,
           now >= lastFetchDate,
           now.timeIntervalSince(lastFetchDate) < Self.fetchInterval {
            return
        }
        store.set(now, forKey: Key.lastFetchDate)
        
        let request = URLRequest(url: fileURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: Self.fetchTimeout)
        do {
            let (data, response) = try await fetch(request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard statusCode == 200 else {
                MXLog.info("No update file (status \(statusCode)), the last good copy stays.")
                return
            }
            guard AppUpdatePolicy(fileData: data) != nil else {
                MXLog.error("Unreadable update file, the last good copy stays.")
                return
            }
            store.set(data, forKey: Key.file)
        } catch {
            MXLog.info("Fetching the update file failed, the last good copy stays: \(error)")
        }
    }
    
    /// What to show now. The dialog comes once per launch: afterwards it is `.nothing` until the next launch.
    func prompt(now: Date = .now) -> AppUpdatePrompt {
        let (prompt, newState) = AppUpdateDecision.evaluate(ownBuild: ownBuild, policy: policy, now: now, state: state)
        if newState != state {
            state = newState
        }
        
        if case .dialog = prompt {
            guard !hasShownDialog else { return .nothing }
            hasShownDialog = true
        }
        return prompt
    }
    
    /// "Later": hides the dialog for 3 days, or for 1 day once the app has been behind for 14 days.
    func snooze(now: Date = .now) {
        state = AppUpdateDecision.snooze(now: now, state: state)
    }
    
    private enum Key {
        static let file = "leveragersAppUpdateFile"
        static let state = "leveragersAppUpdateState"
        static let lastFetchDate = "leveragersAppUpdateLastFetchDate"
    }
}
