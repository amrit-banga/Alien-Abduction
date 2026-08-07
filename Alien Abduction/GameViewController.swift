//
//  GameViewController.swift
//  Alien Abduction
//
//  Created by Amrit Banga on 3/19/26.
//

import UIKit
import SpriteKit
import GameplayKit
import GameKit
import CoreText

class GameViewController: UIViewController {

    private var didPresentScene = false

    override func viewDidLoad() {
        super.viewDidLoad()

        registerCustomFonts()

        // Authenticate Game Center for leaderboards & iCloud sync
        CloudDataManager.shared.authenticateGameCenter(from: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let skView = view as? SKView else { return }

        if !didPresentScene {
            didPresentScene = true

            // Create scene now that the view's layout is final
            let scene = GameScene(size: skView.bounds.size)
            scene.scaleMode = .aspectFill

            skView.presentScene(scene)
            skView.ignoresSiblingOrder = true

            skView.showsFPS = true
            skView.showsNodeCount = true
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return [.left, .right]
    }

    private func registerCustomFonts() {
        let fontNames = ["Alien Invader"]
        let fontExtensions = ["ttf", "otf"]
        for name in fontNames {
            for ext in fontExtensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Fonts/alien_invader") {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                } else if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                }
            }
        }
    }
}
