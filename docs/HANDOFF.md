# Curfew: handoff notes

## Starting a new Claude session? Read this first

1. Open `~/Projects/curfew` in VS Code and start Claude Code there. The new session has no memory of the old one; this file is the memory. Claude's per-project memory is keyed to the folder path, so the rename means it starts fresh too.
2. Everything is committed and pushed to `origin` (https://github.com/mtmangum/curfew), `main` branch. Check with `git status -sb` and `git log --oneline -5`.
3. To play it: `./serve.sh`, then open http://localhost:8060 (browser build). Or open the folder in Godot and press F5. Nothing is left running from the old session; the web server and game window were stopped before the rename, so start `./serve.sh` yourself.
4. The user's last request before the rename: a larger game view in the browser (done), a README and push (done). The last gameplay feature was Stella chasing and barking at cats. Nothing is half-finished.
5. Suggested next step: play-test it, then tune and extend (see "Not done / ideas" below). Ask the user what they want first.

Working agreements from this session:
- Commit and push only when asked; the user explicitly asked for each push so far.
- Git commit messages end with the `Co-Authored-By: Claude ...` line the harness specifies.
- The user is on macOS with Godot 4.7.2 installed at `/Applications/Godot.app`. Homebrew is not usable for installing things on this machine (permissions).
- Verify changes by running the headless checks in `docs/tools/` rather than assuming; Godot 4 GDScript is strict about typed inference (see Gotchas).
- The user's git identity is Matt Mangum; the repo is `mtmangum/curfew`.

Written so work can resume if the original session is lost. Last updated 2026-10-02.

## What this is

**Curfew** is a top-down night stealth game in Godot 4. Nicole (player) is out past curfew with her greyhound Stella and has to sneak home across a patrolled street. It started life as "leash-walk" (a top-down dog-on-a-leash prototype) and was pivoted to stealth. Art and audio come from the sibling project `~/Projects/sidescroller` ("Streetwise", a Phaser side-scroller); its night roster of hazards is the level-design toolbox.

- Repo: https://github.com/mtmangum/curfew (`origin`). The old https://github.com/mtmangum/leash-walk is the remote `leash-walk` and is no longer used.
- Local folder: renamed from `~/Projects/leash-walk` to `~/Projects/curfew` (2026-10-02). If you find old references to `leash-walk` paths, they are stale.
- Working title history: Leash Walk -> Curfew (chosen by the user from Streetwise: After Dark / Curfew / Home Before Dawn / Last Block Home).

## Current state

Playable vertical slice, one hand-built level (2560x1440 world, drawn isometrically). Verified headlessly and with a screenshot; **not yet play-tested by hand**, so all tuning numbers are first guesses.

Implemented:
- Player: WASD/arrows, Shift to sneak (slower, quieter, 0.55x visibility). Footsteps make noise within 45px unless sneaking.
- Cops (10): patrol routes, flashlight cone (raycast-clipped by walls and steam), suspicion bar (1.1s to fill at point blank-ish, faster when close or lit), investigate noises and last-seen position, then look around and resume patrol. Full bar = caught.
- Cats (15): walk to the nearest trash bin and knock it over (noise radius 260, cops investigate). Startle and bolt if the player comes within 45px (noise radius 110).
- Stella: trails Nicole by about 46px (`Dog.FOLLOW_START`) on an 80px leash (`Dog.LEASH`) and can be spotted (0.6x weight). Notices cats within 90px, chases them, hauls Nicole along while straining (`Dog.DRAG_SPEED` 70px/s vs her 85 walk speed, so only walking the other way resists it; sneaking does not cancel it; the leash never stretches past 80px; being dragged counts as loud and unhidden: footsteps make noise and the sneak visibility bonus is lost), barks on arrival (noise 150, cat flees, 3s cooldown).
- Steam vents (13): 4s on / 3.5s off with a 1s warning puff. Active cloud blocks line of sight, so standing in it hides you.
- Trash fires (4): radius 80, makes anyone in it 1.8x easier to spot.
- Win: reach `HOME_ZONE` (the house door in the far top-right corner, ~2700 units from the start in the bottom-left). Lose: caught. R restarts. Red screen vignette scales with the worst cop's suspicion.

Not done / ideas, roughly in priority order:
1. Play-test and tune (cop speed, cone range/FOV, suspicion time, tug strength, vent timings, level layout).
2. More toolbox hazards: rats (sprites exist: scurry and spook), boombox (sprites exist: noise that masks footsteps), sleeping bystander and streetwalker (sprites NOT extracted yet; see tools below).
3. Lose condition options besides instant caught (e.g. cop chases, alert state).
4. Level 2+, a level data format instead of hard-coded arrays in `Main.gd`.
5. (Done) Music, ambience and effects. Still missing: Stella's footsteps/pants, a sound for the flashlight cones, sound options beyond the M mute key.
6. (Done) Local folder renamed to `curfew`.
7. The git history still contains a commit with ~9MB of stray Phaser/Playwright files (`2759c42`). Rewriting history to drop it was offered but not done.

## Code map

`scenes/Main.tscn` is a single node. Everything is built in code by `scripts/Main.gd` so there is no hand-edited scene data to break.

| File | Role |
| --- | --- |
| `Main.gd` | Level data (building rects, cop routes, vent/bin/fire/cat positions), ground drawing, camera, HUD, win/lose, `noise()`, `slide()`, `blocked_circle()`, `ray_hit()`, `los()`, `in_steam()`, `in_fire()` |
| `Player.gd` | Input, movement, sneak, footsteps, `visibility_mult()` |
| `Dog.gd` | Follow, taut-leash drag (`Player.drag()`), cat chase/bark |
| `Cop.gd` | Patrol/investigate/look states, beam polygon, detection and suspicion |
| `Cat.gd` | Idle/go-to-prop/knock/flee/wander states, `scare_from()` |
| `Prop.gd` | Trash bin with `knock()` |
| `SteamVent.gd` | Cycle, cloud drawing, `active` flag read by `Main.ray_hit` |
| `Fire.gd` | Glow + `lights()` |
| `Building.gd` | Isometric box: roof + south/east walls, one window row and ledge per storey (`FLOOR` 24px, `floors` 1-3), 5 wall `PALETTES`, optional shopfront + awning, door, rooftop boxes, the house's glowing door; configured with `setup(rect, floors, palette, shop, house, variant)`; `rect` is also the collision wall; fades when someone is behind it |
| `Style.gd` | Text and HUD look: fonts (`assets/fonts/`), the HUD `Theme`, `display_label`, `keycap`/`hint` widgets, `draw_world_text` (outlined text inside the world) |
| `Sprites.gd` | Texture loading, iso helpers (`iso`, `proj`, `UP`, `ground_dir`, `faces_left`), `upright()` layer + shadow; sprites anchor at bottom-center so a node's origin is the character's feet |

Conventions and design choices:
- **Sound:** `docs/tools/render_sounds.py` synthesises everything new (python3 + numpy; the older chiptune effects `bark`, `tug`, `pickup` still come from `render_assets.mjs`; `lure_drop.wav` is unused). The Music / Ambience / SFX buses live in `default_bus_layout.tres` (do NOT add buses at runtime: in the web build they never reach the browser audio graph and everything is silent; bus levels are set low because the web sample mode has no limiter, so loud layers clip). `Main._setup_audio()` starts the ambience and two music loops; the four loops get their loop points from their `.wav.import` files (`edit/loop_mode=2`, uncompressed). `Main.play(name, db)` is a plain effect; `Main.play_at(name, pos, db, reach)` fades with distance from Nicole and is silent past `reach`. `_update_music()` sets the busy layer's volume from cop suspicion. Steam hiss loops live on each `SteamVent`. Web: the export preset's `html/head_include` injects a script that wraps `AudioContext` and calls `resume()` on the first pointer/touch/key event, because Safari needs resume() inside a user gesture. The web build plays sounds as browser samples (Godot's default for web), not through the engine mixer. To measure real web audio output without a browser extension (RMS, peaks, clipping), drive headless Chrome over the DevTools protocol (see how it was done: chrome `--remote-debugging-port`, node 22 WebSocket). M mutes the Master bus.
- **HUD (Main.gd `_build_hud`):** everything hangs under one `Control` with `Style.theme()` so it picks up the pixel font. Control hints and the objective fade after the player has both walked 600 units and played 30s (`progress` in `_process`); the music and ambience fade in over 4s (`fade_in`, started on first input on the web); `_show_toast()` for brief messages; `_show_banner()` for the CAUGHT / HOME SAFE screen. Version text comes from `config/version` in `project.godot` (currently 0.1.0-beta; keep `CHANGELOG.md` in step).
- **Fonts:** pixel fonts are imported with antialiasing, hinting and subpixel positioning off (edit the `.import` files, not defaults). They are OFL; keep the licence text next to them.
- **Steam:** `SteamVent.gd` builds lumpy pixel-art puff textures in code (`puff_texture(radius, variant)`: a few overlapping lumps, 3-tone shading, half-transparent edge ring). `Cloud` draws three layers: a faint ground fog in the hiding radius (`_draw_zone`; a dashed boundary ring was tried and removed), low billows spread over the footprint (`_draw_fog`), and a rising plume from the grate (`_draw_plume`), all upright and sorted old-to-young. To look at it up close, render a contact sheet: set `vent.t` and `vent.amount`, pin `main.focus` on the vent, crop and enlarge the viewport image.
- **Building variety:** `Main._add_building(rect, index)` picks storeys (`[2,3,2,1,3,2,2][(index*3+1)%7]`), palette and shop-ness from the index, so it is deterministic and the same every run. The decor ring uses indexes after the playable ones.
- **Decor ring:** `Main._make_decor()` surrounds the playable `world_rect` with non-solid scenery blocks (`decor`, margin `DECOR_MARGIN`) and the ground extends under them, so the isometric view never shows void. They are Buildings in `building_nodes` but not in `walls`.
- **Isometric view (added 2026-10-02):** logic is still flat top-down; `global_position` is always a ground-plane position. `Main._update_view()` sets the viewport `canvas_transform` to shear that plane into 2:1 isometric (`Sprites.ISO`, `Main.ZOOM`); there is no Camera2D. Anything drawn in world coordinates (ground, beams, fire glow, noise rings) becomes an ellipse/diamond for free. Anything that must stand up (sprites, bars, labels, leash, steam puffs) hangs under `Sprites.upright(node)` or calls `draw_set_transform_matrix(Sprites.UP)`, and uses `Sprites.iso()` to convert ground vectors to screen offsets.
- Pointer control (mouse and touch, which Godot emulates as left-button mouse events): `Player.gd` stores the pointer in viewport coordinates and converts it to a ground point every frame with the canvas transform, so a held pointer keeps working while the view scrolls. A tap sets a destination (marker ring); holding steers; keys cancel it; being stuck against a wall for 0.3s drops it. Sneak on touch is the `Sneak` toggle button (`Main.sneak_toggle`). Tapping the end banner restarts.
- WASD runs along the ground axes by default (W = up-right, D = down-right, S = down-left, A = up-left on screen) so one key walks a street; Tab toggles `Main.screen_relative` (W = screen up, via `Sprites.ground_dir`). Sprites are still side-view and flip by screen direction (`Sprites.faces_left`); 4/8-direction art is not done.
- Depth: `Main._depth_sort()` assigns `z_index` 100+ to the buildings, props, fires, cats, cops, dog and player within `NEAR_VIEW` (800) of the view each frame (topological sort; boxes vs actors by which side of the box the actor is on). Flat layers use absolute z: ground -100, beams -50, fire glow -30, vents -20, steam 3000, noise rings 3500.
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

Browser build: `./serve.sh` exports with the `Web` preset in `export_presets.cfg` (single-threaded, so no COOP/COEP headers needed) into the gitignored `build/web/` and serves it on port 8060. The 4.7.2 web export templates were installed by extracting only `web_nothreads_{debug,release}.zip` and `version.txt` from the official `.tpz` into `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Base viewport is 1280x720 (stretch `canvas_items`, aspect keep) with view zoom `Main.ZOOM` (1.8).

`.godot/` is gitignored, so a fresh clone must import once (opening it in the editor also does this) or `load()` of PNG/WAV will fail.

Scripted checks live in `docs/tools/`. They are SceneTree scripts; run one with:

```sh
$G --headless --fixed-fps 60 --path . --script docs/tools/test_stealth_rules.gd
```

- `test_stealth_rules.gd`: standing in a cone gets caught; active steam blocks line of sight; knocked bin makes a cop investigate; cat startles; reaching home wins.
- `test_dog_cat.gd`: Stella chases and barks, hauls Nicole (with and without sneaking), and the leash never stretches past its limit.
- `test_pointer.gd` (start/home/wall coordinates are for the 2560x1440 map): tap-to-walk arrives, a tap into a wall gives up, holding steers. It calls `player._unhandled_input` directly because `Input.parse_input_event` applies the headless window's stretch. In SceneTree scripts `main.cops` etc. are empty until a couple of frames have passed, so `await process_frame` before touching them.
- `test_audio.gd`: loops play, the busy music layer follows suspicion, `play_at` falloff, vent hiss, music fade, and buses survive a restart.
- `test_start_safe.gd`: the nearest cop to the spawn is at least 450 units away and standing still for 30s is safe. If you move `START` or a patrol route, run it.
- `test_investigate.gd`: a cop sent to a noise at a bin or barrel, from 8 directions and 3 distances, must give up and go back to patrol rather than circle it (the old code failed 51 of them). Takes about a minute.
- `test_patrols.gd`: every cop keeps walking its route (no wedging on bins, barrels or walls). Takes about a minute.
- `screenshot.gd`: needs a real (non-headless) window and `SHOT_DIR` set to an output folder; saves `shot.png`. Handy for checking visuals without playing.

They poke at internals (`main.cops[0]`, `main.state`, ...), so update them if those change.

## Assets

`assets/sprites/<name>/*.png` and `assets/audio/*.wav` are **generated**, not hand-made. Source art is procedural rect lists in the sidescroller, rendered by two Node scripts (they hard-code `~/Projects/sidescroller` and write into this project; edit the paths if either moves):

- `docs/tools/render_assets.mjs`: player and dog poses (imports `src/gfx/playerFrames.js` and `dogFrames.js`; the Santa hats the sidescroller draws on both are filtered out by colour, see `noHat`), plus the synthesized WAVs (re-implements the sidescroller's `ChiptuneAudio` tone sequences). It also generated pigeon/squirrel/pizza sprites for the abandoned lure concept; those were deleted from the repo, so re-running will recreate them: delete `assets/sprites/{pigeon,pizza,squirrel}` afterwards.
- `docs/tools/extract_night_sprites.mjs`: pulls cop, cat, steam stack, trash fire, rats, boombox, trash bin out of the sidescroller's `BootScene.js` by regex-extracting each `draw*Obstacle` method and running it with a stub that captures the rect list. To get another sprite (e.g. `drawSleepingObstacle`, `drawStreetwalkerObstacle`), add a `save(...)` line.

The sprites are side-view, used here in a 3/4 top-down way. `assets/sprites/steamvent/` is extracted but unused (vents are drawn in code as a grate plus cloud).

## Gotchas learned

- macOS `sed -i ''` has no `\b`; use `perl -pi -e` for word-boundary replacements.
- `Node2D` already has a `hidden` member, so a script variable named `hidden` fails to parse (renamed to `in_cover`).
- Godot 4 scene files use `ExtResource("1")` with string ids; the old prototype's Godot 3 syntax and made-up uids were invalid.
- Actors get `z_index` from `Main._depth_sort()` each frame, so don't set `z_index` on them; put new flat layers on absolute z outside the 100-200 range.
- Performance on the big map: only things within `Main.NEAR_VIEW` of the view are depth-sorted, cops farther than that from the player don't update at all (they freeze and cost nothing), and `ray_hit` rejects walls by bounding box before the exact test.
- Static objects block movement: bins (`Prop.radius`) and fire barrels (`Fire.body_radius`) are circles checked in `Main.blocked_circle`; `slide()` veers around round obstacles. Cats stop 14 units from a bin so they aren't blocked by it.
- Don't add a `Camera2D`: it would override the isometric `canvas_transform`.
- Homebrew could not install Godot on this machine (permissions on `/opt/homebrew`); the user installed the app themselves.
- A ray that starts inside a steam cloud ignores that cloud (entry time is negative), so a cop standing in the cloud can see out of it. Intentional for now.
