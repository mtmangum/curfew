# Performance audit follow-up — 2026-10-04

## Implemented: bounded audio resource reuse

The browser restart memory finding now has a concrete owner: Godot's Web sample registry. Instrumentation in an isolated diagnostic export reads scalar counts from the engine closure: registered audio samples and bytes, active playbacks and their buffers, pooled audio worklets, live WebGL texture/buffer counts, WASM capacity, and the optional Chrome heap estimate. It retains no audio/graphics objects itself. Twenty **actual scene reloads** exercise loops plus a bark, followed by scene disposal and 30 seconds idle.

Before the fix, old scenes/builders/furniture were released at every retry, but the sample registry accumulated new resource IDs. After playback stopped, 125 registered samples still owned 660,556,672 bytes of decoded buffers. An audio-disabled control registered zero samples and did not show the same per-retry heap increase. This identifies audio sample retention independently of Godot's object monitor.

`AudioDirector.stream_for()` now shares streams from a fixed roster across retries. `SteamVent` uses the same cache for its hiss. Each sound keeps its identity, so subsequent retries reuse its browser registration. Playback nodes remain scene-owned and old scenes still free normally. The cache accepts only known sound/loop names and cannot grow from arbitrary names. The final game keeps the existing sample backend, volume behavior and playback rules.

| After 20 reloads and 30 seconds idle | Original | Fixed cache |
| --- | ---: | ---: |
| Registered samples | 125 | 6 |
| Registered decoded buffer bytes | 660,556,672 | 31,458,920 |
| Active playbacks | 0 | 0 |
| Playback buffer bytes | 0 | 0 |
| Orphan nodes | 0 | 0 |

This removes about **629 MB** of registered decoded-buffer retention in that retry workload (roughly 95%). It intentionally retains one bounded resource set for the game session; it does not eliminate all audio allocation, prove a stable whole-browser RSS, or force browser GC. Playback creates temporary buffer copies. As the player encounters additional sounds, the registry can grow up to the fixed roster; six is the count for this particular probe, not a universal cap.

Chrome heap estimates were contaminated by preceding diagnostic documents in the same browser process. Live registry ownership is the decisive before/after measurement. Absolute Chrome tab warnings are not a reliable per-build comparison. The cache probe's legacy harness occasionally paused on focus loss; all 20 cycles and the final idle sample did complete. Later harnesses process always so profiling resumes when a tool window takes focus.

A related upstream report describes sample-backend memory growth on older Godot versions; that report alone did not establish this game's bug. The installed 4.7.2 engine's generated JS and this game's runtime registry counts provided the direct evidence. See [upstream issue #106098](https://github.com/godotengine/godot/issues/106098) and the [sample registry implementation](https://github.com/godotengine/godot/blob/4.7-stable/platform/web/js/libs/library_godot_audio.js).

Two exploratory stream-switch reports used the wrong enum space (ProjectSettings Stream=0/Sample=1 differs from AudioStreamPlayer's Default/Stream/Sample enum). Both were verified to remain sample playback and are explicitly excluded from comparisons. A corrected stream diagnostic export is available, but the selected fix preserves sample playback; no claim of a tested stream-backend improvement is made. [Godot's project-setting documentation](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-audio-general-default-playback-type-web) describes the backend tradeoff.

## Completed: crowd pressure and node inventory

The fixture adds stationary Node2D actors around the camera to exercise ordering/overlap work. This is sort pressure, not a full crowd-AI/rendering benchmark. Every actor z-index matched the uncached reference in all five cases.

| Visible items | Additional actors | Cached median / p95 | Uncached median / p95 |
| --- | ---: | ---: | ---: |
| 80 | 0 | 0.70 / 0.76 ms | 1.43 / 1.56 ms |
| 112 | 32 | 1.28 / 1.36 ms | 2.66 / 2.86 ms |
| 144 | 64 | 2.16 / 2.27 ms | 4.23 / 4.71 ms |
| 208 | 128 | 5.05 / 5.38 ms | 9.52 / 11.37 ms |
| 336 | 256 | 12.50 / 13.40 ms | 24.55 / 26.99 ms |

At 336 items, sorting alone consumes about 12.5 ms of a 16.67 ms frame budget. Current spawn visibility in this fixture was 80 items; an extra 256 simultaneous actors would leave little room for AI/rendering. No further sorting rewrite is justified for the current population by this result. Before a feature substantially increases visible crowds, add a spatial overlap broad phase and replace quadratic selection with a stable priority queue, validating ties/cycles and ordering on adversarial scenes.

The full level-10 inventory counted 9,172 nodes (sum of categories): 3,133 inline-script nodes, 1,260 plain Node2Ds, 769 StreetLights, 764 StreetObjects, 653 RoofProps, 528 parked Cars, 514 Buildings, 456 Sprite2Ds and 377 RoofFans among the largest groups. These are **node counts, not allocation sizes**. Batch/stream scenery only after a device profile establishes memory pressure; wholesale world restructuring is deferred. Inline script resource paths are empty, so their group needs finer attribution before choosing a target.

## Completed: network transfer check

Fresh concurrent curl requests to the deployed WASM and pack transferred 10,248,949 and 3,132,493 bytes respectively, completing in 0.55 and 0.73 seconds on this Mac's network. These are CDN transfer measurements, not full browser cold-boot times; CDN caches may be warm and compilation/world construction are excluded. Gzip is already enabled. Mobile network/device boot remains unmeasured. No custom engine rebuild was undertaken because this connection did not establish a loading bottleneck.

## Validation and session coverage

- **All 31 registered headless checks pass with the final sources.** The stricter full run passed 30/31; the corrected patrol fixture then passed its targeted rerun. The other 30 checks were unchanged. `tests.txt` preserves both results. Coverage includes stream-identity reuse across freed scenes, bounded-cache/unknown-name checks and real-restart helper release.
- Validation uncovered a reporting gap in the old runner: bare boolean failures and numeric failure totals were not enforced. The runner now rejects failed boolean checks and nonzero Godot exits, while allowing diagnostic dictionaries with false fields. The near-sound check counted children on Main instead of AudioDirector; that is corrected. Investigation fixtures now keep the cop within the activity radius, and both investigation/patrol fixtures freeze unrelated NPC shouts. The patrol stall threshold matches the cop's 0.01-unit movement threshold and resets when the AI deliberately advances past a blocked waypoint. It still requires every route target to be visited within 60 simulated seconds, plus over 100 units of actual walking, so an immobile cop skipping targets fails. Target visitation is not proof that every waypoint was physically reached. Investigation/patrol totals now have explicit pass/fail assertions. Historical pass counts from the old runner are superseded. Synthetic runner regression cases confirmed rejection of failed bare/concatenated booleans and nonzero exits, and acceptance of diagnostic false fields.
- Pre-cache native soak completed 30 simulated minutes at fixed 60 FPS: 108,001 frames, 71 actual reloads, 76 chases, wins/catches/car deaths, and about 136,362 world units walked. It reached 31 traffic cars and 10 skaters total. Configured targets are 28/8 **within the active radius**, so total populations can temporarily exceed those targets outside it; these are not hard global caps.
- Native soak clock was simulated: 30 minutes completed in about 222 wall seconds. Native results are headless CPU/lifecycle evidence, not rendered FPS or browser-GC evidence.
- Post-cache native soak also completed: 108,001 frames, 67 actual reloads and 67 chases. Across minute-end snapshots, static allocation ranged from 105.3 to 115.2 MiB (different active levels/populations). After cleanup it was 45.6 MiB, with 91 cached resources, two audit/root nodes, zero orphans and 1,728 objects. Cached audio intentionally raises the retained resource baseline; compare against a warmed baseline, not the earlier uncached counts.
- The Chrome wall-clock probe completed 1,800.49 seconds, 60,888 rendered/process frames, 21 real reloads and 21 chases across completed runs. It recorded three wins, 15 captures and three car deaths, walked about 37,939 world units, and reached 25 cars/nine skaters. See the timing qualifications below.
- Desktop Safari could not be operated: Computer Use returned “Computer Use was not approved to use Safari.” No physical iPhone/Android was connected. iOS simulators are present but were not treated as actual-device performance validation.

## Chrome cleanup and timing limits

The browser's final source hashes match the production scripts. After scene disposal and 30 seconds idle, there were **36 registered samples / 43,205,344 decoded bytes**, zero active playbacks and playback-buffer bytes, two audit/root nodes, 90 resources, 1,546 objects, and zero orphan nodes. Registered audio grew when an additional sound first played, remaining within the 38-stream roster; it did not accumulate another copy of the loop set on each retry. WASM capacity remained 144,703,488 bytes (138 MiB) throughout the recorded samples.

| Chrome measurement | Final live world | After cleanup + 30 seconds idle |
| --- | ---: | ---: |
| Registered decoded audio | 43,205,344 bytes | 43,205,344 bytes |
| Active playback buffers | 31,378,272 bytes | 0 |
| Nodes / orphan nodes | 9,037 / 0 | 2 / 0 |
| Live WebGL textures / buffers | 146 / 3,048 | 90 / 62 |
| Optional JS heap estimate | 156,181,116 bytes | 125,144,738 bytes |
| Pooled audio position worklets | 25 | 30 |

**This was 30 minutes of wall time, not 30 uninterrupted minutes of active gameplay.** The browser was occluded for long intervals; completed-run game clocks total 513.6 seconds, plus the unfinished final run. A three-second native process sample during a stall found the renderer main thread mostly waiting in its event loop. Bringing the game window forward resumed callbacks immediately. The raw report includes catch-up minute rows containing only one frame; those rows are excluded from frame-pacing conclusions. Foreground segments with over 1,000 observations had median 8.3 ms and p95 8.9–9.2 ms, with roughly one-second rebuild/path-planning outliers. The probe's route planner is diagnostic code, not a production game feature. Background gaps, external CPU work and reloads prevent treating this as sustained 30-minute FPS validation.

The optional heap estimate rose from about 64 MB at the first minute to 125 MB after cleanup, and the worklet pool reached 30. These are retained runtime/pool estimates, not proof of either a further leak or a stable total-memory plateau. A native sample observed a 428.2 MiB renderer footprint and 579.8 MiB historical peak at one instant; this is not a longitudinal whole-browser profile. The major decoded-sample duplication is fixed, while whole-process allocation profiling and an uninterrupted foreground/device run remain acceptance work. No script/parse errors appeared in the captured runtime log.

## Reproduction

```sh
python3 docs/tools/run_tests.py
python3 docs/tools/serve_audit.py
python3 docs/tools/build_audit_web.py --probe restarts --playback sample --output build/audit-cache-always
python3 docs/tools/build_audit_web.py --probe soak --playback sample --output build/audit-soak
AUDIT_OUT=/tmp/curfew-soak.json /Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script docs/tools/audit_soak_native.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script docs/tools/audit_crowds.gd
```

Open `http://127.0.0.1:8071/build/audit-cache-always/index.html?mode=cache` and click Start audit. For the long run, use `/build/audit-soak/index.html`. Reports are posted only to the local server and saved in this directory. The probe bypasses focus-loss pause while auditing. Keep the browser foregrounded for frame-time comparisons. Diagnostic exports are ignored under `build/` and are never published.

Remaining acceptance work: an uninterrupted 30-minute foreground browser run, actual iPhone/Android and Safari runs, end-to-end cold boot on mobile networks, and whole-process/browser allocation profiling to resolve the remaining heap/pool growth. A memory budget must be chosen for real target devices, not inferred from this Mac.
