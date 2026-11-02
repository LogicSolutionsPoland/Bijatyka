# GPU Stage 6 — 3D flashlight beam profiling

Source: the validated draft Stage 5 PR #59 head 69f67dd4543b23ffb6b9731eb64df711340d3e7f, whose Stage 5 validation run passed. This branch targets feat/gpu-stage5-screen-effects-20261102. Godot 4.7.2, GL Compatibility, 40% 3D render scale, 60 FPS cap, and the Stage 5 Pencil and visibility-mask passes are held fixed. No APK is built.

## Method

The profile test warms one concentrated ground-floor scene with 30 ordinary-zombie slots, then freezes gameplay and animation. It keeps both Stage 5 screen passes enabled and unchanged. The beam configurations are complete, no translucent meshes, crossed sheets only, and cross-sections only. The Spotlight3D stays at its original 1.6 energy in all four comparisons. Three alternating paired runs compare each partial/off configuration with the complete beam; each phase settles for 10 frames and records 50 rendered frames. The test reports average and P95 frame wall times plus average draw calls.

A separate three-pair test leaves both translucent meshes enabled and changes only spotlight light energy between 1.6 and 0.0. That isolates surface-lighting cost from transparent overdraw. The beam profile verifies the 30 population slots, 40% scale, 60 FPS cap, resident-rig limit, Pencil, mask, and ground shader setting on every sample.

GitHub Actions runs Godot through GL Compatibility with Mesa software OpenGL and one llvmpipe thread. Every timing is a host wall-time measurement. The runner has no Android device or mobile GPU profiler, so these timings do not predict Android FPS or GPU time.

The visual workflow downloads the validated Stage 5 roof and ground captures, creates matching Stage 6 captures, and compares static pixels while excluding player and boss regions. It also saves ground beam images before and behind an opaque wall and checks that the wall cuts off the shaft. The Stage 5 shader, flashlight visibility, zombie, and elevator checks run unchanged.

## Results

Pending the first Stage 6 workflow run. Record the 4 mode averages/P95/draw calls, the three paired deltas for each beam variant, and the separate spotlight on/off values here after the run. Retain only a beam change whose measured benefit repeats and whose before/after visual checks pass. Otherwise keep both beam shaders and runtime geometry unchanged.

## Redmi Android 16 follow-up

Host data cannot establish whether this beam is a mobile GPU bottleneck. On the Redmi Android 16, profile the validated Stage 5 and Stage 6 branches at 40% 3D scale, 60 FPS cap, and the fixed 30-zombie ground scene. Compare complete beam versus no translucent beam, sheets only, and sections only, then compare spotlight energy on/off while the full translucent beam remains visible. Alternate settings in at least three paired runs. Record median and P95 frame times, GPU time if exposed, FPS, draw calls, and device temperature. Confirm screenshots for roof off, ground beam, enemy/boss reveal, and the beam before and behind a wall. Do not infer Android gains from the GitHub runner.

## Ready-to-copy next-stage prompt

> Work in LogicSolutionsPoland/Bijatyka from the latest validated Stage 6 branch and draft PR. First review the host A/B report and, on Redmi Android 16, repeat the complete/no-translucent/sheets-only/sections-only beam comparison at 40% 3D scale, 60 FPS, and 30 zombies. Measure the spotlight separately with the translucent geometry fixed on. Record median/P95 frame times, GPU time if exposed, FPS, draw calls, and temperature; compare roof, ground, and before/behind-wall screenshots. If a repeatable Android measurement identifies a remaining beam cost, make one visually exact optimization on a new branch, run focused Godot 4.7.2 GL Compatibility checks, and open a draft PR targeting the validated Stage 6 branch. Otherwise leave the beam unchanged. Do not modify main, merge PRs, or build an APK. Provide the next ready-to-copy prompt.
