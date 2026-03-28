//
//  GameScene+UI.swift
//  Alien Abduction
//

import SpriteKit
import GameKit

extension GameScene {

    func showSplashScreen() {
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

    func showStartButton() {
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

    func showStatsOverlay() {
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

    func showGameCenterLeaderboard() {
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

    func dismissStatsOverlay() {
        children.filter { $0.name == "statsOverlay" || $0.name == "leaderboardButton" }.forEach { $0.removeFromParent() }
        statsOverlay = nil
    }

    func showHelpOverlay() {
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

    func dismissHelpOverlay() {
        children.filter { $0.name == "helpOverlay" }.forEach { $0.removeFromParent() }
        helpOverlay = nil
    }

    func setupHUD() {
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

    func showPauseMenu() {
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

    func toggleMusic() {
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

    func toggleSound() {
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

    func resumeGame() {
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

    func showPointsPopup(points: Int) {
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
}
