# General CPU optimization — 4 November 2026

Pooled zombie models now retain prepared animation libraries across actor transfers. The flashlight skips repeated render-state submissions when its inputs have not changed, and sends only changed mask uniforms when they do.

Base: `9075792b0e6caa0af969ee21dc113cefa1743193`, the validated head of PR #66. Branch: `perf/general-cpu-20261104`. This is stacked on `feat/zombie-teeth-hidden-in-beam-20261103`; main and the last exported APK are unchanged.

## Implementation and preserved behavior

- Each pooled model owns its animation cache. Motion aliases are installed once in a model-local default library. Imported source clips remain shared and immutable; aliases do not replace another model's or the player's aliases.
- Combat libraries are keyed by the complete punch/kick timing dictionaries. Shambler, brute and stalker timing remains distinct. An LRU limit of four profiles per model prevents unbounded growth from custom timing values.
- Cache compatibility includes animator/skeleton identity, animation root and skeleton paths, source-animation resources, bone names, parent indices and rest transforms. Replacing a source resource or changing the rig/rest setup rebuilds the cache. Source clips are not mutated in place at runtime.
- Playback state, animation-finished connections, actor health, attack state, reveal materials and death handling remain per actor. Existing release/adoption code resets playback and transfers signal ownership.
- Flashlight setters still update immediately. Identical requests from camera input, foundation and the manager are skipped. Movement, yaw, pitch, player-parent rotation, enable state and roof/ground transitions remain responsive. Static booleans are no longer uploaded every frame.
- No change to the 20-ordinary-zombie population, 7-rig budget, 4 attackers, pursuit pressure, sleep/wake thresholds, map, gamepad controls, 10 m beam, tooth-glint occlusion, Pencil, 40% render scale or 60 FPS cap. The separate historical jump-animation branch was not merged into this work.

## Repeatable host measurement

Godot `4.7.2.stable.official.ed1daf0bf`, headless, same host. Run the exact same `game/tests/rig_reuse_benchmark.gd` on the base and candidate in alternating order. Each process warms 9 transfers, then measures 60 synchronous acquire/release pairs, cycling shambler/brute/stalker through the same pooled rig. No other tests ran during these comparisons.

| Pair | Baseline average, ms | Candidate average, ms | Baseline P95, ms | Candidate P95, ms |
| --- | ---: | ---: | ---: | ---: |
| 1 | 16.035 | 0.622 | 19.572 | 0.847 |
| 2 | 13.756 | 0.511 | 15.093 | 0.580 |
| 3 | 14.572 | 0.648 | 16.904 | 0.919 |

The mean of the three averages is **14.788 → 0.594 ms**, about **96% less time in this warmed transfer operation**. Every process created exactly one model and reused it 68 times. This is not a frame-rate, Android CPU/GPU or temperature measurement.

Retaining three timing variants trades memory for avoiding reconstruction: this isolated one-rig fixture's Godot static-memory monitor rose from 57.494 to 58.868 MiB (about 1.374 MiB); resource count rose from 88 to 96. Whole-game/device RSS and graphics memory were not measured. The cache is bounded by resident rigs and four profiles per rig; first-time creation of a rig or previously unseen profile still incurs construction work.

The flashlight regression simulates 60 moving/turning states with three callers per state: it observes exactly 60 updates and 120 uniform writes, instead of the previous unconditional 180 updates and 720 writes. Repeating an unchanged camera state for 120 frames produces no additional submissions. Pitch-only changes update the 3D beam without rewriting ground-mask uniforms.

Reproduce:

```sh
godot --headless --editor --path game --import --quit
godot --headless --path game --script res://tests/general_cpu_optimization_test.gd
godot --headless --path game --script res://tests/rig_reuse_benchmark.gd
```

For baseline comparison, copy only the benchmark script into a clean checkout of the base SHA, import it, then alternate the commands on the two checkouts. Do not compare concurrent runs or treat headless render monitors as GPU measurements.

## Validation

Local Godot import and the new 313-check regression passed. Existing checks passed for rig/death lifecycle (90), enemy attacks including the female boss (494), zombie animations (37), gameplay/gamepad (207), Director (12), concealed spawning (425), 20-zombie dormancy (26), dormant visuals (19), elevator loading, flashlight/camera (96), actual tooth-glint selection (11), whole-enemy reveal (25), environment invariants, player animations (287), and Exo/player quality (185).

The dormant-visual test initially failed on both base and candidate: it called a point 16.1 m from the player "in range" after the flashlight was shortened to 10 m. The fixture now tests a point 5 m behind the player and a separate point beyond `MAX_RADIUS`. No production visibility rule was changed for this failure.

The dedicated `general-cpu-validation.yml` workflow is prepared to repeat the headless suites and check actual GL Compatibility pixels for tooth glints, air beam, wall occlusion, ordinary enemies and the skinned boss. It retains its logs and does not export an APK. **It has not run yet: this branch has not been uploaded.** Local rendered probes could not start because the temporary Xvfb server could not establish listening sockets in this host; no rendered-pass result is claimed.

The clean baseline import emitted the eight existing duplicate imported animation-name diagnostics (Idle, Jump, Sprint and Walk in two models). Neither candidate import nor runtime regression logs contained script errors; the asset diagnostics are not caused by this optimization.

Android validation remains necessary: compare matched camera-turn and sustained combat runs on the Redmi at 40%/60 FPS, including first descent, replacement/death cycles, roof return, beam/tooth visuals, and at least ten minutes of frame-time/thermal observation. This work makes no Android FPS or heat claim and does not change quality settings to manufacture a speedup.
