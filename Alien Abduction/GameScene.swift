//
//  GameScene.swift
//  Alien Abduction
//
//  Created by Amrit Banga on 3/19/26.
//

import SpriteKit
import GameplayKit
import GameKit
import AVFoundation

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none:    UInt32 = 0
    static let saucer:  UInt32 = 0b1
    static let obstacle: UInt32 = 0b10
    static let ground:  UInt32 = 0b100
}

// MARK: - Game States
enum GameState {
    case menu
    case playing
    case paused
    case gameOver
}

// MARK: - Game Phases (environments)
enum GamePhase: CaseIterable {
    case ocean
    case grassland
    case city
}

// MARK: - Data Manager
private let dataManager = CloudDataManager.shared

class GameScene: SKScene, SKPhysicsContactDelegate, GKGameCenterControllerDelegate {

    // MARK: - Properties

    private var gameState: GameState = .menu
    private var gamePhase: GamePhase = .ocean
    private var lastUpdateTime: TimeInterval = 0

    // Nodes
    private var saucer: SKSpriteNode!
    private var saucerFrames: [SKTexture] = []
    private var startButton: SKShapeNode!
    private var statsButton: SKShapeNode!
    private var statsOverlay: SKSpriteNode?
    private var helpButton: SKShapeNode!
    private var helpOverlay: SKSpriteNode?
    private var titleLabel: SKLabelNode!
    private var gameOverOverlay: SKSpriteNode!
    private var groundNode: SKShapeNode!
    private var groundPhysicsNode: SKShapeNode!

    // HUD
    private var scoreLabel: SKLabelNode!
    private var pauseButton: SKShapeNode!
    private var pauseOverlay: SKSpriteNode?

    // Background layers (static)
    private var moonNode: SKSpriteNode!

    // Track whether real assets are available
    private var hasSkyAsset: Bool { UIImage(named: "sky") != nil }
    private var hasMoonAsset: Bool { UIImage(named: "moon") != nil }
    private var hasSaucerAsset: Bool { UIImage(named: "alienSaucer") != nil }
    private var hasOceanAsset: Bool { UIImage(named: "ocean") != nil }

    // Plane asset names
    private let planeAssetNames = ["plane1", "plane2", "plane3"]

    // Scrolling speeds
    private let baseGroundSpeed: CGFloat = 120.0
    private let basePlaneSpeed: CGFloat = 140.0
    private var speedMultiplier: CGFloat = 1.0

    // Saucer movement
    private var movingUp = false
    private var movingDown = false
    private var tractorBeamActive = false
    private var tractorBeamNode: SKShapeNode?
    private let saucerMoveSpeed: CGFloat = 200.0
    private let saucerTopMargin: CGFloat = 50.0
    private let saucerBottomMargin: CGFloat = 140.0

    // Scrolling ocean sprites (two side by side for seamless loop)
    private var oceanSprite1: SKSpriteNode?
    private var oceanSprite2: SKSpriteNode?

    // Tree spawning (grassland phase)
    private var treeSpawnTimer: TimeInterval = 0
    private var treeSpawnInterval: TimeInterval = 1.2

    // Continuous ground terrain
    private var groundWorldOffset: CGFloat = 0
    private let terrainResolution: CGFloat = 4
    private var elapsedTime: TimeInterval = 0

    // Phase timing
    private let initialOceanDuration: TimeInterval = 60.0      // 1 minute ocean
    private let initialGrasslandDuration: TimeInterval = 120.0 // 2 minutes grassland
    private let initialCityDuration: TimeInterval = 120.0      // 2 minutes city
    private var phaseStartTime: TimeInterval = 0              // when current phase started
    private var currentPhaseDuration: TimeInterval = 0        // how long current phase lasts
    private var initialSequenceComplete = false               // after ocean→grass→city, go random

    // Skyscraper spawning (city phase)
    private var skyscraperSpawnTimer: TimeInterval = 0
    private var skyscraperSpawnInterval: TimeInterval = 1.5

    // Environment transition
    private var transitionWorldX: CGFloat = 0          // world X where new env begins
    private let transitionSandWidth: CGFloat = 150.0   // width of transition strip
    private var isTransitioning = false
    private var transitionFromPhase: GamePhase = .ocean
    // Solid-color overlay that represents the old environment, scrolls off left during transition
    private var transitionOverlay1: SKSpriteNode?
    private var transitionOverlay2: SKSpriteNode?
    private var grasslandOverlayNode: SKShapeNode?

    // Plane spawning
    private var planeSpawnTimer: TimeInterval = 0
    private var planeSpawnInterval: TimeInterval = 2.5

    // Animal spawning
    private var animalSpawnTimer: TimeInterval = 0
    private var animalSpawnInterval: TimeInterval = 4.0

    // Oil rig spawning (ocean only)
    private var oilRigSpawnTimer: TimeInterval = 0
    private var oilRigSpawnInterval: TimeInterval = 8.0

    // Idle saucer tracking — send a targeted plane if saucer stays still for 1 second
    private var saucerIdleTimer: TimeInterval = 0
    private var lastSaucerY: CGFloat = 0
    private let saucerIdleThreshold: TimeInterval = 1.0

    // The absolute max terrain height possible (for plane spawn floor)
    // base(50) + hills(~47) + mountain(100) + difficulty(60) = ~257
    private let maxPossibleTerrainHeight: CGFloat = 280.0

    // Scoring
    private var score: Double = 0

    // Font vertical stretch
    private let fontYScale: CGFloat = 1.4

    // Audio
    private var menuMusicPlayer: AVAudioPlayer?
    private var gameMusicPlayer: AVAudioPlayer?
    private var crossfadeTimer: Timer?
    private let musicFadeDuration: TimeInterval = 3.0
    private let crossfadeLeadTime: TimeInterval = 3.0  // start crossfade this many seconds before track ends
    private var tractorBeamSoundAction: SKAction?

    // Audio preferences (persisted via iCloud)
    private var isMusicOff: Bool {
        get { dataManager.bool(forKey: CloudDataManager.musicOffKey) }
        set { dataManager.set(newValue, forKey: CloudDataManager.musicOffKey) }
    }
    private var isSoundOff: Bool {
        get { dataManager.bool(forKey: CloudDataManager.soundOffKey) }
        set { dataManager.set(newValue, forKey: CloudDataManager.soundOffKey) }
    }

    // World X where land hills actually begin (after a flat stretch)
    private var landHillsStartWorldX: CGFloat = 0

    // MARK: - Audio

    private func setupAudio() {
        // Preload tractor beam sound effect
        tractorBeamSoundAction = SKAction.playSoundFileNamed("tractorBeam.mp3", waitForCompletion: false)

        // Setup menu music player
        if let url = Bundle.main.url(forResource: "home", withExtension: "mp3") {
            menuMusicPlayer = try? AVAudioPlayer(contentsOf: url)
            menuMusicPlayer?.numberOfLoops = 0  // we handle looping manually for crossfade
            menuMusicPlayer?.volume = 1.0
            menuMusicPlayer?.prepareToPlay()
        }

        // Setup game music player
        if let url = Bundle.main.url(forResource: "inGame", withExtension: "mp3") {
            gameMusicPlayer = try? AVAudioPlayer(contentsOf: url)
            gameMusicPlayer?.numberOfLoops = 0
            gameMusicPlayer?.volume = 1.0
            gameMusicPlayer?.prepareToPlay()
        }
    }

    private func playMenuMusic() {
        guard !isMusicOff && !isSoundOff else { return }
        stopCrossfadeTimer()
        gameMusicPlayer?.stop()

        menuMusicPlayer?.currentTime = 0
        menuMusicPlayer?.volume = 1.0
        menuMusicPlayer?.play()
        scheduleCrossfadeLoop(for: menuMusicPlayer)
    }

    private func playGameMusic() {
        guard !isMusicOff && !isSoundOff else { return }
        stopCrossfadeTimer()

        // Fade out menu music, fade in game music
        let fadeOutPlayer = menuMusicPlayer
        gameMusicPlayer?.currentTime = 0
        gameMusicPlayer?.volume = 0.0
        gameMusicPlayer?.play()

        let steps = 30
        let stepDuration = musicFadeDuration / Double(steps)
        for i in 0...steps {
            let t = Float(i) / Float(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                fadeOutPlayer?.volume = 1.0 - t
                self?.gameMusicPlayer?.volume = t
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + musicFadeDuration) {
            fadeOutPlayer?.stop()
        }

        scheduleCrossfadeLoop(for: gameMusicPlayer)
    }

    private func stopGameMusic() {
        stopCrossfadeTimer()
        gameMusicPlayer?.stop()

        // Only start menu music if sound is enabled
        guard !isMusicOff && !isSoundOff else { return }

        menuMusicPlayer?.currentTime = 0
        menuMusicPlayer?.volume = 0.0
        menuMusicPlayer?.play()

        // Fade menu music in
        let steps = 30
        let stepDuration = musicFadeDuration / Double(steps)
        for i in 0...steps {
            let t = Float(i) / Float(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                self?.menuMusicPlayer?.volume = t
            }
        }

        scheduleCrossfadeLoop(for: menuMusicPlayer)
    }

    /// Schedule a crossfade loop: near the end of the track, fade out and restart with fade in
    private func scheduleCrossfadeLoop(for player: AVAudioPlayer?) {
        stopCrossfadeTimer()
        guard !isMusicOff && !isSoundOff else { return }
        guard let player = player, player.duration > crossfadeLeadTime * 2 else {
            // Track too short for crossfade, just loop normally
            player?.numberOfLoops = -1
            return
        }

        let checkInterval: TimeInterval = 0.5
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self, weak player] timer in
            guard let self = self, let player = player, player.isPlaying else { return }
            let remaining = player.duration - player.currentTime
            if remaining <= self.crossfadeLeadTime {
                timer.invalidate()
                self.crossfadeRestart(player: player)
            }
        }
    }

    private func crossfadeRestart(player: AVAudioPlayer) {
        guard !isMusicOff && !isSoundOff else { return }
        let steps = 30
        let stepDuration = crossfadeLeadTime / Double(steps)

        // Remember original volume
        let targetVolume = player.volume

        // Start a second playback from the beginning by resetting after fade
        for i in 0...steps {
            let t = Float(i) / Float(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                player?.volume = targetVolume * (1.0 - t)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeLeadTime) { [weak self, weak player] in
            guard let self = self, let player = player else { return }
            player.currentTime = 0
            player.volume = 0.0
            player.play()

            // Fade back in
            for i in 0...steps {
                let t = Float(i) / Float(steps)
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                    player?.volume = targetVolume * t
                }
            }

            // Schedule next crossfade
            self.scheduleCrossfadeLoop(for: player)
        }
    }

    private func stopCrossfadeTimer() {
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
    }

    private func pauseMusic() {
        gameMusicPlayer?.pause()
        stopCrossfadeTimer()
    }

    private func resumeMusic() {
        guard !isMusicOff && !isSoundOff else { return }
        gameMusicPlayer?.play()
        scheduleCrossfadeLoop(for: gameMusicPlayer)
    }

    private func playTractorBeamSound() {
        guard !isSoundOff else { return }
        if let action = tractorBeamSoundAction {
            run(action)
        }
    }

    private let creatureSoundMap: [String: String] = [
        "whale": "whaleScream.mp3",
        "elk": "elkBugle.mp3",
        "cow": "cowScream.mp3",
        "cat": "catMeow.mp3",
        "hikerHuman": "humanScream.mp3",
        "workerHuman": "humanScream.mp3",
        "bigfoot": "bigfootGrowl.mp3",
        "werewolf": "werewolfHowl.mp3",
        "kraken": "krakenScream.mp3"
    ]

    private func playCreatureSound(for creatureType: String) {
        guard !isSoundOff else { return }
        guard let soundFile = creatureSoundMap[creatureType] else { return }
        run(SKAction.playSoundFileNamed(soundFile, waitForCompletion: false))
    }

    // MARK: - Terrain Height Function

    private func terrainHeight(at worldX: CGFloat) -> CGFloat {
        let flatHeight: CGFloat = 50.0

        // During transition FROM grassland, keep computing hills for the old side
        if isTransitioning && transitionFromPhase == .grassland {
            if worldX < transitionWorldX {
                // Still on the grassland side — compute hills normally
                return grasslandHeight(at: worldX)
            } else {
                return flatHeight
            }
        }

        // During transition TO grassland (or between non-grassland phases), flat
        if isTransitioning {
            return flatHeight
        }

        // Ocean and city phases are flat
        if gamePhase == .ocean || gamePhase == .city {
            return flatHeight
        }

        // Flat land stretch before hills begin (grassland)
        if gamePhase == .grassland && worldX < landHillsStartWorldX {
            return flatHeight
        }

        // Grassland terrain with rolling hills
        if gamePhase == .grassland {
            return grasslandHeight(at: worldX)
        }

        return flatHeight
    }

    /// Computes grassland terrain height at a given world X position
    private func grasslandHeight(at worldX: CGFloat) -> CGFloat {
        let flatHeight: CGFloat = 50.0

        if worldX < landHillsStartWorldX {
            return flatHeight
        }

        let rampDistance: CGFloat = 500.0
        let hillBlend = min(1.0, (worldX - landHillsStartWorldX) / rampDistance)

        let baseHeight: CGFloat = 50.0
        let hill1 = sin(worldX * 0.003) * 20.0
        let hill2 = sin(worldX * 0.007 + 1.5) * 12.0
        let hill3 = sin(worldX * 0.0015) * 15.0

        let mountainCycle = worldX.truncatingRemainder(dividingBy: 1200.0)
        var mountainBump: CGFloat = 0
        if mountainCycle > 800 && mountainCycle < 1200 {
            let t = (mountainCycle - 800.0) / 400.0
            mountainBump = sin(t * .pi) * 100.0
        }

        let difficultyRise = min(CGFloat(elapsedTime) * 0.08, 60.0)

        let hills = hill1 + hill2 + hill3 + mountainBump + difficultyRise
        let total = baseHeight + hills * hillBlend
        return max(total, 20.0)
    }

    /// Returns the max ground height currently visible on screen.
    private func currentMaxGroundHeight() -> CGFloat {
        var maxH: CGFloat = 0
        var x: CGFloat = 0
        while x <= size.width {
            let h = terrainHeight(at: groundWorldOffset + x)
            if h > maxH { maxH = h }
            x += 20
        }
        return maxH
    }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        // Pause/resume audio when app goes to background/foreground
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: .appDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: .appWillEnterForeground, object: nil)

        showSplashScreen()
    }

    // MARK: - Splash Screen

    private func showSplashScreen() {
        // Black overlay covering entire screen
        let splash = SKSpriteNode(color: .black, size: size)
        splash.anchorPoint = .zero
        splash.position = .zero
        splash.zPosition = 500
        splash.name = "splashScreen"
        addChild(splash)

        // "Bangar" on top, "Games" below
        let bangarLabel = SKLabelNode(fontNamed: "AlienInvader")
        bangarLabel.text = "Bangar"
        bangarLabel.fontSize = 42
        bangarLabel.yScale = fontYScale
        bangarLabel.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        bangarLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 25)
        bangarLabel.zPosition = 501
        bangarLabel.alpha = 0
        bangarLabel.name = "splashScreen"
        addChild(bangarLabel)

        let gamesLabel = SKLabelNode(fontNamed: "AlienInvader")
        gamesLabel.text = "Games"
        gamesLabel.fontSize = 42
        gamesLabel.yScale = fontYScale
        gamesLabel.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        gamesLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 35)
        gamesLabel.zPosition = 501
        gamesLabel.alpha = 0
        gamesLabel.name = "splashScreen"
        addChild(gamesLabel)

        // Set up the game behind the splash screen
        setupAudio()
        setupBackground()
        setupGround()
        setupSaucer()
        showStartButton()

        // Fade in labels, hold, then fade out splash and start menu music
        let labelFade = SKAction.sequence([
            SKAction.fadeIn(withDuration: 0.6),
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeOut(withDuration: 0.6)
        ])
        bangarLabel.run(labelFade)
        gamesLabel.run(labelFade.copy() as! SKAction)

        splash.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.4),
            SKAction.fadeOut(withDuration: 0.6),
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in
                self?.children.filter { $0.name == "splashScreen" }.forEach { $0.removeFromParent() }
                self?.playMenuMusic()
            }
        ]))
    }

    @objc private func appDidEnterBackground() {
        menuMusicPlayer?.pause()
        gameMusicPlayer?.pause()
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
    }

    @objc private func appWillEnterForeground() {
        guard !isMusicOff && !isSoundOff else { return }
        if gameState == .menu || gameState == .gameOver {
            menuMusicPlayer?.play()
            scheduleCrossfadeLoop(for: menuMusicPlayer)
        } else if gameState == .playing {
            gameMusicPlayer?.play()
            scheduleCrossfadeLoop(for: gameMusicPlayer)
        }
    }

    // MARK: - Start Button & Menu

    private func showStartButton() {
        gameState = .menu

        // Title — "ALIEN" on top, "ABDUCTION" below
        titleLabel = SKLabelNode(fontNamed: "AlienInvader")
        titleLabel.text = "ALIEN"
        titleLabel.fontSize = 52
        titleLabel.yScale = fontYScale
        titleLabel.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        titleLabel.position = CGPoint(x: size.width / 2, y: size.height - 180)
        titleLabel.zPosition = 100
        titleLabel.name = "titleLabel"
        addChild(titleLabel)

        let subtitleLabel = SKLabelNode(fontNamed: "AlienInvader")
        subtitleLabel.text = "ABDUCTION"
        subtitleLabel.fontSize = 52
        subtitleLabel.yScale = fontYScale
        subtitleLabel.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        subtitleLabel.position = CGPoint(x: size.width / 2, y: size.height - 240)
        subtitleLabel.zPosition = 100
        subtitleLabel.name = "titleLabel"
        addChild(subtitleLabel)

        // Start button
        let btnWidth: CGFloat = 200
        let btnHeight: CGFloat = 70
        startButton = SKShapeNode(rectOf: CGSize(width: btnWidth, height: btnHeight), cornerRadius: 16)
        startButton.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        startButton.strokeColor = .white
        startButton.lineWidth = 3
        startButton.position = CGPoint(x: size.width / 2, y: size.height * 0.35)
        startButton.zPosition = 100
        startButton.name = "startButton"

        let label = SKLabelNode(fontNamed: "AlienInvader")
        label.text = "START"
        label.fontSize = 32
        label.yScale = fontYScale
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        startButton.addChild(label)

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.8),
            SKAction.scale(to: 1.0, duration: 0.8)
        ])
        startButton.run(SKAction.repeatForever(pulse))
        addChild(startButton)

        // Stats button below start
        let statsBtnW: CGFloat = 160
        let statsBtnH: CGFloat = 50
        statsButton = SKShapeNode(rectOf: CGSize(width: statsBtnW, height: statsBtnH), cornerRadius: 12)
        statsButton.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        statsButton.strokeColor = .white
        statsButton.lineWidth = 2
        statsButton.position = CGPoint(x: size.width / 2, y: size.height * 0.35 - 90)
        statsButton.zPosition = 100
        statsButton.name = "statsButton"

        let statsLabel = SKLabelNode(fontNamed: "AlienInvader")
        statsLabel.text = "STATS"
        statsLabel.fontSize = 24
        statsLabel.yScale = fontYScale
        statsLabel.fontColor = .white
        statsLabel.verticalAlignmentMode = .center
        statsLabel.horizontalAlignmentMode = .center
        statsButton.addChild(statsLabel)
        addChild(statsButton)

        // Help button below stats
        let helpBtnW: CGFloat = 160
        let helpBtnH: CGFloat = 50
        helpButton = SKShapeNode(rectOf: CGSize(width: helpBtnW, height: helpBtnH), cornerRadius: 12)
        helpButton.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        helpButton.strokeColor = .white
        helpButton.lineWidth = 2
        helpButton.position = CGPoint(x: size.width / 2, y: size.height * 0.35 - 155)
        helpButton.zPosition = 100
        helpButton.name = "helpButton"

        let helpLabel = SKLabelNode(fontNamed: "AlienInvader")
        helpLabel.text = "HELP"
        helpLabel.fontSize = 24
        helpLabel.yScale = fontYScale
        helpLabel.fontColor = .white
        helpLabel.verticalAlignmentMode = .center
        helpLabel.horizontalAlignmentMode = .center
        helpButton.addChild(helpLabel)
        addChild(helpButton)
    }

    private func showStatsOverlay() {
        let overlay = SKSpriteNode(color: .black, size: size)
        overlay.anchorPoint = .zero
        overlay.position = .zero
        overlay.zPosition = 110
        overlay.alpha = 0.85
        overlay.name = "statsOverlay"
        addChild(overlay)
        statsOverlay = overlay

        let bestScore = dataManager.highScore

        let titleLbl = SKLabelNode(fontNamed: "AlienInvader")
        titleLbl.text = "Stats"
        titleLbl.fontSize = 36
        titleLbl.yScale = fontYScale
        titleLbl.fontColor = .white
        titleLbl.position = CGPoint(x: size.width / 2, y: size.height * 0.88)
        titleLbl.zPosition = 115
        titleLbl.name = "statsOverlay"
        addChild(titleLbl)

        let scoreLbl = SKLabelNode(fontNamed: "AlienInvader")
        scoreLbl.text = "Best Score: \(bestScore)"
        scoreLbl.fontSize = 28
        scoreLbl.yScale = fontYScale
        scoreLbl.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        scoreLbl.position = CGPoint(x: size.width / 2, y: size.height * 0.80)
        scoreLbl.zPosition = 115
        scoreLbl.name = "statsOverlay"
        addChild(scoreLbl)

        // Creature catch counts
        let creatures: [(key: String, label: String)] = [
            ("whale", "Whales"),
            ("elk", "Elk"),
            ("cow", "Cows"),
            ("cat", "Cats"),
            ("hikerHuman", "Hikers"),
            ("workerHuman", "Workers"),
            ("bigfoot", "Bigfoots"),
            ("werewolf", "Werewolves"),
            ("kraken", "Krakens")
        ]

        let startY = size.height * 0.72
        let lineSpacing: CGFloat = 32
        let greenColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        let goldColor = SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
        let legendaryNames: Set<String> = ["bigfoot", "werewolf", "kraken"]

        for (i, creature) in creatures.enumerated() {
            let count = dataManager.catchCount(for: creature.key)
            let isLegend = legendaryNames.contains(creature.key)

            let nameLbl = SKLabelNode(fontNamed: "AlienInvader")
            nameLbl.text = creature.label
            nameLbl.fontSize = 20
            nameLbl.yScale = fontYScale
            nameLbl.fontColor = isLegend ? goldColor : .white
            nameLbl.horizontalAlignmentMode = .left
            nameLbl.position = CGPoint(x: size.width * 0.2, y: startY - CGFloat(i) * lineSpacing)
            nameLbl.zPosition = 115
            nameLbl.name = "statsOverlay"
            addChild(nameLbl)

            let countLbl = SKLabelNode(fontNamed: "AlienInvader")
            countLbl.text = "\(count)"
            countLbl.fontSize = 20
            countLbl.yScale = fontYScale
            countLbl.fontColor = isLegend ? goldColor : greenColor
            countLbl.horizontalAlignmentMode = .right
            countLbl.position = CGPoint(x: size.width * 0.8, y: startY - CGFloat(i) * lineSpacing)
            countLbl.zPosition = 115
            countLbl.name = "statsOverlay"
            addChild(countLbl)
        }

        // Leaderboard button — use SKSpriteNode for reliable hit testing
        let lbBtnSize = CGSize(width: 200, height: 50)
        let lbHitArea = SKSpriteNode(color: .clear, size: lbBtnSize)
        lbHitArea.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        lbHitArea.zPosition = 116
        lbHitArea.name = "leaderboardButton"
        addChild(lbHitArea)

        let lbBtn = SKShapeNode(rectOf: lbBtnSize, cornerRadius: 12)
        lbBtn.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        lbBtn.strokeColor = .white
        lbBtn.lineWidth = 2
        lbBtn.position = CGPoint(x: size.width / 2, y: size.height * 0.22)
        lbBtn.zPosition = 115
        lbBtn.name = "leaderboardButton"
        let lbLbl = SKLabelNode(fontNamed: "AlienInvader")
        lbLbl.text = "LEADERBOARD"
        lbLbl.fontSize = 20
        lbLbl.yScale = fontYScale
        lbLbl.fontColor = .white
        lbLbl.verticalAlignmentMode = .center
        lbLbl.horizontalAlignmentMode = .center
        lbLbl.name = "leaderboardButton"
        lbBtn.addChild(lbLbl)
        addChild(lbBtn)

        let closeLbl = SKLabelNode(fontNamed: "AlienInvader")
        closeLbl.text = "Tap to Close"
        closeLbl.fontSize = 20
        closeLbl.yScale = fontYScale
        closeLbl.fontColor = .white
        closeLbl.position = CGPoint(x: size.width / 2, y: size.height * 0.06)
        closeLbl.zPosition = 115
        closeLbl.name = "statsOverlay"
        addChild(closeLbl)
    }

    private func showGameCenterLeaderboard() {
        guard GKLocalPlayer.local.isAuthenticated else {
            // Try to authenticate first
            if let vc = self.view?.window?.rootViewController {
                CloudDataManager.shared.authenticateGameCenter(from: vc)
                // Show alert after a short delay if still not authenticated
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    if !GKLocalPlayer.local.isAuthenticated {
                        let alert = UIAlertController(
                            title: "Game Center",
                            message: "Please sign into Game Center in Settings → Game Center to view the leaderboard.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        })
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                        self?.view?.window?.rootViewController?.present(alert, animated: true)
                    }
                }
            }
            return
        }

        let gcVC = GKGameCenterViewController(leaderboardID: CloudDataManager.leaderboardID,
                                               playerScope: .global,
                                               timeScope: .allTime)
        gcVC.gameCenterDelegate = self
        if let vc = self.view?.window?.rootViewController {
            vc.present(gcVC, animated: true)
        }
    }

    private func dismissStatsOverlay() {
        children.filter { $0.name == "statsOverlay" || $0.name == "leaderboardButton" }.forEach { $0.removeFromParent() }
        statsOverlay = nil
    }

    private func showHelpOverlay() {
        let overlay = SKSpriteNode(color: .black, size: size)
        overlay.anchorPoint = .zero
        overlay.position = .zero
        overlay.zPosition = 110
        overlay.alpha = 0.9
        overlay.name = "helpOverlay"
        addChild(overlay)
        helpOverlay = overlay

        // Title
        let titleLbl = SKLabelNode(fontNamed: "AlienInvader")
        titleLbl.text = "How To Play"
        titleLbl.fontSize = 36
        titleLbl.yScale = fontYScale
        titleLbl.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        titleLbl.position = CGPoint(x: size.width / 2, y: size.height * 0.82)
        titleLbl.zPosition = 115
        titleLbl.name = "helpOverlay"
        addChild(titleLbl)

        // Objective text line 1
        let obj1 = SKLabelNode(fontNamed: "AlienInvader")
        obj1.text = "Abduct Living Creatures"
        obj1.fontSize = 20
        obj1.yScale = fontYScale
        obj1.fontColor = .white
        obj1.position = CGPoint(x: size.width / 2, y: size.height * 0.72)
        obj1.zPosition = 115
        obj1.name = "helpOverlay"
        addChild(obj1)

        // Objective text line 2
        let obj2 = SKLabelNode(fontNamed: "AlienInvader")
        obj2.text = "Without Crashing"
        obj2.fontSize = 20
        obj2.yScale = fontYScale
        obj2.fontColor = .white
        obj2.position = CGPoint(x: size.width / 2, y: size.height * 0.67)
        obj2.zPosition = 115
        obj2.name = "helpOverlay"
        addChild(obj2)

        // Special creatures hint
        let obj3 = SKLabelNode(fontNamed: "AlienInvader")
        obj3.text = "Keep An Eye Out For"
        obj3.fontSize = 20
        obj3.yScale = fontYScale
        obj3.fontColor = .white
        obj3.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        obj3.zPosition = 115
        obj3.name = "helpOverlay"
        addChild(obj3)

        let obj4 = SKLabelNode(fontNamed: "AlienInvader")
        obj4.text = "Special Creatures"
        obj4.fontSize = 20
        obj4.yScale = fontYScale
        obj4.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        obj4.position = CGPoint(x: size.width / 2, y: size.height * 0.57)
        obj4.zPosition = 115
        obj4.name = "helpOverlay"
        addChild(obj4)

        // Controls section title
        let ctrlTitle = SKLabelNode(fontNamed: "AlienInvader")
        ctrlTitle.text = "Controls"
        ctrlTitle.fontSize = 30
        ctrlTitle.yScale = fontYScale
        ctrlTitle.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        ctrlTitle.position = CGPoint(x: size.width / 2, y: size.height * 0.47)
        ctrlTitle.zPosition = 115
        ctrlTitle.name = "helpOverlay"
        addChild(ctrlTitle)

        // Control zones — tall rectangles showing thirds of screen
        let thirdW = size.width / 3
        let zoneY = size.height * 0.27
        let zoneH: CGFloat = 180

        // Left zone — DESCEND
        let leftZone = SKShapeNode(rectOf: CGSize(width: thirdW - 10, height: zoneH), cornerRadius: 10)
        leftZone.fillColor = SKColor(white: 1.0, alpha: 0.1)
        leftZone.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        leftZone.lineWidth = 1.5
        leftZone.position = CGPoint(x: thirdW / 2, y: zoneY)
        leftZone.zPosition = 115
        leftZone.name = "helpOverlay"
        addChild(leftZone)

        let leftTitle = SKLabelNode(fontNamed: "AlienInvader")
        leftTitle.text = "DESCEND"
        leftTitle.fontSize = 20
        leftTitle.yScale = fontYScale
        leftTitle.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        leftTitle.verticalAlignmentMode = .center
        leftTitle.position = CGPoint(x: thirdW / 2, y: zoneY + 30)
        leftTitle.zPosition = 116
        leftTitle.name = "helpOverlay"
        addChild(leftTitle)

        let leftDesc1 = SKLabelNode(fontNamed: "AlienInvader")
        leftDesc1.text = "Tap & Hold"
        leftDesc1.fontSize = 12
        leftDesc1.yScale = fontYScale
        leftDesc1.fontColor = .white
        leftDesc1.verticalAlignmentMode = .center
        leftDesc1.position = CGPoint(x: thirdW / 2, y: zoneY - 5)
        leftDesc1.zPosition = 116
        leftDesc1.name = "helpOverlay"
        addChild(leftDesc1)

        let leftDesc2 = SKLabelNode(fontNamed: "AlienInvader")
        leftDesc2.text = "left side"
        leftDesc2.fontSize = 12
        leftDesc2.yScale = fontYScale
        leftDesc2.fontColor = .white
        leftDesc2.verticalAlignmentMode = .center
        leftDesc2.position = CGPoint(x: thirdW / 2, y: zoneY - 25)
        leftDesc2.zPosition = 116
        leftDesc2.name = "helpOverlay"
        addChild(leftDesc2)

        let leftDesc3 = SKLabelNode(fontNamed: "AlienInvader")
        leftDesc3.text = "of screen"
        leftDesc3.fontSize = 12
        leftDesc3.yScale = fontYScale
        leftDesc3.fontColor = .white
        leftDesc3.verticalAlignmentMode = .center
        leftDesc3.position = CGPoint(x: thirdW / 2, y: zoneY - 45)
        leftDesc3.zPosition = 116
        leftDesc3.name = "helpOverlay"
        addChild(leftDesc3)

        // Middle zone — TRACTOR BEAM
        let midZone = SKShapeNode(rectOf: CGSize(width: thirdW - 10, height: zoneH), cornerRadius: 10)
        midZone.fillColor = SKColor(white: 1.0, alpha: 0.1)
        midZone.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        midZone.lineWidth = 1.5
        midZone.position = CGPoint(x: size.width / 2, y: zoneY)
        midZone.zPosition = 115
        midZone.name = "helpOverlay"
        addChild(midZone)

        let midTitle1 = SKLabelNode(fontNamed: "AlienInvader")
        midTitle1.text = "TRACTOR"
        midTitle1.fontSize = 20
        midTitle1.yScale = fontYScale
        midTitle1.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        midTitle1.verticalAlignmentMode = .center
        midTitle1.position = CGPoint(x: size.width / 2, y: zoneY + 40)
        midTitle1.zPosition = 116
        midTitle1.name = "helpOverlay"
        addChild(midTitle1)

        let midTitle2 = SKLabelNode(fontNamed: "AlienInvader")
        midTitle2.text = "BEAM"
        midTitle2.fontSize = 20
        midTitle2.yScale = fontYScale
        midTitle2.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        midTitle2.verticalAlignmentMode = .center
        midTitle2.position = CGPoint(x: size.width / 2, y: zoneY + 18)
        midTitle2.zPosition = 116
        midTitle2.name = "helpOverlay"
        addChild(midTitle2)

        let midDesc1 = SKLabelNode(fontNamed: "AlienInvader")
        midDesc1.text = "Tap the"
        midDesc1.fontSize = 12
        midDesc1.yScale = fontYScale
        midDesc1.fontColor = .white
        midDesc1.verticalAlignmentMode = .center
        midDesc1.position = CGPoint(x: size.width / 2, y: zoneY - 10)
        midDesc1.zPosition = 116
        midDesc1.name = "helpOverlay"
        addChild(midDesc1)

        let midDesc2 = SKLabelNode(fontNamed: "AlienInvader")
        midDesc2.text = "middle of"
        midDesc2.fontSize = 12
        midDesc2.yScale = fontYScale
        midDesc2.fontColor = .white
        midDesc2.verticalAlignmentMode = .center
        midDesc2.position = CGPoint(x: size.width / 2, y: zoneY - 30)
        midDesc2.zPosition = 116
        midDesc2.name = "helpOverlay"
        addChild(midDesc2)

        let midDesc3 = SKLabelNode(fontNamed: "AlienInvader")
        midDesc3.text = "the screen"
        midDesc3.fontSize = 12
        midDesc3.yScale = fontYScale
        midDesc3.fontColor = .white
        midDesc3.verticalAlignmentMode = .center
        midDesc3.position = CGPoint(x: size.width / 2, y: zoneY - 50)
        midDesc3.zPosition = 116
        midDesc3.name = "helpOverlay"
        addChild(midDesc3)

        // Right zone — ASCEND
        let rightZone = SKShapeNode(rectOf: CGSize(width: thirdW - 10, height: zoneH), cornerRadius: 10)
        rightZone.fillColor = SKColor(white: 1.0, alpha: 0.1)
        rightZone.strokeColor = SKColor(white: 1.0, alpha: 0.4)
        rightZone.lineWidth = 1.5
        rightZone.position = CGPoint(x: thirdW * 2 + thirdW / 2, y: zoneY)
        rightZone.zPosition = 115
        rightZone.name = "helpOverlay"
        addChild(rightZone)

        let rightTitle = SKLabelNode(fontNamed: "AlienInvader")
        rightTitle.text = "ASCEND"
        rightTitle.fontSize = 20
        rightTitle.yScale = fontYScale
        rightTitle.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        rightTitle.verticalAlignmentMode = .center
        rightTitle.position = CGPoint(x: thirdW * 2 + thirdW / 2, y: zoneY + 30)
        rightTitle.zPosition = 116
        rightTitle.name = "helpOverlay"
        addChild(rightTitle)

        let rightDesc1 = SKLabelNode(fontNamed: "AlienInvader")
        rightDesc1.text = "Tap & Hold"
        rightDesc1.fontSize = 12
        rightDesc1.yScale = fontYScale
        rightDesc1.fontColor = .white
        rightDesc1.verticalAlignmentMode = .center
        rightDesc1.position = CGPoint(x: thirdW * 2 + thirdW / 2, y: zoneY - 5)
        rightDesc1.zPosition = 116
        rightDesc1.name = "helpOverlay"
        addChild(rightDesc1)

        let rightDesc2 = SKLabelNode(fontNamed: "AlienInvader")
        rightDesc2.text = "right side"
        rightDesc2.fontSize = 12
        rightDesc2.yScale = fontYScale
        rightDesc2.fontColor = .white
        rightDesc2.verticalAlignmentMode = .center
        rightDesc2.position = CGPoint(x: thirdW * 2 + thirdW / 2, y: zoneY - 25)
        rightDesc2.zPosition = 116
        rightDesc2.name = "helpOverlay"
        addChild(rightDesc2)

        let rightDesc3 = SKLabelNode(fontNamed: "AlienInvader")
        rightDesc3.text = "of screen"
        rightDesc3.fontSize = 12
        rightDesc3.yScale = fontYScale
        rightDesc3.fontColor = .white
        rightDesc3.verticalAlignmentMode = .center
        rightDesc3.position = CGPoint(x: thirdW * 2 + thirdW / 2, y: zoneY - 45)
        rightDesc3.zPosition = 116
        rightDesc3.name = "helpOverlay"
        addChild(rightDesc3)

        // Tap to close
        let closeLbl = SKLabelNode(fontNamed: "AlienInvader")
        closeLbl.text = "Tap to Close"
        closeLbl.fontSize = 18
        closeLbl.yScale = fontYScale
        closeLbl.fontColor = SKColor(white: 1.0, alpha: 0.6)
        closeLbl.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        closeLbl.zPosition = 115
        closeLbl.name = "helpOverlay"
        addChild(closeLbl)
    }

    private func dismissHelpOverlay() {
        children.filter { $0.name == "helpOverlay" }.forEach { $0.removeFromParent() }
        helpOverlay = nil
    }

    // MARK: - Start Gameplay

    private func startGame() {
        gameState = .playing
        gamePhase = .ocean
        speedMultiplier = 1.0
        elapsedTime = 0
        score = 0
        lastAchievementScoreCheck = 0
        planeSpawnTimer = 0
        planeSpawnInterval = 2.5
        animalSpawnTimer = 0
        oilRigSpawnTimer = 0
        treeSpawnTimer = 0
        skyscraperSpawnTimer = 0
        initialSequenceComplete = false
        phaseStartTime = 0
        currentPhaseDuration = 0
        landHillsStartWorldX = 0
        movingUp = false
        movingDown = false
        isTransitioning = false
        saucerIdleTimer = 0
        lastSaucerY = 0

        // Remove menu UI
        let fadeOut = SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.2),
            SKAction.removeFromParent()
        ])
        startButton?.run(fadeOut)
        startButton = nil
        statsButton?.run(fadeOut)
        statsButton = nil
        helpButton?.run(fadeOut)
        helpButton = nil
        // Remove all title labels (including subtitle "ABDUCTION")
        children.filter { $0.name == "titleLabel" }.forEach { $0.run(fadeOut) }
        titleLabel = nil

        setupHUD()
        playGameMusic()
    }

    // MARK: - HUD

    private func setupHUD() {
        // Account for safe area (notch / Dynamic Island)
        let safeTop: CGFloat
        if let window = view?.window {
            safeTop = window.safeAreaInsets.top
        } else {
            safeTop = 60  // sensible default for notched devices
        }
        let hudY = size.height - safeTop - 10

        // Score background pill
        let scoreBg = SKShapeNode(rectOf: CGSize(width: 100, height: 36), cornerRadius: 10)
        scoreBg.fillColor = SKColor(white: 0.0, alpha: 0.5)
        scoreBg.strokeColor = .clear
        scoreBg.position = CGPoint(x: size.width / 2, y: hudY)
        scoreBg.zPosition = 199
        scoreBg.name = "hudElement"
        addChild(scoreBg)

        // Score label — top center
        scoreLabel = SKLabelNode(fontNamed: "AlienInvader")
        scoreLabel.text = "0"
        scoreLabel.fontSize = 24
        scoreLabel.yScale = fontYScale
        scoreLabel.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: size.width / 2, y: hudY)
        scoreLabel.zPosition = 200
        scoreLabel.name = "scoreLabel"
        addChild(scoreLabel)

        // Pause button — top left, solid button
        pauseButton = SKShapeNode(rectOf: CGSize(width: 50, height: 36), cornerRadius: 8)
        pauseButton.fillColor = SKColor(white: 0.3, alpha: 0.8)
        pauseButton.strokeColor = .white
        pauseButton.lineWidth = 2
        pauseButton.position = CGPoint(x: 45, y: hudY)
        pauseButton.zPosition = 200
        pauseButton.name = "pauseButton"
        let pauseLbl = SKLabelNode(fontNamed: "AlienInvader")
        pauseLbl.text = "| |"
        pauseLbl.fontSize = 20
        pauseLbl.yScale = fontYScale
        pauseLbl.fontColor = .white
        pauseLbl.verticalAlignmentMode = .center
        pauseLbl.horizontalAlignmentMode = .center
        pauseButton.addChild(pauseLbl)
        addChild(pauseButton)
    }

    private var lastAchievementScoreCheck: Int = 0

    private func updateScore(dt: TimeInterval) {
        score += dt * 0.5
        scoreLabel?.text = "\(Int(score))"

        // Check score achievements at milestones (avoid checking every frame)
        let currentScore = Int(score)
        if currentScore / 100 > lastAchievementScoreCheck / 100 {
            lastAchievementScoreCheck = currentScore
            dataManager.checkScoreAchievements(currentScore: currentScore)
        }
    }

    // MARK: - Pause

    private func showPauseMenu() {
        gameState = .paused
        movingUp = false
        movingDown = false

        // Freeze all moving objects
        tractorBeamActive = false
        removeTractorBeam()
        children.filter { $0.name == "plane" }.forEach { $0.isPaused = true }
        children.filter { $0.name == "animal" }.forEach { $0.isPaused = true }
        children.filter { $0.name == "oilRig" }.forEach { $0.isPaused = true }
        children.filter { $0.name == "tree" }.forEach { $0.isPaused = true }
        children.filter { $0.name == "skyscraper" }.forEach { $0.isPaused = true }
        children.filter { $0.name == "transitionOverlay" }.forEach { $0.isPaused = true }
        saucer?.isPaused = true
        pauseMusic()

        let overlay = SKSpriteNode(color: .black, size: size)
        overlay.anchorPoint = .zero
        overlay.position = .zero
        overlay.zPosition = 90
        overlay.alpha = 0.7
        overlay.name = "pauseOverlay"
        addChild(overlay)
        pauseOverlay = overlay

        let pausedLabel = SKLabelNode(fontNamed: "AlienInvader")
        pausedLabel.text = "Paused"
        pausedLabel.fontSize = 44
        pausedLabel.yScale = fontYScale
        pausedLabel.fontColor = .white
        pausedLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.6)
        pausedLabel.zPosition = 95
        pausedLabel.name = "pauseOverlay"
        addChild(pausedLabel)

        // Resume button
        let resumeBtn = SKShapeNode(rectOf: CGSize(width: 180, height: 55), cornerRadius: 14)
        resumeBtn.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        resumeBtn.strokeColor = .white
        resumeBtn.lineWidth = 2
        resumeBtn.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        resumeBtn.zPosition = 95
        resumeBtn.name = "resumeButton"
        let resumeLbl = SKLabelNode(fontNamed: "AlienInvader")
        resumeLbl.text = "Resume"
        resumeLbl.fontSize = 26
        resumeLbl.yScale = fontYScale
        resumeLbl.fontColor = .white
        resumeLbl.verticalAlignmentMode = .center
        resumeBtn.addChild(resumeLbl)
        addChild(resumeBtn)

        // Music toggle button
        let musicBtn = SKShapeNode(rectOf: CGSize(width: 180, height: 55), cornerRadius: 14)
        musicBtn.fillColor = isMusicOff ? SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) : SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        musicBtn.strokeColor = .white
        musicBtn.lineWidth = 2
        musicBtn.position = CGPoint(x: size.width / 2, y: size.height * 0.38)
        musicBtn.zPosition = 95
        musicBtn.name = "musicToggleButton"
        let musicLbl = SKLabelNode(fontNamed: "AlienInvader")
        musicLbl.text = isMusicOff ? "Music: OFF" : "Music: ON"
        musicLbl.fontSize = 22
        musicLbl.yScale = fontYScale
        musicLbl.fontColor = .white
        musicLbl.verticalAlignmentMode = .center
        musicLbl.name = "musicToggleLabel"
        musicBtn.addChild(musicLbl)
        addChild(musicBtn)

        // Sound toggle button
        let soundBtn = SKShapeNode(rectOf: CGSize(width: 180, height: 55), cornerRadius: 14)
        soundBtn.fillColor = isSoundOff ? SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) : SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        soundBtn.strokeColor = .white
        soundBtn.lineWidth = 2
        soundBtn.position = CGPoint(x: size.width / 2, y: size.height * 0.30)
        soundBtn.zPosition = 95
        soundBtn.name = "soundToggleButton"
        let soundLbl = SKLabelNode(fontNamed: "AlienInvader")
        soundLbl.text = isSoundOff ? "Sound: OFF" : "Sound: ON"
        soundLbl.fontSize = 22
        soundLbl.yScale = fontYScale
        soundLbl.fontColor = .white
        soundLbl.verticalAlignmentMode = .center
        soundLbl.name = "soundToggleLabel"
        soundBtn.addChild(soundLbl)
        addChild(soundBtn)

        // Quit button
        let quitBtn = SKShapeNode(rectOf: CGSize(width: 180, height: 55), cornerRadius: 14)
        quitBtn.fillColor = SKColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0)
        quitBtn.strokeColor = .white
        quitBtn.lineWidth = 2
        quitBtn.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
        quitBtn.zPosition = 95
        quitBtn.name = "quitButton"
        let quitLbl = SKLabelNode(fontNamed: "AlienInvader")
        quitLbl.text = "Quit"
        quitLbl.fontSize = 26
        quitLbl.yScale = fontYScale
        quitLbl.fontColor = .white
        quitLbl.verticalAlignmentMode = .center
        quitBtn.addChild(quitLbl)
        addChild(quitBtn)
    }

    private func toggleMusic() {
        isMusicOff.toggle()
        // Update button appearance
        if let btn = children.first(where: { $0.name == "musicToggleButton" }) as? SKShapeNode {
            btn.fillColor = isMusicOff ? SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) : SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            if let lbl = btn.childNode(withName: "musicToggleLabel") as? SKLabelNode {
                lbl.text = isMusicOff ? "Music: OFF" : "Music: ON"
            }
        }
        // Immediately stop or start music
        if isMusicOff {
            gameMusicPlayer?.pause()
            stopCrossfadeTimer()
        } else if !isSoundOff {
            gameMusicPlayer?.play()
            scheduleCrossfadeLoop(for: gameMusicPlayer)
        }
    }

    private func toggleSound() {
        isSoundOff.toggle()
        // Update button appearance
        if let btn = children.first(where: { $0.name == "soundToggleButton" }) as? SKShapeNode {
            btn.fillColor = isSoundOff ? SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) : SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
            if let lbl = btn.childNode(withName: "soundToggleLabel") as? SKLabelNode {
                lbl.text = isSoundOff ? "Sound: OFF" : "Sound: ON"
            }
        }
        // Sound off kills everything; sound on restores music if music isn't separately off
        if isSoundOff {
            gameMusicPlayer?.pause()
            stopCrossfadeTimer()
        } else if !isMusicOff {
            gameMusicPlayer?.play()
            scheduleCrossfadeLoop(for: gameMusicPlayer)
        }
    }

    private func resumeGame() {
        children.filter {
            $0.name == "pauseOverlay" || $0.name == "resumeButton" || $0.name == "quitButton" ||
            $0.name == "musicToggleButton" || $0.name == "soundToggleButton"
        }.forEach { $0.removeFromParent() }
        pauseOverlay = nil

        // Unfreeze all moving objects
        children.filter { $0.name == "plane" }.forEach { $0.isPaused = false }
        children.filter { $0.name == "animal" }.forEach { $0.isPaused = false }
        children.filter { $0.name == "oilRig" }.forEach { $0.isPaused = false }
        children.filter { $0.name == "tree" }.forEach { $0.isPaused = false }
        children.filter { $0.name == "skyscraper" }.forEach { $0.isPaused = false }
        children.filter { $0.name == "transitionOverlay" }.forEach { $0.isPaused = false }
        saucer?.isPaused = false

        // Reset lastUpdateTime so dt doesn't jump
        lastUpdateTime = 0

        gameState = .playing
        resumeMusic()
    }

    private func quitToMenu() {
        saveHighScore()
        stopGameMusic()
        removeAllChildren()
        moonNode = nil
        groundWorldOffset = 0
        gameOverOverlay = nil
        pauseOverlay = nil
        scoreLabel = nil
        pauseButton = nil
        gamePhase = .ocean
        speedMultiplier = 1.0
        isTransitioning = false
        initialSequenceComplete = false
        phaseStartTime = 0
        currentPhaseDuration = 0
        landHillsStartWorldX = 0
        skyscraperSpawnTimer = 0
        tractorBeamActive = false
        tractorBeamNode = nil
        oceanSprite1 = nil
        oceanSprite2 = nil
        transitionOverlay1 = nil
        transitionOverlay2 = nil

        setupBackground()
        setupGround()
        setupSaucer()
        showStartButton()
    }

    // MARK: - Phase Management

    private func updatePhase() {
        let previousPhase = gamePhase

        if !initialSequenceComplete {
            // Fixed sequence: ocean → grassland → city
            if elapsedTime < initialOceanDuration {
                gamePhase = .ocean
            } else if elapsedTime < initialOceanDuration + initialGrasslandDuration {
                gamePhase = .grassland
            } else if elapsedTime < initialOceanDuration + initialGrasslandDuration + initialCityDuration {
                gamePhase = .city
            } else {
                // Initial sequence done — start random rotation
                initialSequenceComplete = true
                switchToRandomPhase()
            }
        } else {
            // Random rotation: check if current phase duration has elapsed
            let phaseElapsed = elapsedTime - phaseStartTime
            if phaseElapsed >= currentPhaseDuration {
                switchToRandomPhase()
            }
        }

        // Speed ramps up gradually over total play time
        speedMultiplier = 1.0 + min(CGFloat(elapsedTime) * 0.002, 0.8)

        // Detect phase change and start transition
        if previousPhase != gamePhase && !isTransitioning {
            beginTransition(from: previousPhase, to: gamePhase)
        }

        // End transition once new environment covers most of the screen
        if isTransitioning && groundWorldOffset > transitionWorldX + transitionSandWidth + size.width * 0.3 {
            isTransitioning = false
            // Clean up transition overlays
            transitionOverlay1?.removeFromParent()
            transitionOverlay2?.removeFromParent()
            transitionOverlay1 = nil
            transitionOverlay2 = nil
            grasslandOverlayNode?.removeFromParent()
            grasslandOverlayNode = nil
            // If entering grassland, set flat stretch before hills
            if gamePhase == .grassland {
                let flatDistance = baseGroundSpeed * speedMultiplier * 10.0
                landHillsStartWorldX = groundWorldOffset + flatDistance
            }
        }
    }

    /// Returns true if we're within `buffer` seconds of the next phase change — stop spawning obstacles
    private func nearingPhaseEnd(buffer: TimeInterval = 0.5) -> Bool {
        if isTransitioning { return true }
        if !initialSequenceComplete {
            let nextChange: TimeInterval
            if elapsedTime < initialOceanDuration {
                nextChange = initialOceanDuration
            } else if elapsedTime < initialOceanDuration + initialGrasslandDuration {
                nextChange = initialOceanDuration + initialGrasslandDuration
            } else {
                nextChange = initialOceanDuration + initialGrasslandDuration + initialCityDuration
            }
            return (nextChange - elapsedTime) <= buffer
        } else {
            let phaseElapsed = elapsedTime - phaseStartTime
            return (currentPhaseDuration - phaseElapsed) <= buffer
        }
    }

    private func switchToRandomPhase() {
        let otherPhases = GamePhase.allCases.filter { $0 != gamePhase }
        gamePhase = otherPhases.randomElement()!
        phaseStartTime = elapsedTime
        // Random duration between 1 and 2 minutes
        currentPhaseDuration = TimeInterval.random(in: 60...120)
    }

    private func beginTransition(from oldPhase: GamePhase, to newPhase: GamePhase) {
        isTransitioning = true
        transitionFromPhase = oldPhase
        transitionWorldX = groundWorldOffset + size.width

        // Remove any existing transition overlays
        transitionOverlay1?.removeFromParent()
        transitionOverlay2?.removeFromParent()
        transitionOverlay1 = nil
        transitionOverlay2 = nil

        // For ocean transitions, the ocean sprites handle the visual.
        // For non-ocean old phases, create a colored overlay that scrolls off.
        if oldPhase != .ocean {
            let oldColor: SKColor
            switch oldPhase {
            case .grassland:
                oldColor = SKColor(red: 0.18, green: 0.40, blue: 0.12, alpha: 1.0)
            case .city:
                oldColor = SKColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)
            case .ocean:
                oldColor = .clear // won't reach here
            }
            let h: CGFloat = 50  // match flat terrain height
            let w = size.width
            let ov1 = SKSpriteNode(color: oldColor, size: CGSize(width: w, height: h))
            ov1.anchorPoint = CGPoint(x: 0, y: 0)
            ov1.position = CGPoint(x: 0, y: 0)
            ov1.zPosition = 6
            ov1.name = "transitionOverlay"
            addChild(ov1)
            transitionOverlay1 = ov1

            let ov2 = SKSpriteNode(color: oldColor, size: CGSize(width: w, height: h))
            ov2.anchorPoint = CGPoint(x: 0, y: 0)
            ov2.position = CGPoint(x: w, y: 0)
            ov2.zPosition = 6
            ov2.name = "transitionOverlay"
            addChild(ov2)
            transitionOverlay2 = ov2
        }
    }

    // MARK: - Background

    private func setupBackground() {
        let sky: SKSpriteNode
        if hasSkyAsset {
            sky = SKSpriteNode(imageNamed: "sky")
            sky.size = size
        } else {
            sky = SKSpriteNode(color: SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0), size: size)
            addClouds(to: sky, count: 5)
        }
        sky.anchorPoint = .zero
        sky.position = .zero
        sky.zPosition = -10
        sky.name = "sky"
        addChild(sky)

        if hasMoonAsset {
            moonNode = SKSpriteNode(imageNamed: "moon")
            moonNode.size = CGSize(width: 80, height: 80)
        } else {
            moonNode = createPlaceholderMoon()
        }
        moonNode.position = CGPoint(x: size.width - 60, y: size.height - 60)
        moonNode.zPosition = -8
        moonNode.name = "moon"
        addChild(moonNode)
    }

    private func createPlaceholderMoon() -> SKSpriteNode {
        let container = SKSpriteNode(color: .clear, size: CGSize(width: 80, height: 80))
        let circle = SKShapeNode(circleOfRadius: 35)
        circle.fillColor = SKColor(red: 0.95, green: 0.93, blue: 0.8, alpha: 1.0)
        circle.strokeColor = .clear
        circle.glowWidth = 8
        container.addChild(circle)
        for (cx, cy, cr): (CGFloat, CGFloat, CGFloat) in [(-10, 8, 6), (8, -5, 4), (-3, -12, 5)] {
            let crater = SKShapeNode(circleOfRadius: cr)
            crater.fillColor = SKColor(red: 0.85, green: 0.83, blue: 0.7, alpha: 1.0)
            crater.strokeColor = .clear
            crater.position = CGPoint(x: cx, y: cy)
            circle.addChild(crater)
        }
        return container
    }

    private func addClouds(to parent: SKSpriteNode, count: Int) {
        for _ in 0..<count {
            let cloud = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 60...120), height: CGFloat.random(in: 20...40)))
            cloud.fillColor = SKColor(white: 1.0, alpha: CGFloat.random(in: 0.3...0.6))
            cloud.strokeColor = .clear
            cloud.position = CGPoint(
                x: CGFloat.random(in: 40...(parent.size.width - 40)),
                y: CGFloat.random(in: (parent.size.height * 0.5)...(parent.size.height * 0.9))
            )
            cloud.zPosition = 1
            parent.addChild(cloud)
        }
    }

    // MARK: - Continuous Ground

    private func setupGround() {
        // Scrolling ocean sprites (two side by side for seamless loop)
        if hasOceanAsset {
            let oceanTex = SKTexture(imageNamed: "ocean")
            let oceanH: CGFloat = 50  // match flat terrain height
            let oceanW = size.width

            oceanSprite1 = SKSpriteNode(texture: oceanTex, size: CGSize(width: oceanW, height: oceanH))
            oceanSprite1!.anchorPoint = CGPoint(x: 0, y: 0)
            oceanSprite1!.position = CGPoint(x: 0, y: 0)
            oceanSprite1!.zPosition = 6
            oceanSprite1!.name = "oceanSprite"
            addChild(oceanSprite1!)

            oceanSprite2 = SKSpriteNode(texture: oceanTex, size: CGSize(width: oceanW, height: oceanH))
            oceanSprite2!.anchorPoint = CGPoint(x: 0, y: 0)
            oceanSprite2!.position = CGPoint(x: oceanW, y: 0)
            oceanSprite2!.zPosition = 6
            oceanSprite2!.name = "oceanSprite"
            addChild(oceanSprite2!)
        }

        groundNode = SKShapeNode()
        groundNode.zPosition = 5
        groundNode.name = "groundNode"
        addChild(groundNode)

        groundPhysicsNode = SKShapeNode()
        groundPhysicsNode.zPosition = 5
        groundPhysicsNode.name = "groundPhysics"
        groundPhysicsNode.strokeColor = .clear
        groundPhysicsNode.fillColor = .clear
        addChild(groundPhysicsNode)

        rebuildGroundPath()
    }

    private func updateScrollingSprites(_ s1: SKSpriteNode?, _ s2: SKSpriteNode?, show: Bool, alpha: CGFloat = 1.0) {
        guard let s1 = s1, let s2 = s2 else { return }
        s1.isHidden = !show
        s2.isHidden = !show
        if show {
            let w = size.width
            let offset = groundWorldOffset.truncatingRemainder(dividingBy: w)
            s1.position.x = -offset
            s2.position.x = -offset + w
            if s1.position.x + w < 0 { s1.position.x = s2.position.x + w }
            if s2.position.x + w < 0 { s2.position.x = s1.position.x + w }
            s1.alpha = alpha
            s2.alpha = alpha
        }
    }

    private func updateTransitionOverlay() {
        guard isTransitioning, let ov1 = transitionOverlay1, let ov2 = transitionOverlay2 else { return }

        let endScreenX = transitionWorldX - groundWorldOffset
        if endScreenX + size.width <= 0 {
            // Old environment fully off screen — remove overlays
            ov1.removeFromParent()
            ov2.removeFromParent()
            transitionOverlay1 = nil
            transitionOverlay2 = nil
        } else {
            let w = size.width
            let baseX = endScreenX - w
            ov1.position.x = baseX - w
            ov2.position.x = baseX
            ov1.isHidden = (ov1.position.x + w < 0)
            ov2.isHidden = (ov2.position.x + w < 0)
        }
    }

    private func updateOceanSprites() {
        guard let s1 = oceanSprite1, let s2 = oceanSprite2 else { return }

        if isTransitioning && transitionFromPhase == .ocean {
            // Transitioning away from ocean: let ocean sprites scroll off left
            let oceanEndScreenX = transitionWorldX - groundWorldOffset
            if oceanEndScreenX + size.width <= 0 {
                s1.isHidden = true
                s2.isHidden = true
            } else {
                s1.isHidden = false
                s2.isHidden = false
                s1.xScale = 1.0
                s2.xScale = 1.0
                let w = size.width
                let baseX = oceanEndScreenX - w
                s1.position.x = baseX - w
                s2.position.x = baseX
                if s2.position.x + w < 0 { s2.isHidden = true }
                if s1.position.x + w < 0 { s1.isHidden = true }
            }
        } else if gamePhase == .ocean && !isTransitioning {
            // Normal ocean: infinite scrolling wrap
            s1.isHidden = false
            s2.isHidden = false
            s1.xScale = 1.0
            s2.xScale = 1.0
            updateScrollingSprites(oceanSprite1, oceanSprite2, show: true)
        } else if isTransitioning && gamePhase == .ocean {
            // Transitioning TO ocean — ocean sprites appear from the right at transitionWorldX
            let newStartScreenX = transitionWorldX - groundWorldOffset
            if newStartScreenX > size.width {
                // Not on screen yet
                s1.isHidden = true
                s2.isHidden = true
            } else {
                s1.isHidden = false
                s2.isHidden = false
                s1.xScale = 1.0
                s2.xScale = 1.0
                let w = size.width
                // Position ocean tiles starting from the transition boundary
                let offset = groundWorldOffset.truncatingRemainder(dividingBy: w)
                s1.position.x = newStartScreenX - offset.truncatingRemainder(dividingBy: w)
                s2.position.x = s1.position.x + w
                // Make sure at least one tile covers from transitionWorldX to the right edge
                if s1.position.x > newStartScreenX { s1.position.x -= w }
                if s2.position.x > size.width + w { s2.isHidden = true }
            }
        } else {
            s1.isHidden = true
            s2.isHidden = true
        }
    }

    /// Returns the ground fill/stroke colors for the current phase
    private func currentGroundColors() -> (fill: SKColor, stroke: SKColor) {
        switch gamePhase {
        case .ocean:
            return (SKColor(red: 0.08, green: 0.20, blue: 0.50, alpha: 1.0),
                    SKColor(red: 0.06, green: 0.15, blue: 0.40, alpha: 1.0))
        case .grassland:
            return (SKColor(red: 0.18, green: 0.40, blue: 0.12, alpha: 1.0),
                    SKColor(red: 0.14, green: 0.34, blue: 0.09, alpha: 1.0))
        case .city:
            return (SKColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0),
                    SKColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0))
        }
    }

    /// Returns (fillColor, strokeColor) for a given phase
    private func groundColors(for phase: GamePhase) -> (SKColor, SKColor) {
        switch phase {
        case .ocean:
            return (SKColor(red: 0.08, green: 0.20, blue: 0.50, alpha: 1.0),
                    SKColor(red: 0.06, green: 0.15, blue: 0.40, alpha: 1.0))
        case .grassland:
            return (SKColor(red: 0.18, green: 0.40, blue: 0.12, alpha: 1.0),
                    SKColor(red: 0.14, green: 0.34, blue: 0.09, alpha: 1.0))
        case .city:
            return (SKColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0),
                    SKColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0))
        }
    }

    private func rebuildGroundPath() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))

        var x: CGFloat = 0
        while x <= size.width + terrainResolution {
            let worldX = groundWorldOffset + x
            let h = terrainHeight(at: worldX)
            path.addLine(to: CGPoint(x: x, y: h))
            x += terrainResolution
        }

        path.addLine(to: CGPoint(x: size.width + terrainResolution, y: 0))
        path.closeSubpath()

        groundNode.path = path

        // During transition from grassland, draw the new phase color on the main ground
        // and overlay the old grassland color on the left portion (before transitionWorldX)
        if isTransitioning && transitionFromPhase == .grassland {
            let (newFill, newStroke) = groundColors(for: gamePhase)
            groundNode.fillColor = newFill
            groundNode.strokeColor = newStroke

            // Build a clipped grassland overlay for the old side
            let splitScreenX = transitionWorldX - groundWorldOffset
            if splitScreenX > 0 {
                let oldPath = CGMutablePath()
                oldPath.move(to: CGPoint(x: 0, y: 0))
                var ox: CGFloat = 0
                while ox <= min(splitScreenX, size.width + terrainResolution) {
                    let worldX = groundWorldOffset + ox
                    let h = terrainHeight(at: worldX)
                    oldPath.addLine(to: CGPoint(x: ox, y: h))
                    ox += terrainResolution
                }
                let clampedX = min(splitScreenX, size.width + terrainResolution)
                let hEdge = terrainHeight(at: groundWorldOffset + clampedX)
                oldPath.addLine(to: CGPoint(x: clampedX, y: hEdge))
                oldPath.addLine(to: CGPoint(x: clampedX, y: 0))
                oldPath.closeSubpath()

                if grasslandOverlayNode == nil {
                    let overlay = SKShapeNode()
                    overlay.zPosition = groundNode.zPosition + 0.1
                    overlay.lineWidth = 0
                    addChild(overlay)
                    grasslandOverlayNode = overlay
                }
                grasslandOverlayNode?.path = oldPath
                grasslandOverlayNode?.fillColor = SKColor(red: 0.18, green: 0.40, blue: 0.12, alpha: 1.0)
                grasslandOverlayNode?.strokeColor = SKColor(red: 0.14, green: 0.34, blue: 0.09, alpha: 1.0)
                grasslandOverlayNode?.lineWidth = 0
            } else {
                // Grassland portion fully scrolled off
                grasslandOverlayNode?.removeFromParent()
                grasslandOverlayNode = nil
            }
        } else {
            // No transition from grassland — remove overlay if present
            grasslandOverlayNode?.removeFromParent()
            grasslandOverlayNode = nil

            // Set ground color based on current phase
            let (fill, stroke) = groundColors(for: gamePhase)
            groundNode.fillColor = fill
            groundNode.strokeColor = stroke
        }
        groundNode.lineWidth = 1.5

        // Update scrolling ocean
        updateOceanSprites()
        updateTransitionOverlay()

        // Rebuild physics body
        x = 0
        let edgePath = CGMutablePath()
        var first = true
        while x <= size.width + terrainResolution {
            let worldX = groundWorldOffset + x
            let h = terrainHeight(at: worldX)
            if first {
                edgePath.move(to: CGPoint(x: x, y: h))
                first = false
            } else {
                edgePath.addLine(to: CGPoint(x: x, y: h))
            }
            x += terrainResolution * 2
        }
        edgePath.addLine(to: CGPoint(x: size.width + terrainResolution, y: 0))
        edgePath.addLine(to: CGPoint(x: 0, y: 0))
        edgePath.closeSubpath()

        let body = SKPhysicsBody(polygonFrom: edgePath)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.saucer
        body.collisionBitMask = PhysicsCategory.none
        groundPhysicsNode.physicsBody = body
    }

    // MARK: - Saucer

    private func setupSaucer() {
        let saucerSize = CGSize(width: 90, height: 90)

        let atlas = SKTextureAtlas(named: "alienSaucer")
        let textureNames = atlas.textureNames.sorted()

        if textureNames.count > 1 {
            saucerFrames = textureNames.map { atlas.textureNamed($0) }
            saucer = SKSpriteNode(texture: saucerFrames.first, size: saucerSize)

            let animate = SKAction.animate(with: saucerFrames, timePerFrame: 1.0 / 24.0)
            saucer.run(SKAction.repeatForever(animate))
        } else if hasSaucerAsset {
            saucer = SKSpriteNode(imageNamed: "alienSaucer")
            saucer.size = saucerSize
        } else {
            saucer = createPlaceholderSaucer()
        }

        saucer.position = CGPoint(x: size.width * 0.3, y: size.height * 0.5)
        saucer.zPosition = 50
        saucer.name = "saucer"

        let body: SKPhysicsBody
        if let texture = saucer.texture {
            body = SKPhysicsBody(texture: texture, size: saucerSize)
        } else {
            body = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 30))
        }
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.saucer
        body.contactTestBitMask = PhysicsCategory.obstacle | PhysicsCategory.ground
        body.collisionBitMask = PhysicsCategory.none
        saucer.physicsBody = body

        addChild(saucer)
    }

    private func createPlaceholderSaucer() -> SKSpriteNode {
        let container = SKSpriteNode(color: .clear, size: CGSize(width: 90, height: 55))

        let bodyShape = SKShapeNode(ellipseOf: CGSize(width: 85, height: 28))
        bodyShape.fillColor = SKColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1.0)
        bodyShape.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
        bodyShape.lineWidth = 1.5
        bodyShape.position = CGPoint(x: 0, y: -3)
        container.addChild(bodyShape)

        let dome = SKShapeNode(ellipseOf: CGSize(width: 34, height: 24))
        dome.fillColor = SKColor(red: 0.5, green: 0.9, blue: 1.0, alpha: 0.7)
        dome.strokeColor = SKColor(red: 0.3, green: 0.7, blue: 0.8, alpha: 1.0)
        dome.lineWidth = 1.0
        dome.position = CGPoint(x: 0, y: 10)
        container.addChild(dome)

        for xOff: CGFloat in [-24, -8, 8, 24] {
            let light = SKShapeNode(circleOfRadius: 3.5)
            light.fillColor = .yellow
            light.strokeColor = .clear
            light.position = CGPoint(x: xOff, y: -14)
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.3),
                SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            ])
            light.run(SKAction.repeatForever(blink))
            container.addChild(light)
        }

        return container
    }

    // MARK: - Plane Spawning

    private func spawnPlane() {
        let planeWidth: CGFloat = 80
        let planeHeight: CGFloat = 35

        let chosenName = planeAssetNames.randomElement()!
        let plane: SKSpriteNode
        if UIImage(named: chosenName) != nil {
            plane = SKSpriteNode(imageNamed: chosenName)
            plane.size = CGSize(width: planeWidth, height: planeHeight)
        } else {
            plane = createPlaceholderPlane(width: planeWidth, height: planeHeight)
        }
        plane.name = "plane"
        plane.zPosition = 40

        // Planes always fly above the max possible terrain height
        let minY = maxPossibleTerrainHeight
        let maxY = size.height - 60
        let spawnY = CGFloat.random(in: minY...max(minY + 1, maxY))
        plane.position = CGPoint(x: size.width + planeWidth, y: spawnY)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: planeWidth, height: planeHeight))
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.saucer
        body.collisionBitMask = PhysicsCategory.none
        plane.physicsBody = body

        let speed = (basePlaneSpeed + CGFloat.random(in: -30...30)) * speedMultiplier
        let distance = size.width + planeWidth * 2
        let duration = TimeInterval(distance / speed)
        let moveLeft = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        plane.run(SKAction.sequence([moveLeft, SKAction.removeFromParent()]))

        addChild(plane)
    }

    private func createPlaceholderPlane(width: CGFloat, height: CGFloat) -> SKSpriteNode {
        let plane = SKSpriteNode(color: .clear, size: CGSize(width: width, height: height))

        let fuselage = SKShapeNode(rectOf: CGSize(width: 70, height: 16), cornerRadius: 6)
        fuselage.fillColor = SKColor(white: 0.9, alpha: 1.0)
        fuselage.strokeColor = SKColor(white: 0.6, alpha: 1.0)
        plane.addChild(fuselage)

        let wing = SKShapeNode(rectOf: CGSize(width: 24, height: 48))
        wing.fillColor = SKColor(white: 0.85, alpha: 1.0)
        wing.strokeColor = SKColor(white: 0.6, alpha: 1.0)
        wing.position = CGPoint(x: -6, y: 0)
        plane.addChild(wing)

        let tail = SKShapeNode(rectOf: CGSize(width: 12, height: 22))
        tail.fillColor = SKColor(white: 0.85, alpha: 1.0)
        tail.strokeColor = SKColor(white: 0.6, alpha: 1.0)
        tail.position = CGPoint(x: -30, y: 9)
        plane.addChild(tail)

        let stripe = SKShapeNode(rectOf: CGSize(width: 70, height: 3))
        stripe.fillColor = .red
        stripe.strokeColor = .clear
        stripe.position = CGPoint(x: 0, y: 3)
        plane.addChild(stripe)

        let nose = SKShapeNode(ellipseOf: CGSize(width: 10, height: 14))
        nose.fillColor = SKColor(white: 0.7, alpha: 1.0)
        nose.strokeColor = .clear
        nose.position = CGPoint(x: 36, y: 0)
        plane.addChild(nose)

        return plane
    }

    // MARK: - Collision

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }

        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if categories & PhysicsCategory.saucer != 0 &&
           (categories & PhysicsCategory.obstacle != 0 || categories & PhysicsCategory.ground != 0) {
            // Determine collision point and the obstacle node
            let contactPoint = contact.contactPoint
            let obstacleNode: SKNode?
            if contact.bodyA.categoryBitMask == PhysicsCategory.saucer {
                obstacleNode = contact.bodyB.node
            } else {
                obstacleNode = contact.bodyA.node
            }
            triggerGameOver(at: contactPoint, obstacle: obstacleNode)
        }
    }

    // MARK: - Explosion

    private func createExplosion(at position: CGPoint) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 95

        // Generate a circle texture for particles
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        emitter.particleTexture = SKTexture(image: image)

        emitter.particleBirthRate = 300
        emitter.numParticlesToEmit = 80
        emitter.particleLifetime = 0.8
        emitter.particleLifetimeRange = 0.4

        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 150
        emitter.particleSpeedRange = 80

        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -1.5

        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.5
        emitter.particleScaleSpeed = -1.0

        emitter.particleColorSequence = nil
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        emitter.particleColorRedRange = 0.2
        emitter.particleColorGreenRange = 0.4
        emitter.particleColorBlueRange = 0.1

        // Auto-remove after particles finish
        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.removeFromParent()
        ]))

        return emitter
    }

    // MARK: - Game Over

    private func triggerGameOver(at contactPoint: CGPoint? = nil, obstacle: SKNode? = nil) {
        gameState = .gameOver
        movingUp = false
        movingDown = false
        tractorBeamActive = false
        removeTractorBeam()

        stopGameMusic()
        saveHighScore()

        // Explosion sound
        if !isSoundOff {
            run(SKAction.playSoundFileNamed("explosion.mp3", waitForCompletion: false))
        }

        // Explosion at saucer
        if let saucerPos = saucer?.position {
            addChild(createExplosion(at: saucerPos))
        }
        // Explosion at obstacle
        if let point = contactPoint {
            addChild(createExplosion(at: point))
        }

        // Shake the camera
        let shakeRight = SKAction.moveBy(x: 8, y: 0, duration: 0.04)
        let shakeLeft = SKAction.moveBy(x: -16, y: 0, duration: 0.04)
        let shakeBack = SKAction.moveBy(x: 8, y: 0, duration: 0.04)
        let shake = SKAction.sequence([shakeRight, shakeLeft, shakeBack])
        self.run(SKAction.repeat(shake, count: 4))

        // Flash screen white briefly
        let flash = SKSpriteNode(color: .white, size: size)
        flash.anchorPoint = .zero
        flash.position = .zero
        flash.zPosition = 89
        flash.alpha = 0.8
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeOut(withDuration: 0.3),
            SKAction.removeFromParent()
        ]))

        // Hide saucer after explosion
        saucer?.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.1),
            SKAction.fadeOut(withDuration: 0.2)
        ]))

        children.filter { $0.name == "plane" }.forEach { $0.removeAllActions() }
        children.filter { $0.name == "animal" }.forEach { $0.removeAllActions() }
        children.filter { $0.name == "oilRig" }.forEach { $0.removeAllActions() }
        children.filter { $0.name == "skyscraper" }.forEach { $0.removeAllActions() }
        children.filter { $0.name == "tree" }.forEach { $0.removeAllActions() }

        // Hide HUD
        children.filter { $0.name == "hudElement" }.forEach { $0.removeFromParent() }
        scoreLabel?.removeFromParent()
        scoreLabel = nil
        pauseButton?.removeFromParent()
        pauseButton = nil

        gameOverOverlay = SKSpriteNode(color: .black, size: size)
        gameOverOverlay.anchorPoint = .zero
        gameOverOverlay.position = .zero
        gameOverOverlay.zPosition = 90
        gameOverOverlay.alpha = 0
        gameOverOverlay.name = "gameOverOverlay"
        addChild(gameOverOverlay)

        let gameOverLabel = SKLabelNode(fontNamed: "AlienInvader")
        gameOverLabel.text = "Game Over"
        gameOverLabel.fontSize = 48
        gameOverLabel.yScale = fontYScale
        gameOverLabel.fontColor = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        gameOverLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.75)
        gameOverLabel.zPosition = 100
        gameOverLabel.alpha = 0
        gameOverLabel.name = "gameOverLabel"
        addChild(gameOverLabel)

        // Show final score
        let finalScoreLabel = SKLabelNode(fontNamed: "AlienInvader")
        finalScoreLabel.text = "Score: \(Int(score))"
        finalScoreLabel.fontSize = 36
        finalScoreLabel.yScale = fontYScale
        finalScoreLabel.fontColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        finalScoreLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 80)
        finalScoreLabel.zPosition = 100
        finalScoreLabel.alpha = 0
        finalScoreLabel.name = "gameOverLabel"
        addChild(finalScoreLabel)

        // Restart button (solid, like start button)
        let restartBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 14)
        restartBtn.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        restartBtn.strokeColor = .white
        restartBtn.lineWidth = 3
        restartBtn.position = CGPoint(x: size.width / 2, y: size.height / 2)
        restartBtn.zPosition = 100
        restartBtn.alpha = 0
        restartBtn.name = "restartButton"
        let restartLbl = SKLabelNode(fontNamed: "AlienInvader")
        restartLbl.text = "RESTART"
        restartLbl.fontSize = 26
        restartLbl.yScale = fontYScale
        restartLbl.fontColor = .white
        restartLbl.verticalAlignmentMode = .center
        restartLbl.horizontalAlignmentMode = .center
        restartBtn.addChild(restartLbl)
        addChild(restartBtn)

        // Return to menu button
        let menuBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 60), cornerRadius: 14)
        menuBtn.fillColor = SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        menuBtn.strokeColor = .white
        menuBtn.lineWidth = 3
        menuBtn.position = CGPoint(x: size.width / 2, y: size.height / 2 - 80)
        menuBtn.zPosition = 100
        menuBtn.alpha = 0
        menuBtn.name = "menuButton"
        let menuLbl = SKLabelNode(fontNamed: "AlienInvader")
        menuLbl.text = "MENU"
        menuLbl.fontSize = 26
        menuLbl.yScale = fontYScale
        menuLbl.fontColor = .white
        menuLbl.verticalAlignmentMode = .center
        menuLbl.horizontalAlignmentMode = .center
        menuBtn.addChild(menuLbl)
        addChild(menuBtn)

        gameOverOverlay.run(SKAction.fadeAlpha(to: 0.85, duration: 0.6))
        gameOverLabel.run(SKAction.fadeIn(withDuration: 0.8))
        finalScoreLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.3),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
        restartBtn.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
        menuBtn.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.7),
            SKAction.fadeIn(withDuration: 0.5)
        ]))
    }

    // MARK: - High Score

    private func saveHighScore() {
        dataManager.highScore = Int(score)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        switch gameState {
        case .menu:
            // Overlays showing — dismiss them
            if statsOverlay != nil {
                let tapped = nodes(at: location)
                if tapped.contains(where: { $0.name == "leaderboardButton" || $0.parent?.name == "leaderboardButton" }) {
                    dismissStatsOverlay()
                    showGameCenterLeaderboard()
                } else {
                    dismissStatsOverlay()
                }
                return
            }
            if helpOverlay != nil {
                dismissHelpOverlay()
                return
            }
            let tappedNodes = nodes(at: location)
            if tappedNodes.contains(where: { $0.name == "startButton" || $0.parent?.name == "startButton" }) {
                startGame()
            } else if tappedNodes.contains(where: { $0.name == "statsButton" || $0.parent?.name == "statsButton" }) {
                showStatsOverlay()
            } else if tappedNodes.contains(where: { $0.name == "helpButton" || $0.parent?.name == "helpButton" }) {
                showHelpOverlay()
            }

        case .playing:
            let tappedNodes = nodes(at: location)
            if tappedNodes.contains(where: { $0.name == "pauseButton" }) {
                showPauseMenu()
                return
            }
            handleTouchInput(location: location)

        case .paused:
            let tappedNodes = nodes(at: location)
            if tappedNodes.contains(where: { $0.name == "resumeButton" || $0.parent?.name == "resumeButton" }) {
                resumeGame()
            } else if tappedNodes.contains(where: { $0.name == "musicToggleButton" || $0.parent?.name == "musicToggleButton" }) {
                toggleMusic()
            } else if tappedNodes.contains(where: { $0.name == "soundToggleButton" || $0.parent?.name == "soundToggleButton" }) {
                toggleSound()
            } else if tappedNodes.contains(where: { $0.name == "quitButton" || $0.parent?.name == "quitButton" }) {
                quitToMenu()
            }

        case .gameOver:
            let tappedNodes = nodes(at: location)
            if tappedNodes.contains(where: { $0.name == "restartButton" || $0.parent?.name == "restartButton" }) {
                restartGame()
            } else if tappedNodes.contains(where: { $0.name == "menuButton" || $0.parent?.name == "menuButton" }) {
                quitToMenu()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gameState == .playing, let touch = touches.first else { return }
        handleTouchInput(location: touch.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .playing {
            movingUp = false
            movingDown = false
            tractorBeamActive = false
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .playing {
            movingUp = false
            movingDown = false
            tractorBeamActive = false
        }
    }

    private func handleTouchInput(location: CGPoint) {
        let third = size.width / 3
        if location.x > third * 2 {
            // Right third — ascend
            movingUp = true
            movingDown = false
            tractorBeamActive = false
        } else if location.x > third {
            // Middle third — tractor beam
            movingUp = false
            movingDown = false
            if !tractorBeamActive {
                playTractorBeamSound()
            }
            tractorBeamActive = true
        } else {
            // Left third — descend
            movingUp = false
            movingDown = true
            tractorBeamActive = false
        }
    }

    // MARK: - Restart

    private func restartGame() {
        removeAllChildren()
        moonNode = nil
        groundWorldOffset = 0
        gameOverOverlay = nil
        pauseOverlay = nil
        scoreLabel = nil
        pauseButton = nil
        gamePhase = .ocean
        speedMultiplier = 1.0
        isTransitioning = false
        initialSequenceComplete = false
        phaseStartTime = 0
        currentPhaseDuration = 0
        landHillsStartWorldX = 0
        skyscraperSpawnTimer = 0
        tractorBeamActive = false
        tractorBeamNode = nil
        oceanSprite1 = nil
        oceanSprite2 = nil
        transitionOverlay1 = nil
        transitionOverlay2 = nil

        setupBackground()
        setupGround()
        setupSaucer()
        setupHUD()
        playGameMusic()

        gameState = .playing
        elapsedTime = 0
        score = 0
        lastAchievementScoreCheck = 0
        planeSpawnTimer = 0
        planeSpawnInterval = 2.5
        animalSpawnTimer = 0
        oilRigSpawnTimer = 0
        treeSpawnTimer = 0
        skyscraperSpawnTimer = 0
        initialSequenceComplete = false
        phaseStartTime = 0
        currentPhaseDuration = 0
        landHillsStartWorldX = 0
        isTransitioning = false
        movingUp = false
        movingDown = false
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard gameState != .gameOver && gameState != .paused else { return }

        scrollGround(dt: dt)

        if gameState == .playing {
            elapsedTime += dt
            updatePhase()
            updateScore(dt: dt)
            updateSaucerPosition(dt: dt)
            updateTractorBeam()
            updatePlaneSpawning(dt: dt)
            updateAnimalSpawning(dt: dt)
            updateOilRigSpawning(dt: dt)
            updateTreeSpawning(dt: dt)
            updateSkyscraperSpawning(dt: dt)
            increaseDifficulty()
        }
    }

    // MARK: - Saucer Movement

    private func updateSaucerPosition(dt: TimeInterval) {
        guard let saucer = saucer else { return }

        var newY = saucer.position.y

        if movingUp {
            newY += saucerMoveSpeed * CGFloat(dt)
        } else if movingDown {
            newY -= saucerMoveSpeed * CGFloat(dt)
        }

        let topLimit = size.height - saucerTopMargin
        let bottomLimit = saucerBottomMargin
        newY = max(bottomLimit, min(topLimit, newY))

        saucer.position.y = newY

        // Track if saucer is idle (not moving vertically)
        if abs(newY - lastSaucerY) < 1.0 {
            saucerIdleTimer += dt
            if saucerIdleTimer >= saucerIdleThreshold {
                saucerIdleTimer = 0
                spawnTargetedPlane(atY: newY)
            }
        } else {
            saucerIdleTimer = 0
        }
        lastSaucerY = newY
    }

    /// Spawns a plane aimed directly at the saucer's current Y level
    private func spawnTargetedPlane(atY y: CGFloat) {
        let planeWidth: CGFloat = 80
        let planeHeight: CGFloat = 35

        let chosenName = planeAssetNames.randomElement()!
        let plane: SKSpriteNode
        if UIImage(named: chosenName) != nil {
            plane = SKSpriteNode(imageNamed: chosenName)
            plane.size = CGSize(width: planeWidth, height: planeHeight)
        } else {
            plane = createPlaceholderPlane(width: planeWidth, height: planeHeight)
        }
        plane.name = "plane"
        plane.zPosition = 40
        plane.position = CGPoint(x: size.width + planeWidth, y: y)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: planeWidth, height: planeHeight))
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.saucer
        body.collisionBitMask = PhysicsCategory.none
        plane.physicsBody = body

        let speed = (basePlaneSpeed + 40) * speedMultiplier  // slightly faster than normal
        let distance = size.width + planeWidth * 2
        let duration = TimeInterval(distance / speed)
        let moveLeft = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        plane.run(SKAction.sequence([moveLeft, SKAction.removeFromParent()]))

        addChild(plane)
    }

    // MARK: - Tractor Beam

    private func updateTractorBeam() {
        if tractorBeamActive, let saucer = saucer {
            // Get ground height directly below the saucer
            let saucerScreenX = saucer.position.x
            let worldX = groundWorldOffset + saucerScreenX
            let groundY = terrainHeight(at: worldX)

            let saucerBottomY = saucer.position.y - 30  // bottom of saucer
            let beamHeight = saucerBottomY - groundY
            guard beamHeight > 0 else {
                removeTractorBeam()
                return
            }

            // Trapezoid beam: narrow at saucer, wider at ground
            let topWidth: CGFloat = 12
            let bottomWidth: CGFloat = 40 + beamHeight * 0.1  // widens with distance

            let path = CGMutablePath()
            path.move(to: CGPoint(x: -topWidth / 2, y: 0))                   // top-left
            path.addLine(to: CGPoint(x: topWidth / 2, y: 0))                  // top-right
            path.addLine(to: CGPoint(x: bottomWidth / 2, y: -beamHeight))     // bottom-right
            path.addLine(to: CGPoint(x: -bottomWidth / 2, y: -beamHeight))    // bottom-left
            path.closeSubpath()

            if tractorBeamNode == nil {
                let beam = SKShapeNode()
                beam.fillColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 0.25)
                beam.strokeColor = SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.4)
                beam.lineWidth = 1.0
                beam.glowWidth = 3.0
                beam.zPosition = 45
                beam.name = "tractorBeam"
                addChild(beam)
                tractorBeamNode = beam
            }

            tractorBeamNode?.path = path
            tractorBeamNode?.position = CGPoint(x: saucer.position.x, y: saucerBottomY)

            // Check if beam is touching any animals
            checkTractorBeamAbduction()
        } else {
            removeTractorBeam()
        }
    }

    private func removeTractorBeam() {
        tractorBeamNode?.removeFromParent()
        tractorBeamNode = nil
    }

    // MARK: - Ground Scrolling

    private func scrollGround(dt: TimeInterval) {
        groundWorldOffset += baseGroundSpeed * speedMultiplier * CGFloat(dt)
        rebuildGroundPath()
    }

    // MARK: - Plane Spawning

    private func updatePlaneSpawning(dt: TimeInterval) {
        planeSpawnTimer += dt
        if planeSpawnTimer >= planeSpawnInterval {
            planeSpawnTimer = 0
            spawnPlane()
        }
    }

    // MARK: - Animal Spawning

    private func updateAnimalSpawning(dt: TimeInterval) {
        // Animals spawn in ocean, grassland, and city
        guard (gamePhase == .ocean || gamePhase == .grassland || gamePhase == .city) && !isTransitioning && !nearingPhaseEnd() else { return }
        animalSpawnTimer += dt
        if animalSpawnTimer >= animalSpawnInterval {
            animalSpawnTimer = 0
            spawnAnimal()
        }
    }

    private func spawnAnimal() {
        let animalName: String
        var isLegendary = false
        let legendaryRoll = Int.random(in: 1...50)

        if gamePhase == .ocean {
            animalName = "whale"
        } else if gamePhase == .grassland {
            if legendaryRoll == 1 {
                animalName = "bigfoot"
                isLegendary = true
            } else {
                // Humans are rarer: 1/6 chance for hiker, rest split between elk and cow
                let roll = Int.random(in: 1...6)
                if roll == 1 {
                    animalName = "hikerHuman"
                } else if roll <= 3 {
                    animalName = "cow"
                } else {
                    animalName = "elk"
                }
            }
        } else if gamePhase == .city {
            // Humans are rarer: 1/4 chance for workerHuman, rest is cat
            let roll = Int.random(in: 1...4)
            animalName = (roll == 1) ? "workerHuman" : "cat"
        } else {
            return
        }

        let animalSize: CGSize
        if animalName == "whale" {
            animalSize = CGSize(width: 40, height: 30)
        } else if animalName == "bigfoot" {
            animalSize = CGSize(width: 50, height: 55)
        } else if animalName == "hikerHuman" || animalName == "workerHuman" {
            animalSize = CGSize(width: 30, height: 45)
        } else {
            animalSize = CGSize(width: 40, height: 30)
        }

        let animal = SKSpriteNode(imageNamed: animalName)
        animal.size = animalSize
        animal.name = "animal"
        animal.zPosition = 7
        let isHuman = (animalName == "hikerHuman" || animalName == "workerHuman")
        let pointValue: Int = isLegendary ? 200 : (isHuman ? 30 : 10)
        animal.userData = NSMutableDictionary()
        animal.userData?["points"] = pointValue
        animal.userData?["legendary"] = isLegendary
        animal.userData?["creatureType"] = animalName

        // Position on the ground surface at the right edge
        let spawnScreenX = size.width + animalSize.width
        let worldX = groundWorldOffset + spawnScreenX
        let groundY = terrainHeight(at: worldX)
        let yOffset: CGFloat
        if animalName == "whale" {
            yOffset = animalSize.height * 0.10
        } else if animalName == "cow" {
            yOffset = animalSize.height / 2 - 8
        } else {
            yOffset = animalSize.height / 2
        }
        animal.position = CGPoint(x: spawnScreenX, y: groundY + yOffset)

        addChild(animal)

        let speed = baseGroundSpeed * speedMultiplier
        let distance = size.width + animalSize.width * 2
        let duration = TimeInterval(distance / speed)
        let moveLeft = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        animal.run(SKAction.sequence([moveLeft, SKAction.removeFromParent()]))
    }

    // MARK: - Oil Rig Spawning

    private func updateOilRigSpawning(dt: TimeInterval) {
        // Only spawn oil rigs during the ocean phase
        guard gamePhase == .ocean && !isTransitioning && !nearingPhaseEnd() else { return }
        oilRigSpawnTimer += dt
        if oilRigSpawnTimer >= oilRigSpawnInterval {
            oilRigSpawnTimer = 0
            spawnOilRig()
        }
    }

    private func spawnOilRig() {
        let rigWidth: CGFloat = 135
        let rigHeight: CGFloat = 180

        let oilRig = SKSpriteNode(imageNamed: "oilRig")
        oilRig.size = CGSize(width: rigWidth, height: rigHeight)
        oilRig.name = "oilRig"
        oilRig.zPosition = 7

        // Position on the ocean surface at the right edge
        let spawnScreenX = size.width + rigWidth
        let worldX = groundWorldOffset + spawnScreenX
        let groundY = terrainHeight(at: worldX)
        oilRig.position = CGPoint(x: spawnScreenX, y: groundY + rigHeight / 2 - 8)

        // Physics body so saucer crashes into it
        let body = SKPhysicsBody(rectangleOf: CGSize(width: rigWidth * 0.8, height: rigHeight))
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.obstacle
        body.contactTestBitMask = PhysicsCategory.saucer
        body.collisionBitMask = PhysicsCategory.none
        oilRig.physicsBody = body

        addChild(oilRig)

        // Move left with the ground speed
        let speed = baseGroundSpeed * speedMultiplier
        let distance = size.width + rigWidth * 2
        let duration = TimeInterval(distance / speed)
        let moveLeft = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        oilRig.run(SKAction.sequence([moveLeft, SKAction.removeFromParent()]))

        // 1/50 chance to spawn a kraken underneath the oil rig
        if Int.random(in: 1...50) == 1 {
            let krakenSize = CGSize(width: 60, height: 50)
            let kraken = SKSpriteNode(imageNamed: "kraken")
            kraken.size = krakenSize
            kraken.name = "animal"
            kraken.zPosition = 7
            kraken.userData = NSMutableDictionary()
            kraken.userData?["points"] = 200
            kraken.userData?["legendary"] = true
            kraken.userData?["creatureType"] = "kraken"
            kraken.position = CGPoint(x: spawnScreenX, y: groundY + krakenSize.height * 0.10)
            addChild(kraken)
            kraken.run(SKAction.sequence([moveLeft.copy() as! SKAction, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Tree Spawning

    private func updateTreeSpawning(dt: TimeInterval) {
        // Spawn trees only during grassland phase, not during transitions
        guard gamePhase == .grassland && !isTransitioning && !nearingPhaseEnd() else { return }
        treeSpawnTimer += dt
        if treeSpawnTimer >= treeSpawnInterval {
            treeSpawnTimer = 0
            spawnTree()
        }
    }

    private func spawnTree() {
        guard UIImage(named: "tree1") != nil else { return }

        let treeWidth: CGFloat = CGFloat.random(in: 35...55)
        let treeHeight: CGFloat = treeWidth * 1.8  // tall trees

        let tree = SKSpriteNode(imageNamed: "tree1")
        tree.size = CGSize(width: treeWidth, height: treeHeight)
        tree.name = "tree"
        tree.zPosition = 6

        // Position on the terrain surface at the right edge
        let spawnScreenX = size.width + treeWidth
        let worldX = groundWorldOffset + spawnScreenX
        let groundY = terrainHeight(at: worldX)
        tree.position = CGPoint(x: spawnScreenX, y: groundY + treeHeight / 2 - 8)

        addChild(tree)

        // Move left with the ground speed
        let speed = baseGroundSpeed * speedMultiplier
        let distance = size.width + treeWidth * 2
        let duration = TimeInterval(distance / speed)
        let moveLeft = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        tree.run(SKAction.sequence([moveLeft, SKAction.removeFromParent()]))
    }

    // MARK: - Skyscraper Spawning (City Phase)

    private func updateSkyscraperSpawning(dt: TimeInterval) {
        guard gamePhase == .city && !isTransitioning && !nearingPhaseEnd() else { return }
        skyscraperSpawnTimer += dt
        if skyscraperSpawnTimer >= skyscraperSpawnInterval {
            skyscraperSpawnTimer = 0
            spawnSkyscraper()
        }
    }

    private func spawnSkyscraper() {
        guard UIImage(named: "skyscrapers") != nil else { return }

        let buildingWidth: CGFloat = CGFloat.random(in: 150...240)
        let buildingHeight: CGFloat = CGFloat.random(in: 120...220)

        let building = SKSpriteNode(imageNamed: "skyscrapers")
        building.size = CGSize(width: buildingWidth, height: buildingHeight)
        building.name = "skyscraper"
        building.zPosition = 6

        // Position on the flat ground at the right edge
        let spawnScreenX = size.width + buildingWidth
        let worldX = groundWorldOffset + spawnScreenX
        let groundY = terrainHeight(at: worldX)
        building.position = CGPoint(x: spawnScreenX, y: groundY + buildingHeight / 2)

        // Physics body for collision (obstacle)
        building.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: buildingWidth * 0.8, height: buildingHeight * 0.9))
        building.physicsBody?.isDynamic = false
        building.physicsBody?.categoryBitMask = PhysicsCategory.obstacle
        building.physicsBody?.contactTestBitMask = PhysicsCategory.saucer
        building.physicsBody?.collisionBitMask = PhysicsCategory.none

        addChild(building)

        // Move left with ground speed
        let speed = baseGroundSpeed * speedMultiplier
        let distance = size.width + buildingWidth * 2
        let duration = TimeInterval(distance / speed)
        let moveLeft = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        building.run(SKAction.sequence([moveLeft, SKAction.removeFromParent()]))

        // 1/50 chance to spawn a werewolf on top of the skyscraper
        if Int.random(in: 1...50) == 1 {
            let wwSize = CGSize(width: 40, height: 50)
            let werewolf = SKSpriteNode(imageNamed: "werewolf")
            werewolf.size = wwSize
            werewolf.name = "animal"
            werewolf.zPosition = 8
            werewolf.userData = NSMutableDictionary()
            werewolf.userData?["points"] = 200
            werewolf.userData?["legendary"] = true
            werewolf.userData?["creatureType"] = "werewolf"
            werewolf.position = CGPoint(x: spawnScreenX, y: groundY + buildingHeight + wwSize.height / 2)
            addChild(werewolf)
            werewolf.run(SKAction.sequence([moveLeft.copy() as! SKAction, SKAction.removeFromParent()]))
        }
    }

    // MARK: - Tractor Beam Abduction

    /// Check if the tractor beam is touching any animals and abduct them.
    private func checkTractorBeamAbduction() {
        guard tractorBeamActive, let saucer = saucer else { return }

        let saucerX = saucer.position.x
        let saucerBottomY = saucer.position.y - 30
        let worldX = groundWorldOffset + saucerX
        let groundY = terrainHeight(at: worldX)

        // Beam covers from saucerBottomY down to groundY, centered on saucerX
        // Check horizontal range based on beam width at each animal's Y
        let animals = children.filter { $0.name == "animal" }
        for animal in animals {
            let animalX = animal.position.x
            let animalY = animal.position.y

            // Is the animal vertically within the beam? Allow slightly below groundY for submerged animals (whales)
            guard animalY <= saucerBottomY && animalY >= groundY - 20 else { continue }

            // Calculate beam width at this Y level
            let t = (saucerBottomY - animalY) / max(saucerBottomY - groundY, 1)  // 0 at top, 1 at bottom
            let beamHalfWidth = (12.0 + (40.0 + (saucerBottomY - groundY) * 0.1 - 12.0) * t) / 2.0

            // Is the animal horizontally within the beam?
            if abs(animalX - saucerX) <= beamHalfWidth + 20 {
                abductAnimal(animal)
            }
        }
    }

    private func abductAnimal(_ animal: SKNode) {
        animal.name = "abducting"  // prevent re-triggering
        animal.removeAllActions()

        // Award points based on animal type
        let points = (animal.userData?["points"] as? Int) ?? 10
        score += Double(points)

        // Check score achievements immediately after points awarded
        dataManager.checkScoreAchievements(currentScore: Int(score))

        // Track creature catch count (synced to iCloud, max 1,000,000)
        if let creatureType = animal.userData?["creatureType"] as? String {
            dataManager.incrementCatch(for: creatureType)
            dataManager.checkCatchAchievements(for: creatureType)
            playCreatureSound(for: creatureType)
        }

        // Show +points popup below the score label
        showPointsPopup(points: points)

        // Flash white and disappear
        let flashWhite = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.15)
        let fadeOut = SKAction.fadeOut(withDuration: 0.3)
        let moveUp = SKAction.moveBy(x: 0, y: 30, duration: 0.3)
        let group = SKAction.group([fadeOut, moveUp])
        let sequence = SKAction.sequence([flashWhite, group, SKAction.removeFromParent()])
        animal.run(sequence)

        // Flash the tractor beam white briefly
        if let beam = tractorBeamNode {
            let originalFill = beam.fillColor
            let originalStroke = beam.strokeColor
            beam.fillColor = SKColor(white: 1.0, alpha: 0.5)
            beam.strokeColor = SKColor(white: 1.0, alpha: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak beam] in
                beam?.fillColor = originalFill
                beam?.strokeColor = originalStroke
            }
        }
    }

    private func showPointsPopup(points: Int) {
        guard let scoreLabel = scoreLabel else { return }

        let popup = SKLabelNode(fontNamed: "AlienInvader")
        popup.text = "+\(points)"
        popup.fontSize = points >= 200 ? 22 : 18
        popup.yScale = fontYScale
        popup.fontColor = points >= 200 ? SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0) : SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
        popup.position = CGPoint(x: scoreLabel.position.x, y: scoreLabel.position.y - 25)
        popup.zPosition = 200
        popup.alpha = 1.0

        addChild(popup)

        let moveDown = SKAction.moveBy(x: 0, y: -20, duration: 0.8)
        let fadeOut = SKAction.fadeOut(withDuration: 0.8)
        let group = SKAction.group([moveDown, fadeOut])
        popup.run(SKAction.sequence([group, SKAction.removeFromParent()]))
    }

    // MARK: - Difficulty

    private func increaseDifficulty() {
        // Start at 2.5s, linearly decrease to 0.33s (3 per second) over 240 seconds (4 minutes)
        let t = min(elapsedTime / 240.0, 1.0)
        planeSpawnInterval = 2.5 - t * 2.17  // 2.5 → 0.33
    }

    // MARK: - GKGameCenterControllerDelegate

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
