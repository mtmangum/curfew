# Playability and engagement audit — 2026-10-04

The short, forgiving first homecoming is working as a route-survival introduction. The largest risks to continued play are the abrupt level 2 transition and incomplete touch controls. Level 2 simultaneously removes navigation help, lengthens the journey, and sharply increases patrol and traffic pressure. In this sample, every route bot was caught before Stella supplied a home hint. A pointer-only player also cannot resume after the game auto-pauses.

This audit applies the [free browser game design principles](../../../DESIGN_PRINCIPLES.md): earn an early success, explain danger before punishment, preserve learning after mistakes, and give players a reason to continue. It records measured mechanics and review findings; it does **not** establish human completion or retention rates. Gameplay rules were left unchanged.

**Implementation follow-up (2026-10-05):** A1’s pointer controls have been released in `78fa423`; see [verification and remaining device checks](../../../qa/2026-10-05-pointer-controls.md). The evidence below describes the original audited revision. A2’s level 2 bridge and threshold-aware patrol warning have also been released in that commit; see [balance verification](../../../qa/2026-10-05-second-level-playability.md). A3 is released in `e98794b`; [navigation verification](../../../qa/2026-10-05-navigation.md) records requests, priority and detours. The broader HUD readability issue, A4, remains open.

## Scope and evidence

- Source revision: `62cf5d4a373747ad32b6ad05f728dcb479c24d9a` on `main`, including the found-item release.
- Godot 4.7.2, fixed 60 Hz headless simulation. Thirty-two route runs: rush/careful policies, six home IDs each on levels 1 and 2, four each on level 3, one run per policy/home, traffic enabled, 180-second limit.
- Twelve controlled detection fixtures, actual pause-handler inputs, one clue-interruption fixture, and nine no-input first-hint probes. See [probes.json](probes.json), [probes.log](probes.log), and [audit_playability.gd](../../../tools/audit_playability.gd).
- Chrome desktop inspection of the normal Web export, served on an isolated local origin. First-visit presentation, keyboard pause/resume, a click on the paused canvas, a fresh load at a responsive 390 × 844 CSS-pixel viewport, and level selection followed by a browser-toolbar reload were inspected. This was viewport emulation, not a physical phone test.
- Reviewed navigation, Stella, hazards/recovery, items, tutorial persistence, failure/win flow, level progression and mobile affordances. Levels 4+ received source review only.
- The Web pack used for browser inspection is the previously verified normal release pack: SHA-256 `ab3dc0762eed13061557b53fcf5ff17712c593a94a3e5c1853a6711ac096b74b`.

Raw route evidence: [level 1](level-1.json), [level 2](level-2.json), [level 3](level-3.json), with corresponding `.log` files. [summary.json](summary.json) aggregates those records using ordinary statistical medians.

## Measured experience

| Measure | Level 1 | Level 2 | Level 3 |
| --- | --- | --- | --- |
| Route outcomes | 12/12 won | 12/12 caught | 8/8 caught |
| Run duration range | 22.6–29.2 s | 20.1–43.1 s | 14.2–33.2 s |
| Rush median duration | 27.2 s | 24.4 s | 25.85 s |
| Careful median duration | 27.9 s | 32.85 s | 22.3 s |
| Initial straight-line home distances sampled | 1,455–1,713 | 4,736–6,446 | 4,993–6,055 |
| Chases / recorded escapes | 0 / 0 | 16 / 2 | 12 / 2 |
| Home-scent events during route runs | 16 | 0 | 0 |
| Runs with car damage | 0 | 8 | 1 |
| Runs with skater damage | 0 | 4 | 2 |
| Usable items found | 0 | 2 extinguishers | 2 coffees, 2 treats |

Damage-source counts overlap; they are not counts of deaths. All deaths here were cop captures. Level 1 runs did collect pizza; “usable items” means the carried treat/donut/hoodie/extinguisher/coffee system. Bots did not use those items.

No-input probes, with traffic disabled, supplied the first scent at 8.18–11.27 seconds on level 1, 45.30–52.28 seconds on level 2, and 60.52–82.85 seconds on level 3. All nine were still playing and had zero displacement before the hint. These measure an undistracted start, not a wandering beginner. The level 2 route runs ended before even the configured 40-second minimum scent interval except three runs; those three also received no scent.

### The level 2 transition changes too much together

| Rule | Level 1 | Level 2 |
| --- | --- | --- |
| Fraction of patrols present | 20% | 100% |
| Detection-rate multiplier | 0.35 | 1.0 |
| Suspicion threshold for chase | 0.7 | 0.2 |
| Cop chase speed | 68 | 80 (Nicole walks at 85) |
| Nearby car target | 2 | 18 |
| Nearby skateboarder target | 0 | 4 |
| Street NPCs / lingering zombies | Absent | Enabled |
| Home distance bounds | 1,400–2,200 | At least 4,500 |
| Scent interval when free and safe | 8–14 s | 40–65 s |
| Working phone booths | Yes | No |

Source: `LevelSettings.for_level`, `Cop`, `Player`, `TrafficDirector`. Traffic ramps with distance from the start (700 to 2,200 units); all 18 cars are not present immediately. Even with that ramp, car and skater damage frequently preceded capture.

Controlled continuous-visibility fixtures placed a moving Nicole 60 or 100 world units directly ahead of a cop on an open road, lit, with Stella far away. They freeze movement and measure detection only:

| Conditions | Level 1: seconds to chase | Level 2 | Level 3 |
| --- | --- | --- | --- |
| 60 units, walking | 0.817 | 0.083 | 0.083 |
| 60 units, sneaking | 1.483 | 0.150 | 0.150 |
| 100 units, walking | 1.050 | 0.117 | 0.100 |
| 100 units, sneaking | 1.917 | 0.200 | 0.183 |

These are scenario measurements, not a universal spotting time. They show that level 2 can leave almost no time to notice a patrol and react after entering continuous sight. The yellow `?` belongs to investigation; uninterrupted sight in patrol can go straight to red `!`. The small suspicion bar remains the only pre-chase visual signal in that case.

## Prioritized actions

### A1 — P0: make pause and essential controls usable without a keyboard

**Confirmed:** `PauseMenu._unhandled_input` accepts only P/Esc. Its overlay has no Resume button. Actual mouse and touch handler probes both leave the tree paused; P resumes. Clicking the paused canvas in Chrome also left it paused. Focus loss calls `pause()`, so a player returning from another tab/app needs a keyboard to continue.

`Main.sneak_toggle` is retained only for tests/bots; no UI exposes it. The HUD's key hints ignore mouse input. Sneak is essential from level 2, and the torch becomes essential in level 3 darkness. Movement and the item slot support pointer input, but the complete play loop does not.

**Action:** add an obvious Resume button and reachable pause/sneak controls, plus a torch control on dark levels. Make sound controls available through that same small menu. Keep controls clear of movement and the retry banner; consume UI touches so they do not also set a walking destination.

**Acceptance:** finish movement → sneak → item use → pause → resume → retry using only pointer input. On actual Android Chrome and iOS Safari, switch away and back during play, then resume without a keyboard or reload. Repeat through a level transition and orientation change. Preserve keyboard shortcuts and automatic freeze on focus loss.

### A2 — P1: turn level 2 into a bridge, with a readable patrol warning

**Measured:** 12/12 level 1 routes survived with no sightings or damage; 0/12 level 2 routes survived. Careful routes lasted longer on level 2 but still failed. This is a strong mechanical discontinuity; it is not proof that a human cannot win.

**Action:** change the level 2 settings as a coherent introduction: retain generous early hints, shorten the first harder journey, moderate patrol/traffic density, and introduce fewer NPC types together. Carry more of level 1's warning threshold and escape margin into level 2. Add a conspicuous suspicion warning before chase and make its displayed progress correspond to the actual chase threshold. Do not increase level 1 hazard density merely to make its bot results look harder.

**Acceptance:** in comparable lit walking fixtures at 60 and 100 units, give level 2 at least roughly 0.75 seconds of readable warning as an initial tuning target, then validate by observation. Repeat route survival on several distinct homes with both policies; measure first hint, first damage, chase escape and completion. Treat persistent universal bot failure as a reason to inspect routes, while judging beginner enjoyment with people. Preserve successful level 1 quick wins and useful challenge later.

### A3 — P1: provide navigation help before a blind search becomes frustration

**Confirmed:** scent intervals rise to 40–65 seconds immediately after the first win. Working phone booths disappear at the same transition. `Dog._can_scent` also suppresses hints during tension or stun. New distractions are considered before an overdue scent can start. A hint already in progress is protected correctly; an overdue one can still wait through successive distractions.

`Dog` moves directly along the vector to home during scenting, rather than following a walkable route. Its regular following branch has detour handling. `MiniMap` reveals home only when near/seen; phone calls reveal an area, not the destination. A bearing can therefore point into a building without explaining the useful street choice. This navigation risk is source-derived; its frequency was not measured in this audit.

**Action:** retain early guidance on level 2, prioritize an overdue hint after the current distraction finishes, and offer a bounded “Stella, home?” request or lost-player prompt. Keep a brief bearing visible long enough to choose a street. If Stella physically leads, use a reachable waypoint around obstacles. Explain the first working booth's three-second stand-still interaction nearby.

**Acceptance:** a fresh player gets actionable direction within roughly 15 seconds on levels 1 and 2 when free and safe. Tests cover an obstacle between dog/home, consecutive distractions and a hint due during a chase. Finish the existing distraction before starting the hint, protect the full hint once started, and keep the home-discovery mechanic.

### A4 — P1: make the HUD and tutorial readable on a phone-sized viewport

**Observed:** the 390 × 844 fresh-load browser view letterboxes the 16:9 playfield, leaving small text and most height unused. `project.godot` keeps a 1280 × 720 canvas aspect. With a 390-pixel available width, the nominal playfield is about 390 × 219 CSS pixels, the 64-unit item slot about 19.5 CSS pixels, and the 18-unit clue text about 5.5 CSS pixels. These are layout estimates; physical-device readability and hit accuracy were not tested.

**Action:** adapt HUD scale/layout independently of world framing, keep action targets finger-sized, and reduce the persistent key strip to controls relevant to the current input method. Present movement, Stella and the goal first; reveal advanced controls when useful. If portrait is deliberately unsupported, provide a clear landscape prompt and verify that landscape is actually usable.

**Acceptance:** test 390 × 844 portrait and 844 × 390 landscape, both before and after loading, with readable goal/clues and a comfortably tappable item slot/menu. Verify on real phones at default browser zoom. A proposed starting target is 44–48 CSS pixels for primary touch controls; it is a design target, not a measurement of the current game.

### A5 — P1: preserve explanations when urgent clues interrupt them

**Confirmed:** `Clues.offer` records and saves a clue as seen before its reading time elapses. `Hud.show_clue` replaces the previous text and kills its tween. The collision probe offers scent then an urgent treat pickup: the treat replaces the scent explanation, and the scent can never be offered again. This conflicts with the principle that early hints finish without interruption. The hidden CLUES cheat is the only replay mechanism.

**Action:** queue ordinary explanations; if urgent danger interrupts one, restore it afterward. Mark a clue seen after a sufficient visible dwell, and add visible help/replay access in the pause menu. Give item details a readable, revisitable description. Do not require a long forced tutorial pause.

**Acceptance:** exercise scent → item and scent → cop warning collisions, including pause and death while a clue is visible. The important warning appears promptly, the interrupted explanation is recoverable, and persistence does not silently suppress unread teaching on the next visit.

### A6 — P2: teach one useful skill before the difficulty depends on it

**Measured:** level 1's 12 shortest-route runs never saw a cop and found no carried items. That establishes room for a quick success, but not mastery of sneak, escaping sight or using a treat. Human exploratory routes may differ.

**Action:** place an optional, readable patrol encounter and an accessible first treat/donut along the early journey, with enough safety to experiment. Use the level-clear moment to explain the next level's one or two new demands and why it is interesting. Keep the short successful route possible.

**Acceptance:** in beginner observation, players can explain Stella's home cue and demonstrate sneak or identify a safe route around a patrol before tougher pressure. Record whether they noticed the item and understood its use. Do not gate the first win behind a mandatory test.

### A7 — P2: preserve earned progress and explain the next attempt

**Confirmed by source and a browser check:** `Main.level_number` survives scene restarts as a static variable but has no browser-level checkpoint storage; a page reload begins at the default level. In Chrome, selecting level 2 with the existing LEVEL cheat and reloading with the browser toolbar returned to level 1. This checked selection persistence, not a manually completed level. Clue memory persists across browser visits, so a returning player can lose level progress while retaining suppressed explanations. `Main.caught` gives the generic CAUGHT banner, with no short reason or suggested response.

**Action:** store the last unlocked/completed level locally and offer Continue/New Run. Add one brief causal retry hint, distinguishing cop capture from depleted life and explaining that health does not protect against capture. Preserve the existing same-house, explored-map retry and quick transition. Saving a whole mid-chase world is unnecessary.

**Acceptance:** after clearing level 1, reload and continue into level 2 without replaying the introduction. New Run remains easy to find. Storage failure falls back safely. After a death, a beginner can identify what ended the run and one action to try next.

### A8 — P2: make balance comparisons reproducible

**Confirmed:** `bot_playtest._play` calls `seed()` before adding Main, but `Main._ready` calls `randomize()`. Traffic's separate RNG is seeded afterward; the home selection is controlled by `home_seed`. Other global actor randomness is not fully reproducible. Also, RunLog's `route` field is initial straight-line home distance, and `progress` is the best improvement in that distance, not path length or the fraction of a route completed.

**Action:** add an explicit audit RNG hook applied before actor generation, without changing normal play's randomness. Label distance/progress accurately and log distinct destination identities plus A* path length. Add item-aware and escape-aware policies before using bot win rates as balance acceptance gates.

**Acceptance:** identical audit inputs reproduce initial actors and event timelines; different run IDs vary them. Paired settings comparisons use matched initial conditions. Reports distinguish simulation outcomes from beginner completion.

## Preserve what is already helping engagement

- The near home, sparse hazards and frequent first-level scent are a good basis for earning the first win. The 12 successful routes show that the introduction no longer requires perfect hazard management.
- Stella's personality, short distractions and visual home cue give the game an identity. The median recorded rooted time was 3.5 seconds on level 1; that alone is not a reason to remove her behavior. Evaluate future forced stops together with warning time and nearby hazards.
- The same-house, explored-map retry preserves learning. Health grace and pizza allow nonfatal recovery. Build clearer failure feedback on top of those mechanisms.
- Win/next-level titles and changing weather, darkness and neon supply progression. Help more players reach and anticipate those changes before adding further hazards.
- First-use audio startup, the music fade, rooftop fading and obstruction-aware normal dog following support a low-friction presentation. This audit did not remeasure audio latency or performance.

## Suggested implementation order

1. A1 pointer/touch completion and A4 readable controls.
2. A2 level 2 warning and a gentler settings transition; A3 earlier useful navigation.
3. A5 reliable tutorial delivery; A6 safe optional practice.
4. A7 saved milestone and causal retry hint; A8 stronger measurement tooling.

Run a small observed beginner pilot after the first two steps: about 5–8 unfamiliar players across desktop and actual phones. Ask them to play with minimal coaching. Record time to understanding the objective, first useful home cue, first mistake, first win, explanation of death, successful retry, and the voluntary choice to start level 2. Also test leaving/returning to the tab. Aim for the existing “first homecoming within a couple of minutes including discovery” target. Report individual observations and counts; this sample cannot estimate population retention reliably.

## Reproduction and limits

From the project root, using the installed Godot binary:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,careful seeds=6 level=1 max=180 verbose=1 out=/tmp/playability-level-1.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,careful seeds=6 level=2 max=180 verbose=1 out=/tmp/playability-level-2.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/bot_playtest.gd -- policy=rush,careful seeds=4 level=3 max=180 verbose=1 out=/tmp/playability-level-3.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/audit_playability.gd -- out=/tmp/playability-probes.json
```

The probe script is diagnostic code under docs, not a production rule change. It disables traffic for detection/idle fixtures and does not persist run history or clue state in headless mode. Raw logs include teardown ObjectDB/resource warnings; those were not treated as new memory findings here.

Bots know the destination, use A* pointer steering, and do not model reading, searching or motivation. They do not use carried items or phone booths, nor systematically choose cover after being spotted. Home IDs can choose the same house: the six sampled IDs give four distinct initial distances on level 1 and five on level 2. Results cannot be interpreted as six unique maps, exact paired randomness, or human win percentages. No-input fixtures are not novice sessions. Clue timers use wall-clock time, so headless fixed-FPS runs do not establish reading-time quality. Phone hardware, touch emulation fidelity, landscape usability, Safari, later-level survival, real-player item tactics and return-session behavior need further observation.
