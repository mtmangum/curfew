# Curfew

A top-down night stealth game in Godot 4. Nicole is out past curfew with her greyhound Stella, and has to sneak home across a patrolled street without being seen.

## Run

1. Install [Godot](https://godotengine.org/) 4.3 or newer.
2. Open this folder (the one with `project.godot`) in Godot and press F5.

## Controls

| Input | Action |
| --- | --- |
| WASD / arrow keys | Move |
| Shift (hold) | Sneak: slower, quieter, harder to spot |
| R | Restart |

## How it plays

Get Nicole to the lit door of the house in the top-right corner.

- **Cops** patrol with flashlight cones. Standing in a cone fills their suspicion bar; fill it and you're caught. They get suspicious faster the closer you are, and slower if you sneak. Walls block the beam.
- **Stella** follows on a short leash and can be spotted too.
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
  Player.gd Dog.gd Cop.gd Cat.gd Prop.gd SteamVent.gd Fire.gd
  Sprites.gd       sprite loading helpers
assets/
  sprites/         pixel art rendered from the Streetwise sidescroller
  audio/           chiptune sound effects
```

The level is plain data at the top of `Main.gd` (building rects, cop routes, vent and bin positions), so it's easy to rearrange.

## Level design toolbox

Sprites for more night hazards from Streetwise are already in `assets/sprites/` and ready to become mechanics: `rats` (scurry and spook) and `boombox` (noise that masks footsteps). More, like the sleeping bystander, can be pulled from the sidescroller.
