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
        var height = max(total, 20.0)

        // When grassland is handing off to the city, the city boundary is
        // placed farther ahead and this final stretch eases the hills to the
        // city's flat ground height. Because the blend starts offscreen, the
        // currently visible terrain never snaps into a different shape.
        if isTransitioning,
           transitionFromPhase == .grassland,
           gamePhase == .city {
            let flattenStart = transitionWorldX - grasslandCityFlattenDistance
            if worldX >= flattenStart {
                let remaining = max(
                    0,
                    min(1, (transitionWorldX - worldX) / grasslandCityFlattenDistance)
                )
                let smoothRemaining = remaining * remaining * (3 - 2 * remaining)
                height = flatHeight + (height - flatHeight) * smoothRemaining
            }
        }

        return height
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

    func updateShootingStars(dt: TimeInterval) {
        shootingStarTimer += dt
        guard shootingStarTimer >= shootingStarInterval else { return }

        shootingStarTimer = shootingStarTimer.truncatingRemainder(
            dividingBy: shootingStarInterval
        )
        spawnShootingStar()
    }

    func spawnShootingStar() {
        let star = SKNode()
        star.name = "shootingStar"
        star.zPosition = -9.4
        star.alpha = 0
        star.position = CGPoint(
            x: CGFloat.random(in: size.width * 0.35...size.width * 0.95),
            y: CGFloat.random(in: size.height * 0.68...size.height * 0.92)
        )

        let trailLength = CGFloat.random(in: 42...58)
        let trailPath = CGMutablePath()
        trailPath.move(to: .zero)
        trailPath.addLine(to: CGPoint(x: trailLength, y: trailLength * 0.42))

        let trail = SKShapeNode(path: trailPath)
        trail.strokeColor = SKColor(white: 0.92, alpha: 0.75)
        trail.lineWidth = 1
        trail.glowWidth = 1.2
        trail.fillColor = .clear
        star.addChild(trail)

        let head = SKShapeNode(circleOfRadius: 1.35)
        head.fillColor = SKColor(white: 0.98, alpha: 0.85)
        head.strokeColor = .clear
        head.glowWidth = 1.5
        star.addChild(head)

        // This node intentionally has no physics body or touch behavior.
        addChild(star)

        let travelDistance = CGFloat.random(in: 70...95)
        let duration = TimeInterval.random(in: 0.38...0.52)
        let travel = SKAction.moveBy(
            x: -travelDistance,
            y: -travelDistance * 0.42,
            duration: duration
        )
        travel.timingMode = .linear

        let visibility = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.34, duration: 0.04),
            SKAction.wait(forDuration: duration * 0.38),
            SKAction.fadeOut(withDuration: duration * 0.42)
        ])
        star.run(SKAction.sequence([
            SKAction.group([travel, visibility]),
            SKAction.removeFromParent()
        ]))
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

        grassBladeDetailNode?.removeFromParent()
        let grassBlades = SKShapeNode()
        grassBlades.name = "grassBladeDetail"
        grassBlades.zPosition = 6.1
        grassBlades.strokeColor = SKColor(red: 0.34, green: 0.66, blue: 0.18, alpha: 0.95)
        grassBlades.lineWidth = 1.25
        grassBlades.fillColor = .clear
        addChild(grassBlades)
        grassBladeDetailNode = grassBlades

        waterDetailNode?.removeFromParent()
        let waterDetails = SKShapeNode()
        waterDetails.name = "waterDetail"
        waterDetails.zPosition = 6.2
        waterDetails.strokeColor = SKColor(red: 0.05, green: 0.21, blue: 0.36, alpha: 0.85)
        waterDetails.lineWidth = 1.35
        waterDetails.fillColor = .clear
        addChild(waterDetails)
        waterDetailNode = waterDetails

        waterHighlightDetailNode?.removeFromParent()
        let waterHighlights = SKShapeNode()
        waterHighlights.name = "waterHighlightDetail"
        waterHighlights.zPosition = 6.25
        waterHighlights.strokeColor = SKColor(red: 0.12, green: 0.30, blue: 0.48, alpha: 0.58)
        waterHighlights.lineWidth = 0.9
        waterHighlights.fillColor = .clear
        addChild(waterHighlights)
        waterHighlightDetailNode = waterHighlights

        cityDetailNode?.removeFromParent()
        let cityDetails = SKShapeNode()
        cityDetails.name = "cityDetail"
        cityDetails.zPosition = 6.15
        cityDetails.strokeColor = SKColor(red: 0.22, green: 0.23, blue: 0.27, alpha: 0.88)
        cityDetails.lineWidth = 1.25
        cityDetails.fillColor = .clear
        addChild(cityDetails)
        cityDetailNode = cityDetails

        rebuildGroundPath(force: true)
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
            return (SKColor(red: 0.19, green: 0.19, blue: 0.21, alpha: 1.0),
                    SKColor(red: 0.12, green: 0.12, blue: 0.135, alpha: 1.0))
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
            return (SKColor(red: 0.19, green: 0.19, blue: 0.21, alpha: 1.0),
                    SKColor(red: 0.12, green: 0.12, blue: 0.135, alpha: 1.0))
        }
    }

    func rebuildGroundPath(force: Bool = false) {
        guard groundNode != nil, groundPhysicsNode != nil else { return }

        let stateChanged = terrainGeometryPhase != gamePhase ||
            terrainGeometryWasTransitioning != isTransitioning ||
            terrainGeometryTransitionFromPhase != transitionFromPhase
        let distanceSinceRebuild = abs(groundWorldOffset - (terrainGeometryBaseOffset ?? groundWorldOffset))
        let needsRebuild = force || terrainGeometryBaseOffset == nil ||
            stateChanged || distanceSinceRebuild >= terrainGeometryRebuildDistance

        if !needsRebuild, let baseOffset = terrainGeometryBaseOffset {
            // The cached paths are built in world space. Translating their nodes
            // every frame keeps scrolling fluid without asking SpriteKit to
            // tessellate several new paths and allocate a physics body each tick.
            let translation = baseOffset - groundWorldOffset
            groundNode.position.x = translation
            groundPhysicsNode.position.x = translation
            grasslandOverlayNode?.position.x = translation
            grassBladeDetailNode?.position.x = translation
            waterDetailNode?.position.x = translation
            waterHighlightDetailNode?.position.x = translation
            cityDetailNode?.position.x = translation

            updateOceanSprites()
            updateTransitionOverlay()
            return
        }

        groundNode.position = .zero
        groundPhysicsNode.position = .zero
        grasslandOverlayNode?.position = .zero
        grassBladeDetailNode?.position = .zero
        waterDetailNode?.position = .zero
        waterHighlightDetailNode?.position = .zero
        cityDetailNode?.position = .zero

        let renderEndX = size.width + terrainResolution + terrainGeometryRebuildDistance
        var terrainPoints: [CGPoint] = []
        terrainPoints.reserveCapacity(Int(renderEndX / terrainResolution) + 2)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))

        var x: CGFloat = 0
        while x <= renderEndX {
            let worldX = groundWorldOffset + x
            let h = terrainHeight(at: worldX)
            let point = CGPoint(x: x, y: h)
            terrainPoints.append(point)
            path.addLine(to: point)
            x += terrainResolution
        }
        if let lastPoint = terrainPoints.last, lastPoint.x < renderEndX {
            let finalPoint = CGPoint(
                x: renderEndX,
                y: terrainHeight(at: groundWorldOffset + renderEndX)
            )
            terrainPoints.append(finalPoint)
            path.addLine(to: finalPoint)
        }

        path.addLine(to: CGPoint(x: renderEndX, y: 0))
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
                let clampedX = min(splitScreenX, renderEndX)
                var lastOverlayX: CGFloat = 0
                for point in terrainPoints where point.x <= clampedX {
                    oldPath.addLine(to: point)
                    lastOverlayX = point.x
                }
                if lastOverlayX < clampedX {
                    let hEdge = terrainHeight(at: groundWorldOffset + clampedX)
                    oldPath.addLine(to: CGPoint(x: clampedX, y: hEdge))
                }
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

        rebuildGrassDetails()
        rebuildWaterDetails()
        rebuildCityDetails()

        // Update scrolling ocean
        updateOceanSprites()
        updateTransitionOverlay()

        // An open edge chain is sufficient for ground contact and is much
        // cheaper than recreating a filled polygon every frame.
        let edgePath = CGMutablePath()
        var lastPhysicsPoint: CGPoint?
        for (index, point) in terrainPoints.enumerated() where index.isMultiple(of: 2) {
            if lastPhysicsPoint == nil {
                edgePath.move(to: point)
            } else {
                edgePath.addLine(to: point)
            }
            lastPhysicsPoint = point
        }
        if let finalPoint = terrainPoints.last,
           lastPhysicsPoint?.x != finalPoint.x {
            edgePath.addLine(to: finalPoint)
        }

        let body = SKPhysicsBody(edgeChainFrom: edgePath)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        body.contactTestBitMask = PhysicsCategory.saucer
        body.collisionBitMask = PhysicsCategory.none
        groundPhysicsNode.physicsBody = body

        terrainGeometryBaseOffset = groundWorldOffset
        terrainGeometryPhase = gamePhase
        terrainGeometryWasTransitioning = isTransitioning
        terrainGeometryTransitionFromPhase = transitionFromPhase
    }

    /// Rebuilds deterministic grass details at the terrain surface. The blades
    /// are keyed to world-space cells, so they scroll smoothly without changing
    /// shape or flickering between frames.
    func rebuildGrassDetails() {
        guard let grassBladeDetailNode else { return }

        let hasGrass = gamePhase == .grassland ||
            (isTransitioning && transitionFromPhase == .grassland)
        guard hasGrass else {
            grassBladeDetailNode.path = nil
            grassBladeDetailNode.isHidden = true
            return
        }

        // One combined path avoids forcing SpriteKit to tessellate three
        // separate grass layers every frame.
        let detailPath = CGMutablePath()
        let spacing: CGFloat = 11
        let firstCell = Int(floor(groundWorldOffset / spacing)) - 1
        let lastCell = Int(ceil((groundWorldOffset + size.width) / spacing)) + 2

        for cell in firstCell...lastCell {
            let worldX = CGFloat(cell) * spacing
            guard shouldDrawGrass(at: worldX) else { continue }

            let x = worldX - groundWorldOffset
            let y = terrainHeight(at: worldX) + 1
            let height = 4 + terrainDetailVariation(cell: cell, salt: 1.7) * 6
            let lean = (terrainDetailVariation(cell: cell, salt: 5.3) - 0.5) * 5

            detailPath.move(to: CGPoint(x: x, y: y))
            detailPath.addLine(to: CGPoint(x: x + lean, y: y + height))
            detailPath.move(to: CGPoint(x: x - 1.2, y: y))
            detailPath.addLine(to: CGPoint(x: x - 3.2, y: y + height * 0.68))
            detailPath.move(to: CGPoint(x: x + 1.2, y: y))
            detailPath.addLine(to: CGPoint(x: x + 3.4, y: y + height * 0.58))

            // Shorter dark blades add depth and break up the solid green fill.
            let backX = x + spacing * 0.45
            let backWorldX = worldX + spacing * 0.45
            guard shouldDrawGrass(at: backWorldX) else { continue }
            let backY = terrainHeight(at: backWorldX) + 0.5
            let backHeight = 2.5 + terrainDetailVariation(cell: cell, salt: 9.1) * 3.5
            detailPath.move(to: CGPoint(x: backX, y: backY))
            detailPath.addLine(to: CGPoint(x: backX - 1.6, y: backY + backHeight))
            detailPath.move(to: CGPoint(x: backX + 1, y: backY))
            detailPath.addLine(to: CGPoint(x: backX + 2.4, y: backY + backHeight * 0.72))

            // Sparse marks just beneath the turf keep the body of the hills
            // from reading as a single flat block of green.
            let grain = terrainDetailVariation(cell: cell, salt: 13.4)
            if grain > 0.34 {
                let grainY = y - 5 - terrainDetailVariation(cell: cell, salt: 17.8) * 13
                let grainLength = 2 + grain * 3
                detailPath.move(to: CGPoint(x: x - grainLength / 2, y: grainY))
                detailPath.addLine(to: CGPoint(x: x + grainLength / 2, y: grainY + 0.8))
            }
        }

        grassBladeDetailNode.path = detailPath
        grassBladeDetailNode.isHidden = false
    }

    /// Adds low-cost wave crests, foam, currents, glints, and bubbles to the
    /// ocean. Every mark is anchored in world space so scrolling stays smooth.
    func rebuildWaterDetails() {
        guard let waterDetailNode, let waterHighlightDetailNode else { return }

        let hasWater = gamePhase == .ocean ||
            (isTransitioning && transitionFromPhase == .ocean)
        guard hasWater else {
            waterDetailNode.path = nil
            waterDetailNode.isHidden = true
            waterHighlightDetailNode.path = nil
            waterHighlightDetailNode.isHidden = true
            return
        }

        let detailPath = CGMutablePath()
        let highlightPath = CGMutablePath()
        let spacing: CGFloat = 30
        let firstCell = Int(floor(groundWorldOffset / spacing)) - 1
        let lastCell = Int(ceil((groundWorldOffset + size.width) / spacing)) + 2

        for cell in firstCell...lastCell {
            let worldX = CGFloat(cell) * spacing
            guard shouldDrawWater(at: worldX) else { continue }

            let x = worldX - groundWorldOffset
            let surfaceY = terrainHeight(at: worldX) + 0.8
            let waveWidth = 15 + terrainDetailVariation(cell: cell, salt: 21.7) * 12
            let waveHeight = 1.4 + terrainDetailVariation(cell: cell, salt: 25.2) * 1.8
            let halfWidth = waveWidth / 2

            detailPath.move(to: CGPoint(x: x - halfWidth, y: surfaceY))
            detailPath.addQuadCurve(
                to: CGPoint(x: x + halfWidth, y: surfaceY),
                control: CGPoint(x: x, y: surfaceY + waveHeight)
            )

            // A smaller offset crest reads as a thin cap of foam while keeping
            // the original dark-blue wave lines dominant.
            let foamWorldX = worldX + spacing * 0.18
            if shouldDrawWater(at: foamWorldX) {
                let foamX = foamWorldX - groundWorldOffset
                let foamY = terrainHeight(at: foamWorldX) + 2.2
                let foamWidth = waveWidth * 0.42
                highlightPath.move(to: CGPoint(x: foamX - foamWidth / 2, y: foamY))
                highlightPath.addQuadCurve(
                    to: CGPoint(x: foamX + foamWidth / 2, y: foamY),
                    control: CGPoint(x: foamX, y: foamY + waveHeight * 0.65)
                )
            }

            // Short glints beneath the surface break up the water texture
            // without adding another SpriteKit rendering layer.
            let glintWorldX = worldX + spacing * 0.4
            guard shouldDrawWater(at: glintWorldX) else { continue }
            let glintX = glintWorldX - groundWorldOffset
            let glintDepth = 8 + terrainDetailVariation(cell: cell, salt: 29.6) * 28
            let glintLength = 5 + terrainDetailVariation(cell: cell, salt: 33.1) * 10
            detailPath.move(to: CGPoint(x: glintX - glintLength / 2, y: 50 - glintDepth))
            detailPath.addLine(to: CGPoint(x: glintX + glintLength / 2, y: 50 - glintDepth + 0.5))

            // Longer, faint diagonal strokes suggest slow underwater currents.
            let currentY = 10 + terrainDetailVariation(cell: cell, salt: 36.7) * 22
            let currentLength = 11 + terrainDetailVariation(cell: cell, salt: 39.2) * 13
            detailPath.move(to: CGPoint(x: x - currentLength / 2, y: currentY))
            detailPath.addLine(to: CGPoint(x: x + currentLength / 2, y: currentY + 1.8))

            // Sparse bubble clusters add depth without creating individual
            // SpriteKit nodes or physics bodies.
            if cell.isMultiple(of: 3) {
                let bubbleWorldX = worldX + spacing * 0.72
                if shouldDrawWater(at: bubbleWorldX) {
                    let bubbleX = bubbleWorldX - groundWorldOffset
                    let bubbleBaseY = 9 + terrainDetailVariation(cell: cell, salt: 42.6) * 13
                    for bubbleIndex in 0..<3 {
                        let radius = CGFloat(bubbleIndex + 1) * 0.55
                        let bubbleCenter = CGPoint(
                            x: bubbleX + CGFloat(bubbleIndex) * 3.2,
                            y: bubbleBaseY + CGFloat(bubbleIndex) * 5.4
                        )
                        highlightPath.addEllipse(
                            in: CGRect(
                                x: bubbleCenter.x - radius,
                                y: bubbleCenter.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )
                        )
                    }
                }
            }
        }

        waterDetailNode.path = detailPath
        waterDetailNode.isHidden = false
        waterHighlightDetailNode.path = highlightPath
        waterHighlightDetailNode.isHidden = false
    }

    /// Draws a curb, sidewalk seams, asphalt cracks, and sparse utility covers
    /// in one path so the city reads as a street without adding render layers.
    func rebuildCityDetails() {
        guard let cityDetailNode else { return }

        let hasCity = gamePhase == .city ||
            (isTransitioning && transitionFromPhase == .city)
        guard hasCity else {
            cityDetailNode.path = nil
            cityDetailNode.isHidden = true
            return
        }

        let detailPath = CGMutablePath()

        // Two continuous lines form the top curb and inner sidewalk edge.
        for lineY: CGFloat in [50.5, 39.5] {
            var isDrawing = false
            var screenX: CGFloat = 0
            while screenX <= size.width + terrainResolution {
                let worldX = groundWorldOffset + screenX
                if shouldDrawCity(at: worldX) {
                    let point = CGPoint(x: screenX, y: lineY)
                    if isDrawing {
                        detailPath.addLine(to: point)
                    } else {
                        detailPath.move(to: point)
                        isDrawing = true
                    }
                } else {
                    isDrawing = false
                }
                screenX += terrainResolution * 2
            }
        }

        let spacing: CGFloat = 52
        let firstCell = Int(floor(groundWorldOffset / spacing)) - 1
        let lastCell = Int(ceil((groundWorldOffset + size.width) / spacing)) + 2
        for cell in firstCell...lastCell {
            let worldX = CGFloat(cell) * spacing
            guard shouldDrawCity(at: worldX) else { continue }
            let x = worldX - groundWorldOffset

            // Sidewalk slab seam.
            detailPath.move(to: CGPoint(x: x, y: 50))
            detailPath.addLine(to: CGPoint(x: x, y: 40))

            // A small, deterministic branching crack in the asphalt.
            let crackX = x + spacing * 0.48
            let crackWorldX = worldX + spacing * 0.48
            if shouldDrawCity(at: crackWorldX),
               terrainDetailVariation(cell: cell, salt: 37.4) > 0.3 {
                let crackY = 17 + terrainDetailVariation(cell: cell, salt: 41.8) * 13
                let lean = (terrainDetailVariation(cell: cell, salt: 45.2) - 0.5) * 7
                detailPath.move(to: CGPoint(x: crackX - 4, y: crackY + 4))
                detailPath.addLine(to: CGPoint(x: crackX, y: crackY))
                detailPath.addLine(to: CGPoint(x: crackX + lean, y: crackY - 5))
                detailPath.move(to: CGPoint(x: crackX, y: crackY))
                detailPath.addLine(to: CGPoint(x: crackX + 4, y: crackY + 1.5))
            }

            // An occasional flattened ellipse suggests a manhole or drain.
            if cell.isMultiple(of: 4) {
                let coverWorldX = worldX + spacing * 0.72
                if shouldDrawCity(at: coverWorldX) {
                    let coverX = coverWorldX - groundWorldOffset
                    detailPath.addEllipse(
                        in: CGRect(x: coverX - 8, y: 10, width: 16, height: 5)
                    )
                }
            }
        }

        cityDetailNode.path = detailPath
        cityDetailNode.isHidden = false
    }

    private func shouldDrawGrass(at worldX: CGFloat) -> Bool {
        if isTransitioning {
            if transitionFromPhase == .grassland {
                return worldX < transitionWorldX
            }
            return gamePhase == .grassland && worldX >= transitionWorldX
        }
        return gamePhase == .grassland
    }

    private func shouldDrawWater(at worldX: CGFloat) -> Bool {
        if isTransitioning {
            if transitionFromPhase == .ocean {
                return worldX < transitionWorldX
            }
            return gamePhase == .ocean && worldX >= transitionWorldX
        }
        return gamePhase == .ocean
    }

    private func shouldDrawCity(at worldX: CGFloat) -> Bool {
        if isTransitioning {
            if transitionFromPhase == .city {
                return worldX < transitionWorldX
            }
            return gamePhase == .city && worldX >= transitionWorldX
        }
        return gamePhase == .city
    }

    private func terrainDetailVariation(cell: Int, salt: CGFloat) -> CGFloat {
        let raw = sin(CGFloat(cell) * 12.9898 + salt * 78.233) * 43_758.5453
        return raw - floor(raw)
    }

    // MARK: - Ground Scrolling

    func scrollGround(dt: TimeInterval) {
        groundWorldOffset += baseGroundSpeed * speedMultiplier * CGFloat(dt)
        rebuildGroundPath()
    }
}
