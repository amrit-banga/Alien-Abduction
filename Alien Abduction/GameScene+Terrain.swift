//
//  GameScene+Terrain.swift
//  Alien Abduction
//

import SpriteKit

extension GameScene {

    // MARK: - Terrain Height

    func terrainHeight(at worldX: CGFloat) -> CGFloat {
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
    func grasslandHeight(at worldX: CGFloat) -> CGFloat {
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
    func currentMaxGroundHeight() -> CGFloat {
        var maxH: CGFloat = 0
        var x: CGFloat = 0
        while x <= size.width {
            let h = terrainHeight(at: groundWorldOffset + x)
            if h > maxH { maxH = h }
            x += 20
        }
        return maxH
    }

    // MARK: - Background

    func setupBackground() {
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

    func createPlaceholderMoon() -> SKSpriteNode {
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

    func addClouds(to parent: SKSpriteNode, count: Int) {
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

    func setupGround() {
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

    func updateScrollingSprites(_ s1: SKSpriteNode?, _ s2: SKSpriteNode?, show: Bool, alpha: CGFloat = 1.0) {
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

    func updateTransitionOverlay() {
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

    func updateOceanSprites() {
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
    func currentGroundColors() -> (fill: SKColor, stroke: SKColor) {
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
    func groundColors(for phase: GamePhase) -> (SKColor, SKColor) {
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

    func rebuildGroundPath() {
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

    // MARK: - Ground Scrolling

    func scrollGround(dt: TimeInterval) {
        groundWorldOffset += baseGroundSpeed * speedMultiplier * CGFloat(dt)
        rebuildGroundPath()
    }
}
