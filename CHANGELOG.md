# Changelog

All notable changes to Curfew are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/) with a `-beta` suffix while it is
pre-release. The current version is also set in `project.godot`
(`config/version`).

## [Unreleased]

### Added
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
