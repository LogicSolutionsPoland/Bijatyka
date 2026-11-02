# GPU Stage 5 — ground-floor screen effects

Source: validated draft PR #58 head `59d5ac356a8c7d7f4e351d8756a3345a2a858abc`. This branch targets `feat/gpu-stage4-android-resources-20261102`. Godot 4.7.2 GL Compatibility, Android ARM64, 40% mobile 3D render scale and 60 FPS cap remain the release settings. No APK was exported.

## Baseline and A/B method

`gpu_stage4_benchmark.gd -- --effects=both|mask|pencil|neither` starts a fresh fixed 30-ordinary-zombie concentrated ground scene per mode, warms 90 frames and samples 180 rendered frames. The optional flag fixes the host viewport scale at 0.40 and the frame cap at 60. It changes only the visibility of the named screen quad(s); the ground shader's `floor_skip_enabled` stays true, and the 3D beam, enemy classifier, Pencil materials, map, lights and camera remain unchanged. The baseline below was collected before the Stage 5 shader edit on local Mesa llvmpipe software OpenGL. The debug profiler now also exposes an independent Pencil switch, and its mask switch leaves floor skipping fixed for an isolated on-device pass comparison.

| Baseline effect mode | Software OpenGL wall average / P95 (ms) | Draw calls average |
| --- | ---: | ---: |
| Both enabled | 186.698 / 339.815 | 178.3 |
| Mask only | 176.327 / 308.354 | 177.3 |
| Pencil only | 191.707 / 282.224 | 177.3 |
| Neither | 218.204 / 405.215 | 176.3 |

All four runs had 30 population slots, at most seven resident ordinary rigs, 180 rendered frames and unchanged floor skipping. The counterintuitive “neither” timing shows that scheduling and software-renderer variance exceeds the isolated effect cost. A second benchmark alternated both/mask/both/pencil/both/neither/both on one frozen 30-zombie scene. Its four unchanged “both” averages ranged from 142.539 to 224.291 ms before the edit and 126.790 to 187.072 ms after it. These results **cannot rank the actual Android GPU cost** of Pencil, mask and beam. The headless runs also rendered zero frames and were dominated by the 60 FPS cap; they are host CPU checks only.

The Stage 3 Pencil shader can call `view_pos` up to 18 times for a near crease pixel. A trial sharing these samples reduced its source calls to 10, but a direct alternating comparison with identical shader uniforms on one frozen scene measured Stage 4 averages of 208.723, 250.137 and 241.354 ms versus trial averages of 263.592, 273.890 and 243.141 ms. That trial was rejected and the original Pencil shader restored. Its source-call reduction was not a measured performance win on this host.

## Change selected

The ground mask already computes `illuminated_weight`; when it is exactly 1, its black overlay has exactly zero alpha and a blend cannot change the underlying Pencil result. `flashlight_visibility.gdshader` now discards only those fragments before the transparent blend. The same range, facing, oval edge, player exemption, depth reconstruction, enemy and boss ordering, and 3D beam remain in place. The mask is still hidden on the rooftop. This five-line shader change does not approximate the blackout boundary.

For a direct old/new check, `gpu_stage5_mask_pair.gd` alternates the committed Stage 4 shader fixture and the new shader on the **same** frozen 30-zombie ground frame. It checks all ten configured uniforms for equality, precompiles both variants, keeps Pencil and the beam on, and samples 50 frames per phase at 40% scale/60 FPS cap. The local single-threaded llvmpipe run yielded:

| Pair | Stage 4 mask average (ms) | Stage 5 mask average (ms) |
| --- | ---: | ---: |
| 1 | 252.444 | 217.329 |
| 2 | 206.262 | 212.181 |
| 3 | 220.419 | 202.988 |
| Three-pair mean | 226.375 | 210.833 |

The host mean is 15.542 ms lower (6.9%) in this run, while pair 2 reversed direction. This is **desktop software OpenGL wall time**, with observed drift, not an Android GPU time or a promised FPS improvement. The change is retained as a draft candidate for device validation.

## Visual and regression evidence

Godot 4.7.2 imported the project without shader or script errors. A clean import reports eight pre-existing duplicate `Idle`/`Jump`/`Sprint`/`Walk` animation-name diagnostics from two Universal Base character GLBs; the workflow accepts only those exact import messages and fails on all other errors. Focused headless runs passed GPU Stage 3 (19 checks), GPU Stage 4 (153 checks), flashlight visibility (97 checks), whole-enemy reveal (25 checks), the 30-zombie dormancy test (23 checks), and elevator loading. The Stage 5 capture probe saved fixed 1280×720 roof and ground images with the mobile 40% scene scale. Excluding the animated player and boss regions, 99.9979% of ground pixels matched the Stage 4 capture exactly and none differed by more than one 8-bit color level. The rooftop keeps both screen passes and the beam hidden. Desktop software OpenGL probes passed the flashlight edge/player (22 checks), depth-tested beam and wall cutoff (7), ordinary-enemy reveal (21), skinned boss silhouette (9), and rendered Stage 4 geometry (153). The generated images and logs remain local to the validation environment; the workflow uploads fresh captures and logs for reviewers.

The dedicated workflow runs focused headless checks, all four software-rendered effect modes, the alternating comparison, the direct old/new mask comparison, roof/ground captures and rendered beam, wall, enemy and boss probes. It uploads logs and captures. Neither host path supplies Android GPU time, mobile FPS, VRAM or thermal data.

## Redmi Android 16 follow-up

No Android device or GPU profiler is available in this environment, and this stage does not build an APK. In a later debug build, compare the Stage 4 and Stage 5 branches on the same Redmi at 40% 3D scale and a 60 FPS cap. Open the F3 profiler (hold the top-right corner for 1.5 seconds), select the 30-zombie concentrated scenario, and keep the camera route, boss position, brightness and device temperature preparation as similar as possible. Record at least three five-minute ground-floor runs per build, with median/P95 frame time, GPU frame time if available, FPS, draw calls and temperature. Within one build, sample both ON, Pencil OFF, restore, mask OFF, restore, one toggle at a time; the floor shader stays fixed, so mask-OFF is a pass-cost probe rather than a gameplay screenshot. Capture matched roof, Pencil ground, flashlight edge, beam before/behind a wall, player and zombies/boss inside/outside the light. Report missing GPU counters as unavailable.

## Ready-to-copy next-step prompt

> Work in `LogicSolutionsPoland/Bijatyka` from the latest validated head of the draft Stage 5 screen-effects PR. Do not touch `main`, merge PRs or build an APK until the optimization stages are complete. Collect Redmi Android 16 GPU/frame-time traces at 40% 3D scale and 60 FPS with 30 ordinary zombies, comparing Stage 4 and Stage 5 over matched five-minute ground runs. Record median/P95 frame times, GPU time if exposed, FPS and temperature, and verify rooftop, Pencil, flashlight edge, beam wall occlusion and boss/enemy reveal screenshots. Identify the largest *measured* remaining GPU cost, then make one scoped optimization on a new branch. Keep map, zombie AI, combat, controls and visual behavior unchanged; run the focused Godot 4.7.2 GL Compatibility checks and open a draft PR only after validation. Report host measurements separately from phone results and provide the next ready-to-copy prompt.
