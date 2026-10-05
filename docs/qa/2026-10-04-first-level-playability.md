# First-level playability review — 2026-10-04

## Intent and commit review

Make the first homecoming approachable for someone who opened a free browser game
and has little incentive to persevere through repeated failures or a blind search.
The continuing requirements are in [Design principles](../DESIGN_PRINCIPLES.md).

Reviewed the new `e01a93a` commit against the previous `a83058e` baseline: level 5
neon, corner characters, their placement and lighting, activity/depth integration,
and Stella's new sniff behavior. The additions are gated to level 5 and preserve
the protection of an active scent hint. The neon regression check passes. No
blocking integration issue was found for this first-level change.

A minor existing level 5 caveat: `CornerFolk._process` pauses the sniff cooldown
outside the nearby view. Its advertised 40 seconds therefore means nearby active
time, rather than unconditional elapsed play time. If revisiting a corner should
always reset eligibility after 40 elapsed seconds, move the cooldown decrement
ahead of the distance guard in a future change.

## Tuning

| First-level setting | Before | After |
| --- | ---: | ---: |
| Home distance from start | 2,400–4,700 | 1,400–2,200 |
| Patrol fraction | 40% | 20% |
| Suspicion rate multiplier | 0.85 | 0.35 |
| Chase threshold | 20% exposure | 70% exposure |
| Chase speed | 80 units/sec | 68 units/sec |
| Nearby moving cars | 5 | 2 |
| Nearby skateboarders | 3 | 0; introduced on level 2 |
| Scent interval when free and safe | 22–38 sec | 8–14 sec |

Nicole still walks at 85 units/sec. Working phone booths, squirrels, cats, clear
lighting, same-house retries and the explored map remain part of the introduction.
Later-level difficulty settings retain their defaults. README, changelog, handoff
and gallery descriptions now agree with the roster and introduction.

## A genuine leash trap found during balance testing

On a route north from the start, Stella could wedge behind a parked car while
Nicole was already ahead of it. The dog tried to follow directly through the car;
the taut leash stopped Nicole. Replanning the bot's route did not solve this.
Diagnostics showed an 80-unit leash, a clear step for Nicole, a blocked step for
Stella, no distraction and no active chase. This was a game issue, not just bot
steering.

Ordinary following now plans a short detour when movement stalls for 0.25 seconds.
The temporary 8-unit navigation grid has a 48-unit margin, a hard 1,024-cell cap,
and refuses separations over 160 units. Planning retries are limited to once per
second. It uses the existing collision grid and avoids diagonal corner cutting;
the temporary navigation object is released after planning. Only the small path
is retained, and it is cleared on arrival or a distraction.

While she takes that detour, a taut leash gently eases Nicole back to give Stella
room. Reeling the dog toward Nicole instead would undo the detour at every step.
There is no teleport or change to the leash length. This following correction
applies on all levels; cat, squirrel, hydrant, corner-sniff and scent priorities
are preserved.

## Verification

- Passed the final focused checks: `dog_follow`, `first_level`, `dog_gait`,
  `dog_cat`, `scent_priority`, `stella_stops`, `tug`, `neon`, `chase`, `minimap`.
- Also passed `levels`, `home`, `start_safe` and `gallery` during tuning. The home
  check was run separately on level 1 across 12 built worlds: four distinct homes,
  all within the distance band, clear doors and no parked car across the zone.
  The first-level check additionally samples the chooser across 24 seeds.
- With a conspicuous walking Nicole 60 units directly ahead of a cop, the first
  chase starts after 0.817 seconds, versus 0.083 seconds on level 2. This is one
  controlled case, not a universal reaction time: lighting, distance, sneaking,
  alertness and Stella affect detection.
- Walking away for two seconds increases an initial 45-unit gap to 79 units.
- The first unblocked scent starts within its 8–14-second window; real traffic
  spawning respects the two-car nearby target and produces no skateboarders.
- A real parked-car regression verifies escape, collision, leash length, bounded
  path storage and that the path is discarded. A large teleport does not allocate
  a city-sized graph. Planning time is recorded below with the balance results.
- The production Web export succeeds. Chrome loads level 1; Stella's house bubble
  and explanatory scent card are visible and readable. The gallery shows
  skateboarders first appearing on level 2 and retains the new Neon Nose section.

### Published release verification

Gameplay commit `5a0b81eacf91e3a979d1c4b54a26ba7a77a6ff6f` was pushed to
`main` and published through `deploy.sh --skip-export`, using the successful final
production Web export. GitHub Pages reports build
`e02a376bee274e41c9d4d66fcce7bde602e867e8` as `built`, with no build error.

Downloaded live artifacts match the tested export byte for byte:

| Artifact | Bytes | SHA-256 prefix |
| --- | ---: | --- |
| `index.pck` | 3,744,120 | `77dd8b5cb7371c4c` |
| `sprite-gallery.html` | 5,453 | `2adecf06a6bf47cc` |
| `web/sprite-gallery.js` | 13,148 | `ffffff11ba08080b` |

A fresh Chrome tab loaded the [published game](https://mtmangum.github.io/curfew/)
and rendered level 1 with Nicole, Stella and the scent bubble. Pause worked, and
the verification tab was left paused. The temporary preview server and baseline
worktree were removed after verification. Unrelated work from the other agent
was excluded from the gameplay commit and deployment.

### Test harness corrections

The bot previously cut corners while looking ahead, could continue aiming into an
obsolete corridor after being dragged, and could stop at a grid cell just outside
the actual door. It now checks movement segments, replans after a stall, and enters
the real door zone. Actor/traffic randomness is seeded per home and run. The end
banner gets a frame to finish deferred layout before a test world is freed.

Both comparison builds use the same corrected bot. The older game runs in an
isolated worktree at `e01a93a`; the current game uses the revised tuning and dog
following. The scent test now uses an open road and removes incidental
distractions; it no longer assumes a particular randomly chosen home direction.
The home test now fails if it detects an invalid door, rather than merely printing
the problem count.

## Controlled balance comparison

Godot 4.7.2, headless, fixed 60 simulation fps; six home seeds, one run each of
`rush` and `careful`, traffic enabled, 120-second limit. These are 12 route-survival
runs per build, with the same corrected harness and per-run random seeds.

| Outcome | Before (`e01a93a`) | After |
| --- | ---: | ---: |
| Reached home | 0 / 12 | 12 / 12 |
| Caught by a cop | 12 / 12 | 0 / 12 |
| Hit by a car | 0 / 12 | 0 / 12 |
| Timed out | 0 / 12 | 0 / 12 |

After tuning, median completion is **27.3 seconds**, with a
22.5–32.2-second range. No run required a cop escape. This is deliberately a
forgiving navigation introduction; a controlled cop encounter separately verifies
warning and recovery. Across the 24 chooser seeds there are four possible homes;
the six balance seeds are not six unique destinations.

| Home seed | Before rush | Before careful | After rush | After careful |
| --- | --- | --- | --- | --- |
| 0 | caught (24.3s) | caught (48.0s) | won (27.3s) | won (26.5s) |
| 1 | caught (40.8s) | caught (27.2s) | won (28.8s) | won (32.2s) |
| 2 | caught (24.2s) | caught (25.1s) | won (22.5s) | won (22.6s) |
| 3 | caught (26.5s) | caught (38.6s) | won (27.3s) | won (24.7s) |
| 4 | caught (26.7s) | caught (26.5s) | won (26.6s) | won (28.8s) |
| 5 | caught (27.6s) | caught (32.5s) | won (28.8s) | won (28.8s) |

The parked-car fixture clears in **0.9 seconds** without clipping or exceeding the
existing leash tolerance. Twenty local route rebuilds averaged **0.384 ms** in the
headless check on this Mac. This small sample does not establish browser frame
budgets or mobile performance; rebuilds are capped and ordinary following does not
create navigation grids.

Reproduce the balance run in each checkout:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . \
  --script docs/tools/bot_playtest.gd -- \
  policy=rush,careful seeds=6 max=120 out=/tmp/first-level-results.json
```

Use the current harness in the older checkout too. The planner uses
[Godot's AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html)
with diagonal travel allowed only when neighboring cells are unobstructed.

## Limits and next human check

These bots already know the destination. They measure survival on a route, not
whether a beginner understands Stella, finds the route, enjoys it, or keeps
playing. Six home seeds can repeat the same house. The few minutes to a first win
remain a design target requiring novice testing, including touch controls.

Watch several first-time browser players: record time to understand the goal,
notice the first useful scent, reach home, retry after a mistake, and choose to
continue to level 2. In particular, check the jump in difficulty on level 2 and
whether repeated scent hints feel helpful rather than disruptive.

Headless scene teardown still prints the repository's existing ObjectDB/resource
shutdown warnings in both comparison builds. These are not evidence of a newly
introduced Web leak, and this balance pass does not replace the prior memory
audit or a long-session browser memory test.
