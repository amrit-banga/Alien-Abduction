//
//  GameScene+PowerUps.swift
//  Alien Abduction
//

import SpriteKit

enum PowerUpKind: String, CaseIterable {
    case doublePoints
    case shield
}

extension GameScene {

    var currentPointsMultiplier: Double {
        doublePointsTimeRemaining > 0 ? 2.0 : 1.0
    }

    func resetPowerUpsForNewRun() {
        activePowerUp?.removeFromParent()
        activePowerUp = nil
        powerUpSpawnTimer = 0
        lastSpawnedPowerUpKind = nil
        doublePointsTimeRemaining = 0
        doublePointsIndicator?.removeFromParent()
        doublePointsIndicator = nil
        doublePointsIndicatorLabel = nil
        hasShield = false
        stopShieldHum()
        shieldVisual?.removeFromParent()
        shieldVisual = nil
        shieldInvincibilityTimeRemaining = 0
        saucer?.removeAction(forKey: "shieldInvincibility")
        saucer?.alpha = 1
    }

    func updatePowerUps(dt: TimeInterval) {
        updateDoublePointsDuration(dt: dt)
        updateShieldInvincibility(dt: dt)
        updatePowerUpSpawning(dt: dt)
    }

    private func updatePowerUpSpawning(dt: TimeInterval) {
        powerUpSpawnTimer += dt
        guard activePowerUp == nil,
              powerUpSpawnTimer >= powerUpSpawnInterval else { return }

        // If every sky lane is temporarily occupied by planes, leave the timer
        // ready and retry next frame instead of creating an unsafe power-up.
        if spawnRandomPowerUp() {
            powerUpSpawnTimer = 0
        }
    }

    @discardableResult
    func spawnRandomPowerUp() -> Bool {
        let kind: PowerUpKind
        switch lastSpawnedPowerUpKind {
        case .doublePoints:
            kind = .shield
        case .shield:
            kind = .doublePoints
        case nil:
            guard let firstKind = PowerUpKind.allCases.randomElement() else { return false }
            kind = firstKind
        }
        return spawnPowerUp(kind)
    }

    @discardableResult
    func spawnDoublePointsPowerUp() -> Bool {
        spawnPowerUp(.doublePoints)
    }

    @discardableResult
    func spawnShieldPowerUp() -> Bool {
        spawnPowerUp(.shield)
    }

    private func spawnPowerUp(_ kind: PowerUpKind) -> Bool {
        guard activePowerUp == nil, let spawnY = safePowerUpSpawnY() else { return false }

        let powerUp = SKNode()
        powerUp.name = "powerUp"
        powerUp.position = CGPoint(x: size.width + 36, y: spawnY)
        powerUp.zPosition = 60
        powerUp.userData = NSMutableDictionary()
        powerUp.userData?["type"] = kind.rawValue

        let orb = SKShapeNode(circleOfRadius: 28)
        switch kind {
        case .doublePoints:
            orb.fillColor = SKColor(red: 0.1, green: 1.0, blue: 0.35, alpha: 0.28)
            orb.strokeColor = SKColor(red: 0.25, green: 1.0, blue: 0.45, alpha: 1.0)
        case .shield:
            orb.fillColor = SKColor(red: 0.15, green: 0.65, blue: 1.0, alpha: 0.28)
            orb.strokeColor = SKColor(red: 0.3, green: 0.8, blue: 1.0, alpha: 1.0)
        }
        orb.lineWidth = 3
        orb.glowWidth = 8
        powerUp.addChild(orb)

        let core = SKShapeNode(circleOfRadius: 18)
        switch kind {
        case .doublePoints:
            core.fillColor = SKColor(red: 0.03, green: 0.38, blue: 0.1, alpha: 0.82)
            core.strokeColor = SKColor(red: 0.3, green: 1.0, blue: 0.45, alpha: 0.9)
        case .shield:
            core.fillColor = SKColor(red: 0.03, green: 0.2, blue: 0.45, alpha: 0.82)
            core.strokeColor = SKColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 0.9)
        }
        core.lineWidth = 1.5
        powerUp.addChild(core)

        switch kind {
        case .doublePoints:
            let label = SKLabelNode(fontNamed: "AlienInvader")
            label.text = "2X"
            label.fontSize = 18
            label.yScale = fontYScale
            label.fontColor = SKColor(red: 0.3, green: 1.0, blue: 0.45, alpha: 1.0)
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.zPosition = 1
            powerUp.addChild(label)

        case .shield:
            let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            let iconGray = UIColor(white: 0.72, alpha: 1.0)
            if let symbol = UIImage(systemName: "shield.fill", withConfiguration: configuration) {
                let image = symbol.withTintColor(iconGray, renderingMode: .alwaysOriginal)
                let icon = SKSpriteNode(texture: SKTexture(image: image))
                icon.name = "shieldPowerUpIcon"
                icon.size = CGSize(width: 22, height: 25)
                icon.color = .white
                icon.colorBlendFactor = 0
                icon.zPosition = 1
                powerUp.addChild(icon)
            }
        }

        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.45),
            SKAction.scale(to: 0.96, duration: 0.45)
        ])
        orb.run(SKAction.repeatForever(pulse))

        let body = SKPhysicsBody(circleOfRadius: 27)
        body.isDynamic = true
        body.affectedByGravity = false
        body.categoryBitMask = PhysicsCategory.powerUp
        body.contactTestBitMask = PhysicsCategory.saucer
        body.collisionBitMask = PhysicsCategory.none
        powerUp.physicsBody = body

        activePowerUp = powerUp
        lastSpawnedPowerUpKind = kind
        addChild(powerUp)

        let speed = baseGroundSpeed * speedMultiplier
        let distance = size.width + 72
        let duration = TimeInterval(distance / speed)
        let moveLeft = SKAction.moveBy(x: -distance, y: 0, duration: duration)
        let leaveScreen = SKAction.run { [weak self, weak powerUp] in
            guard let self, let powerUp, self.activePowerUp === powerUp else { return }
            self.activePowerUp = nil
        }
        powerUp.run(SKAction.sequence([moveLeft, leaveScreen, SKAction.removeFromParent()]))
        return true
    }

    private func safePowerUpSpawnY() -> CGFloat? {
        let minY = max(maxPossibleTerrainHeight + 55, saucerBottomMargin + 55)
        let maxY = size.height - saucerTopMargin - 35
        guard maxY > minY else { return nil }

        let planeYs = children.filter { $0.name == "plane" }.map(\.position.y)
        for _ in 0..<30 {
            let candidate = CGFloat.random(in: minY...maxY)
            if planeYs.allSatisfy({ abs($0 - candidate) >= powerUpPlaneClearance }) {
                return candidate
            }
        }
        return nil
    }

    func safePlaneSpawnY(minY: CGFloat, maxY: CGFloat) -> CGFloat? {
        guard maxY > minY else { return minY }
        guard let powerUpY = activePowerUp?.position.y else {
            return CGFloat.random(in: minY...maxY)
        }

        for _ in 0..<30 {
            let candidate = CGFloat.random(in: minY...maxY)
            if abs(candidate - powerUpY) >= powerUpPlaneClearance {
                return candidate
            }
        }

        // Fall back to the edge of the available sky that is farthest from the
        // orb. If even that is too close, skip this plane spawn.
        let fallback = abs(minY - powerUpY) > abs(maxY - powerUpY) ? minY : maxY
        return abs(fallback - powerUpY) >= powerUpPlaneClearance ? fallback : nil
    }

    func isPlaneLaneAvailable(atY y: CGFloat) -> Bool {
        guard let powerUpY = activePowerUp?.position.y else { return true }
        return abs(y - powerUpY) >= powerUpPlaneClearance
    }

    func collectPowerUp(_ powerUp: SKNode) {
        guard powerUp === activePowerUp,
              let rawKind = powerUp.userData?["type"] as? String,
              let kind = PowerUpKind(rawValue: rawKind) else { return }

        let collectionPosition = powerUp.position
        activePowerUp = nil
        powerUp.name = "collectedPowerUp"
        powerUp.physicsBody = nil
        powerUp.removeAllActions()

        switch kind {
        case .doublePoints:
            activateDoublePoints()
        case .shield:
            collectShieldPowerUp()
        }
        addChild(createGreenPowerUpBurst(at: collectionPosition))

        powerUp.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.5, duration: 0.16),
                SKAction.fadeOut(withDuration: 0.16)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    private func activateDoublePoints() {
        doublePointsTimeRemaining = doublePointsDuration
        playDoublePointsPickupSound()
        doublePointsIndicator?.isHidden = false
        updateDoublePointsIndicator()

        doublePointsIndicator?.removeAction(forKey: "activationPulse")
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.18)
        ])
        doublePointsIndicator?.run(pulse, withKey: "activationPulse")
    }

    func collectShieldPowerUp() {
        playShieldPickupSound()

        if hasShield {
            let points = Int(100.0 * currentPointsMultiplier)
            score += Double(points)
            scoreLabel?.text = "\(Int(score))"
            dataManager.checkScoreAchievements(currentScore: Int(score))
            showPointsPopup(points: points)
            return
        }

        hasShield = true
        installShieldVisual()
        playShieldHumIfActive()
    }

    private func installShieldVisual() {
        shieldVisual?.removeFromParent()
        guard let saucer else { return }

        // This is a visual child only. It deliberately has no physics body, so
        // the saucer's original collision shape remains unchanged.
        let shield = SKShapeNode(ellipseOf: CGSize(width: 70, height: 49))
        shield.name = "shieldVisual"
        shield.fillColor = SKColor(red: 0.2, green: 0.75, blue: 1.0, alpha: 0.12)
        shield.strokeColor = SKColor(red: 0.35, green: 0.85, blue: 1.0, alpha: 0.9)
        shield.lineWidth = 0.3
        shield.glowWidth = 3
        shield.zPosition = 10
        saucer.addChild(shield)
        shieldVisual = shield

        let shimmer = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.68, duration: 0.55),
            SKAction.fadeAlpha(to: 1.0, duration: 0.55)
        ])
        shield.run(SKAction.repeatForever(shimmer), withKey: "shieldShimmer")
    }

    func breakShield(at contactPoint: CGPoint) {
        guard hasShield else { return }

        hasShield = false
        stopShieldHum()
        shieldInvincibilityTimeRemaining = shieldInvincibilityDuration

        let brokenShield = shieldVisual
        shieldVisual = nil
        brokenShield?.removeAllActions()
        brokenShield?.run(SKAction.sequence([
            SKAction.group([
                SKAction.scale(to: 1.35, duration: 0.12),
                SKAction.fadeOut(withDuration: 0.12)
            ]),
            SKAction.removeFromParent()
        ]))

        addChild(createBlueShieldBurst(at: contactPoint))
        playShieldBreakSound()

        let flashHalfCycleDuration: TimeInterval = 0.1
        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.35, duration: flashHalfCycleDuration),
            SKAction.fadeAlpha(to: 1.0, duration: flashHalfCycleDuration)
        ])
        let flashCount = max(
            1,
            Int(ceil(shieldInvincibilityDuration / flash.duration))
        )
        saucer?.run(
            SKAction.repeat(flash, count: flashCount),
            withKey: "shieldInvincibility"
        )
    }

    func shieldCanAbsorbCollision(categoryBitMask: UInt32) -> Bool {
        hasShield && categoryBitMask & PhysicsCategory.obstacle != 0
    }

    private func updateShieldInvincibility(dt: TimeInterval) {
        guard shieldInvincibilityTimeRemaining > 0 else { return }
        shieldInvincibilityTimeRemaining = max(0, shieldInvincibilityTimeRemaining - dt)
        if shieldInvincibilityTimeRemaining == 0 {
            saucer?.removeAction(forKey: "shieldInvincibility")
            saucer?.alpha = 1
        }
    }

    private func updateDoublePointsDuration(dt: TimeInterval) {
        guard doublePointsTimeRemaining > 0 else { return }
        doublePointsTimeRemaining = max(0, doublePointsTimeRemaining - dt)
        updateDoublePointsIndicator()

        if doublePointsTimeRemaining == 0 {
            doublePointsIndicator?.isHidden = true
            doublePointsIndicator?.setScale(1)
        }
    }

    private func updateDoublePointsIndicator() {
        let seconds = Int(ceil(doublePointsTimeRemaining))
        doublePointsIndicatorLabel?.text = String(
            format: "2X POINTS %d:%02d",
            seconds / 60,
            seconds % 60
        )
    }

    func createGreenPowerUpBurst(at position: CGPoint) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 70

        let textureSize = CGSize(width: 7, height: 7)
        UIGraphicsBeginImageContextWithOptions(textureSize, false, 0)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: textureSize)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let image {
            emitter.particleTexture = SKTexture(image: image)
        }

        emitter.particleBirthRate = 500
        emitter.numParticlesToEmit = 45
        emitter.particleLifetime = 0.38
        emitter.particleLifetimeRange = 0.12
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 125
        emitter.particleSpeedRange = 55
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -2.6
        emitter.particleScale = 0.9
        emitter.particleScaleRange = 0.35
        emitter.particleScaleSpeed = -1.4
        emitter.particleColorSequence = nil
        emitter.particleColorBlendFactor = 1
        emitter.particleColor = SKColor(red: 0.15, green: 1.0, blue: 0.35, alpha: 1.0)
        emitter.particleColorGreenRange = 0.2

        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.7),
            SKAction.removeFromParent()
        ]))
        return emitter
    }

    func createBlueShieldBurst(at position: CGPoint) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.position = position
        emitter.zPosition = 70

        let textureSize = CGSize(width: 7, height: 7)
        UIGraphicsBeginImageContextWithOptions(textureSize, false, 0)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: textureSize)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let image {
            emitter.particleTexture = SKTexture(image: image)
        }

        emitter.particleBirthRate = 700
        emitter.numParticlesToEmit = 65
        emitter.particleLifetime = 0.48
        emitter.particleLifetimeRange = 0.15
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 155
        emitter.particleSpeedRange = 75
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -2.2
        emitter.particleScale = 0.9
        emitter.particleScaleRange = 0.4
        emitter.particleScaleSpeed = -1.3
        emitter.particleColorSequence = nil
        emitter.particleColorBlendFactor = 1
        emitter.particleColor = SKColor(red: 0.25, green: 0.8, blue: 1.0, alpha: 1.0)
        emitter.particleColorBlueRange = 0.18
        emitter.particleColorGreenRange = 0.15

        emitter.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.8),
            SKAction.removeFromParent()
        ]))
        return emitter
    }
}
