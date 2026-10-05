# Game feedback follow-up — 2026-10-04

## Changes

| Request | Result |
| --- | --- |
| Sometimes-delayed pickup sound | Register the cached pickup WAV as a Web sample during level loading, before pizza collection or phone calls. |
| Smaller cats | Reduce sprite scale from 0.41 to 0.26, about 37%. Keep movement and collision behavior. |
| Slower music entrance | Nine-second music fade, independent of the four-second ambience fade. Loops start at the quiet initial gain before their first update. |
| Uninterrupted home sniffing | A due hint waits for current distractions to end. Once started, it finishes before Stella notices another cat, squirrel or hydrant. Ordinary chasing resumes afterwards. |
| Trees off sidewalks | Remove trees from both sidewalk furniture lists. Keep trees, grates and squirrel habitats inside plazas. |

## Audio evidence and limits

The pickup WAV starts without leading silence, and collection already requests the sound in the same frame as healing. Loading the resource alone does not prepare its Web sample. Godot documents first-use registration as a possible lag source and recommends registration during asset loading: [AudioServer sample registration](https://docs.godotengine.org/en/4.6/classes/class_audioserver.html#class-audioserver-method-register-stream-as-sample).

A temporary Chrome Web export using the actual `AudioDirector.gd`, audio assets and bus layout showed the pickup sample registered before any pickup request. Instrumenting `AudioBufferSourceNode.start()` measured 14.7 ms from the first button request to Web Audio startup, and 1.8 ms on repeat. Music and ambience began at zero gain and reached full gain. The headless audio check also verifies that ambience arrives while music is still fading, pickup healing and playback start together, tension still raises the busy music layer, and ending a run fades music out.

These measurements cover browser scheduling, not speaker latency. The intermittent report was not reproduced during a complete player run; the change removes first-use sample registration from the collection path. Stream identity and scene cleanup checks protect the previous memory fix.

## Visual and gameplay checks

A Godot-rendered comparison of walking/sitting, running and hissing poses showed the smaller cats beside Stella and the previous scale. The new cat body is about half Stella's width in the running comparison.

All 13 focused headless checks passed: audio, scent priority, Stella's stops, grates and plaza-only tree placement, cat sitting, dog/cat chasing, clue cards, levels, audio cache reuse, scene cleanup, home reachability, obstacles and patrol routes. The reachability check covers six map seeds. The scent regression introduces cats, squirrels and a hydrant throughout an active hint, verifies its full duration, and checks that chasing resumes afterwards. The normal production Web export completed without script or export errors.

Run them with:

```sh
python3 docs/tools/run_tests.py audio scent_priority stella_stops grates cat_sit dog_cat clues levels audio_cache memory_lifecycle reachable obstacles patrols
```
