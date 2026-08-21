//
//  Alien_AbductionTests.swift
//  Alien AbductionTests
//
//  Created by Amrit Banga on 3/19/26.
//

import XCTest
import CoreGraphics
import SpriteKit
@testable import Alien_Abduction

final class Alien_AbductionTests: XCTestCase {

    func testHUDStaysInsideCompatibilitySafeArea() {
        // A narrow safe frame models the rounded/cropped compatibility window
        // presented on an 11-inch iPad.
        let safeFrame = CGRect(x: 28, y: 20, width: 334, height: 627)
        let hud = GameUILayout.hudCenters(in: safeFrame)
        let pauseFrame = CGRect(
            x: hud.pause.x - GameUILayout.hudControlSize.width / 2,
            y: hud.pause.y - GameUILayout.hudControlSize.height / 2,
            width: GameUILayout.hudControlSize.width,
            height: GameUILayout.hudControlSize.height
        )

        XCTAssertGreaterThanOrEqual(pauseFrame.minX, safeFrame.minX)
        XCTAssertLessThanOrEqual(pauseFrame.maxX, safeFrame.maxX)
        XCTAssertGreaterThanOrEqual(pauseFrame.minY, safeFrame.minY)
        XCTAssertLessThanOrEqual(pauseFrame.maxY, safeFrame.maxY)
    }

    func testShootingStarsSpawnEverySevenSecondsBehindGameplay() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))

        scene.updateShootingStars(dt: 6.9)
        XCTAssertNil(scene.children.first { $0.name == "shootingStar" })

        scene.updateShootingStars(dt: 0.2)
        let star = try XCTUnwrap(scene.children.first { $0.name == "shootingStar" })
        XCTAssertEqual(scene.shootingStarInterval, 7)
        XCTAssertNil(star.physicsBody)
        XCTAssertGreaterThan(star.zPosition, -10)
        XCTAssertLessThan(star.zPosition, -8)
    }

    func testPauseMenuButtonsNeverOverlapOnShortViewport() {
        let safeFrame = CGRect(x: 28, y: 20, width: 334, height: 627)
        let layout = GameUILayout.pauseMenuPositions(in: safeFrame)
        let expectedCenterSpacing = GameUILayout.pauseMenuButtonSize.height + GameUILayout.pauseMenuButtonGap

        XCTAssertEqual(layout.buttonYs.count, 5)
        for index in 1..<layout.buttonYs.count {
            XCTAssertEqual(layout.buttonYs[index - 1] - layout.buttonYs[index], expectedCenterSpacing)
        }

        let topEdge = layout.buttonYs[0] + GameUILayout.pauseMenuButtonSize.height / 2
        let bottomEdge = layout.buttonYs[4] - GameUILayout.pauseMenuButtonSize.height / 2
        XCTAssertLessThanOrEqual(topEdge, safeFrame.maxY)
        XCTAssertGreaterThanOrEqual(bottomEdge, safeFrame.minY)
    }

    func testControlsOverlayBackgroundMatchesEntryPoint() {
        let menuScene = GameScene(size: CGSize(width: 390, height: 844))
        menuScene.showHelpOverlay()
        XCTAssertEqual(menuScene.helpOverlay?.alpha, CGFloat(1))

        let firstPlayScene = GameScene(size: CGSize(width: 390, height: 844))
        firstPlayScene.showHelpOverlay(
            resumesGameOnDismissal: true,
            transparentBackground: true
        )
        XCTAssertEqual(firstPlayScene.helpOverlay?.alpha, CGFloat(0.82))

        let pauseScene = GameScene(size: CGSize(width: 390, height: 844))
        pauseScene.showHelpOverlay(transparentBackground: true)
        XCTAssertEqual(pauseScene.helpOverlay?.alpha, CGFloat(0.82))
    }

    func testPauseControlsTemporarilyHidePauseMenu() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.gameState = .paused

        let pauseBackground = SKSpriteNode()
        pauseBackground.name = "pauseOverlay"
        scene.pauseOverlay = pauseBackground
        scene.addChild(pauseBackground)

        let controlsButton = SKNode()
        controlsButton.name = "controlsButton"
        scene.addChild(controlsButton)

        scene.showPauseControlsOverlay()
        XCTAssertTrue(pauseBackground.isHidden)
        XCTAssertTrue(controlsButton.isHidden)
        XCTAssertEqual(scene.helpOverlay?.alpha, CGFloat(0.82))

        scene.dismissHelpOverlay()
        XCTAssertFalse(pauseBackground.isHidden)
        XCTAssertFalse(controlsButton.isHidden)
    }

    func testDoublePointsMultiplierOnlyAppliesWhileActive() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))

        scene.doublePointsTimeRemaining = 0
        XCTAssertEqual(scene.currentPointsMultiplier, 1)

        scene.doublePointsTimeRemaining = 30
        XCTAssertEqual(scene.currentPointsMultiplier, 2)
    }

    func testPowerUpEffectDurations() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))

        XCTAssertEqual(scene.doublePointsDuration, 30)
        XCTAssertEqual(scene.shieldInvincibilityDuration, 2)
        XCTAssertEqual(scene.powerUpSpawnInterval, 31)
    }

    func testPowerUpTypesAlternateAfterFirstSpawn() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))

        XCTAssertTrue(scene.spawnDoublePointsPowerUp())
        XCTAssertEqual(scene.lastSpawnedPowerUpKind, .doublePoints)
        scene.activePowerUp?.removeFromParent()
        scene.activePowerUp = nil

        XCTAssertTrue(scene.spawnRandomPowerUp())
        XCTAssertEqual(scene.lastSpawnedPowerUpKind, .shield)
        XCTAssertEqual(scene.activePowerUp?.userData?["type"] as? String, PowerUpKind.shield.rawValue)
        scene.activePowerUp?.removeFromParent()
        scene.activePowerUp = nil

        XCTAssertTrue(scene.spawnRandomPowerUp())
        XCTAssertEqual(scene.lastSpawnedPowerUpKind, .doublePoints)
        XCTAssertEqual(scene.activePowerUp?.userData?["type"] as? String, PowerUpKind.doublePoints.rawValue)
    }

    func testActivePowerUpProtectsItsPlaneLane() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        let powerUp = SKNode()
        powerUp.position.y = 400
        scene.activePowerUp = powerUp

        XCTAssertFalse(scene.isPlaneLaneAvailable(atY: 489))
        XCTAssertTrue(scene.isPlaneLaneAvailable(atY: 490))
        XCTAssertTrue(scene.isPlaneLaneAvailable(atY: 250))
    }

    func testTreesAreSaucerObstacles() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.spawnTree()

        let tree = try XCTUnwrap(scene.children.first { $0.name == "tree" })
        let body = try XCTUnwrap(tree.physicsBody)
        XCTAssertTrue(body.isDynamic)
        XCTAssertFalse(body.affectedByGravity)
        XCTAssertEqual(body.categoryBitMask, PhysicsCategory.obstacle)
        XCTAssertEqual(body.contactTestBitMask, PhysicsCategory.saucer)
        XCTAssertEqual(body.collisionBitMask, PhysicsCategory.none)
    }

    func testGrassDetailsOnlyAppearInGrassland() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.setupGround()

        scene.gamePhase = .grassland
        scene.rebuildGroundPath()
        XCTAssertFalse(try XCTUnwrap(scene.grassBladeDetailNode).isHidden)
        XCTAssertFalse(try XCTUnwrap(scene.grassBladeDetailNode?.path).isEmpty)

        scene.gamePhase = .ocean
        scene.rebuildGroundPath()
        XCTAssertTrue(try XCTUnwrap(scene.grassBladeDetailNode).isHidden)
    }

    func testWaterDetailsOnlyAppearInOcean() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.setupGround()

        scene.gamePhase = .ocean
        scene.rebuildGroundPath()
        XCTAssertFalse(try XCTUnwrap(scene.waterDetailNode).isHidden)
        XCTAssertFalse(try XCTUnwrap(scene.waterDetailNode?.path).isEmpty)
        XCTAssertFalse(try XCTUnwrap(scene.waterHighlightDetailNode).isHidden)
        XCTAssertFalse(try XCTUnwrap(scene.waterHighlightDetailNode?.path).isEmpty)

        scene.gamePhase = .grassland
        scene.rebuildGroundPath()
        XCTAssertTrue(try XCTUnwrap(scene.waterDetailNode).isHidden)
        XCTAssertTrue(try XCTUnwrap(scene.waterHighlightDetailNode).isHidden)
    }

    func testTerrainGeometryTranslatesBetweenThrottledRebuilds() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.setupGround()

        let initialBaseOffset = try XCTUnwrap(scene.terrainGeometryBaseOffset)
        scene.groundWorldOffset = initialBaseOffset + 5
        scene.rebuildGroundPath()

        XCTAssertEqual(
            try XCTUnwrap(scene.terrainGeometryBaseOffset),
            initialBaseOffset,
            accuracy: 0.001
        )
        XCTAssertEqual(scene.groundNode.position.x, -5, accuracy: 0.001)
        XCTAssertEqual(scene.groundPhysicsNode.position.x, -5, accuracy: 0.001)

        scene.groundWorldOffset = initialBaseOffset + scene.terrainGeometryRebuildDistance
        scene.rebuildGroundPath()

        XCTAssertEqual(
            try XCTUnwrap(scene.terrainGeometryBaseOffset),
            scene.groundWorldOffset,
            accuracy: 0.001
        )
        XCTAssertEqual(scene.groundNode.position.x, 0, accuracy: 0.001)
        XCTAssertEqual(scene.groundPhysicsNode.position.x, 0, accuracy: 0.001)
    }

    func testGrasslandFlattensBeforeCityBoundary() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.groundWorldOffset = 1_000
        scene.landHillsStartWorldX = 0
        scene.gamePhase = .city
        scene.beginTransition(from: .grassland, to: .city)

        let expectedBoundary = scene.groundWorldOffset + scene.size.width +
            scene.grasslandCityFlattenDistance
        XCTAssertEqual(scene.transitionWorldX, expectedBoundary, accuracy: 0.01)

        let heightJustBeforeCity = scene.terrainHeight(at: scene.transitionWorldX - 0.1)
        let cityHeight = scene.terrainHeight(at: scene.transitionWorldX)
        XCTAssertEqual(heightJustBeforeCity, 50, accuracy: 0.01)
        XCTAssertEqual(cityHeight, 50, accuracy: 0.01)
    }

    func testCityGroundIsDarkGray() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        let colors = scene.groundColors(for: .city)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        XCTAssertTrue(colors.0.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red, 0.19, accuracy: 0.001)
        XCTAssertEqual(green, 0.19, accuracy: 0.001)
        XCTAssertEqual(blue, 0.21, accuracy: 0.001)
    }

    func testCityDetailsOnlyAppearInCity() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.setupGround()

        scene.gamePhase = .city
        scene.rebuildGroundPath()
        XCTAssertFalse(try XCTUnwrap(scene.cityDetailNode).isHidden)
        XCTAssertFalse(try XCTUnwrap(scene.cityDetailNode?.path).isEmpty)

        scene.gamePhase = .ocean
        scene.rebuildGroundPath()
        XCTAssertTrue(try XCTUnwrap(scene.cityDetailNode).isHidden)
    }

    func testSkyscrapersStopSpawningBeforeCityTransition() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.gamePhase = .city
        scene.initialSequenceComplete = true
        scene.phaseStartTime = 0
        scene.currentPhaseDuration = 60
        scene.skyscraperSpawnTimer = scene.skyscraperSpawnInterval

        scene.elapsedTime = 56
        scene.updateSkyscraperSpawning(dt: 0)
        XCTAssertNotNil(scene.children.first { $0.name == "skyscraper" })

        scene.children.filter { $0.name == "skyscraper" }.forEach { $0.removeFromParent() }
        scene.skyscraperSpawnTimer = scene.skyscraperSpawnInterval
        scene.elapsedTime = 57
        scene.updateSkyscraperSpawning(dt: 0)
        XCTAssertNil(scene.children.first { $0.name == "skyscraper" })

        let maximumEntryTime = TimeInterval((240 * 1.5) / scene.baseGroundSpeed)
        XCTAssertGreaterThan(scene.skyscraperTransitionClearance, maximumEntryTime)
    }

    func testShieldVisualDoesNotChangeSaucerHitbox() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        let saucer = SKSpriteNode(color: .clear, size: CGSize(width: 90, height: 90))
        let originalBody = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 30))
        saucer.physicsBody = originalBody
        scene.saucer = saucer
        scene.addChild(saucer)

        scene.collectShieldPowerUp()

        XCTAssertTrue(scene.hasShield)
        XCTAssertTrue(scene.shieldVisual?.parent === saucer)
        XCTAssertNil(scene.shieldVisual?.physicsBody)
        XCTAssertTrue(saucer.physicsBody === originalBody)
        let shieldPath = try XCTUnwrap(scene.shieldVisual?.path)
        XCTAssertEqual(shieldPath.boundingBox.width, 70, accuracy: 0.01)
        XCTAssertEqual(shieldPath.boundingBox.height, 49, accuracy: 0.01)
        XCTAssertEqual(scene.shieldVisual?.lineWidth, CGFloat(0.3))
    }

    func testShieldPowerUpUsesGrayIcon() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        XCTAssertTrue(scene.spawnShieldPowerUp())

        let powerUp = try XCTUnwrap(scene.activePowerUp)
        let icon = try XCTUnwrap(
            powerUp.children.first { $0.name == "shieldPowerUpIcon" } as? SKSpriteNode
        )
        XCTAssertEqual(icon.colorBlendFactor, 0)
    }

    func testShieldAbsorbsEveryObstacleCategoryAcrossBiomes() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.hasShield = true

        let obstacleContact = PhysicsCategory.saucer | PhysicsCategory.obstacle
        let groundContact = PhysicsCategory.saucer | PhysicsCategory.ground

        // Plane, tree, oil-rig, and skyscraper bodies all use `.obstacle`.
        XCTAssertTrue(scene.shieldCanAbsorbCollision(categoryBitMask: obstacleContact))
        XCTAssertFalse(scene.shieldCanAbsorbCollision(categoryBitMask: groundContact))

        scene.hasShield = false
        XCTAssertFalse(scene.shieldCanAbsorbCollision(categoryBitMask: obstacleContact))
    }

    func testShieldBreakFlashesForFullInvincibilityDuration() throws {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        let saucer = SKSpriteNode()
        scene.saucer = saucer
        scene.addChild(saucer)
        scene.hasShield = true

        scene.breakShield(at: .zero)

        let flash = try XCTUnwrap(saucer.action(forKey: "shieldInvincibility"))
        XCTAssertEqual(flash.duration, scene.shieldInvincibilityDuration, accuracy: 0.001)
        XCTAssertEqual(
            scene.shieldInvincibilityTimeRemaining,
            scene.shieldInvincibilityDuration,
            accuracy: 0.001
        )
    }

    func testDuplicateShieldAwardsOneHundredBasePoints() {
        let scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.hasShield = true

        scene.collectShieldPowerUp()
        XCTAssertEqual(scene.score, 100)

        scene.doublePointsTimeRemaining = 30
        scene.collectShieldPowerUp()
        XCTAssertEqual(scene.score, 300)
    }

}
