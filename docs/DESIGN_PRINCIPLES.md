# Playability for a free browser game

Players have invested little in opening this game and can leave with one click.
Getting them to understand it and enjoy an early success is a design requirement.
Difficulty should grow after they have a reason to continue.

- **Earn a first win quickly.** Aim for a first homecoming within a couple of minutes
  of active play, including discovery. This is a design target to validate with new
  players, not a claim established by a bot that already knows the route.
- **Require participation without punishing discovery.** Stella points the way and
  waits at the leash limit; home hints must not carry an idle player toward success.
  Preserve meaningful movement and stealth choices while keeping early mistakes
  forgiving. Make guidance clearer before adding hazards to make the opening harder.
- **Teach through a forgiving first level.** Introduce movement, Stella, the scent
  of home, and readable patrols. Add hazards gradually: skateboarders and street
  people start on level 2; darkness and police cars start on level 3. Offer a nearby
  item and an optional patrol to experiment with, without gating homecoming. Explain
  the next walk's new demands and a useful response when the player wins.
- **Give direction before frustration.** Offer frequent early scent hints and a
  nearby destination. Hints must remain readable and finish without interruption.
  An overdue hint gets the next turn after a distraction; a bounded home request offers help when needed. Leads should choose reachable streets and leave a brief bearing to follow. Phone booths explain their short stand-still interaction nearby.
- **Make early mistakes recoverable.** A warning should leave time to respond;
  walking away and breaking sight should work. Keep the existing same-house,
  explored-map retry, so a mistake does not erase learning. Save unlocked levels
  between visits when local storage is available. Explain the cause of a lost run
  and one useful response on the retry card.
- **Keep friction low.** Preserve clear controls, legible feedback, quick loading,
  responsive audio and smooth rendering. Keep Pause and Sneak persistent; put secondary map/home actions in Pause and reveal Torch/items when relevant. Evaluate forced stops and new hazards
  together, rather than assuming each is harmless on its own.
- **Measure outcomes, then watch real beginners.** Check time to first useful hint,
  route length, completion and causes of death across multiple homes. Use bots to
  expose unfair routes and verify changes; use novice play sessions to assess
  comprehension, wandering, touch controls and whether players want to continue.

Before changing the introduction, ask whether a new player can understand the goal,
notice the danger, recover, and reach an early success. If not, simplify or defer
the feature to a later level. Later levels can be demanding once the rules are known.

## First-level tuning

The first pass uses a 1,400–2,200-unit home distance band, 20% of patrols, two nearby
cars, no skateboarders, and scent intervals of 8–14 seconds when Stella is free and
safe. Suspicion grows at 35% of the normal rate and a chase starts at 70% exposure;
chasing cops move at 68 units/sec while Nicole walks at 85. Level 2 retains that
reaction window, raises patrols to 40%, and uses 72-unit/sec chases. Its home band
is 2,200–4,200 units, with five nearby cars, one skateboarder, working phones and
10–15-second scent intervals. Punks, zombies and lingering pressure begin on level 3;
levels 3+ retain their existing balance settings. These numbers are tunable; the principles above persist.

See [the first-level balance report](qa/2026-10-04-first-level-playability.md) for
verification and remaining human playtesting needs.
