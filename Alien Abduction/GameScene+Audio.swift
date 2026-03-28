//
//  GameScene+Audio.swift
//  Alien Abduction
//

import SpriteKit
import AVFoundation

extension GameScene {

    // MARK: - Audio Setup

    func setupAudio() {
        tractorBeamSoundAction = SKAction.playSoundFileNamed("tractorBeam.mp3", waitForCompletion: false)

        if let url = Bundle.main.url(forResource: "home", withExtension: "mp3") {
            menuMusicPlayer = try? AVAudioPlayer(contentsOf: url)
            menuMusicPlayer?.numberOfLoops = 0
            menuMusicPlayer?.volume = 1.0
            menuMusicPlayer?.prepareToPlay()
        }

        if let url = Bundle.main.url(forResource: "inGame", withExtension: "mp3") {
            gameMusicPlayer = try? AVAudioPlayer(contentsOf: url)
            gameMusicPlayer?.numberOfLoops = 0
            gameMusicPlayer?.volume = 1.0
            gameMusicPlayer?.prepareToPlay()
        }
    }

    // MARK: - Music Playback

    func playMenuMusic() {
        guard !isMusicOff && !isSoundOff else { return }
        stopCrossfadeTimer()

        gameMusicPlayer?.stop()

        menuMusicPlayer?.currentTime = 0
        menuMusicPlayer?.volume = 1.0
        menuMusicPlayer?.play()
        scheduleCrossfadeLoop(for: menuMusicPlayer)
    }

    func playGameMusic() {
        guard !isMusicOff && !isSoundOff else { return }
        stopCrossfadeTimer()

        let fadeOutPlayer = menuMusicPlayer
        gameMusicPlayer?.currentTime = 0
        gameMusicPlayer?.volume = 0.0
        gameMusicPlayer?.play()

        let steps = 30
        let stepDuration = musicFadeDuration / Double(steps)
        for i in 0...steps {
            let t = Float(i) / Float(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                fadeOutPlayer?.volume = 1.0 - t
                self?.gameMusicPlayer?.volume = t
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + musicFadeDuration) {
            fadeOutPlayer?.stop()
        }

        scheduleCrossfadeLoop(for: gameMusicPlayer)
    }

    func stopGameMusic() {
        stopCrossfadeTimer()
        gameMusicPlayer?.stop()

        guard !isMusicOff && !isSoundOff else { return }

        menuMusicPlayer?.currentTime = 0
        menuMusicPlayer?.volume = 0.0
        menuMusicPlayer?.play()

        let steps = 30
        let stepDuration = musicFadeDuration / Double(steps)
        for i in 0...steps {
            let t = Float(i) / Float(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                self?.menuMusicPlayer?.volume = t
            }
        }

        scheduleCrossfadeLoop(for: menuMusicPlayer)
    }

    func scheduleCrossfadeLoop(for player: AVAudioPlayer?) {
        stopCrossfadeTimer()
        guard !isMusicOff && !isSoundOff else { return }
        guard let player = player, player.duration > crossfadeLeadTime * 2 else {
            player?.numberOfLoops = -1
            return
        }

        let checkInterval: TimeInterval = 0.5
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self, weak player] timer in
            guard let self = self, let player = player, player.isPlaying else { return }
            let remaining = player.duration - player.currentTime
            if remaining <= self.crossfadeLeadTime {
                timer.invalidate()
                self.crossfadeRestart(player: player)
            }
        }
    }

    func crossfadeRestart(player: AVAudioPlayer) {
        guard !isMusicOff && !isSoundOff else { return }
        let steps = 30
        let stepDuration = crossfadeLeadTime / Double(steps)

        let targetVolume = player.volume

        for i in 0...steps {
            let t = Float(i) / Float(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                player?.volume = targetVolume * (1.0 - t)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + crossfadeLeadTime) { [weak self, weak player] in
            guard let self = self, let player = player else { return }
            player.currentTime = 0
            player.volume = 0.0
            player.play()

            for i in 0...steps {
                let t = Float(i) / Float(steps)
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak player] in
                    player?.volume = targetVolume * t
                }
            }

            self.scheduleCrossfadeLoop(for: player)
        }
    }

    func stopCrossfadeTimer() {
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
    }

    func pauseMusic() {
        gameMusicPlayer?.pause()
        stopCrossfadeTimer()
    }

    func resumeMusic() {
        guard !isMusicOff && !isSoundOff else { return }
        gameMusicPlayer?.play()
        scheduleCrossfadeLoop(for: gameMusicPlayer)
    }

    // MARK: - Sound Effects

    func playTractorBeamSound() {
        guard !isSoundOff else { return }
        if let action = tractorBeamSoundAction {
            run(action)
        }
    }

    func playCreatureSound(for creatureType: String) {
        guard !isSoundOff else { return }
        let creatureSoundMap: [String: String] = [
            "whale": "whaleScream.mp3",
            "elk": "elkBugle.mp3",
            "cow": "cowScream.mp3",
            "cat": "catMeow.mp3",
            "hikerHuman": "humanScream.mp3",
            "workerHuman": "humanScream.mp3",
            "bigfoot": "bigfootGrowl.mp3",
            "werewolf": "werewolfHowl.mp3",
            "kraken": "krakenScream.mp3"
        ]
        guard let soundFile = creatureSoundMap[creatureType] else { return }
        run(SKAction.playSoundFileNamed(soundFile, waitForCompletion: false))
    }
}
