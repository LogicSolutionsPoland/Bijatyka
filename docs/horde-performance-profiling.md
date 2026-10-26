# Bijatyka performance profiling

## Debug-only overlay

The profiler exists only in Godot debug builds and is hidden when the scene starts.
Toggle it with **F3** on desktop. On a phone, press and hold the empty top-right screen corner for 1.5 seconds. The profiler panel is created once and refreshes twice per second.

The overlay shows engine FPS when rendered, frame processing and physics processing time, living non-boss zombie count by distance band (0–18 m, 18–30 m, and active but outside 30 m), selected and resident detailed rigs, dying rigs, spare models, rig creations/reuses/overflow, boss rig activity, reduced-motion visible zombies, active visible animated zombie skeletons, draw calls, rendered objects, effect-pool activity, and engine static memory. A headless/no-render session displays render-only values as unavailable. Engine static memory is shown as unavailable when the monitor returns no value (including release builds).

## Repeatable scenarios

Choose a population button under either scenario heading:

- **Concentrated horde** puts the selected 20, 100, or 200 zombies into a deterministic spiral within roughly 12 m of the player. They use normal zombie AI and combat.
- **Normal 50 m approach** uses the existing concealed spawn director, camera/cover checks, spawn budget, 50 m arrival distance, forward spawning, and assault handoff. It fills the selected population cap through the same normal flow.

The debug **Stop scenario / restore normal 5** button clears the temporary horde and restores the ordinary 5-zombie endless replacement flow. The normal cap is 5; the 200-zombie capacity remains available only for debug stress scenarios. Visibility, spawn distance, controls, and gameplay systems stay unchanged.

## Automated headless comparison

The validation workflow runs `godot --headless --path game --script res://tests/horde_scenario_benchmark.gd`. It runs all ten stress-population/scenario combinations, allows up to 1,200 physics frames for valid concealed approach births, warms the scene, samples 120 frames, and writes one `HEADLESS_HORDE_SAMPLE` JSON line per run. It fails with active and pending counts when approach cannot fill. The sample includes the old process/physics monitor averages for comparison, per-physics-tick samples, headless wall-frame interval percentiles and maximum, selected/resident/dying rigs, peak resident count, model/effect reuse and overflow, distance bands, and engine static memory start/peak/end. FPS, draw calls, and rendered objects are `N/A` without rendered frames.

The engine timing monitors are updated at their own cadence; repeated reads should not be interpreted as independent frame-time spike samples. The wall-frame interval percentiles measure the headless runner's elapsed time between scene ticks, including scheduling and benchmark overhead. They are not Android FPS, GPU measurements, device frame pacing, battery use, or thermal results. Compare timings on the same runner configuration and use a real rendered session plus sustained profiling on the target Android phone for those device conclusions.

## Phase 4 animation scaling

Phase 2 recorded these CI headless frame-processing averages for the six comparison scenarios:

| Scenario | 20 zombies | 100 zombies | 200 zombies |
| --- | ---: | ---: | ---: |
| Concentrated within about 12 m | 6.722 ms | 9.282 ms | 13.763 ms |
| Normal 50 m approach | 9.666 ms | 1.250 ms | 0.563 ms |

The runner data is not isolated rig cost and has no Android renderer/device samples. It therefore cannot establish a safe handset capacity. The initial cap is 20 ordinary-zombie full rigs because 20 is the smallest measured concentrated population; this gives a reproducible, measured runner envelope instead of scaling the animation count with the 200-zombie gameplay cap. The player and boss remain full quality outside that ordinary-zombie cap. Recheck the overlay and six post-change samples on the same device before increasing it.

The manager re-ranks eligible zombies every 0.20 s. Windups, hit reactions, recovery, and current player targets receive priority; nearby selections get a small retention bonus. A zombie enters full-rig selection at 16 m and retains it until 18.5 m, limiting churn at tier edges. Phase 8 returns a deselected rig to one bounded pool, including when its owner dies. The 20 resident slots include selected rigs, dying rigs, and spare rigs. Dying detailed actors keep their rig until the authored death clip completes; unselected dying actors collapse through the shared silhouette without allocating another rig. The remaining visible zombies use one shared, low-poly MultiMesh with continuous shader limb motion. Instance placement and heading refresh at about 30 Hz. Outside 30 m both visual tiers stay hidden. AI, collision, attack resolution and spawn timings remain on their existing gameplay schedules.

## Phase 5 runtime effect reuse

The Phase 2 scenario averages are warmed steady-state samples and do not correlate a creation event with a frame-time spike. A focused Phase 5 baseline therefore measured the synchronous script-side construction and scene attachment call time for the four repeated visual paths (24 warmed calls each, headless CI runner):

| Effect | Average call time | Maximum observed |
| --- | ---: | ---: |
| Melee sweep | 67.3 µs | 115 µs |
| Melee hit impact | 348.5 µs | 441 µs |
| Zombie hit flash | 74.4 µs | 159 µs |
| Spell burst | 248.5 µs | 341 µs |

These values measure the synchronous creation/attachment function only. They do not measure full frame time, rendering, GPU work, or handset performance. The largest repeated costs were the melee impact and spell burst; all four paths were pooled because sweeps and hit flashes also recur during rapid melee. The player and enemy paths retain their original allocation-based fallback if the pool manager is unavailable.

The main-thread effect pool is bounded at 4 attack sweeps, 6 melee impacts, 3 spell bursts, and 6 zombie hit flashes (19 visual objects total). The sweep and burst lifetimes are 0.22 s; hit visuals last 0.18 s. These limits provide spare overlap around the existing five-hit-per-second melee cadence without tying capacity to the 200-zombie horde. The pool constructs at most one visual object per frame during preparation, and each effect shares cached sphere/shard mesh resources while keeping its own mutable material. Phase 8 separately reuses up to 20 ordinary-zombie detailed rigs. Whole zombie gameplay nodes are still destroyed after their death signal: reusing them would require a wider AI, signal, collision, animation, and replacement reset contract without a measured benefit.

If a cosmetic pool is exhausted, it drops that visual request and increments the overflow counter; it never grows past its cap or changes hit, damage, animation, or replacement behavior. In-game debug output reports created, reused, active, and overflow counts. The validation benchmark reports pooled acquisition timing and reuse counts; its headless times are not device frame-pacing results. Physical Android profiling is still needed to determine whether these CPU-side savings reduce visible stutter on the target handset.
