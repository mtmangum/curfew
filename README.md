# Leash Walk

A minimal top-down Godot prototype. You control Nicole on a walk; her dog Stella is on a leash and gets distracted by lures you place with the mouse.

> **Status:** early prototype. Placeholder shapes are drawn in code; sprites and audio have been imported into `assets/` but are not wired in yet.

## Requirements

- [Godot Engine](https://godotengine.org/) 4.x

## Run

1. Clone the repo and open this folder (the one containing `project.godot`) in Godot.
2. Run `res://scenes/Main.tscn` (it's the configured main scene, so F5 works).

## Controls

| Input | Action |
| --- | --- |
| Arrow keys / WASD | Move Nicole (`ui_up`, `ui_down`, `ui_left`, `ui_right`) |
| Mouse click | Spawn a lure at the cursor; the dog runs to it |

## How it works

- **Leash:** a maximum leash length constrains the dog's distance from the player. The dog pulls when chasing a lure.
- **Dog states:** `FOLLOW_OWNER`, `CHASE_LURE`, `RETURN` (see `scripts/Dog.gd`).
- **NPC lures:** `SpawnManager` periodically spawns lures near the camera.

  | Kind | Attraction | Lifetime |
  | --- | --- | --- |
  | squirrel | medium | hops around briefly, then despawns |
  | pigeon | low | short |
  | pizza | high | longer |

## Project layout

```
project.godot
scenes/    Main.tscn, Lure.tscn
scripts/   Player.gd, Dog.gd, Lure.gd, Main.gd, SpawnManager.gd
assets/    imported images/audio (from the sidescroller project)
```

## Roadmap

- Replace placeholder drawing with sprites from `assets/`.
- Proper leash physics (forces).
- Dog personality states.
- Fully spawnable NPCs (squirrels, pigeons, pizza).
