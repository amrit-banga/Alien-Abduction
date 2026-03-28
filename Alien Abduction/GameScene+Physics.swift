//
//  GameScene+Physics.swift
//  Alien Abduction
//

import SpriteKit

extension GameScene {

    // MARK: - Explosion

    func createExplosion(at position: CGPoint) -> SKEmitterNode {
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

    func triggerGameOver(at contactPoint: CGPoint? = nil, obstacle: SKNode? = nil) {
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

    func saveHighScore() {
        dataManager.highScore = Int(score)
    }

    // MARK: - Tractor Beam

    func updateTractorBeam() {
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

    func removeTractorBeam() {
        tractorBeamNode?.removeFromParent()
        tractorBeamNode = nil
    }

    // MARK: - Tractor Beam Abduction

    /// Check if the tractor beam is touching any animals and abduct them.
    func checkTractorBeamAbduction() {
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

    func abductAnimal(_ animal: SKNode) {
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
}
