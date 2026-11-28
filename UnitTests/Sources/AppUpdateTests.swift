//
// Copyright 2026 Element Creations Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

@testable import ElementX
import Foundation
import Testing

struct AppUpdateDecisionTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let updateURL: URL = "https://testflight.apple.com/join/zMWdSWBu"
    private let day: TimeInterval = 24 * 60 * 60
    
    @Test("Nothing shows without thresholds or without the app's own build")
    func nothingWithoutPolicyOrBuild() {
        let state = AppUpdateState(firstBehindDate: nil, snoozedUntil: nil)
        
        let withoutPolicy = AppUpdateDecision.evaluate(ownBuild: 5, policy: nil, now: now, state: state)
        #expect(withoutPolicy.prompt == .nothing)
        #expect(withoutPolicy.state == state)
        
        let withoutBuild = AppUpdateDecision.evaluate(ownBuild: nil, policy: makePolicy(min: 10, recommended: 10), now: now, state: state)
        #expect(withoutBuild.prompt == .nothing)
        #expect(withoutBuild.state == state)
    }
    
    @Test("Below the minimum build the blocking screen shows, even while the dialog is snoozed")
    func blockingBelowMinimum() {
        let state = AppUpdateState(firstBehindDate: nil, snoozedUntil: now.addingTimeInterval(day))
        
        let result = AppUpdateDecision.evaluate(ownBuild: 5, policy: makePolicy(min: 6, recommended: 8), now: now, state: state)
        
        #expect(result.prompt == .blocking(updateURL: updateURL))
        #expect(result.state.firstBehindDate == now)
    }
    
    @Test("Below the recommended build the dialog shows and the first time behind is noted")
    func dialogBelowRecommended() {
        let result = AppUpdateDecision.evaluate(ownBuild: 7, policy: makePolicy(min: 6, recommended: 8), now: now, state: AppUpdateState())
        
        #expect(result.prompt == .dialog(updateURL: updateURL))
        #expect(result.state.firstBehindDate == now)
        
        let later = AppUpdateDecision.evaluate(ownBuild: 7, policy: makePolicy(min: 6, recommended: 9), now: now.addingTimeInterval(day), state: result.state)
        #expect(later.state.firstBehindDate == now)
    }
    
    @Test("Nothing shows once up to date, and the first time behind is forgotten")
    func nothingWhenUpToDate() {
        let state = AppUpdateState(firstBehindDate: now.addingTimeInterval(-day), snoozedUntil: nil)
        
        let result = AppUpdateDecision.evaluate(ownBuild: 8, policy: makePolicy(min: 6, recommended: 8), now: now, state: state)
        
        #expect(result.prompt == .nothing)
        #expect(result.state.firstBehindDate == nil)
    }
    
    @Test("Thresholds at zero show nothing")
    func nothingAtZero() {
        let result = AppUpdateDecision.evaluate(ownBuild: 1, policy: makePolicy(min: 0, recommended: 0), now: now, state: AppUpdateState())
        
        #expect(result.prompt == .nothing)
        #expect(result.state == AppUpdateState())
    }
    
    @Test("\"Later\" hides the dialog for 3 days")
    func laterHidesForThreeDays() {
        let policy = makePolicy(min: 6, recommended: 8)
        let behind = AppUpdateDecision.evaluate(ownBuild: 7, policy: policy, now: now, state: AppUpdateState()).state
        
        let snoozed = AppUpdateDecision.snooze(now: now, state: behind)
        
        #expect(snoozed.snoozedUntil == now.addingTimeInterval(3 * day))
        #expect(AppUpdateDecision.evaluate(ownBuild: 7, policy: policy, now: now.addingTimeInterval(3 * day - 1), state: snoozed).prompt == .nothing)
        #expect(AppUpdateDecision.evaluate(ownBuild: 7, policy: policy, now: now.addingTimeInterval(3 * day), state: snoozed).prompt == .dialog(updateURL: updateURL))
    }
    
    @Test("\"Later\" hides the dialog for 1 day once the app has been behind for 14 days")
    func laterHidesForOneDayAfterTwoWeeks() {
        let thirteenDays = AppUpdateState(firstBehindDate: now.addingTimeInterval(-13 * day), snoozedUntil: nil)
        #expect(AppUpdateDecision.snooze(now: now, state: thirteenDays).snoozedUntil == now.addingTimeInterval(3 * day))
        
        let fourteenDays = AppUpdateState(firstBehindDate: now.addingTimeInterval(-14 * day), snoozedUntil: nil)
        #expect(AppUpdateDecision.snooze(now: now, state: fourteenDays).snoozedUntil == now.addingTimeInterval(day))
    }
    
    @Test("A new recommended build keeps the dialog snoozed")
    func newRecommendedBuildKeepsSnooze() {
        let behind = AppUpdateDecision.evaluate(ownBuild: 7, policy: makePolicy(min: 6, recommended: 8), now: now, state: AppUpdateState()).state
        let snoozed = AppUpdateDecision.snooze(now: now, state: behind)
        
        let result = AppUpdateDecision.evaluate(ownBuild: 7, policy: makePolicy(min: 6, recommended: 12), now: now.addingTimeInterval(day), state: snoozed)
        
        #expect(result.prompt == .nothing)
        #expect(result.state.snoozedUntil == snoozed.snoozedUntil)
    }
    
    // MARK: - Helpers
    
    private func makePolicy(min: Int, recommended: Int) -> AppUpdatePolicy {
        AppUpdatePolicy(minBuild: min, recommendedBuild: recommended, updateURL: updateURL)
    }
}

struct AppUpdatePolicyTests {
    @Test("A valid file gives the iOS thresholds")
    func validFile() throws {
        let file = #"{"v":1,"ios":{"min_build":3,"recommended_build":5,"update_url":"https://testflight.apple.com/join/zMWdSWBu"},"android":{"min_build":0}}"#
        
        let policy = try #require(AppUpdatePolicy(fileData: Data(file.utf8)))
        
        #expect(policy == AppUpdatePolicy(minBuild: 3, recommendedBuild: 5, updateURL: "https://testflight.apple.com/join/zMWdSWBu"))
    }
    
    @Test("Anything but version 1 with non-negative integer builds and an https link is ignored",
          arguments: [#"{"v":2,"ios":{"min_build":1,"recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":"1","ios":{"min_build":1,"recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"ios":{"min_build":1,"recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":1}"#,
                      #"{"v":1,"android":{"min_build":1,"recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":1,"ios":{"min_build":-1,"recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":1,"ios":{"min_build":1,"recommended_build":-2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":1,"ios":{"min_build":1.5,"recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":1,"ios":{"min_build":"1","recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":1,"ios":{"recommended_build":2,"update_url":"https://example.com/app"}}"#,
                      #"{"v":1,"ios":{"min_build":1,"recommended_build":2}}"#,
                      #"{"v":1,"ios":{"min_build":1,"recommended_build":2,"update_url":"http://example.com/app"}}"#,
                      #"{"v":1,"ios":{"min_build":1,"recommended_build":2,"update_url":"itms-beta://example.com/app"}}"#,
                      #"{"v":1,"ios":{"min_build":1,"recommended_build":2,"update_url":"https://"}}"#,
                      #"<html>Not found</html>"#,
                      ""])
    func invalidFile(_ file: String) {
        #expect(AppUpdatePolicy(fileData: Data(file.utf8)) == nil)
    }
}

struct AppUpdateServiceTests {
    private let store = VolatileUserDefaults()
    private let frontDoor = FrontDoorStub()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let hour: TimeInterval = 60 * 60
    private let updateURL: URL = "https://testflight.apple.com/join/zMWdSWBu"
    
    @Test("The update file is read from the front door with an 8 second timeout")
    func request() async throws {
        await makeService(ownBuild: 7).refreshIfDue(now: now)
        
        let request = try #require(frontDoor.requests.first)
        #expect(request.url?.absoluteString == "https://login.leveragers.com/app/agents.json")
        #expect(request.timeoutInterval == 8)
    }
    
    @Test("The last good file is kept: a blocked app stays blocked at its next launch, offline")
    func lastGoodCopyKept() async {
        frontDoor.body = file(min: 6, recommended: 8)
        let service = makeService(ownBuild: 5)
        await service.refreshIfDue(now: now)
        #expect(service.prompt(now: now) == .blocking(updateURL: updateURL))
        
        frontDoor.isOffline = true
        let nextLaunch = makeService(ownBuild: 5)
        await nextLaunch.refreshIfDue(now: now.addingTimeInterval(2 * hour))
        #expect(nextLaunch.prompt(now: now.addingTimeInterval(2 * hour)) == .blocking(updateURL: updateURL))
    }
    
    @Test("A missing, unreadable or unreachable file changes nothing")
    func failuresChangeNothing() async {
        frontDoor.body = file(min: 6, recommended: 8)
        let service = makeService(ownBuild: 5)
        await service.refreshIfDue(now: now)
        let policy = service.policy
        #expect(policy != nil)
        
        frontDoor.statusCode = 404
        await service.refreshIfDue(now: now.addingTimeInterval(hour))
        #expect(service.policy == policy)
        
        frontDoor.statusCode = 200
        frontDoor.body = #"{"v":1,"ios":{"min_build":0,"recommended_build":0,"update_url":"http://example.com"}}"#
        await service.refreshIfDue(now: now.addingTimeInterval(2 * hour))
        #expect(service.policy == policy)
        
        frontDoor.isOffline = true
        await service.refreshIfDue(now: now.addingTimeInterval(3 * hour))
        #expect(service.policy == policy)
        #expect(frontDoor.requests.count == 4)
    }
    
    @Test("A new valid file replaces the last one")
    func newFileReplacesLastOne() async {
        frontDoor.body = file(min: 6, recommended: 8)
        let service = makeService(ownBuild: 5)
        await service.refreshIfDue(now: now)
        #expect(service.prompt(now: now) == .blocking(updateURL: updateURL))
        
        frontDoor.body = file(min: 0, recommended: 0)
        await service.refreshIfDue(now: now.addingTimeInterval(hour))
        #expect(service.prompt(now: now.addingTimeInterval(hour)) == .nothing)
    }
    
    @Test("A fresh install that can't read the file shows nothing")
    func freshInstallOffline() async {
        frontDoor.isOffline = true
        let service = makeService(ownBuild: 5)
        
        await service.refreshIfDue(now: now)
        
        #expect(service.policy == nil)
        #expect(service.prompt(now: now) == .nothing)
    }
    
    @Test("The file is fetched at most once an hour, even across launches")
    func fetchedOnceAnHour() async {
        await makeService(ownBuild: 7).refreshIfDue(now: now)
        await makeService(ownBuild: 7).refreshIfDue(now: now.addingTimeInterval(hour - 1))
        #expect(frontDoor.requests.count == 1)
        
        await makeService(ownBuild: 7).refreshIfDue(now: now.addingTimeInterval(hour))
        #expect(frontDoor.requests.count == 2)
    }
    
    @Test("Nothing shows when the app's own build can't be read")
    func unreadableOwnBuild() async {
        frontDoor.body = file(min: 6, recommended: 8)
        let service = makeService(ownBuild: nil)
        
        await service.refreshIfDue(now: now)
        
        #expect(service.prompt(now: now) == .nothing)
    }
    
    @Test("The dialog shows once per launch and \"Later\" is remembered across launches")
    func dialogOncePerLaunch() async {
        frontDoor.body = file(min: 6, recommended: 8)
        let service = makeService(ownBuild: 7)
        await service.refreshIfDue(now: now)
        
        #expect(service.prompt(now: now) == .dialog(updateURL: updateURL))
        #expect(service.prompt(now: now) == .nothing)
        
        let nextLaunch = makeService(ownBuild: 7)
        #expect(nextLaunch.prompt(now: now.addingTimeInterval(hour)) == .dialog(updateURL: updateURL))
        nextLaunch.snooze(now: now.addingTimeInterval(hour))
        
        let snoozedLaunch = makeService(ownBuild: 7)
        #expect(snoozedLaunch.prompt(now: now.addingTimeInterval(2 * hour)) == .nothing)
        
        let launchAfterSnooze = makeService(ownBuild: 7)
        #expect(launchAfterSnooze.prompt(now: now.addingTimeInterval(hour + 3 * 24 * hour)) == .dialog(updateURL: updateURL))
    }
    
    @Test("The first time behind is remembered across launches")
    func firstBehindDateRemembered() async {
        frontDoor.body = file(min: 6, recommended: 8)
        let service = makeService(ownBuild: 7)
        await service.refreshIfDue(now: now)
        _ = service.prompt(now: now)
        
        let twoWeeksLater = now.addingTimeInterval(14 * 24 * hour)
        let nextLaunch = makeService(ownBuild: 7)
        #expect(nextLaunch.prompt(now: twoWeeksLater) == .dialog(updateURL: updateURL))
        nextLaunch.snooze(now: twoWeeksLater)
        
        #expect(makeService(ownBuild: 7).prompt(now: twoWeeksLater.addingTimeInterval(23 * hour)) == .nothing)
        #expect(makeService(ownBuild: 7).prompt(now: twoWeeksLater.addingTimeInterval(24 * hour)) == .dialog(updateURL: updateURL))
    }
    
    @Test("The texts exist in English and French")
    func texts() throws {
        for language in ["en", "fr"] {
            let bundle = try #require(Bundle.lprojBundle(for: language))
            for key in AppUpdateStrings.keys {
                #expect(bundle.localizedString(forKey: key, value: nil, table: AppUpdateStrings.table) != key, "\(language): \(key)")
            }
        }
        
        let french = try #require(Bundle.lprojBundle(for: "fr"))
        #expect(french.localizedString(forKey: "app_update_required_title", value: nil, table: AppUpdateStrings.table) == "Mise à jour requise")
    }
    
    // MARK: - Helpers
    
    private func makeService(ownBuild: Int?) -> AppUpdateService {
        AppUpdateService(frontDoorURL: "https://login.leveragers.com", ownBuild: ownBuild, store: store) { [frontDoor] request in
            try await frontDoor.fetch(request)
        }
    }
    
    private func file(min: Int, recommended: Int) -> String {
        #"{"v":1,"ios":{"min_build":\#(min),"recommended_build":\#(recommended),"update_url":"https://testflight.apple.com/join/zMWdSWBu"}}"#
    }
}

/// Answers the requests of the update check like the front door would.
private final class FrontDoorStub {
    var body = ""
    var statusCode = 200
    var isOffline = false
    private(set) var requests: [URLRequest] = []
    
    func fetch(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        
        if isOffline {
            throw URLError(.notConnectedToInternet)
        }
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
            throw URLError(.badURL)
        }
        return (Data(body.utf8), response)
    }
}
