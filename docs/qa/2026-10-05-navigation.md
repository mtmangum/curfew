# Navigation playability follow-up — 2026-10-05

Implements A3 from the [playability audit](../audits/2026-10-04/playability/REPORT.md): give useful direction before searching becomes frustrating. These changes are local, based on the A1/A2 release `78fa423` and its verification commit `5ba2a43`; they have not been committed or deployed.

## Player behavior

- **Stella, home?** (also **H**) requests a hint. It waits until Stella finishes the current distraction and Nicole is safe, with a 30-second request cooldown. Repeated requests cannot restart or extend a running hint. The control shows queued, leading and cooldown states, consumes pointer taps, fits beneath the other controls and hides on the end screen or when home is found.
- An overdue hint gets the next turn after the current cat, squirrel, marking or sniffing finishes. A newly arriving distraction cannot take that turn. A started hint retains the existing protection from new animals. Tension, stun and nearby active pursuit defer its start; the direct chase check covers the frame before audio tension rises.
- Stella follows reachable local waypoints instead of pressing directly into a wall. The house bubble and direction arrow remain for four seconds after leading, giving time to choose a street. This preserves exploration: requesting help does not reveal the house on the map.
- An unused working booth shows **Stand still 3s** when nearby and visible. The first eligible phone clue explains that standing beside it for three seconds reveals nearby streets, without marking home. The nearby instruction remains useful when another clue is occupying the card. Calls and their noise/reveal rules are unchanged.

Level 1's 8–14-second and level 2's 10–15-second automatic hint intervals remain as released in A2. They apply when free and safe; a current distraction or pursuit can delay a hint. Existing early-level fixtures still pass. Later-level balance settings are unchanged.

## Route and memory bounds

`DogGuidance.gd` first checks a clear straight lead, capped at 300 units. A blocked lead searches a temporary 31 × 31 grid with 20-unit spacing, checks swept-circle clearance along edges, chooses a reachable exit toward home and smooths the resulting path. When home is inside the search but unreachable, an exit avoids choosing the same blocked wall face again. The search has at most 961 cells; its arrays are discarded after planning. Only the short waypoint list survives until the hint ends. Planning occurs once per hint, rather than every frame.

The planner considers static collision, with clearance for Nicole as well as Stella. It does not find a complete city route or avoid live patrols/traffic. Leads still use the normal leash and gentle pull; detours let Nicole ease toward Stella rather than undoing each sideways step. A current planted target is cleared before waiting on its timer, preventing a repeated arrival from resetting the stop indefinitely.

## Verification

Godot 4.7.2, fixed 60 Hz, macOS. [Headless fixture output](2026-10-05-navigation/fixture.log), [native fixture output](2026-10-05-navigation/native-fixture.log), and [final navigation runner result](2026-10-05-navigation/navigation-regression.log).

| Check | Result |
| --- | --- |
| Actual GUI home tap and actual H input dispatch | Both queue the same request; tap does not set a destination or leave held steering latched |
| Repeated request / request during an active hint | Rejected without extending the hint |
| Current cat, squirrel or marking followed by a fresh distraction | Current activity finishes; the overdue hint takes the next turn |
| Due request during chase, stun or tension | Waits, then starts when safe |
| Full hint and four-second bearing | Protected from new distractions; no home reveal from the request |
| Six real parked cars and six real buildings | All returned paths have swept-circle clearance; at most nine smoothed waypoints |
| Actual Stella movement around a parked car | Sideways progress and passage around the car, without clipping or a leash trap |
| Working phone instruction and interaction | Explained before use; unused at two seconds, used after three seconds |
| Finding home and end banner | Request control hides; found home rejects requests |

The final native blocked-route sample's slowest plan took **8.008 ms**; the corresponding headless sample took **8.272 ms**. These are small fixture samples on this Mac, not Web or mobile frame-time guarantees. The existing restart/memory lifecycle group passes.

All **19 regression groups** passed: navigation, scent priority, dog/cat, following, gait, clues, pointer controls, map/phones, memory lifecycle, planted stops, items, first level, second level, level progression, pause, pointer movement, neon sniffing, chase and stealth. See [regression output](2026-10-05-navigation/regressions.log). The final additional H dispatch assertion also passes through the runner.

The native 390 × 844 window fixture passes GUI control and layout checks, including the extra home button: [output](2026-10-05-navigation/small-window.log), [first-level controls](2026-10-05-navigation/first-level-controls.png), [dark controls](2026-10-05-navigation/dark-controls.png), [pause](2026-10-05-navigation/paused.png). Other visual evidence: [leading around a car](2026-10-05-navigation/leading-around-car.png), [phone instruction and clue](2026-10-05-navigation/phone-instruction.png).

The normal Web release export succeeded. Chrome loaded it on an isolated local origin; clicking **Stella, home?** displayed the leading state and visible house/arrow cue, and Pause remained usable. Local pack SHA-256: `30713a873bcedd6a46e439109b5644ff2a9debe2969171de66649bb82ca4a977`. The browser test tab, local server and native fixtures were closed after verification.

## Remaining observation

These checks establish mechanics, not beginner comprehension or engagement. Watch first-time players choose a street from Stella's cue, use the request when lost and discover a working booth. Check the hint-start planning cost and touch controls on physical phones. A4's broader HUD/clue/item readability and A5's interrupted-clue behavior remain open. A local lead can help around an obstacle without solving a long city route; judge whether repeated hints reduce wandering in actual play.

## Reproduce

```sh
python3 docs/tools/run_tests.py navigation scent_priority dog_cat dog_follow dog_gait clues pointer_controls minimap memory_lifecycle stella_stops items first_level second_level levels pause pointer neon chase stealth_rules
NAVIGATION_SHOTS=docs/qa/2026-10-05-navigation /Applications/Godot.app/Contents/MacOS/Godot --fixed-fps 60 --path . --script docs/tools/test_navigation.gd
POINTER_SMALL_WINDOW=1 POINTER_SHOTS=docs/qa/2026-10-05-navigation /Applications/Godot.app/Contents/MacOS/Godot --fixed-fps 60 --path . --script docs/tools/test_pointer_controls.gd
```
