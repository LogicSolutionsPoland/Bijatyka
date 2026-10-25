# Phase 8: resident rig cap and Android build verification

## Runtime ownership

The ordinary-zombie `HordeFarVisuals` manager owns a pool of at most 20 imported detailed models. The budget counts selected actors, detailed actors playing a death clip, and models waiting in the spare pool. A deselected actor hands its stopped rig back before the manager promotes another actor. A new model is instantiated only when the pool is empty and the resident count is below 20. Player and boss models do not enter this pool.

During death, a selected actor keeps its rig until the authored clip finishes. Its slot is reserved when the remaining candidates are ranked. An unselected actor stays in the shared moving silhouette tier and visibly collapses over 0.45 seconds without constructing a rig. Both paths disable gameplay collision and AI immediately, then emit defeat once and hand the ordinary-zombie replacement to the existing spawn director. Pool transfer clears the old animation signal, playback, visibility, and transform state before the next actor uses the model. The 16 m/18.5 m selection hysteresis and combat priority remain intact.

This bounds detailed model allocations over repeated deaths and tier switches. It does not pool whole zombie gameplay nodes, which would need a separate reset contract for AI, collisions, signals, and health. The existing 19-object visual effect pool is unchanged. The Burning Horizon shaders, environment materials, Compatibility renderer, lighting and shadow settings are unchanged.

## Local correctness checks

Godot 4.7.2 import, gameplay and controls, player/zombie animation, concealed spawn and assault, combat effect pool, horde LOD, Burning Horizon, environment invariants, six scenario benchmark runs, and 600 frames of the playable scene completed locally. The dedicated 200-actor lifecycle test verifies 20 resident rigs, a reserved dying rig, an unselected death that allocates no rig, exactly-once replacement, 25 more death/respawn cycles, model reuse, and no model creation beyond 20. Software-rendered Compatibility checks are part of `Bijatyka performance validation` on GitHub Actions; local headless checks cannot substitute for that render probe or a physical Android test.

## Comparable local wall-frame samples

The same Godot 4.7.2 binary and host ran the Phase 7 tree and the Phase 8 tree in alternating order, twice each. A common standalone harness started each of the six normal scenarios, warmed 60 scene frames, and measured 120 headless scene-tick intervals with `Time.get_ticks_usec()`. The table shows the median of the two run values, in milliseconds. Every scenario reached its requested living population.

| Scenario | Phase 7 average | Phase 8 average | Phase 7 p95 | Phase 8 p95 |
| --- | ---: | ---: | ---: | ---: |
| 20 concentrated | 6.905 | 6.896 | 9.696 | 8.926 |
| 100 concentrated | 6.944 | 6.900 | 13.592 | 11.093 |
| 200 concentrated | 7.517 | 7.093 | 16.798 | 14.788 |
| 20 at 50 m | 11.353 | 6.901 | 11.496 | 8.910 |
| 100 at 50 m | 6.958 | 6.941 | 12.621 | 10.989 |
| 200 at 50 m | 6.914 | 6.994 | 15.302 | 14.825 |

The 200-at-50-m average rose by 0.080 ms. Maximum intervals were also mixed: the 200-at-50-m median maximum rose from 19.594 to 23.284 ms, while the 200-concentrated median maximum fell from 33.595 to 26.144 ms. These are short headless elapsed-time samples influenced by OS scheduling, physics ticks, and the harness; they do not establish sustained handset FPS or GPU speed. The engine's `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` monitor averages remain in the official benchmark for continuity with Phase 2 but are updated at the engine's monitor cadence, so the benchmark does not present repeated monitor values as independent frame-time percentiles.

The Phase 8 official headless benchmark recorded all six scenarios at the requested population and a peak of 20 resident rigs, zero rig-pool overflow, and 20 total imported rig constructions while moving through the scenarios. Engine static memory in its 200-actor samples was approximately 56.8–56.9 MiB. The Phase 7 baseline had similar static memory at 200 actors (about 56.0–56.9 MiB), but had no resident-rig or reuse counters and could accumulate rigs after repeated LOD changes and deaths. These engine static-memory values are not total Android process memory.

## Android verification

The manual export workflow uses Godot 4.7.2, the Android ARM64 preset, and the same debug export. It now checks APK ZIP integrity, the ARM64 Godot library and absence of other CPU ABIs, the package ID, nonempty compiled game scripts and scenes, Burning Horizon and crowd shaders, imported zombie asset, and audio before upload. The workflow artifact is a ZIP containing the APK. Physical installation, animation appearance, sustained FPS, temperature, and battery use require a device test.
