//
//  CloudDataManager.swift
//  Alien Abduction
//
//  Syncs game data (high scores, catch counts, settings) across devices
//  using iCloud Key-Value Store (NSUbiquitousKeyValueStore) tied to Apple ID.
//

import Foundation
import GameKit

final class CloudDataManager {

    static let shared = CloudDataManager()

    // MARK: - Keys

    static let highScoreKey = "AlienAbductionHighScore"
    static let musicOffKey = "AlienAbductionMusicOff"
    static let soundOffKey = "AlienAbductionSoundOff"
    static let hasShownFirstPlayControlsKey = "AlienAbductionHasShownFirstPlayControls"

    static let allCreatureKeys: [String] = [
        "catches_whale", "catches_elk", "catches_cow", "catches_cat",
        "catches_hikerHuman", "catches_workerHuman",
        "catches_bigfoot", "catches_werewolf", "catches_kraken"
    ]
    static let legacyHikerCatchKey = "catches_hiker"

    // Game Center leaderboard ID — set this in App Store Connect
    static let leaderboardID = "com.alienabduction.highscore"

    // Game Center achievement IDs
    static let scoreAchievements: [(score: Int, id: String)] = [
        (200,   "com.alienabduction.score200"),
        (500,   "com.alienabduction.score500"),
        (1000,  "com.alienabduction.score1000"),
        (5000,  "com.alienabduction.score5000"),
        (3500,  "com.alienabduction.score3500")
    ]

    // Normal creatures — achievement for catching 10 of each
    static let normalCatchAchievements: [(creature: String, id: String)] = [
        ("whale",       "com.alienabduction.catch10whales"),
        ("elk",         "com.alienabduction.catch10elk"),
        ("cow",         "com.alienabduction.catch10cows"),
        ("cat",         "com.alienabduction.catch10cats"),
        ("hikerHuman",  "com.alienabduction.catch10hikers"),
        ("workerHuman", "com.alienabduction.catch10workers")
    ]

    // Legendary creatures — achievement for catching 2 of each
    static let legendaryCatchAchievements: [(creature: String, id: String)] = [
        ("bigfoot",  "com.alienabduction.catch2bigfoot"),
        ("werewolf", "com.alienabduction.catch2werewolf"),
        ("kraken",   "com.alienabduction.catch2kraken")
    ]

    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    private var isInitialCloudMergePending = true
    private var pendingInitialCloudMerge: DispatchWorkItem?

    // MARK: - Init

    private init() {
        // Listen for iCloud changes pushed from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        // Kick off initial sync
        cloud.synchronize()
        // Import anything already cached, but do not upload missing values until
        // iCloud confirms its initial download. This prevents a fresh install
        // from replacing remote stats with local default zeroes.
        mergeFromCloud(uploadLocalValuesMissingFromCloud: false)
        scheduleMergeAfterInitialCloudDownload()
    }

    // MARK: - Merge

    /// Stats only move upward, so the higher value always wins. Returning nil
    /// when neither store has a value is important: zero must not be invented
    /// and uploaded during a fresh install's initial iCloud sync.
    static func mergedMonotonicValue(localValue: Int?, cloudValue: Int?) -> Int? {
        switch (localValue, cloudValue) {
        case let (localValue?, cloudValue?):
            return max(localValue, cloudValue)
        case let (localValue?, nil):
            return localValue
        case let (nil, cloudValue?):
            return cloudValue
        case (nil, nil):
            return nil
        }
    }

    private func localIntegerIfPresent(forKey key: String) -> Int? {
        guard local.object(forKey: key) != nil else { return nil }
        return local.integer(forKey: key)
    }

    private func cloudIntegerIfPresent(forKey key: String) -> Int? {
        guard cloud.object(forKey: key) != nil else { return nil }
        return Int(cloud.longLong(forKey: key))
    }

    @discardableResult
    private func mergeMonotonicValue(
        forKey key: String,
        uploadLocalValueMissingFromCloud: Bool,
        additionalLocalValues: [Int] = [],
        additionalCloudValues: [Int] = []
    ) -> Bool {
        let localValue = ([localIntegerIfPresent(forKey: key)] + additionalLocalValues)
            .compactMap { $0 }
            .max()
        let cloudValue = ([cloudIntegerIfPresent(forKey: key)] + additionalCloudValues)
            .compactMap { $0 }
            .max()

        guard let merged = CloudDataManager.mergedMonotonicValue(
            localValue: localValue,
            cloudValue: cloudValue
        ) else {
            return false
        }

        if localIntegerIfPresent(forKey: key) != merged {
            local.set(merged, forKey: key)
        }

        if let currentCloudValue = cloudIntegerIfPresent(forKey: key) {
            guard currentCloudValue != merged else { return false }
            cloud.set(Int64(merged), forKey: key)
            return true
        }

        guard uploadLocalValueMissingFromCloud, localValue != nil else {
            return false
        }
        cloud.set(Int64(merged), forKey: key)
        return true
    }

    private func mergeFromCloud(uploadLocalValuesMissingFromCloud: Bool) {
        var changedCloud = mergeMonotonicValue(
            forKey: CloudDataManager.highScoreKey,
            uploadLocalValueMissingFromCloud: uploadLocalValuesMissingFromCloud
        )

        // Creature catches — keep the higher count
        for key in CloudDataManager.allCreatureKeys {
            let isHikerKey = key == "catches_hikerHuman"
            let legacyLocalValue = isHikerKey
                ? localIntegerIfPresent(forKey: CloudDataManager.legacyHikerCatchKey)
                : nil
            let legacyCloudValue = isHikerKey
                ? cloudIntegerIfPresent(forKey: CloudDataManager.legacyHikerCatchKey)
                : nil
            changedCloud = mergeMonotonicValue(
                forKey: key,
                uploadLocalValueMissingFromCloud: uploadLocalValuesMissingFromCloud,
                additionalLocalValues: [legacyLocalValue].compactMap { $0 },
                additionalCloudValues: [legacyCloudValue].compactMap { $0 }
            ) || changedCloud
        }

        // Audio settings — cloud wins if it has a value
        for key in [CloudDataManager.musicOffKey, CloudDataManager.soundOffKey] {
            if cloud.object(forKey: key) != nil {
                local.set(cloud.bool(forKey: key), forKey: key)
            } else if uploadLocalValuesMissingFromCloud, local.object(forKey: key) != nil {
                cloud.set(local.bool(forKey: key), forKey: key)
                changedCloud = true
            }
        }

        // The first-play controls flag is monotonic: once it is true on any
        // device, it should stay true everywhere.
        let controlsKey = CloudDataManager.hasShownFirstPlayControlsKey
        let localHasControlsValue = local.object(forKey: controlsKey) != nil
        let cloudHasControlsValue = cloud.object(forKey: controlsKey) != nil
        if localHasControlsValue || cloudHasControlsValue {
            let hasShownFirstPlayControls = (localHasControlsValue && local.bool(forKey: controlsKey))
                || (cloudHasControlsValue && cloud.bool(forKey: controlsKey))
            local.set(hasShownFirstPlayControls, forKey: controlsKey)
            if cloudHasControlsValue {
                if cloud.bool(forKey: controlsKey) != hasShownFirstPlayControls {
                    cloud.set(hasShownFirstPlayControls, forKey: controlsKey)
                    changedCloud = true
                }
            } else if uploadLocalValuesMissingFromCloud {
                cloud.set(hasShownFirstPlayControls, forKey: controlsKey)
                changedCloud = true
            }
        }

        if changedCloud {
            cloud.synchronize()
        }
    }

    @objc private func iCloudDidChange(_ notification: Notification) {
        let reason = (notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber)?
            .intValue

        if reason == NSUbiquitousKeyValueStoreInitialSyncChange
            || reason == NSUbiquitousKeyValueStoreAccountChange {
            // Apple recommends delaying writes while the initial download is
            // in progress. Import the values received so far and restart the
            // short quiet period before uploading the merged local snapshot.
            isInitialCloudMergePending = true
            mergeFromCloud(uploadLocalValuesMissingFromCloud: false)
            scheduleMergeAfterInitialCloudDownload()
        } else if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            mergeFromCloud(uploadLocalValuesMissingFromCloud: false)
        } else {
            mergeFromCloud(uploadLocalValuesMissingFromCloud: !isInitialCloudMergePending)
        }
    }

    private func scheduleMergeAfterInitialCloudDownload() {
        pendingInitialCloudMerge?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.isInitialCloudMergePending = false
            self.mergeFromCloud(uploadLocalValuesMissingFromCloud: true)
        }
        pendingInitialCloudMerge = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    // MARK: - Public Accessors

    func integer(forKey key: String) -> Int {
        return local.integer(forKey: key)
    }

    func bool(forKey key: String) -> Bool {
        return local.bool(forKey: key)
    }

    func set(_ value: Int, forKey key: String) {
        let currentLocalValue = localIntegerIfPresent(forKey: key)
        let currentCloudValue = cloudIntegerIfPresent(forKey: key)
        let merged = CloudDataManager.mergedMonotonicValue(
            localValue: max(value, currentLocalValue ?? value),
            cloudValue: currentCloudValue
        ) ?? value
        local.set(merged, forKey: key)
        guard !isInitialCloudMergePending else { return }
        cloud.set(Int64(merged), forKey: key)
        cloud.synchronize()
    }

    func set(_ value: Bool, forKey key: String) {
        local.set(value, forKey: key)
        guard !isInitialCloudMergePending else { return }
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }

    // MARK: - High Score (convenience)

    var highScore: Int {
        get { integer(forKey: CloudDataManager.highScoreKey) }
        set {
            let current = highScore
            if newValue > current {
                set(newValue, forKey: CloudDataManager.highScoreKey)
                submitScoreToGameCenter(newValue)
            }
        }
    }

    var hasShownFirstPlayControls: Bool {
        get { bool(forKey: CloudDataManager.hasShownFirstPlayControlsKey) }
        set { set(newValue, forKey: CloudDataManager.hasShownFirstPlayControlsKey) }
    }

    // MARK: - Creature Catches (convenience)

    func catchCount(for creatureType: String) -> Int {
        return integer(forKey: "catches_\(creatureType)")
    }

    func incrementCatch(for creatureType: String) {
        let key = "catches_\(creatureType)"
        let current = integer(forKey: key)
        if current < 1_000_000 {
            set(current + 1, forKey: key)
        }
    }

    // MARK: - Game Center

    func authenticateGameCenter(from viewController: UIViewController) {
        GKLocalPlayer.local.authenticateHandler = { [weak viewController] gcAuthVC, error in
            DispatchQueue.main.async {
                if let gcAuthVC = gcAuthVC, let vc = viewController {
                    vc.present(gcAuthVC, animated: true)
                } else if GKLocalPlayer.local.isAuthenticated {
                    print("Game Center authenticated: \(GKLocalPlayer.local.displayName)")
                    self.restoreHighScoreFromGameCenter()
                } else if let error = error {
                    print("Game Center auth failed: \(error.localizedDescription)")
                }
            }
        }
    }

    var isGameCenterAuthenticated: Bool {
        return GKLocalPlayer.local.isAuthenticated
    }

    func submitScoreToGameCenter(_ score: Int) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(
            score,
            context: 0,
            player: GKLocalPlayer.local,
            leaderboardIDs: [CloudDataManager.leaderboardID]
        ) { error in
            if let error = error {
                print("Failed to submit score: \(error.localizedDescription)")
            }
        }
    }

    private func restoreHighScoreFromGameCenter() {
        GKLeaderboard.loadLeaderboards(IDs: [CloudDataManager.leaderboardID]) { leaderboards, error in
            if let error = error {
                print("Failed to load leaderboard: \(error.localizedDescription)")
                self.submitExistingHighScoreToGameCenter()
                return
            }

            guard let leaderboard = leaderboards?.first else {
                self.submitExistingHighScoreToGameCenter()
                return
            }

            leaderboard.loadEntries(
                for: [GKLocalPlayer.local],
                timeScope: .allTime
            ) { localPlayerEntry, _, error in
                if let error = error {
                    print("Failed to restore Game Center score: \(error.localizedDescription)")
                }

                let gameCenterScore = localPlayerEntry.map { Int($0.score) } ?? 0
                let restoredScore = max(self.highScore, gameCenterScore)
                if restoredScore > self.highScore {
                    self.set(restoredScore, forKey: CloudDataManager.highScoreKey)
                }
                if restoredScore > gameCenterScore {
                    self.submitScoreToGameCenter(restoredScore)
                }
            }
        }
    }

    private func submitExistingHighScoreToGameCenter() {
        let best = highScore
        if best > 0 {
            submitScoreToGameCenter(best)
        }
    }

    // MARK: - Achievements

    private func reportAchievement(id: String, percentComplete: Double = 100.0) {
        guard GKLocalPlayer.local.isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("Achievement report failed: \(error.localizedDescription)")
            }
        }
    }

    /// Call this whenever the score changes during gameplay
    func checkScoreAchievements(currentScore: Int) {
        for entry in CloudDataManager.scoreAchievements {
            if currentScore >= entry.score {
                reportAchievement(id: entry.id)
            }
        }
    }

    /// Call this after incrementing a creature's catch count
    func checkCatchAchievements(for creatureType: String) {
        let count = catchCount(for: creatureType)

        // Normal creatures — 10 catches
        for entry in CloudDataManager.normalCatchAchievements {
            if entry.creature == creatureType {
                let percent = min(Double(count) / 10.0 * 100.0, 100.0)
                reportAchievement(id: entry.id, percentComplete: percent)
                return
            }
        }

        // Legendary creatures — 2 catches
        for entry in CloudDataManager.legendaryCatchAchievements {
            if entry.creature == creatureType {
                let percent = min(Double(count) / 2.0 * 100.0, 100.0)
                reportAchievement(id: entry.id, percentComplete: percent)
                return
            }
        }
    }
}
