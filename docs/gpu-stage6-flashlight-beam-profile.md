# GPU Stage 6 — 3D flashlight beam profiling

Source: validated draft Stage 5 PR #59 head 69f67dd4543b23ffb6b9731eb64df711340d3e7f, whose Stage 5 validation run 41445734781 passed. This branch was created from that head and targets the Stage 5 branch, feat/gpu-stage5-screen-effects-20261102. Godot 4.7.2, GL Compatibility, 40% 3D render scale, 60 FPS cap, and the Stage 5 Pencil and visibility-mask passes are fixed. No APK was built.

## Method

The profile warms one concentrated ground-floor scene with 30 ordinary-zombie population slots, then freezes gameplay and animation. Both Stage 5 screen passes remain enabled and unchanged. The configurations are complete beam, no translucent beam meshes, crossed sheets only, and cross-sections only. Spotlight3D remains at its production energy of 1.6 during all four beam comparisons. Three alternating paired comparisons are run for each partial/off configuration; every phase settles for 10 frames and records 50 rendered frames. Average and P95 frame wall times and average draw calls are reported.

A separate three-pair comparison keeps both translucent meshes enabled and changes only spotlight energy between 1.6 and 0.0. This separates surface-lighting variation from transparent geometry. The test verifies all 30 slots, 40% scale, 60 FPS cap, resident-rig limit, Pencil, mask, and ground shader setting.

GitHub Actions uses Godot 4.7.2, GL Compatibility, Mesa software OpenGL, and one llvmpipe thread on an Ubuntu host. These are host wall-time measurements, not Android GPU timings or Android FPS. No Android device or GPU profiler was available.

The visual workflow compares matching Stage 5 and Stage 6 roof and ground captures, excluding the player and boss regions from the static pixel count. It also captures the ground beam before and behind an opaque wall. A separate shader-only A/B compares the production beam shader with a zero-alpha discard trial on the same frozen frame.

## Measurements

### Frozen ground scene: beam modes

Stage 6 validation run 41454615222, host software renderer. Average frame and draw-call values use all sampled frames; P95 is the 95th percentile of host wall time.

| Mode | Average wall time (ms) | P95 wall time (ms) | Average draw calls | Frames |
|---|---:|---:|---:|---:|
| Complete beam | 139.749 | 143.370 | 172 | 900 |
| No translucent meshes | 138.587 | 142.720 | 170 | 300 |
| Crossed sheets only | 138.183 | 141.999 | 171 | 300 |
| Cross-sections only | 139.317 | 142.727 | 171 | 300 |

Paired deltas are candidate minus complete beam, so negative values mean less host wall time when a layer is removed. Each result is the mean of three paired runs; the range is the smallest to largest individual paired delta.

| Comparison | Mean paired delta (ms) | Paired range (ms) | Draw-call delta |
|---|---:|---:|---:|
| No translucent meshes | -0.990 | -1.700 to -0.482 | -2 |
| Crossed sheets only | -1.450 | -2.233 to -0.413 | -1 |
| Cross-sections only | -0.721 | -1.088 to -0.387 | -1 |

On this software-rendered host, removing translucent geometry reduced draw calls and had a consistently lower mean wall time in the final three-pair run. Repeated workflow runs show that the size of the timing difference varies, and it does not translate to an Android GPU or FPS estimate. The layer-removal modes visibly remove part of the requested beam, so none is a preservation-safe production change.

### Spotlight isolated from transparent overdraw

Both translucent meshes stayed enabled for all samples.

| Spotlight energy | Average wall time (ms) | P95 wall time (ms) | Average draw calls |
|---|---:|---:|---:|
| On, 1.6 | 140.639 | 143.920 | 172 |
| Off, 0.0 | 139.778 | 143.560 | 172 |

Off-minus-on averaged -0.861 ms across three pairs, with individual paired deltas from -2.091 to +0.784 ms. The direction varied, so this host run does not establish a repeatable spotlight-lighting cost.

### Visually matched shader trial

The test-only trial adds a discard when the calculated sheet alpha is zero. Production shader parameters and the beam geometry remain identical. The 1280×720 same-frame reference/trial comparison changed zero pixels by more than 1 eight-bit color level; maximum difference was 1 level.

| Repeated host run | Reference avg / P95 (ms) | Trial avg / P95 (ms) | Trial-minus-reference paired deltas (ms) | Mean delta (ms) |
|---|---:|---:|---:|---:|
| Earlier shader run A | 148.600 / 150.991 | 149.158 / 153.257 | -0.245, +1.044, +0.875 | +0.558 |
| Earlier shader run B | 148.309 / 150.451 | 147.997 / 149.945 | -0.585, -0.333, -0.020 | -0.313 |
| Final validation run | 151.835 / 155.726 | 151.637 / 155.357 | -1.190, +0.450, +0.146 | -0.198 |

Draw calls stayed at 172 in both shader variants in the final run. Although the screenshot comparison passed, the timing direction is not repeatable: the same test was slower on average in run A, faster in run B, and mixed within the final run. The test-only discard was therefore not promoted into the production shader.

## Visual checks and exact changes

The Stage 5 and Stage 6 roof/ground captures were visually inspected. The rooftop capture keeps the flashlight off; the ground capture keeps the full flashlight appearance and reveals. Static-pixel comparisons, with player and boss regions excluded, found 2,451 of 856,500 roof pixels changed by more than one level (0.286%) and 3,967 of 799,266 ground pixels (0.496%). Both are below the workflow's 1% drift threshold. The images are captures from separate runs, so small differences include scene timing variation.

Before/behind-wall ground captures differed at 50,527 pixels. The dedicated rendered beam probe measured blue-channel maximum 0.624 before the wall and 0.314 behind it, confirming visible attenuation/occlusion. The shader-only trial matched the production reference within one color level as recorded above. Flashlight visibility, enemy/boss reveal, rooftop off state, and Stage 5 Pencil/mask checks all passed.

The change adds the Stage 6 workflow and profile, the frozen-scene benchmark, visual capture/comparison scripts, a copy of the Stage 5 production shader as a test reference, and a test-only zero-alpha discard candidate. The existing rendered flashlight test also saves the before/behind-wall probe images. No production beam shader, flashlight visibility behavior, beam geometry, zombie behavior, map content, controls, combat, Pencil appearance, mask shape, render scale, or FPS cap was changed.

## Validation

GitHub Actions run 41454615222 passed on branch head c40d9e3ee245aad8f5959dbe33ce38e5896551f4: https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/41454615222

Focused checks passed: GPU Stage 3 (19), GPU Stage 4 (153), 30-slot zombie population (23), flashlight visibility/camera (97), whole-enemy reveal (25), elevator loading and ground GPU warmup, rendered flashlight volume (11), rendered beam/wall probe (7), the four-mode profile, paired shader trial, and roof/ground/wall comparison. No shader or runtime script errors were reported by these focused checks. The import step retains the existing filter for duplicate Idle, Jump, Sprint, and Walk animation-name diagnostics.

## Remaining Redmi Android 16 validation

The host cannot establish the beam's cost on the target mobile GPU. On the Redmi Android 16, repeat complete/no-translucent/sheets-only/sections-only at the same 30-zombie ground scene, 40% 3D scale, and 60 FPS cap, keeping the Stage 5 Pencil and mask enabled. Alternate settings in at least three paired runs. Separately compare spotlight on/off with both beam meshes fixed on. Record median and P95 frame time, GPU time if exposed, FPS, draw calls, and device temperature. Compare rooftop, ground beam, enemy/boss reveal, and before/behind-wall captures. Do not infer device performance from these host numbers.

## Ready-to-copy next-stage prompt

> Starting from the latest validated Stage 6 branch and draft PR in LogicSolutionsPoland/Bijatyka, repeat the complete/no-translucent/sheets-only/sections-only beam comparison on the Redmi Android 16 using the fixed 30-zombie ground scene, 40% 3D render scale, and 60 FPS cap, with the Stage 5 Pencil and visibility mask enabled. Keep the spotlight lighting cost separate by comparing energy on/off while both translucent meshes remain enabled. Alternate settings in at least three paired runs and record median/P95 frame time, GPU time if exposed, FPS, draw calls, and temperature. Compare roof, ground, enemy/boss reveal, and before/behind-wall images. Only make a production beam change if Android measurements show a repeatable gain and image comparisons preserve the full beam and wall occlusion. Run focused Godot 4.7.2 GL Compatibility checks, create a new branch, and open a draft PR targeting the validated Stage 6 branch. Do not modify main, merge PRs, or build an APK. Include the measurements and a ready-to-copy prompt for the following stage.
