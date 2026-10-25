# Bijatyka performance profiling

## Debug-only overlay

The profiler exists only in Godot debug builds and is hidden when the scene starts.
Toggle it with **F3** on desktop. On a phone, press and hold the empty top-right screen corner for 1.5 seconds. The profiler panel is created once and refreshes twice per second.

The overlay shows engine FPS when rendered, frame processing and physics processing time, living non-boss zombie count by distance band (0–18 m, 18–30 m, and active but outside 30 m), full zombie rigs against their 20-rig budget, boss rig activity, reduced-motion visible zombies, active visible animated zombie skeletons, draw calls, rendered objects, and engine static memory. A headless/no-render session displays render-only values as unavailable. Engine static memory is shown as unavailable when the monitor returns no value (including release builds).

## Repeatable scenarios

Choose a population button under either scenario heading:

- **Concentrated horde** puts the selected 20, 100, or 200 zombies into a deterministic spiral within roughly 12 m of the player. They use normal zombie AI and combat.
- **Normal 50 m approach** uses the existing concealed spawn director, camera/cover checks, spawn budget, 50 m arrival distance, forward spawning, and assault handoff. It fills the selected population cap through the same normal flow.

The debug **Stop scenario / restore normal 200** button clears the temporary horde and restores the ordinary 200-zombie endless replacement flow. The default 200 cap, 30 m visibility, 50 m arrivals, game controls, and gameplay systems remain unchanged outside the temporary scenario.

## Automated headless comparison

The validation workflow runs `godot --headless --path game --script res://tests/horde_scenario_benchmark.gd`. It runs all six population/scenario combinations, warms the scene, samples 120 frames, and writes one `HEADLESS_HORDE_SAMPLE` JSON line per run to the Actions log. Headless runs report process/physics timing, distance bands, full-rig counts, reduced-motion counts, and scene counts. They explicitly report FPS, draw calls, and rendered object counts as unavailable when no frame was rendered.

These runner measurements are useful for comparing script/physics work on the same runner configuration. They are not Android FPS, GPU measurements, device frame pacing, or thermal results. A real rendered session and sustained profiling on the target Android phone are still required for those.

## Phase 4 animation scaling

Phase 2 recorded these CI headless frame-processing averages for the six comparison scenarios:

| Scenario | 20 zombies | 100 zombies | 200 zombies |
| --- | ---: | ---: | ---: |
| Concentrated within about 12 m | 6.722 ms | 9.282 ms | 13.763 ms |
| Normal 50 m approach | 9.666 ms | 1.250 ms | 0.563 ms |

The runner data is not isolated rig cost and has no Android renderer/device samples. It therefore cannot establish a safe handset capacity. The initial cap is 20 ordinary-zombie full rigs because 20 is the smallest measured concentrated population; this gives a reproducible, measured runner envelope instead of scaling the animation count with the 200-zombie gameplay cap. The player and boss remain full quality outside that ordinary-zombie cap. Recheck the overlay and six post-change samples on the same device before increasing it.

The manager re-ranks eligible zombies every 0.20 s. Windups, hit reactions, recovery, and current player targets receive priority; nearby selections get a small retention bonus. A zombie enters full-rig selection at 16 m and retains it until 18.5 m, limiting churn at tier edges. Animation selection changes visibility and playback but retains any already-created rig for reuse. The remaining living zombies inside 30 m use one shared, low-poly MultiMesh with per-instance phase/speed and continuous shader limb motion. Instance placement and heading refresh at about 30 Hz; shader motion is evaluated continuously by the renderer. Outside 30 m both visual tiers stay hidden. AI, collision, attack resolution and spawn timings remain on their existing gameplay schedules.
