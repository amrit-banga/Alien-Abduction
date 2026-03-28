//
//  GameScene+Spawning.swift
//  Alien Abduction
//

import SpriteKit

extension GameScene {

    func spawnPlane() {
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

    func createPlaceholderPlane(width: CGFloat, height: CGFloat) -> SKSpriteNode {
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

    func spawnTargetedPlane(atY y: CGFloat) {
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

    func updatePlaneSpawning(dt: TimeInterval) {
        planeSpawnTimer += dt
        if planeSpawnTimer >= planeSpawnInterval {
            planeSpawnTimer = 0
            spawnPlane()
        }
    }

    func updateAnimalSpawning(dt: TimeInterval) {
        // Animals spawn in ocean, grassland, and city
        guard (gamePhase == .ocean || gamePhase == .grassland || gamePhase == .city) && !isTransitioning && !nearingPhaseEnd() else { return }
        animalSpawnTimer += dt
        if animalSpawnTimer >= animalSpawnInterval {
            animalSpawnTimer = 0
            spawnAnimal()
        }
    }

    func spawnAnimal() {
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

    func updateOilRigSpawning(dt: TimeInterval) {
        // Only spawn oil rigs during the ocean phase
        guard gamePhase == .ocean && !isTransitioning && !nearingPhaseEnd() else { return }
        oilRigSpawnTimer += dt
        if oilRigSpawnTimer >= oilRigSpawnInterval {
            oilRigSpawnTimer = 0
            spawnOilRig()
        }
    }

    func spawnOilRig() {
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

    func updateTreeSpawning(dt: TimeInterval) {
        // Spawn trees only during grassland phase, not during transitions
        guard gamePhase == .grassland && !isTransitioning && !nearingPhaseEnd() else { return }
        treeSpawnTimer += dt
        if treeSpawnTimer >= treeSpawnInterval {
            treeSpawnTimer = 0
            spawnTree()
        }
    }

    func spawnTree() {
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

    func updateSkyscraperSpawning(dt: TimeInterval) {
        guard gamePhase == .city && !isTransitioning && !nearingPhaseEnd() else { return }
        skyscraperSpawnTimer += dt
        if skyscraperSpawnTimer >= skyscraperSpawnInterval {
            skyscraperSpawnTimer = 0
            spawnSkyscraper()
        }
    }

    func spawnSkyscraper() {
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

    func increaseDifficulty() {
        // Start at 2.5s, linearly decrease to 0.33s (3 per second) over 240 seconds (4 minutes)
        let t = min(elapsedTime / 240.0, 1.0)
        planeSpawnInterval = 2.5 - t * 2.17  // 2.5 → 0.33
    }
}
