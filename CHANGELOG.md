# Changelog

All notable changes to Curfew are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/) with a `-beta` suffix while it is
pre-release. The current version is also set in `project.godot`
(`config/version`).

## [Unreleased]

### Added
- Room behind the start. The spawn was in the bottom-left corner, 50 units
  from the south edge and 70 from the west edge, so most directions ended at the
  edge of the world almost at once. A column of tiles to the west and a row to
  the south now sit behind it (quiet outskirts with buildings, cars, lamps and
  bins but no cops or cats), so the nearest edge is over 1,400 units away. The
  world is 10240x4320.
- Cops hold their flashlights: his front arm comes down gripping a torch with a
  lit lens, and a faint shaft of light runs from the lens to where the beam
  meets the ground. The raised club now appears only while a cop is chasing you
  (he has spotted you); while patrolling or checking out a noise it is down.
- Cats sit when they are not moving (an upright sitting cat with a curled tail
  that blinks every few seconds) and run only when they are going somewhere.
- Street lights (about 310 across the map, a few flickering): a slim post with a
  lamp head, a warm bloom and a soft pool of light on the road. The posts are
  solid; the light is only for looks (it does not affect stealth, yet).
- More awnings: shop windows get long striped awnings in several colours,
  most other doors get a small canopy, and some buildings have a row of little
  awnings over their first-floor windows.
- New buildings in the biggest empty spaces: shallow shops along the top strip
  of each tile (which narrows the boulevards where tiles meet) and three
  buildings in the plazas either side of the north-south patrol street.
- More cars: about 1,060 now, nose to tail along the kerbs and some along the
  lanes (lane cars only where a clear corridor remains).
- Parked cars along the avenues: boxy isometric sedans in seven colours with
  glass, wheels, and head or tail lights, depth-sorted like buildings. They are
  solid to walk into but low, so light and sight pass over them. They are placed
  by a rule that keeps them off patrol routes, bins, barrels, vents and the
  front door, and out of the immediate spawn spot (with some in view from the very
  first screen). `docs/tools/test_reachable.gd`
  proves the start is still connected to the front door.
- Sound overhaul. A night ambience loop (traffic rumble, wind, light hum, a
  distant car) and a two-layer music loop in A minor: a calm layer always
  plays, and a busy layer with drums and an arpeggio swells in as cops get
  suspicious or go to investigate. Both fade out when the run ends.
- New effects: footsteps (Nicole's are quieter when sneaking; cops' footsteps
  are audible nearby so you can hear them coming), a steam hiss that grows as
  a vent blows and as you get close, bin crashes, cat meows and hisses, a
  cop "huh?" cue when they go to investigate and a sharper cue when they spot
  you, a police whistle sting when you are caught, a jingle when you get home,
  and a tick for the Sneak button.
- Sound mixing: separate Music, Ambience and SFX buses, world sounds that
  fall off with distance, and the M key mutes everything.
- `docs/tools/render_sounds.py` synthesises all the new audio (no samples) and
  `docs/tools/test_audio.gd` checks the wiring.
- Pixel-art text: Pixelify Sans for the HUD and Silkscreen Bold for the title,
  signs and keycaps, with outlines and drop shadows so it reads over the
  street (fonts under the SIL Open Font License, see `assets/fonts/`).
- A tidier HUD: keyboard-key icons for the controls along the bottom, which
  fade out once you have walked a short way, a short objective line that fades
  later, a toast when Tab switches the key mapping, a styled Sneak button and
  a version tag.
- A restyled end screen: dimmed view, a big coloured title that pops in
  ("CAUGHT" in red, "HOME SAFE" in gold) and a blinking restart prompt.
- A ring of decorative city blocks and street around the playable area, plus a
  curb line at the real edge, so the view never shows empty void.
- `docs/tools/test_patrols.gd`: checks that every cop keeps walking its route.

### Changed
- Street lamp art redone: a cast-iron post with a plinth, bands and a curved
  arm, a lantern with a pointed cap, glass and a frame, a warm bloom, a faint
  shaft of light, and a pixel-dithered pool of light on the ground in place of
  the stacked rings.
- Nicole's footstep sound is switched off for now (it never sat right). Her steps
  still make noise that cops can hear, and `Player.FOOTSTEP_SOUND` brings the
  sound back. Cops' footsteps still play near you as a cue.
- Much more ground to walk on. The world is now six times bigger: a 3x2 grid of
  the 2560x1440 district (7680x2880 in all), with the middle column mirrored
  so it doesn't repeat exactly. You start in the bottom-left corner and the house
  is in the far top-right, about 8,000 units away. It has 60 cops, 90 cats, 78
  steam vents, 78 bins, 24 trash fires and 162 buildings. Cops and cats
  far from you stand still and cost nothing.
- The chain-link fence round the edge of the map was tried and removed: the
  larger world makes the edge far away, and the decorative blocks and street
  still carry on beyond it.
- Faster on the big map: collisions and cops' light rays look only at the walls,
  cars, bins and barrels in the cells near them, and the depth sort compares
  only things whose screen boxes overlap (4 ms down to 0.3 ms).
- Stella walks instead of running. She now has a four-frame walk cycle
  (upright legs stepping in diagonal pairs) and follows Nicole at an easy pace,
  with her steps tied to the ground she covers so her feet keep up. The
  stretched-out gallop is kept for when she is after a cat. The walk frames
  are authored in `render_assets.mjs`, since the sidescroller's dog only has a
  gallop and a sit.
- Footsteps rebuilt. The old sound had a 95 Hz thump that sounded like a drum
  and played on a fixed timer that drifted against the walk animation. Now each
  step is a short pavement heel-click with a faint scuff and no low end (five
  variants, with a little random volume and pitch each time), and it fires on
  the animation's foot-down frames, so the beat matches her gait: every 0.3s
  walking, every 0.5s sneaking. Cops use the same sounds pitched down for heavier
  boots, synced to their walk too. `docs/tools/test_footsteps.gd` checks the beat.
- The control hints stay up much longer: they fade only after you have walked
  about 600 units and played for 30 seconds (the objective line lasts twice
  that). The music and ambience now fade in over four seconds instead of
  starting at full volume; on the web the fade begins at your first click or
  key press, when the browser lets audio start.
- More variety in buildings. They now have one, two or three storeys (about
  15%, 55% and 30%; the house has three) with a row of windows and a ledge for
  every floor, five wall colours (slate, brick, grey-green, sand, navy), shops
  with lit windows and coloured awnings on some ground floors, a front door,
  and air-conditioning units and stairwells on the roofs.
- Removed the painted centre-line dashes along the avenues for a cleaner street.
- No cop is near the start any more: the bottom-street patrol that began 50
  units from the spawn point now runs 600+ units away, so the nearest cop is
  over 500 units from the start. `docs/tools/test_start_safe.gd` guards this.
- More cats to avoid: 15 now (was 7), spread across the map.
- Stella trails farther behind Nicole: she follows about 46 units back (was
  about 28) and the leash is 80 units (was 55).
- Removed the Santa hats from Nicole and Stella. The sidescroller's sprite
  source dresses them in hats; `render_assets.mjs` now filters the hat pieces
  out when rendering Curfew's sprites.
- Steam art redone: a plume of lumpy, shaded pixel-art cloud puffs that bursts
  from the grate, rises, sways and widens, with low fog billowing across the
  whole hiding zone (replacing the hard concentric discs). The palette is cooler and darker, and puffs have a
  soft pixel edge instead of dithering.
- Stella now really hauls Nicole when she chases a cat: the leash goes taut and
  Nicole is dragged along at 70 units/s (she walks at 85), instead of the leash
  appearing to get longer. Sneaking no longer cancels it, and being dragged is
  loud and easy to spot, so the best plan is to keep away from cats. The leash
  can no longer stretch past its limit.
- The night ambience is tonal and sparse (a soft low drone, a faint hum, crickets and a rare distant car) instead of filtered noise, and the steam hiss is darker, quieter and only audible close to a vent. Both removed a constant hiss-like wash.
- Steam is now shaded pixel-art puffs that rise, grow and fade, over a faint
  mist on the ground that marks the area where you are hidden. Far-away vents
  are not redrawn.
- The world is four times bigger (2560x1440) and the house is in the far
  top-right corner, about 2,700 units from the start. It now has 10 cops, 7
  cats, 13 steam vents, 13 bins and 4 trash fires.
- Bins and fire barrels are solid. Everyone slides around them instead of
  walking through.

### Fixed
- Cops circling forever with a "?": a noise at a bin or fire barrel sent a cop
  to a spot he could never stand on, and sliding around the object counted as
  moving, so he never gave up. Cops now arrive when they are close enough (16
  units) and stop investigating after 8 seconds at most.
- Web build had no sound at all: audio buses created at runtime never reach the
  browser's audio graph. The Music / Ambience / SFX buses are now defined in
  `default_bus_layout.tres`, and bus levels leave headroom so layered sounds
  no longer clip and distort.
- Web build: audio is now unlocked from inside the first click, tap or key
  press (a small script in the page's head, set in the Web export preset),
  which browsers such as Safari require before they will play sound.
- Cops no longer get stuck on bins and fire barrels. They slide around round
  obstacles, and a cop that cannot make progress for a second skips to its
  next waypoint. Bins and barrels were also moved off patrol lines.

## [0.1.0-beta] - 2026-10-02

First playable beta: a stealth vertical slice in Godot 4.

### Added
- Top-down night stealth game: Nicole and her greyhound Stella sneak home
  across a patrolled street.
- Cops with raycast flashlight cones, a suspicion bar, and patrol, investigate
  and look-around behaviour. A full bar means caught.
- Noise model: footsteps, knocked bins, startled cats and barks all draw cops.
  Shift sneaks (slower, quieter, harder to spot).
- Cats that knock over trash bins and bolt when approached.
- Stella on a leash: she chases and barks at cats and can drag Nicole along
  unless Nicole sneaks.
- Steam vents that cycle on and off and block sight lines, and trash fires that
  make anyone nearby easier to spot.
- Win by reaching the lit door of the house; a red vignette warns as a cop's
  suspicion rises.
- Isometric rendering: buildings are extruded boxes that fade when someone is
  behind them, with depth sorting, ground shadows and upright sprites.
- Controls: click or tap to walk and hold to steer, WASD and arrow keys along
  the streets (Tab switches to screen-relative), Shift or an on-screen Sneak
  button, R or a tap to restart.
- Browser build: `serve.sh` exports and serves the game on port 8060.
- Headless checks in `docs/tools/` for the stealth rules, dog and cat
  behaviour, and pointer movement.
- Art and sound rendered from the Streetwise sidescroller's procedural pixel
  art and chiptune tones.
