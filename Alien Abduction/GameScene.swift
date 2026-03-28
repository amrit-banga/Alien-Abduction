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
let dataManager = CloudDataManager.shared

class GameScene: SKScene, SKPhysicsContactDelegate, GKGameCenterControllerDelegate {

    // MARK: - Properties

    var gameState: GameState = .menu
    var gamePhase: GamePhase = .ocean
    var lastUpdateTime: TimeInterval = 0

    // Nodes
    var saucer: SKSpriteNode!
    var saucerFrames: [SKTexture] = []
    var startButton: SKShapeNode!
    var statsButton: SKShapeNode!
    var statsOverlay: SKSpriteNode?
    var helpButton: SKShapeNode!
    var helpOverlay: SKSpriteNode?
    var titleLabel: SKLabelNode!
    var gameOverOverlay: SKSpriteNode!
    var groundNode: SKShapeNode!
    var groundPhysicsNode: SKShapeNode!

    // HUD
    var scoreLabel: SKLabelNode!
    var pauseButton: SKShapeNode!
    var pauseOverlay: SKSpriteNode?

    // Background layers (static)
    var moonNode: SKSpriteNode!

    // Track whether real assets are available
    var hasSkyAsset: Bool { UIImage(named: "sky") != nil }
    var hasMoonAsset: Bool { UIImage(named: "moon") != nil }
    var hasSaucerAsset: Bool { UIImage(named: "alienSaucer") != nil }
    var hasOceanAsset: Bool { UIImage(named: "ocean") != nil }

    // Plane asset names
    let planeAssetNames = ["plane1", "plane2", "plane3"]

    // Scrolling speeds
    let baseGroundSpeed: CGFloat = 120.0
    let basePlaneSpeed: CGFloat = 140.0
    var speedMultiplier: CGFloat = 1.0

    // Saucer movement
    var movingUp = false
    var movingDown = false
    var tractorBeamActive = false
    var tractorBeamNode: SKShapeNode?
    let saucerMoveSpeed: CGFloat = 200.0
    let saucerTopMargin: CGFloat = 50.0
    let saucerBottomMargin: CGFloat = 140.0

    // Scrolling ocean sprites (two side by side for seamless loop)
    var oceanSprite1: SKSpriteNode?
    var oceanSprite2: SKSpriteNode?

    // Tree spawning (grassland phase)
    var treeSpawnTimer: TimeInterval = 0
    var treeSpawnInterval: TimeInterval = 1.2

    // Continuous ground terrain
    var groundWorldOffset: CGFloat = 0
    let terrainResolution: CGFloat = 4
    var elapsedTime: TimeInterval = 0

    // Phase timing
    let initialOceanDuration: TimeInterval = 60.0
    let initialGrasslandDuration: TimeInterval = 120.0
    let initialCityDuration: TimeInterval = 120.0
    var phaseStartTime: TimeInterval = 0
    var currentPhaseDuration: TimeInterval = 0
    var initialSequenceComplete = false

    // Skyscraper spawning (city phase)
    var skyscraperSpawnTimer: TimeInterval = 0
    var skyscraperSpawnInterval: TimeInterval = 1.5

    // Environment transition
    var transitionWorldX: CGFloat = 0
    let transitionSandWidth: CGFloat = 150.0
    var isTransitioning = false
    var transitionFromPhase: GamePhase = .ocean
    var transitionOverlay1: SKSpriteNode?
    var transitionOverlay2: SKSpriteNode?
    var grasslandOverlayNode: SKShapeNode?

    // Plane spawning
    var planeSpawnTimer: TimeInterval = 0
    var planeSpawnInterval: TimeInterval = 2.5

    // Animal spawning
    var animalSpawnTimer: TimeInterval = 0
    var animalSpawnInterval: TimeInterval = 4.0

    // Oil rig spawning (ocean only)
    var oilRigSpawnTimer: TimeInterval = 0
    var oilRigSpawnInterval: TimeInterval = 8.0

    // Idle saucer tracking
    var saucerIdleTimer: TimeInterval = 0
    var lastSaucerY: CGFloat = 0
    let saucerIdleThreshold: TimeInterval = 1.0

    // The absolute max terrain height possible (for plane spawn floor)
    let maxPossibleTerrainHeight: CGFloat = 280.0

    // Scoring
    var score: Double = 0

    // Font vertical stretch
    let fontYScale: CGFloat = 1.4

    // Audio
    var menuMusicPlayer: AVAudioPlayer?
    var gameMusicPlayer: AVAudioPlayer?
    var crossfadeTimer: Timer?
    let musicFadeDuration: TimeInterval = 3.0
    let crossfadeLeadTime: TimeInterval = 3.0
    var tractorBeamSoundAction: SKAction?

    // Audio preferences (persisted via iCloud)
    var isMusicOff: Bool {
        get { dataManager.bool(forKey: CloudDataManager.musicOffKey) }
        set { dataManager.set(newValue, forKey: CloudDataManager.musicOffKey) }
    }
    var isSoundOff: Bool {
        get { dataManager.bool(forKey: CloudDataManager.soundOffKey) }
        set { dataManager.set(newValue, forKey: CloudDataManager.soundOffKey) }
    }

    // World X where land hills actually begin (after a flat stretch)
    var landHillsStartWorldX: CGFloat = 0

    // Score achievement tracking
    var lastAchievementScoreCheck: Int = 0

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: .appDidEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: .appWillEnterForeground, object: nil)

        showSplashScreen()
    }

    @objc func appDidEnterBackground() {
        menuMusicPlayer?.pause()
        gameMusicPlayer?.pause()
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
    }

    @objc func appWillEnterForeground() {
        guard !isMusicOff && !isSoundOff else { return }
        if gameState == .menu || gameState == .gameOver {
            menuMusicPlayer?.play()
            scheduleCrossfadeLoop(for: menuMusicPlayer)
        } else if gameState == .playing {
            gameMusicPlayer?.play()
            scheduleCrossfadeLoop(for: gameMusicPlayer)
        }
    }

    // MARK: - Start Gameplay

    func startGame() {
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
        children.filter { $0.name == "titleLabel" }.forEach { $0.run(fadeOut) }
        titleLabel = nil

        setupHUD()
        playGameMusic()
    }

    // MARK: - Score

    func updateScore(dt: TimeInterval) {
        score += dt * 0.5
        scoreLabel?.text = "\(Int(score))"

        let currentScore = Int(score)
        if currentScore / 100 > lastAchievementScoreCheck / 100 {
            lastAchievementScoreCheck = currentScore
            dataManager.checkScoreAchievements(currentScore: currentScore)
        }
    }

    // MARK: - Quit to Menu

    func quitToMenu() {
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

    func updatePhase() {
        let previousPhase = gamePhase

        if !initialSequenceComplete {
            if elapsedTime < initialOceanDuration {
                gamePhase = .ocean
            } else if elapsedTime < initialOceanDuration + initialGrasslandDuration {
                gamePhase = .grassland
            } else if elapsedTime < initialOceanDuration + initialGrasslandDuration + initialCityDuration {
                gamePhase = .city
            } else {
                initialSequenceComplete = true
                switchToRandomPhase()
            }
        } else {
            let phaseElapsed = elapsedTime - phaseStartTime
            if phaseElapsed >= currentPhaseDuration {
                switchToRandomPhase()
            }
        }

        speedMultiplier = 1.0 + min(CGFloat(elapsedTime) * 0.002, 0.8)

        if previousPhase != gamePhase && !isTransitioning {
            beginTransition(from: previousPhase, to: gamePhase)
        }

        if isTransitioning && groundWorldOffset > transitionWorldX + transitionSandWidth + size.width * 0.3 {
            isTransitioning = false
            transitionOverlay1?.removeFromParent()
            transitionOverlay2?.removeFromParent()
            transitionOverlay1 = nil
            transitionOverlay2 = nil
            grasslandOverlayNode?.removeFromParent()
            grasslandOverlayNode = nil
            if gamePhase == .grassland {
                let flatDistance = baseGroundSpeed * speedMultiplier * 10.0
                landHillsStartWorldX = groundWorldOffset + flatDistance
            }
        }
    }

    func nearingPhaseEnd(buffer: TimeInterval = 0.5) -> Bool {
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

    func switchToRandomPhase() {
        let otherPhases = GamePhase.allCases.filter { $0 != gamePhase }
        gamePhase = otherPhases.randomElement()!
        phaseStartTime = elapsedTime
        currentPhaseDuration = TimeInterval.random(in: 60...120)
    }

    func beginTransition(from oldPhase: GamePhase, to newPhase: GamePhase) {
        isTransitioning = true
        transitionFromPhase = oldPhase
        transitionWorldX = groundWorldOffset + size.width

        transitionOverlay1?.removeFromParent()
        transitionOverlay2?.removeFromParent()
        transitionOverlay1 = nil
        transitionOverlay2 = nil

        if oldPhase != .ocean {
            let oldColor: SKColor
            switch oldPhase {
            case .grassland:
                oldColor = SKColor(red: 0.18, green: 0.40, blue: 0.12, alpha: 1.0)
            case .city:
                oldColor = SKColor(red: 0.20, green: 0.20, blue: 0.22, alpha: 1.0)
            case .ocean:
                oldColor = .clear
            }
            let h: CGFloat = 50
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

    // MARK: - Saucer

    func setupSaucer() {
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

    func createPlaceholderSaucer() -> SKSpriteNode {
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

    // MARK: - Collision

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .playing else { return }

        let categories = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if categories & PhysicsCategory.saucer != 0 &&
           (categories & PhysicsCategory.obstacle != 0 || categories & PhysicsCategory.ground != 0) {
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

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        switch gameState {
        case .menu:
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

    func handleTouchInput(location: CGPoint) {
        let third = size.width / 3
        if location.x > third * 2 {
            movingUp = true
            movingDown = false
            tractorBeamActive = false
        } else if location.x > third {
            movingUp = false
            movingDown = false
            if !tractorBeamActive {
                playTractorBeamSound()
            }
            tractorBeamActive = true
        } else {
            movingUp = false
            movingDown = true
            tractorBeamActive = false
        }
    }

    // MARK: - Restart

    func restartGame() {
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

    func updateSaucerPosition(dt: TimeInterval) {
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

    // MARK: - GKGameCenterControllerDelegate

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
