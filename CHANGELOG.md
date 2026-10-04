# Changelog

All notable changes to Streetwise II: Curfew are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/) with a `-beta` suffix while it is
pre-release. The current version is also set in `project.godot`
(`config/version`).

## [Unreleased]

### Added
- The sprite gallery shows the new additions: a "Street details" section (the tree grate on its own and with
  its tree standing in it, the seven kinds of shop window, the neon OPEN sign in three colours) and a
  "Signals & clues" section (a cop's "?" and "!" popping in, Stella's thought bubble, and the six clue
  pictures), 38 new frames in 6 new groups. They are rendered from the game's own drawing code by
  `docs/tools/render_gallery_extras.gd` (the grate is now `scripts/Grate.gd`, the thought bubble
  `Style.draw_thought_bubble` and the cop mark `Cop.draw_alert_mark`, shared with the game), the page
  marks them "Godot render", and the clue pictures say "Levels 1 to 3 only". `docs/tools/test_gallery.gd`
  checks the manifest against the files.
- Shop windows with something in them (`scripts/ShopWindows.gd`). The wide windows on a shopfront (about a
  third of the buildings) were flat lit rectangles; each shop is now one of seven kinds, picked by its
  building: shoes, hats, electronics (glowing screens), a boutique (mannequins in dresses), a grocer
  (bottles and a crate of fruit), a bakery (cakes and a loaf) or books. A lit window has a warm interior
  with a strip light and a floor, a shelf and the goods, and the windows of one shop differ from each
  other. About one shop in three has a neon OPEN sign in its second window (pink, cyan or red, in a
  pixel font drawn on the wall, with a faint halo on a dark board). The displays are plain rectangles in
  the window's own units, listed as data, so a test checks they all fit. Windows that are dark or boarded
  stay as they were. (`docs/tools/test_shop_windows.gd`)
- City tree grates: every street and plaza tree now stands in a square cast-iron grate set in the pavement
  (a steel frame, rings of short radial slots, a dark pit for the trunk), the way real city trees do. It is
  drawn on the ground by the tile (`Ground.TileGround`), so anyone walking past stands over it, not under
  the tree. It is sized to the pavement round the tree (the kerb trees have only 9 units to spare): 17 units
  across at the kerb, up to 26 where there is room, and never reaches the road. Flat fills and one batched
  line run per tile, so it costs next to nothing. (`docs/tools/test_grates.gd`)
- Clues (`scripts/Clues.gd`): one-time hints that explain what just happened, so the rules need not be
  guessed. A card at the bottom of the screen (a picture and a line or two, up for about as long as it takes
  to read) names the cause and says what to do: a bin knocked over by a cat (and, if a cop heard it, that the
  crash drew him), Stella catching the scent of home, a cop's first yellow "?" and first red "!", Stella
  hauling Nicole after something (loud: walk the other way), and a zombie getting up. Each shows once and is
  remembered across visits (the browser's localStorage on the web, a file in user:// elsewhere); they show
  only on levels 1 to 3 (`settings.clues`), one at a time and at least 6 s apart (the "!" skips the wait),
  and not over the level's title card. Typing CLUES forgets what has been shown. The pictures are drawn in
  code (`Style.draw_clue_icon`). `Main.noise` now returns how many cops turned to look, and `Cop.hear` says
  whether he did. (`docs/tools/test_clues.gd`)
- A thought bubble with a house in it over Stella's head while she leads the way home (on every sniff, all
  levels), so it is plain what she is doing. It replaces the old two-second line of text.
- A published sprite gallery with search, animation controls, original PNG links, and first-appearance
  levels for the character roster. Rooftop previews use the game's procedural drawing code, including
  three air-conditioning cabinet colours, a turning fan, the water tank, and the house roof.
- Reproducible performance and memory audits in `docs/audits/2026-10-04/`, covering native and Web
  exports, real scene reloads, audio ownership, crowd sorting, and long-session lifecycle checks.
- Regression checks for scene/helper cleanup and bounded audio-stream reuse across retries.

### Changed
- A cop's torch beam is drawn accurately and lights the walls it hits. The beam used to start at the torch lens
  (drawn 27 plane units from his feet) while its rays were cast from his feet, so it skewed and folded over
  itself near a wall or facing north-west. Now the rays are cast from the hand (from his feet if his hand is in a
  wall), the lit pool is a fan that cannot fold, and the lens is joined to it by the beam's two edges and a faint
  wedge. Where the beam lands on a south or east wall (the two the camera sees) the building shows a soft warm
  patch there, brighter the nearer the wall; it is a child of the building (`BeamSpots.gd`), so it fades with the
  building and cars and people in front still cover it. (`Cop._update_beam`, `Collision.ray_hit_wall`,
  `docs/tools/test_beam.gd`)
- A better home icon, in Stella's thought bubble and on the clue card: a bigger bubble, and a house that looks
  like the game's own, with a pitched roof and chimney, a lit window and a glowing door (it was a plain 15-pixel
  house). The gallery frames are re-rendered from the same code.
- Stella's first sniff of home, the one with the clue card, lasts about 6 seconds instead of 2.6, so the card
  no longer pulls your eye away from what she is doing: you can read it and still watch her sniff and set off.
  Later sniffs are unchanged. (`Dog.SCENT_TIME_FIRST`)
- Shop awnings hang higher and shallower (from 22 down to 17, 7 deep, to 23 down to 19, 5 deep): the old
  ones hid the top third of every shop window, and so most of a display.
- Sprite gallery inputs, selects, and buttons share a 44-pixel height, padding, and label spacing. Removed the inspiration link from its footer.
- A cop in pursuit now shows a red "!" over his head; the yellow "?" stays for a cop who is only going
  to look at a noise or a glimpse. Both pop in large and settle (the "!" also throbs a little), so a
  change of alert level is easy to catch out of the corner of your eye. (`Cop.alert_mark`)
- Trash bins and both trash-fire animation frames use consistent isometric barrel geometry. The
  lying zombie hobo has a clearer resting silhouette and gentler animation in the gallery.
- Gallery exports are included by the local server and deployment scripts; image URLs carry content
  hashes so updated art cannot mix with cached old frames.
- Depth sorting calculates each object's key once per frame, preserving ordering and roughly halving
  sort time in the measured fixtures.

### Fixed
- The chimney on the house's roof looked slightly see-through: the roof's tile courses are batched lines drawn
  after everything else, so they ran across it. The courses are now drawn before the chimney. (The gallery's
  house frame is re-rendered.)
- `docs/tools/test_dog_cat.gd` was testing nothing: it set up Stella and the cat at fixed coordinates that are
  inside a building in today's city, so she never moved, Nicole was dragged 0 units, and it passed because
  it asserted nothing. It now finds open ground (`Helpers.open_run`, shared with `test_tug.gd`) and checks
  that she barks, the cat flees, Nicole is hauled (sneaking or not) and the leash holds at its limit.
- The leash tug no longer sounds like a crunch. It was a thump under two bursts of filtered noise, and
  sustained noise reads as gravel (spectral flatness 0.177). It is now built from tonal pieces: a hard
  lunge at a cat, squirrel or hydrant plays `tug` (a soft thump, a tiny strap tick and a jingle of clasp
  and collar-ring clinks, flatness 0.005), and the gentle pull toward home plays a new `tug_soft` (a damped
  twang of the taut cord and two clinks, 0.001). (`docs/tools/render_sounds.py`; chosen by ear from three
  candidates. `docs/tools/test_tug.gd` checks which one plays when.)
- A strong reference cycle between the level and furniture builders that retained helpers after
  scene disposal.
- Web audio samples accumulating across scene reloads: a fixed stream cache shares resource identities
  for effects, loops, and vent hiss. The 20-retry probe retained about 629 MB less decoded audio after
  cleanup while preserving the existing sample backend.
- Generated build assets being re-imported into later game packs; `build/.gdignore` and export
  exclusions keep them out.
- Test reporting that missed bare failed boolean checks and nonzero process exits. The audio effect
  check now counts playback children on their owner; patrol/investigation checks assert their totals.

## [0.2.0-beta] - 2026-10-04

The second beta: the game is no longer one level. Getting home clears a level and starts the next, each
with its own look (a blackout, rain, an abandoned neighbourhood), plus the new name, plazas with zombies,
rooftops, real barks, a quicker and smoother loading page, and a lot of speed-ups.

### Added
- Rooftops (`scripts/Roofs.gd`). The camera looks down on the city, so roofs were a big stretch of flat
  colour with a box or two. Each roof now has a surface (tar paper, gravel or membrane seams, with
  stains) in a colour that leans toward rust, green-grey, concrete or slate, a low parapet with
  coping, up to three sizeable air-conditioning units (a cream, sage or grey cabinet on base rails with louvres, an access panel with a green light, and a big round fan on top), and on about one roof in three a wooden
  round wooden water tank (staves, iron hoops, a conical cap, on braced legs, like the ones on New York
  roofs), and nothing stands within 30 units of a roof edge: with a building faded, a piece near the edge
  looked like it was in the street. (A first version had skylights, solar panels, billboards, laundry lines
  and more; it looked like clutter in the road once a building went see-through, so it was cut back to
  just these.) The house she is heading for has a pitched terracotta roof with a chimney and a thread of
  smoke. Every roof is worked out from the building's number (so it is always the same) and drawn with
  batched calls, and the building's screen box reaches up to cover the tallest piece.
- Turning fans on the rooftops: about a third of the air-conditioning units have a fan that turns slowly
  (each at its own speed, from about 0.7 to 2 radians a second, so it looks lazy rather than
  mechanical). Each is a tiny piece of its own (`scripts/RoofFan.gd`) that redraws only its four spokes
  about 12 times a second, never the building, and the activity gate switches it off when it is more
  than 1,000 units from Nicole, so only the fifteen or so near her ever run. Measured at about 0.05 ms a
  frame for the fans in view, and 0.4 ms for 200 of them redrawn every single frame.
- Stella's nose. Home is no longer on the map until you have found it, so you have to explore or follow
  the dog: every so often (22-38 s on level 1, then 40-65, then 55-85) she lifts her head, sniffs
  (a new sound) and leads off toward home for a few seconds with a gentle pull on the leash, a few
  scent wisps drifting from her nose. A cat, squirrel or hydrant drops it, and she stops once home is
  found. (`scripts/Dog.gd`, `settings.nose`)
- The cover art (`docs/streetwise-ii-curfew-cover.png`) is at the top of the README, and a smaller copy
  (`docs/streetwise-ii-curfew-social.jpg`) is published with the site as `cover.jpg`, so the game's link
  shows it when shared (Open Graph and Twitter card tags in the loading page).
- Level 3, "Rainy Night": level 2 with rain. Slanting streaks and little splashes over the screen,
  puddles with a pale sheen on the roads, lightning now and then with thunder a beat behind it, and a
  rain sound under everything. The rain hushes every noise a little: sounds carry 25% less far, so
  a bark or a shout that would have brought a cop running now has to be closer.
- Level 4, "Quarantine" (and up): level 3 with the neighbourhood abandoned. About 30% of the dark windows
  are boarded up with planks, most buildings have tags sprayed on their lower walls, a third of the
  parked cars are rusted wrecks with smashed glass, scorch marks and dead lights, and most of the
  pavement furniture (benches, planters, cones, mailboxes) is replaced by striped quarantine barriers.
  (Not done from the idea list: tape across streets and extra trash fires.)
- Every level has a name and a title card as it starts ("LEVEL 3 / RAINY NIGHT": Past Curfew, Lights
  Out, Rainy Night, Quarantine, then The Long Way Home), and the end banner says which is next.
- New sounds (`docs/tools/render_sounds.py`): a cold wind loop and a far-off siren every half-minute or
  so from level 2, a rain loop and thunder from level 3. Compressed (ADPCM) to keep the download small.
- Level 2 looks different from level 1 (`scripts/LevelLook.gd`, numbers in `scripts/LevelSettings.gd`):
  a cold teal cast over the whole world, a thin drifting fog (two layers of soft cloud and a haze that
  thickens toward the top of the screen), and a blackout: about two lit windows in three are out and
  the ones still lit are a sickly pale green, shop windows go dark, nearly a third of the street lights
  are dead (no light on the ground to be spotted in; the ones a pizza slice or the punks stand under
  stay lit) and more of the rest flicker. The house she is heading for keeps its lit windows. Level 1
  keeps its warm night; level 3 and up get a little darker, mistier and more blacked-out.
- Zombies asleep in the plazas, from level 2: some lie stretched out on the park benches and some
  sit slumped by the fountain, flies buzzing round them. They stay put until Nicole comes within
  about 120 units, then get up and come after her like any zombie; if she gets away they go back
  to their seat and lie down again. (New sprites from `docs/tools/render_zombie_rest.mjs`.)
- A hidden way to test any level: type LEVEL and then a digit (1 to 9; 0 is level 10) and the
  game starts that level in a new neighbourhood. Nothing on screen mentions it.
- Pause: P or Esc stops the whole game and shows a PAUSED card; the same again carries on. The
  game also pauses itself when the window loses focus or the browser tab is hidden. (`scripts/PauseMenu.gd`)
- A better bark for Stella: three sharp, high greyhound barks (one a double "ruff-ruff"), picked at
  random with a little pitch wobble, in place of the single chiptune beep. Synthesised in
  `docs/tools/render_sounds.py`.
- Levels. Getting home clears a level and the next try is the next level, in a new
  neighbourhood; losing keeps the level (and the house and the map, as before). The level
  shows beside the life bar and in a toast at the start.
  - Level 1, a gentle walk home: about 40% of the cops (23, down from 56) who are a little
    slower to notice her, only a few cars (5 near her) and skateboarders (3), no hobos, punks
    or zombies at all, and a house 2,400 to 4,700 units away (a walk of 30 to 55 seconds).
  - Level 2, the full city: every cop, hobos, punks and zombie groups, plenty of traffic (18
    cars, 4 skateboarders), zombies that turn up if she dawdles, and a house at least 4,500
    away. No working phone booths (they are scenery) and no squirrels: those are level 1 only,
    and so on for every later level.
  - Level 3 and up: level 2 with busier roads, more skateboarders, jumpier cops and a longer
    way home.
  `scripts/LevelSettings.gd` holds the numbers. `CURFEW_LEVEL=2` in the environment starts a
  session on that level (the test runner uses it so the checks exercise the full city).
- Overcharge: pizza keeps adding life when it is already full. The bar grows a neon-green
  stretch past 100 (up to 160, like Streetwise) that flickers, and hits take it off first.
  A pizza is only left lying when even that is full.
- Zombie hobos now look the part and are not green: ashen skin, matted hair, hollow
  eyes, a torn dirty coat with a denim patch and a ragged hem, frayed trousers and one
  bare foot (`assets/sprites/zombie`, made from the hobo's frames by
  `docs/tools/render_zombie.mjs`), with a little swarm of flies circling the head.
- The map is now a tool rather than a compass. Home is no longer pinned at the start:
  there is a dashed ring over the part of town it is in (and a "HOME ABOUT 900 m NE"
  caption). The ring tightens as Nicole gets closer, never grows back, and gives way to
  the house itself once she is near enough to see it. The map also remembers what she
  has seen: pizza slices, steam vents and working phone booths where she has been near
  them, and the last place she saw each cop (a red mark that fades over 45 seconds).
- Phone booths (about one in three of the ones you can see works; a cyan handset bubble bobs above each): stand beside one for
  three seconds and the map fills in for 600 units round it and home is marked. The call
  can be heard a short way off, and standing still draws zombies if it goes on.
- After a lost run (or R mid-run) the next try keeps the same house and the map she had
  explored, so each attempt teaches her the city. A win starts a new neighbourhood, and
  so does Shift+R.
- A loading page of our own (`web/shell.html`) in place of Godot's logo and single bar.
  A night street with Nicole and Stella walking home to a house whose door lights up
  as the game loads, a cop with a torch, and one bar for each part of the start-up:
  the ENGINE and the GAME DATA (measured as they download, in MB, with a note for slow
  connections), then SOUND, THE CITY and STREETS, reported by the game itself while it
  builds the world a piece at a time. Tips rotate underneath. The build is no longer
  one long frozen frame on a slow phone: on the web the world is built a frame at a time
  (`Main.progressive_boot`, `boot_step`), and the page stays until the game says it is
  ready. Elsewhere the game still builds in one go. The desktop boot splash is now a
  plain night-blue screen instead of the Godot logo.
- Stella uses her marking pose while she pees.
- Stella at the foot of the tree now sits and barks up at the squirrel, then rears up on
  her hind legs with her front paws on the trunk (new `rear0`/`rear1` frames, mouth open
  just after each bark), and repeats. Made by `docs/tools/render_dog_rear.mjs`.
- Proper squirrel art: a shaded, outlined squirrel with a big plume tail, cream belly and
  an acorn, in four poses (sitting and nibbling, running in two frames, climbing the
  trunk, and chattering from the branches), drawn a little smaller than a cat. Made by
  `docs/tools/render_squirrel.mjs`; it and `render_dog_rear.mjs` share `pixel_shapes.mjs`.
- A life meter (top left, red to green like the one in Streetwise). Street hazards
  now cost life instead of ending the run: a car takes half (and flings Nicole clear,
  seeing stars), a skateboarder or a punk 15, a hobo's grip 3 a second, a zombie's
  bite 10. After any hit she flickers and cannot be hurt again for 2.5 seconds. A cop
  catching her still ends the run at once. Out of life it is RUN OVER or KNOCKED OUT.
- Pizza slices (about 40 across the map) lie on the pavement by some street lights,
  with a pulsing ring so they show up at night. Walking over one restores 35 life, past
  full into the overcharge stretch (see below).
- Fire hydrants (a few on every tile). When Stella sees one she hasn't marked she
  goes and pees on it, rooted there for 3.5 seconds, and the leash holds Nicole where
  it runs out. She needs 40 seconds before the next one.
- Squirrels at the foot of some trees. When Stella (or Nicole) comes near, one bolts up
  the trunk; Stella chases it, then stands under the tree barking up at it for about 8
  seconds, rooted, with Nicole held by the leash. The barking is loud: cops come.
- Zombie hobos (about 24 doze in the alleys). They wake when Nicole is within 340
  units and shamble after her by smell, moaning (cops hear it). They are slower than
  even a sneak, so they only catch her if she stops. A bite costs life and slows her.
- A reason to keep moving: stand about (stay within 70 units of one spot) for 8
  seconds and zombies start turning up out of sight, one every 4 seconds (up to 6),
  and shamble towards her. A toast warns the first time.
- Seeing stars: when Nicole is knocked down (skateboarder or punk) sparkles circle
  her head until she is up. A skateboarder knocks her down for 2.5 seconds (was
  1.4); it still never ends the run.
- Playtest telemetry. `RunLog.gd` records every run: time, distance, how many
  times cops saw Nicole, chases started and escaped, knock-downs, time sneaking,
  lit, dragged or held, and how the run ended (won, caught, run over, or
  abandoned with R) and where. F3 shows a live readout. Finished runs print a
  `RUNLOG` line and are saved (`user://runs.jsonl`; in the browser,
  `localStorage.getItem("curfew_runs")`), so playtest results can be pasted back.
  C copies every run since the game was opened (as JSON) to the clipboard, ready to
  paste. The end banner shows no stats: it is just the title and the prompt.
- `docs/tools/bot_playtest.gd`: a scripted player (rush, sneak, careful) that
  walks an A* route through the real game and reports win rate, deaths by cause
  and how far runs get; `policy=profile` measures the routes. First baseline: the
  bots reached only about 10-40% of the way, mostly killed by cars and by cops
  that stand on the route. See docs/HANDOFF.md.
- Street people to avoid. None of them can end the run on their own, but all are
  loud (so cops come) and all cost time:
  - Crazy hobos live by the burn barrels (24 across the map). One mutters and
    shuffles about his spot until Nicole comes within about 100 units, then rants
    at her, shuffles over and gets hold of her: she crawls at a third of her speed
    while he has her, and he keeps bellowing.
  - Street punks (about 46) loiter in twos under street lights. They notice her
    from 150 units, jeer for a moment (time to run), then chase her at 92 units/s,
    faster than her walk. A punk who catches her shoves her flat on her back for
    just over a second, then gloats before the next go. They give up if she gets
    far enough away.
  - Mean skateboarders tear along the roads at about 190 units/s (about four
    near her at a time), swerve at her if she is in their way, and knock her flat
    for a moment on contact.
  New pixel-art sprites for all three, and a gruff "yell" sound. Nicole can now be
  knocked down (`stun`) or held (`hold`).
- A proper street grid. The city is now regular blocks between roads: four-lane
  avenues (with a double-yellow centre line and white lane dashes) and two-lane
  streets (a broken yellow centre line, a solid white line by the parking lane),
  zebra crossings on every arm of every junction, and pavements round every block.
  Streets are narrower than before (114 units, avenues 148, where the old layout
  ran 100 to 220+ wide). A few blocks are open plazas, paved, with a fountain, trees,
  benches and planters; Nicole starts in one. Cops patrol loops round the pavements
  of the blocks, and cars park along the streets (one side, not on avenues).
- Traffic that never fades or vanishes in view. A traffic director spawns cars on the
  right-hand lanes of nearby roads at least 700 units from Nicole (far outside the
  view) and removes them only once they are 1,250 units behind, so a car is never
  seen appearing, fading out or disappearing. (Before, each car drove a short fixed
  stretch and faded out at its ends, which looked like cars vanishing.)
- `docs/tools/run_tests.py` runs all the headless checks, each with a timeout (a
  script error in a headless run otherwise leaves Godot hanging forever), and says
  which pass.
- Traffic. Cars drive up and down the roads (about 16 round Nicole at a time, spawned and removed off screen). If one hits Nicole or Stella the run is
  over ("RUN OVER"), so the player has to watch for headlights and pick a moment to
  cross. Each car has headlight beams on the road ahead, honks when she is in its
  way (the horn carries 240 units, so cops come to look), whooshes as it passes,
  and fades in and out at the ends of its road.
- Street lights now matter. Standing in a lamp's pool of light makes a cop see you
  about 1.8 times faster (as with the trash fires), and Nicole and Stella warm in
  tint when lit. A flickering lamp lights nothing while it is out. Pools are
  smaller (56 units) and the lamps further apart, so there are dark routes.
- Ten kinds of street furniture and junk, about 450 across the map: dumpsters,
  crate stacks, striped barricades, fire hydrants, mailboxes, benches, phone booths
  with lit glass, trees with leafy crowns, traffic cones and planters. All solid,
  placed in the gaps along the kerbs and kept clear of patrols, cars and the start.
- Home is random. Each run picks a different building as the house: a wide one
  at least 4,500 units from the start, with open street in front of its door
  (no bin, barrel, vent, patrol or other building on it). The map, the win
  check and the parked cars all follow. `docs/tools/test_home.gd` checks many
  seeds; `test_reachable.gd` checks the way home is walkable for each.
- Online at https://mtmangum.github.io/curfew/ (GitHub Pages). `./deploy.sh`
  exports the web build and publishes it to the `gh-pages` branch as a single
  fresh commit.
- A small map in the top-right corner. It only knows what Nicole has seen: the
  streets and buildings within about 380 units of wherever she has walked are
  revealed and the rest stays dark, so exploring uncovers it. Home is always
  marked (a pulsing gold house) with the distance in metres underneath. It shows
  no cops or cats, since she can't know where they are. N hides or shows it.
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
- The loading page no longer hands over before the tip on it can be read. A cached start took about a
  second, so the tip (and then the "Home is the house with the lit door" line) flashed by. Once the game
  is built it now asks the page how much longer to wait (`window.curfewHold`, answered by
  `Main._hold_for_loader`), and the page says: until the tip showing has had its reading time (1.2 s plus
  40 ms a character, at most 5 s, so about 3 to 5 s from opening the page on a fast start). A slow
  start is never held (nothing waits past 5.4 s from opening), pressing a key or clicking skips the wait
  (the page says "Press any key to go."), and the game stays frozen and out of sight meanwhile so nothing
  happens behind the page. Tips also rotate no sooner than they can be read (the long ones used to be
  replaced after 4.5 s) and stop rotating once the wait starts. Checked in a simulated page (fast,
  slow and skipped starts, 14 random tips each) and in headless Chrome, where the game polled the
  page and started 4.2 s after asking for a 4 s hold. The longest tip was shortened to fit.
- What stands on a roof (the air-conditioning units and the water tank) is now a piece of its own on the
  building (`scripts/RoofProps.gd`), so it can fade on its own terms when the building goes see-through.
  Anything that, seen from the camera, reaches outside the building's outline (a tall water tank near the
  back edge pokes up over the street behind: all 172 of the tanks do, by up to 27 px, and none of the 1,187
  units) is hidden altogether while the building is see-through, so nothing looks like it is standing in the
  street (`Roofs.overhangs`; the rule is geometric, not "tanks"). The rest fade to the building's alpha
  squared, about 9% where the building is at 30%, and they stay over the building. (`Sprites.roof_box` is
  the box helper the roof pieces share.)
- Stella's barks are now real ones, cut from a recording of a dog (`docs/barks.m4a`, the owner's own) by
  `docs/tools/process_barks.py`. The first three singles were told apart by nobody: every bark in the
  recording is about 0.12 s and those three had almost the same tone (centroids 1543-1617 Hz). The set
  is now four singles picked for how they differ (a low woof near 940 Hz up to a brighter yelp near 1790 Hz,
  and one a little longer), a pair and a run of three; the game never plays the same single twice in a
  row, now and then plays a run, and wobbles the pitch by about 12% and the volume. The synthesised barks
  (two rounds of them, the second tuned after the first sounded like a laser) never read as barks and are
  gone, along with the helper code that made them. Measured, not heard: the tone figures are from the
  files, so the real test is how they sound.
- Coming back after a lost run, she is put where she fell (it was moving her a median of 450 units on level
  1, 800 on levels 2 and 3, and thousands, often back to the start, when she was caught at a cop: the "no
  cop within 380 and no patrol within 220" rule left almost no spot). She now comes back at the spot, or the
  nearest open ground within a few steps, and what could end her at once is moved instead: a cop whose
  post is within 380 is sent to the far end of his own patrol, and street people within 160 are told to
  leave her be for a few seconds. (`Main._respawn_spot`, `_clear_threats_from`, `Cop.send_away_from`)
- Things far from the action no longer run a script every frame: an activity gate (`ActivityGate.gd`, every
  quarter of a second, and at once if Nicole jumps far) switches off the per-frame script of cops, cats,
  street people, squirrels, pizza, fires and flickering lamps beyond 1,000 units and back on inside 900.
  They already stood still out there; they were just being called to say so (559 of the 8,000 nodes ran a
  script every frame, now about 85). A small win natively (about 0.2 ms a frame), more on slower devices.
  It works through each node's process mode, separate from `set_process`, so a node stopped on purpose
  (a test freezing a cop) stays stopped.
- Much faster drawing, with the same look. A profile showed the frame time was dominated by draw calls:
  nearly all the art used `draw_colored_polygon`, `draw_circle` and `draw_polyline`, which Godot draws one
  call each, so a view cost about 2,500 draw calls (4,700 on level 4). Triangles and quads now go through
  `draw_primitive`, polylines through `draw_multiline`, circles, blooms and puddles through one shared disc
  texture, and the ground is drawn in runs of the same kind, which Godot batches. A typical level 1 view
  went from about 2,500 draw calls to about 190, and level 4 from about 4,700 to about 250. Frame time with
  Godot's Compatibility renderer (the kind the browser build uses), uncapped, on a fast Mac: level 1 12.8 ms
  to 5.0 ms and level 4 22.2 ms to 7.4 ms, about 2.6 and 3 times faster. (With the default desktop renderer
  on the same Mac level 1 was already at the screen's 120 fps and level 4 went from about 90 to 120.) The
  helpers are in `Sprites.gd` (`fill`, `polyline`, `outline`, `disc`, `ellipse`) and the rules are in
  `docs/HANDOFF.md`. Browser numbers are not measured. (An earlier note here quoted 23-28 fps before and
  53-63 after: those readings were taken on a machine that was busy with something else and were wrong.)
- Code tidy, no change to the game: `Main.gd` (947 lines) hands its audio to `AudioDirector.gd`, its draw
  order and see-through buildings to `DepthSorter.gd` and its heads-up display to `Hud.gd` (Main keeps
  forwarding `play`, `play_at`, `bark`, `footstep`, `_show_toast` and `_show_banner`, so the rest of
  the game is untouched), and `LevelBuilder.gd` (727 lines) hands the street furniture, squirrels,
  plaza zombies and phone booths to `FurnitureBuilder.gd`. The tests that reached into the moved
  parts now go through `main.audio`, `main.hud` and `main.builder.furniture`.
- Stella loses interest in cats: after about seven seconds of going for one she gives up on it and
  ignores every cat for half a minute, so a cat that will not run no longer has her hauling Nicole about
  for ever. (`Dog.CAT_INTEREST`, `CAT_BORED_FOR`; counted in the run log as the stop "cat_bored")
- Home is not marked on the map any more: the dashed ring that tightened as you got close, and the
  "HOME ABOUT 900 m NE" caption, are gone. The house appears (with its distance) once you have seen it
  or got within about 260 units. A phone booth call still fills in the map around the booth, but no
  longer marks home. (Level 1's balance with this is untested.)
- The loading page's cop holds a real silver torch (the beam starts at its lens), keeps it out in front
  when he runs, and swings a club from his other hand. The walk cycles are one strip of frames slid
  along in whole-frame steps, and every animation on the page is now plain linear keyframes with no
  `steps()` timing: Safari runs `steps()` animations on the page's own thread, where they stalled (and
  one frame could vanish for an instant, a flicker) whenever the game was busy building the city.
- The loading page animates more smoothly. The cop, Nicole and Stella now move with CSS transforms and
  the walk cycles and progress bars with transform and opacity animations, which the browser runs
  itself, instead of `left`/`width` transitions and an image swap from a timer, which stutter whenever
  the game is busy building the city.
- One fountain in three is switched off, for variety: still, dull water with a few leaves on it and no jet.
- Street lights that flicker now do it where you can see it: steady, then every few seconds a second-long
  stutter (drops out, back, out again, dark for a beat). More of them flicker (one in six on level 1, one in
  four on level 2).
- Only buildings fade out when Nicole walks behind them. Benches, trees, the fountain, hydrants, phone
  booths and the rest of the street furniture, and parked cars, all stay solid.
- The sound of the leash going taut (`tug`), which plays the moment Stella lunges at a cat and barks, was
  a falling chiptune zap and is the likelier source of the "laser gun" sound: it is now a rope creak,
  a low thump and a huff of breath, with no pitch sweep.
- Stella's bark no longer sounds like a laser: the pitch holds (it used to dive by nearly half in a
  fifth of a second), the voice is a rasping click-train through broad vowel formants with plenty of
  breath, and there is a short snap at the front. Same three barks (the third a double "ruff-ruff").
- Fountain water is animated: a pulsing jet, droplets that arc out and fall back into the basin
  (each starting a small ripple where it lands), ripples spreading from the jet's foot, and glints
  sliding over the surface. Only fountains near the view are redrawn each frame.
- Coming back after a lost run, she is never put near a cop: the spot must be at least 380 from every
  cop and 220 from every patrol route (a cop would be along in moments), searching outward from
  where she fell and falling back to the usual start.
- The game is now called **Streetwise II: Curfew** (it was just "Curfew"): the window and page
  title, the loading page (a small "STREETWISE II" over the big CURFEW), the README and the
  notes. The repo, the web address and the internal names (`curfew_runs`, `CURFEW_LEVEL`,
  `window.curfewBoot`) are unchanged, so nothing saved or linked breaks.
- Phone booths now look like phone booths: a glass booth on four posts with the telephone
  inside and a handset sign on the roof. A working one is lit and glows on the pavement, with
  a cyan handset bubble bobbing above it in place of the old diamond; the rest are dark, and
  so is a working one once its call has been used. Booths are put on the street-facing
  pavement, and a booth with a building in front of it is never a working one (so a marker
  never floats over a building with no booth to be seen). About one booth in three that you
  can see works.
- Cops on the map are no longer tracked: a mark appears only for a cop Nicole can actually see
  (never through a wall), and fades in ten seconds (it was 45). It is where she last saw him,
  not where he is.
- Their own sounds. The bin-crash clang now means one thing, a cat tipping a bin. A car
  hit, a skateboarder clipping Nicole, a punk's shove and a zombie's bite each have a
  sound of their own (`car_hit`, `skate_hit`, `shove`, `zombie_bite`), and zombies moan
  with a long low groan (`zombie_moan`) instead of a slowed-down yell. Synthesised in
  `docs/tools/render_sounds.py`.
- You can get away from a zombie. His grip is weaker (she keeps 60% of her speed in it,
  faster than he walks), it lasts at most 2.5 seconds before she wrenches free and he
  staggers back, and he cannot take hold of her again for 6 seconds. They are there to
  slow her down, not to pin her.
- A cop's torch beam now leaves the torch. It used to start at his feet (so it looked like it
  bent down to the ground beside him); now it fans out from the lens in his hand, at the
  height of the torch, to where it reaches. The faint shaft down to the ground is gone.
- After a lost run (or R mid-run) you start again where you fell instead of at the start,
  on open ground with no cop, street person or zombie close (the world is rebuilt, so they
  are back at their posts), and with a fresh life bar. A win, or Shift+R, still starts a
  new neighbourhood from the start.
- The noise rings are now a faint, smooth ring spreading over the ground as an isometric
  ellipse and fading as it goes (a second, fainter one just behind it). No dots, no dashes,
  and about a fifth of the old opacity. `scripts/NoiseRing.gd`.
- Trees match the isometric look: the crowns are clusters of isometric blocks (a lit top
  rhombus and two shaded sides) softened with small leafy tufts, on a square trunk; the pine
  is stacked faceted pyramids (`docs/tools/render_trees.mjs`).
- The loading page's cop starts at the far end from the house, facing away with his torch
  sweeping the other way. Once Nicole is well under way he notices, turns, and runs after
  her from a good way back with his club out and his torch bobbing ahead.
- A gentler start. Nothing that hunts her is placed near the start: no cop patrols within
  1,000 units of it (56 cops now, down from 60), and no hobo, punk or zombie within 900.
  Traffic and skateboarders build up with distance (none within 700 units of the start,
  the full amount from 2,200), and the linger zombies wait out the first 45 seconds and
  the start area. There is time to look round, play with the fountain and the squirrels,
  and learn the controls before the first threat.
- On the loading page the cop's torch beam now starts at the lens of his torch, sweeps
  about as he searches, and he turns to look the other way every few seconds, instead of
  holding a beam on Nicole.
- Better trees: pixel-art foliage built from overlapping leaf clumps (shaded from the top
  left, speckled with light and dark leaves) over a barked trunk with a root flare and
  limbs, in four kinds: round oaks, tall elms, pines, and the odd autumn tree, with a soft
  shadow on the ground. Made by `docs/tools/render_trees.mjs` (`assets/sprites/tree`).
- Half as many punks (about 24, down from 48): one pair under every 22nd street light.
- No steam vent stands behind a building any more. A plume rising behind a block looked
  like the building was smoking, and the grate was hidden anyway; those vents are
  dropped (38 are left, from 72).
- The map is on M and the sound mute is on N (they were the other way round). The
  on-screen SNEAK button is gone: it sat on top of the restart hint. Sneak is Shift.
- A punk who knocks Nicole down gloats for a moment and then leaves her alone for 12
  seconds, so she can get up and get away; a punk who finds her already down backs off,
  and one who cannot catch her gives up after 8 seconds.
- Stella's barks carry much farther (340 units, up from 190) and tell the cops where
  Nicole is, not just where Stella is. A cop who hears one is keyed up for 8 seconds:
  quicker to get there, more suspicious once he does, and he searches longer.
- Fountains no longer fade out when Nicole or Stella stands behind them (buildings and
  taller street furniture still do).
- A cop gives up a chase he cannot win: after 8 seconds without getting within 30
  units of Nicole he stops even if he can still see her, catches his breath for a few
  seconds and ignores her at a distance for 5 more.
- A hobo's grip now lasts 3 seconds at most; she wrenches free and he cannot grab
  her again for 6.
- Car headlights throw a soft pool of light on the road ahead (brightest at the
  bumper, widening and fading with distance, dithered like the street lamps' pools)
  in place of two flat, hard-edged grey wedges that looked like dark triangles.
- Cops react the moment they see you. A cop who sees something stops walking and
  turns to look at it while his suspicion builds, starts the chase sooner (at
  0.2 instead of 0.3), and if he loses you after even a glimpse he goes to where
  he saw you instead of carrying on with his patrol (before, a brief sighting could
  leave him walking the other way).
- Code: level generation (tiles, parked cars, street lights, furniture, traffic,
  scenery) moved out of `Main.gd` into `LevelBuilder.gd`.
- Stella's walk is smooth. She used to follow all-or-nothing, so while Nicole
  walked she kept crossing her start and stop distances and flashed between the
  walking and sitting poses (28 to 67 times in four seconds in a test). Her speed
  now eases with how far behind she is, so she keeps pace and slows to a stop; she
  sits only after being still for a moment, and only turns when the direction is
  clearly to one side.
- About a third as many parked cars (about 840, down from 2,300): "too many".
- Code: level data moved out of `Main.gd` into `LevelData.gd`, and collision and
  line-of-sight queries into `Collision.gd` (Main keeps thin wrappers, so nothing
  that calls `main.slide(...)` etc. changed). First steps of a cleanup that is
  splitting the 1,100-line `Main.gd` into focused files.
- A real chase. A cop who sees Nicole (suspicion past 0.3) now runs after her at
  80 units/s with his club out, and the game ends only when he reaches her, not
  the instant a bar fills at a distance. She walks at 85, so she can just
  outpace him (sneaking at 42 cannot). He follows her to where she was last seen,
  stops running after four seconds without sight of her, then looks around and
  goes back on patrol. A noise does not turn him from a chase.
- Stella faces the cat for as long as she is after it, even when she stops beside
  it or the leash holds her back (she used to keep facing her last direction of travel).
- Stella barks at cats: once as soon as she notices one and again as she runs at
  it (every 1.1 s while she is after it), each bark carrying 190 units to any
  cop. Only the bark that lands on the cat sends it running.
- Street lamp art redone: a cast-iron post with a plinth, bands and a curved
  arm, a lantern with a pointed cap, glass and a frame, a warm bloom, a faint
  shaft of light, and a pixel-dithered pool of light on the ground in place of
  the stacked rings.
- Nicole's footstep sound is switched off for now (it never sat right). Her steps
  still make noise that cops can hear, and `Player.FOOTSTEP_SOUND` brings the
  sound back. Cops' footsteps still play near you as a cue.
- Much more ground to walk on. The world is now six times bigger: a 3x2 grid of
  the 2560x1440 district (7680x2880 in all), with the middle column mirrored
  so it doesn't repeat exactly. You start in the bottom-left and the house is
  somewhere far away (it is chosen at random each run, at least 4,500 units
  off). It has 60 cops, 90 cats, 78 steam vents, 78 bins, 24 trash fires and
  162 buildings. Cops and cats far from you stand still and cost nothing.
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

### Removed
- Two more dead items (`Building.SHOP_LIT`, `Vitals.last_source`).
- Unused assets and code: the old chiptune `bark.wav` and `lure_drop.wav`; the boombox, rats and
  steam-puff sprites; the dog's attack, leap, lick and second gallop frames; the player's second
  idle, jump, kneel, prone and stumble poses; and a handful of dead functions, constants and
  variables. The sprite and sound generators in `docs/tools` no longer write them.

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
