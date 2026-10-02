# Curfew: handoff notes

Written so work can resume if the original session is lost. Last updated 2026-10-02.

## What this is

**Curfew** is a top-down night stealth game in Godot 4. Nicole (player) is out past curfew with her greyhound Stella and has to sneak home across a patrolled street. It started life as "leash-walk" (a top-down dog-on-a-leash prototype) and was pivoted to stealth. Art and audio come from the sibling project `~/Projects/sidescroller` ("Streetwise", a Phaser side-scroller); its night roster of hazards is the level-design toolbox.

- Repo: https://github.com/mtmangum/curfew (`origin`). The old https://github.com/mtmangum/leash-walk is the remote `leash-walk` and is no longer used.
- Local folder is still `~/Projects/leash-walk`; the name was never changed on disk.
- Working title history: Leash Walk -> Curfew (chosen by the user from Streetwise: After Dark / Curfew / Home Before Dawn / Last Block Home).

## Current state

Playable vertical slice, one hand-built level (1280x720 world, camera zoom 2). Verified headlessly and with a screenshot; **not yet play-tested by hand**, so all tuning numbers are first guesses.

Implemented:
- Player: WASD/arrows, Shift to sneak (slower, quieter, 0.55x visibility). Footsteps make noise within 45px unless sneaking.
- Cops (3): patrol routes, flashlight cone (raycast-clipped by walls and steam), suspicion bar (1.1s to fill at point blank-ish, faster when close or lit), investigate noises and last-seen position, then look around and resume patrol. Full bar = caught.
- Cats (2): walk to the nearest trash bin and knock it over (noise radius 260, cops investigate). Startle and bolt if the player comes within 45px (noise radius 110).
- Stella: follows on a 55px leash and can be spotted (0.6x weight). Notices cats within 90px, chases them, drags Nicole along while straining (30px/s, cancelled by Shift), barks on arrival (noise 150, cat flees, 3s cooldown).
- Steam vents (4): 4s on / 3.5s off with a 1s warning puff. Active cloud blocks line of sight, so standing in it hides you.
- Trash fire (1): radius 80, makes anyone in it 1.8x easier to spot.
- Win: reach `HOME_ZONE` (door at top-right). Lose: caught. R restarts. Red screen vignette scales with the worst cop's suspicion.

Not done / ideas, roughly in priority order:
1. Play-test and tune (cop speed, cone range/FOV, suspicion time, tug strength, vent timings, level layout).
2. More toolbox hazards: rats (sprites exist: scurry and spook), boombox (sprites exist: noise that masks footsteps), sleeping bystander and streetwalker (sprites NOT extracted yet; see tools below).
3. Lose condition options besides instant caught (e.g. cop chases, alert state).
4. Level 2+, a level data format instead of hard-coded arrays in `Main.gd`.
5. Music/ambient audio. Only 4 one-shot SFX exist (`pickup`, `bark`, `lure_drop`, `tug`); `lure_drop` is currently unused.
6. Rename the local folder to `curfew` if desired.
7. The git history still contains a commit with ~9MB of stray Phaser/Playwright files (`2759c42`). Rewriting history to drop it was offered but not done.

## Code map

`scenes/Main.tscn` is a single node. Everything is built in code by `scripts/Main.gd` so there is no hand-edited scene data to break.

| File | Role |
| --- | --- |
| `Main.gd` | Level data (building rects, cop routes, vent/bin/fire/cat positions), ground drawing, camera, HUD, win/lose, `noise()`, `slide()`, `blocked_circle()`, `ray_hit()`, `los()`, `in_steam()`, `in_fire()` |
| `Player.gd` | Input, movement, sneak, footsteps, `visibility_mult()` |
| `Dog.gd` | Follow, leash clamp, cat chase/bark/tug |
| `Cop.gd` | Patrol/investigate/look states, beam polygon, detection and suspicion |
| `Cat.gd` | Idle/go-to-prop/knock/flee/wander states, `scare_from()` |
| `Prop.gd` | Trash bin with `knock()` |
| `SteamVent.gd` | Cycle, cloud drawing, `active` flag read by `Main.ray_hit` |
| `Fire.gd` | Glow + `lights()` |
| `Sprites.gd` | Texture loading; sprites anchor at bottom-center so a node's origin is the character's feet |

Conventions and design choices:
- Actors live under a `y_sort_enabled` container. Flashlight beams (z -50), ground (z -100), steam clouds and noise rings (z 50 / 40) use absolute z.
- Scripts reference `main` untyped (no `class_name`s) and call its methods dynamically. Locals are explicitly typed because `:=` on a Variant is a parse error in Godot 4.
- 4-space indentation in scripts (matches the original prototype).
- Sprite scale: player and dog 0.5, cop 0.36, cat 0.41, bin and fire 0.36. Default texture filter is nearest.
- Noise model: `main.noise(pos, radius, show_ring)` tells every cop within radius to `hear(pos)`. Cops that are currently `seeing` the player ignore it.

## Running and testing

Godot 4.7.2 is installed at `/Applications/Godot.app/Contents/MacOS/Godot` (the project targets 4.3+; `config/features` says 4.3).

```sh
G=/Applications/Godot.app/Contents/MacOS/Godot
$G --path .                                  # run the game
$G --headless --path . --import              # first run after a fresh clone: builds .godot/ import cache
$G --headless --path . --quit-after 120      # smoke test: any SCRIPT ERROR means a parse/runtime problem
```

`.godot/` is gitignored, so a fresh clone must import once (opening it in the editor also does this) or `load()` of PNG/WAV will fail.

Scripted checks live in `docs/tools/`. They are SceneTree scripts; run one with:

```sh
$G --headless --fixed-fps 60 --path . --script docs/tools/test_stealth_rules.gd
```

- `test_stealth_rules.gd`: standing in a cone gets caught; active steam blocks line of sight; knocked bin makes a cop investigate; cat startles; reaching home wins.
- `test_dog_cat.gd`: Stella chases, barks, drags Nicole, cat flees.
- `screenshot.gd`: needs a real (non-headless) window and `SHOT_DIR` set to an output folder; saves `shot.png`. Handy for checking visuals without playing.

They poke at internals (`main.cops[0]`, `main.state`, ...), so update them if those change.

## Assets

`assets/sprites/<name>/*.png` and `assets/audio/*.wav` are **generated**, not hand-made. Source art is procedural rect lists in the sidescroller, rendered by two Node scripts (they hard-code `~/Projects/sidescroller` and write into this project; edit the paths if either moves):

- `docs/tools/render_assets.mjs`: player and dog poses (imports `src/gfx/playerFrames.js` and `dogFrames.js`), plus the synthesized WAVs (re-implements the sidescroller's `ChiptuneAudio` tone sequences). It also generated pigeon/squirrel/pizza sprites for the abandoned lure concept; those were deleted from the repo, so re-running will recreate them.
- `docs/tools/extract_night_sprites.mjs`: pulls cop, cat, steam stack, trash fire, rats, boombox, trash bin out of the sidescroller's `BootScene.js` by regex-extracting each `draw*Obstacle` method and running it with a stub that captures the rect list. To get another sprite (e.g. `drawSleepingObstacle`, `drawStreetwalkerObstacle`), add a `save(...)` line.

The sprites are side-view, used here in a 3/4 top-down way. `assets/sprites/steamvent/` is extracted but unused (vents are drawn in code as a grate plus cloud).

## Gotchas learned

- macOS `sed -i ''` has no `\b`; use `perl -pi -e` for word-boundary replacements.
- `Node2D` already has a `hidden` member, so a script variable named `hidden` fails to parse (renamed to `in_cover`).
- Godot 4 scene files use `ExtResource("1")` with string ids; the old prototype's Godot 3 syntax and made-up uids were invalid.
- `Camera2D` + `y_sort` + absolute-z children: keep new draw layers on absolute z to avoid surprises.
- Homebrew could not install Godot on this machine (permissions on `/opt/homebrew`); the user installed the app themselves.
- A ray that starts inside a steam cloud ignores that cloud (entry time is negative), so a cop standing in the cloud can see out of it. Intentional for now.
