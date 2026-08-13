//
//  Alien_AbductionTests.swift
//  Alien AbductionTests
//
//  Created by Amrit Banga on 3/19/26.
//

import XCTest
import CoreGraphics
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

    func testPauseMenuButtonsNeverOverlapOnShortViewport() {
        let safeFrame = CGRect(x: 28, y: 20, width: 334, height: 627)
        let layout = GameUILayout.pauseMenuPositions(in: safeFrame)
        let expectedCenterSpacing = GameUILayout.pauseMenuButtonSize.height + GameUILayout.pauseMenuButtonGap

        XCTAssertEqual(layout.buttonYs.count, 4)
        for index in 1..<layout.buttonYs.count {
            XCTAssertEqual(layout.buttonYs[index - 1] - layout.buttonYs[index], expectedCenterSpacing)
        }

        let topEdge = layout.buttonYs[0] + GameUILayout.pauseMenuButtonSize.height / 2
        let bottomEdge = layout.buttonYs[3] - GameUILayout.pauseMenuButtonSize.height / 2
        XCTAssertLessThanOrEqual(topEdge, safeFrame.maxY)
        XCTAssertGreaterThanOrEqual(bottomEdge, safeFrame.minY)
    }

}
