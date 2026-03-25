# Alien Abduction

An endless side-scrolling game built with SpriteKit where you pilot an alien saucer, abducting creatures while avoiding obstacles.

## Gameplay

Control a UFO flying across three dynamically changing environments — ocean, grassland, and city. Use your tractor beam to abduct creatures for points while dodging planes, terrain, and obstacles. The longer you survive, the faster and harder it gets.

### Controls

- **Left side of screen** — Tap & hold to descend
- **Middle of screen** — Tap to activate tractor beam
- **Right side of screen** — Tap & hold to ascend

### Environments

| Environment | Ground | Obstacles | Creatures |
|---|---|---|---|
| Ocean | Scrolling water | Oil rigs | Whales |
| Grassland | Rolling green hills | Trees | Elk, Cows, Hikers |
| City | Flat grey pavement | Skyscrapers | Cats, Workers |

Environments cycle randomly after the initial sequence (ocean → grassland → city), each lasting 1-2 minutes.

### Creatures

| Creature | Environment | Points |
|---|---|---|
| Whale | Ocean | 10 |
| Elk | Grassland | 10 |
| Cow | Grassland | 10 |
| Cat | City | 10 |
| Hiker | Grassland | 30 |
| Worker | City | 30 |
| **Bigfoot** 🟡 | Grassland | 200 |
| **Werewolf** 🟡 | City (on rooftops) | 200 |
| **Kraken** 🟡 | Ocean (under oil rigs) | 200 |

🟡 Legendary creatures are extremely rare (1/100 spawn chance).

### Difficulty

- Plane spawn rate increases from 1 every 2.5 seconds to 2 per second over 3 minutes
- Game speed gradually increases over time
- If you hover at the same height for 1 second, a plane is sent directly at you

## Features

- Three unique scrolling environments with smooth transitions
- Procedurally generated terrain with rolling hills
- Animated alien saucer (96-frame sprite atlas)
- Background music with crossfade looping (menu and in-game tracks)
- Unique sound effects for each creature when abducted
- Explosion animation and screen shake on crash
- Pause menu with music and sound toggles (persisted)
- Help screen with control overlay
- Stats page tracking lifetime catches for every creature
- Game Center integration (leaderboards and achievements)
- iCloud sync — progress carries across devices via Apple ID

## Achievements

**Score Milestones:** 200, 500, 1000, 3500, 5000 points

**Creature Collection:** Catch 10 of each normal creature, catch 2 of each legendary creature

## Tech Stack

- **SpriteKit** — Game engine, physics, rendering
- **AVFoundation** — Background music with crossfade looping
- **GameKit** — Game Center leaderboards and achievements
- **NSUbiquitousKeyValueStore** — iCloud data sync
- **Swift / UIKit** — iOS app lifecycle

## Requirements

- iOS 15.0+
- Xcode 15+

## Assets

- Custom font: Alien Invader
- Sprite atlas: 96-frame saucer animation
- Original music tracks and creature sound effects
