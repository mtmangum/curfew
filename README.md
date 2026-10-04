# Streetwise II: Curfew

**Play it in your browser: https://mtmangum.github.io/curfew/**

*Streetwise II: Curfew* is an isometric night stealth game in Godot 4. Nicole is out past curfew with her greyhound Stella, and has to sneak home across a big, patrolled neighbourhood without being seen.

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
| Shift (hold) | Sneak: slower, quieter, harder to spot |
| M | Show / hide the map |
| N | Mute / unmute sound |
| P or Esc | Pause / carry on (it also pauses itself when you switch away) |
| C | Copy this session's playtest run log to the clipboard (for pasting into notes) |
| F3 | Playtest readout (sightings, chases, time, where you are) |
| R, or click / tap after the end banner | Try again (same house, you keep your map). After a win, or with Shift+R, a new neighbourhood |

## Levels

- **Level 1** is a gentle walk home: a few cops to avoid, a few cars and skateboarders, and no street people. Mostly about finding the way, with phone booths to call for directions and squirrels to distract Stella.
- **Level 2** is the full city, in a blackout: more cops, plus hobos, punks and zombies, much more traffic, a cold fog, dark windows and dead street lights. There are no working phone booths and no squirrels from here on.
- **Level 3** adds rain: puddles, lightning, and a hush that makes every noise carry less far.
- **Level 4 and up** abandon the neighbourhood: boarded windows, graffiti, wrecked cars and quarantine barriers. Every level has a name.
- **Level 3 and up** keep turning it up. Getting home moves you to the next level in a new neighbourhood; losing means trying the same level again.

## How it plays

Get Nicole to the lit door of the house. Which house changes every run: it is somewhere far across the neighbourhood from where you start, and the map in the corner only gives you a ring over the part of town it is in, which tightens as you get closer. On level 1, lit phone booths (a cyan handset bubble bobs over them; stand beside one for three seconds) give you the exact spot. After a lost run you try again for the same house, with the map you had explored (Shift+R for a new neighbourhood). It is a long walk across a city of avenues and side streets, past parked cars, traffic, steam vents, cats and cops.

- **Cops** patrol with flashlight cones. Standing in a cone fills their suspicion bar; fill it and you're caught. They get suspicious faster the closer you are, and slower if you sneak. Walls block the beam.
- **Stella** follows on a short leash and can be spotted too. She notices cats nearby and lunges for them, hauling Nicole along behind her at nearly walking speed. Sneaking doesn't stop it, and being dragged is loud and easy to spot, so the best move is to steer clear of cats. When Stella reaches one she barks, which is loud and sends the cat running.
- **Footsteps** are audible at close range unless you sneak.
- **Cats** wander to trash bins and knock them over. The crash makes noise, and cops go to investigate. Walk too close to a cat and it hisses and bolts, which is also noisy. A cat near a cop's route can pull them off it.
- **Life.** The bar at the top left drops when a car, skateboarder, punk, hobo or zombie gets you, and you are out when it is empty. Pizza slices on the pavement (by street lights) restore it, and keep adding past full into a neon-green overcharge. A cop catching you still ends the run at once. If a cop chases you and you keep ahead for about 8 seconds, he gives up.
- **Stella is easily distracted.** She pees on fire hydrants (3.5 seconds rooted, and the leash holds you) and, if a squirrel bolts up a tree, chases it and barks up at the tree (loud) until it settles.
- **Zombie hobos** (from level 2) shamble after you slowly. Keep moving: they cannot catch you if you do, and if you stand about, more turn up.
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
