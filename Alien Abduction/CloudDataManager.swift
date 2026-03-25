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

    static let allCreatureKeys: [String] = [
        "catches_whale", "catches_elk", "catches_cow", "catches_cat",
        "catches_hiker", "catches_workerHuman",
        "catches_bigfoot", "catches_werewolf", "catches_kraken"
    ]

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
        mergeFromCloud()
    }

    // MARK: - Merge (take the max for scores/counts, latest for booleans)

    private func mergeFromCloud() {
        // High score — keep the higher value
        let cloudScore = Int(cloud.longLong(forKey: CloudDataManager.highScoreKey))
        let localScore = local.integer(forKey: CloudDataManager.highScoreKey)
        let best = max(cloudScore, localScore)
        local.set(best, forKey: CloudDataManager.highScoreKey)
        cloud.set(Int64(best), forKey: CloudDataManager.highScoreKey)

        // Creature catches — keep the higher count
        for key in CloudDataManager.allCreatureKeys {
            let cloudVal = Int(cloud.longLong(forKey: key))
            let localVal = local.integer(forKey: key)
            let merged = max(cloudVal, localVal)
            local.set(merged, forKey: key)
            cloud.set(Int64(merged), forKey: key)
        }

        // Audio settings — cloud wins if it has a value
        for key in [CloudDataManager.musicOffKey, CloudDataManager.soundOffKey] {
            if cloud.object(forKey: key) != nil {
                local.set(cloud.bool(forKey: key), forKey: key)
            } else {
                cloud.set(local.bool(forKey: key), forKey: key)
            }
        }
    }

    @objc private func iCloudDidChange(_ notification: Notification) {
        mergeFromCloud()
    }

    // MARK: - Public Accessors

    func integer(forKey key: String) -> Int {
        return local.integer(forKey: key)
    }

    func bool(forKey key: String) -> Bool {
        return local.bool(forKey: key)
    }

    func set(_ value: Int, forKey key: String) {
        local.set(value, forKey: key)
        cloud.set(Int64(value), forKey: key)
        cloud.synchronize()
    }

    func set(_ value: Bool, forKey key: String) {
        local.set(value, forKey: key)
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
                    // Submit any existing high score
                    let best = self.highScore
                    if best > 0 {
                        self.submitScoreToGameCenter(best)
                    }
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
