# MultiplayerFPS-AI

A 3D first-person shooter prototype built with **Godot 4.4** and **GDScript**, combining host/join multiplayer with configurable, state-based AI opponents.

Host a session, choose the number and difficulty of bots, and explore a small arena with first-person movement and pistol combat. The project brings together Godot's multiplayer tools, raycast shooting, and an AI behavior system in a compact codebase.

> **Status:** Development prototype. Human-player networking is implemented; AI replication to joining clients is incomplete. The notes below describe the current source code, which has not been runtime-tested for this README.

## Features

- **Host and join:** ENet-based connections through a simple main menu.
- **First-person controls:** Mouse look, WASD movement, and jumping.
- **Pistol combat:** Raycast hit detection, weapon animations, and muzzle-flash particles.
- **Health and respawning:** Players start with three health points; each damage call removes one. Human players reset to the world origin when defeated, while bots select a spawn position and return to patrol.
- **Configurable bots:** Choose 0–8 AI players and difficulty from 0.5–2.0 before hosting.
- **AI behavior states:** Patrol, chase, attack, retreat, and search.
- **Visual feedback:** A player health HUD, green bot bodies, overhead bot names, and color-coded bot health labels.

## Getting started

### Requirements

- **Godot 4.4**, matching the version declared in `project.godot`.
- A graphics setup compatible with the project's **Forward Plus** renderer.
- Git, if cloning the repository.
- Blender if you want Godot to import or edit the included `.blend` source assets. The gameplay scenes reference the included `.glb` models.

### Open the project

1. Clone the repository, or download and extract it from GitHub:

   ```bash
   git clone https://github.com/ex188/MultiplayerFPS-AI.git
   ```

2. In Godot's Project Manager, choose **Import** and select:

   ```text
   MultiplayerFPS-AI/MultiplayerFPS-AI/project.godot
   ```

   The repository contains a nested project folder; import the `project.godot` file inside it.

3. Allow Godot to import the assets, then open the project.
4. Press **F6 with `world.tscn` open**, or **F5** to run the configured main scene.

The checked-in gameplay scripts run in Godot. No Python service or machine-learning model is required.

## Playing

### Host a session

1. Set **AI Difficulty** and **AI Players** in the main menu.
2. Click **Host**.
3. Bots spawn one at a time, approximately one second apart.

The defaults are **3 bots** at **1.0 difficulty**. Hosting alone lets you try the bot behavior. Set the bot count to **0** when testing human-only multiplayer.

### Join a session

1. Start another game instance.
2. Enter the host's address in the address field.
3. Click **Join**.

For two instances on the same computer, use `127.0.0.1`. On a local network, use the host computer's LAN address. The port is fixed at **UDP 9999** in `world.gd`.

Connections across the internet require a reachable host and suitable firewall/router configuration for UDP 9999. A UPnP helper exists in the source but is not called by the hosting flow, so port mapping is not automatic.

### Controls

| Action | Control |
| --- | --- |
| Move | W / A / S / D |
| Look around | Mouse |
| Shoot | Left mouse button |
| Jump | Space (`ui_accept`) |
| Quit the application | Escape |

**Debug input note:** `world.gd` also uses `ui_accept` to damage the first bot, so jumping can trigger that test. Other built-in UI actions and the T key trigger AI diagnostics. These development bindings should be removed or separated before normal playtesting.

## How the AI works

Bots use a **finite-state machine written in GDScript**. There is no trained model or external AI API.

| State | Behavior |
| --- | --- |
| Patrol | Move between predefined points and begin chasing a nearby target. |
| Chase | Move toward the target and enter attack range. |
| Attack | Turn toward the target and attempt shots after a line-of-sight check. |
| Retreat | Move away when the target gets too close. |
| Search | Move around the last known target position. |

Decisions run on a **0.1-second timer**, and bots can select other bots as targets. Their movement speed is 8 units per second, compared with 10 for human players.

Difficulty changes the shooting probability and cooldown. The script also calculates a `reaction_time` value, but that value is not currently used in decision timing.

Although the bot scene includes a `NavigationAgent3D`, movement currently follows targets directly. Navigation-mesh pathfinding and obstacle avoidance are not implemented in the active movement logic.

## Project structure

Paths below are relative to the repository root:

```text
MultiplayerFPS-AI/
├── project.godot       # Godot configuration and input mappings
├── world.tscn          # Arena, host/join menu, AI settings, and HUD
├── world.gd            # Session setup, player spawning, and bot management
├── player.tscn         # Human player, pistol, and network synchronizer
├── Player.gd           # Movement, shooting, damage, and respawning
├── AIPlayer.tscn       # Bot body, weapon, timer, and labels
├── AIPlayer.gd         # AI state machine and combat behavior
├── environment.tscn    # Arena model and materials
├── models/            # Blender sources and exported GLB models
├── addons/            # Kenney particle and prototype texture assets
├── AI_README.md        # Earlier AI implementation notes
└── LICENSE            # MIT license
```

## Current limitations

- **Bot networking is unfinished.** The world spawner registers only the human-player scene, and the bot scene has no `MultiplayerSynchronizer`. Bot decisions use host authority, but bot spawning and state are not fully replicated to joining clients.
- **Remote human targeting needs work.** Human players join the `player` group only on their owning peer. Host-controlled bots therefore do not discover remote human players through that group as currently written.
- **Combat remains experimental.** Debug damage/shooting hooks and extensive logging are still enabled. Multiplayer combat and bot hit detection need further playtesting.
- **Connection feedback is limited.** Host/join handlers do not currently surface connection errors in the menu.

Some statements in the earlier `AI_README.md`, including navigation-mesh movement and seamless bot networking, describe behavior beyond the current implementation.

## License and credits

The project includes an **MIT license**, with the existing copyright notice **Copyright (c) 2023 Logan Lang**. See [LICENSE](MultiplayerFPS-AI/LICENSE) and retain its notice when redistributing the code.

Included Kenney assets have their own **CC0** license notices:

- [Particle Pack license](MultiplayerFPS-AI/addons/kenney_particle_pack/LICENSE.txt)
- [Prototype Textures license](MultiplayerFPS-AI/addons/kenney_prototype_textures/LICENSE.txt)

This README is intended for the repository root, alongside the `MultiplayerFPS-AI/` project directory.

