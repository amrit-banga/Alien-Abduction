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

    override func viewDidLoad() {
        super.viewDidLoad()

        registerCustomFonts()

        guard let view = self.view as? SKView else { return }

        // Create scene programmatically sized to the view
        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .aspectFill

        view.presentScene(scene)
        view.ignoresSiblingOrder = true

        view.showsFPS = true
        view.showsNodeCount = true

        // Authenticate Game Center for leaderboards & iCloud sync
        CloudDataManager.shared.authenticateGameCenter(from: self)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
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
