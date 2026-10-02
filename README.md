# Curfew

An isometric night stealth game in Godot 4. Nicole is out past curfew with her greyhound Stella, and has to sneak home across a big, patrolled neighbourhood without being seen.

## Play online

The latest build is at **https://mtmangum.github.io/curfew/**. It runs in the browser; click once so the sound can start.

## Run

1. Install [Godot](https://godotengine.org/) 4.3 or newer.
2. Open this folder (the one with `project.godot`) in Godot and press F5.

### In the browser

`./serve.sh` exports a web build to `build/web/` and serves it at http://localhost:8060 (use `./serve.sh --skip-export` to reuse the last build). It fills the browser tab and scales with the window. Web export needs Godot's export templates installed (Editor > Manage Export Templates).

## Controls

| Input | Action |
| --- | --- |
| Click / tap | Walk to that spot; hold and drag to keep steering toward the pointer |
| WASD / arrow keys | Move along the streets (each key follows one street direction) |
| Tab | Switch to screen-relative movement (W = screen up) |
| Shift (hold) or the Sneak button | Sneak: slower, quieter, harder to spot (the button is a toggle, for touch screens) |
| M | Mute / unmute sound |
| R, or click / tap after the end banner | Restart |

## How it plays

Get Nicole to the lit door of the house in the far top-right corner of the map. You start at the opposite corner, a long walk away, past parked cars, steam vents, cats and cops.

- **Cops** patrol with flashlight cones. Standing in a cone fills their suspicion bar; fill it and you're caught. They get suspicious faster the closer you are, and slower if you sneak. Walls block the beam.
- **Stella** follows on a short leash and can be spotted too. She notices cats nearby and lunges for them, hauling Nicole along behind her at nearly walking speed. Sneaking doesn't stop it, and being dragged is loud and easy to spot, so the best move is to steer clear of cats. When Stella reaches one she barks, which is loud and sends the cat running.
- **Footsteps** are audible at close range unless you sneak.
- **Cats** wander to trash bins and knock them over. The crash makes noise, and cops go to investigate. Walk too close to a cat and it hisses and bolts, which is also noisy. A cat near a cop's route can pull them off it.
- **Steam vents** cycle on and off. A short puff warns that one is about to blow. While venting, the cloud blocks sight lines, so standing in it hides you.
- **Trash fires** light up anyone nearby, making you easier to spot.

## Project layout

```
project.godot
scenes/Main.tscn   a single node; the level is built in code
scripts/
  Main.gd          level layout, walls, line of sight, noise, win/lose
  Player.gd Dog.gd Cop.gd Cat.gd Prop.gd SteamVent.gd Fire.gd Building.gd Car.gd
  Sprites.gd       sprite loading helpers
assets/
  sprites/         pixel art rendered from the Streetwise sidescroller
  audio/           chiptune sound effects
```

The level is plain data at the top of `Main.gd` (building rects, cop routes, vent and bin positions), so it's easy to rearrange.

## Level design toolbox

Sprites for more night hazards from Streetwise are already in `assets/sprites/` and ready to become mechanics: `rats` (scurry and spook) and `boombox` (noise that masks footsteps). More, like the sleeping bystander, can be pulled from the sidescroller.

## Development

See [docs/HANDOFF.md](docs/HANDOFF.md) for the code map, how to run the headless checks in `docs/tools/`, how the sprites and sounds are generated, and the to-do list.

The art is generated from the procedural pixel art of the Streetwise sidescroller (a sibling project), so there are no hand-made image files to edit.

Version history is in [CHANGELOG.md](CHANGELOG.md). Fonts: [Pixelify Sans](https://fonts.google.com/specimen/Pixelify+Sans) and [Silkscreen](https://fonts.google.com/specimen/Silkscreen), both under the SIL Open Font License (see `assets/fonts/`).
