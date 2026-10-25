# Bijatyka performance profiling

## Debug-only overlay

The profiler exists only in Godot debug builds and is hidden when the scene starts.
Toggle it with **F3** on desktop. On a phone, press and hold the empty top-right screen corner for 1.5 seconds. The profiler panel is created once and refreshes twice per second.

The overlay shows engine FPS when rendered, frame processing and physics processing time, living non-boss zombie count by visual band (detailed 0–18 m, shared low-poly 18–30 m, and active but outside 30 m), active visible animated zombie skeletons, draw calls, rendered objects, and engine static memory. A headless/no-render session displays render-only values as unavailable. Engine static memory is shown as unavailable when the monitor returns no value (including release builds).

## Repeatable scenarios

Choose a population button under either scenario heading:

- **Concentrated horde** puts the selected 20, 100, or 200 zombies into a deterministic spiral within roughly 12 m of the player. They use normal zombie AI and combat.
- **Normal 50 m approach** uses the existing concealed spawn director, camera/cover checks, spawn budget, 50 m arrival distance, forward spawning, and assault handoff. It fills the selected population cap through the same normal flow.

The debug **Stop scenario / restore normal 200** button clears the temporary horde and restores the ordinary 200-zombie endless replacement flow. The default 200 cap, 30 m visibility, 50 m arrivals, game controls, and gameplay systems remain unchanged outside the temporary scenario.

## Automated headless comparison

The validation workflow runs `godot --headless --path game --script res://tests/horde_scenario_benchmark.gd`. It runs all six population/scenario combinations, warms the scene, samples 120 frames, and writes one `HEADLESS_HORDE_SAMPLE` JSON line per run to the Actions log. Headless runs report process/physics timing and scene counts. They explicitly report FPS, draw calls, and rendered object counts as unavailable when no frame was rendered.

These runner measurements are useful for comparing script/physics work on the same runner configuration. They are not Android FPS, GPU measurements, device frame pacing, or thermal results. A real rendered session and sustained profiling on the target Android phone are still required for those.
