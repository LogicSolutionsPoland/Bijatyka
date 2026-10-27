# Ring-fight animation implementation and verification — 27 October 2026

## What is integrated

The full 48.882 s montage was indexed as 48 timestamped visual observations in [catalog.md](catalog.md), with source character, start/end pose, joints, foot/weight notes, looping and gameplay use. Sixteen manually reconstructed reference techniques/poses have separate Godot `.tres` clips for **each** of the actual Universal Base male and female rigs: 32 clips and two library manifests. One left high kick is an explicitly mirrored gameplay adaptation of the seen kick, not independently observed footage. Source key data and offline baker are in `tools/ring_reference/`.

The `ring_reference` library installs on the actual player, detailed ordinary zombies and female boss. The four live melee actions select these baked references: left punch → `lead_straight`, right punch → `rear_hook`, left kick → mirrored `left_high_kick`, right kick → `right_high_kick`. Enemy attack profiles keep their telegraph timing; player damage and five hits per second stay at the pre-existing 0.10/0.12-second contact windows. Existing animation blend duration and input paths remain unchanged. The fallback retains the earlier imported punches and kicks if the new library is unavailable. Other cataloged clips are accessible on the AnimationPlayers for future gameplay hooks but are not silently assigned to dodge, death, taunt, or ground combat.

The resources bake all fitted rotations and pelvis translation. Runtime only loads and plays Animation resources and caches resampled attack copies for shared profile/rig combinations. No runtime IK, pose estimation, per-frame limb fitting, material or lighting pass was added. The ordinary-zombie cap is still exactly five; the boss remains separate. The low-detail crowd representation does not carry the full skeletal library; detailed ordinary zombie rigs do.

## How the reconstruction was made

Source video was viewed on timestamped contact sheets over all 2,930 frames and at 10 samples/s through the useful exchanges. Three-dimensional hand/foot targets and torso/hip motion were hand authored in `motions.json`; a Godot 4.7.2 offline baker fitted two-bone chains on each actual rig and constrained planted feet. The 30-Hz baking uses 65-bone poses, closed-fist source guard and position keys for the pelvis. Authored clips preserve source-range metadata and contact markers. The live action copies retime the contact marker to the already defined gameplay attack window. This is manually inferred animation, **not motion capture from the video**.

## Evidence in this work session

| Check | Result |
|---|---|
| Godot 4.7.2 project import | Completed without script or resource load errors |
| Ring resource test on actual male player and female boss skeletons | **26,494 assertions passed**: 16 clips/rig; bone bindings, normalized finite poses, unmodified imported source, shared attack caching and contact retiming |
| Planted foot sampled at 120 Hz | Maximum displacement **0.00104 m** across selected stationary and single-leg techniques; authored frame fit maximum below 0.000001 m |
| Baked joint continuity | Maximum sampled adjacent rotation **1.123 rad** across all clips; no pole inversion found by sampled check |
| Player combat test | **136 assertions passed**: guard, contact pose/range, damage timing, repeat and buffered attacks, locomotion priority and controls |
| Enemy combat test | **494 assertions passed**: three male enemy variants plus female boss, left/right targeting at three headings, contact, support foot and playback |
| Existing gameplay/foundation, zombie animation, zombie teeth integration | **470 / 37 / 8 assertions passed** |
| Scene smoke | 240 frames headless, no script errors |
| GL Compatibility software rendering | Rendered 32 representative frames and 11 further phase frames for each of four main clips on each actual rig. Inspected player and female boss contact poses, guard, kick retraction, hand trajectories and absence of T-pose in sampled sequences. |

The render used Mesa llvmpipe on desktop. It is a visual review of models and sampled animation playback, not an Android hardware performance measurement. Frames are internal review captures. The source camera often hides the feet and reverse sides of limbs; the footage is a cinematic edit with freezes, cuts and occlusions. It cannot establish exact 3D joint angles or confirm the kick's anatomical side. The clips infer depth, complete a return to guard where the cut hides recovery, and adapt actions to the characters' different bind poses.

## Limits and adjustments still needed

- The 0.10/0.12-second player damage windows compress the reference's longer preparation into the established five-hits-per-second cadence. Side-by-side review on the user's Android device can determine whether these fast attacks should be visually emphasized further without changing damage timing.
- The included high kick is a manually approximated leg trajectory with planted support; it is not a full-body airborne or spinning kick. Airborne root trajectories, complete falls, uppercuts, independent defensive blocks and a clean backward/lateral gait were not recoverable reliably, so none was added as a live mechanic.
- Optional `step_in`, `pivot_exit`, `rope_recoil`, `arms_raised_taunt`, `kick_landing`, `duck_roll` and ground-target clips need a future gameplay rule before triggering them during play; using a rope recoil without a rope or a ground strike against upright enemies would misrepresent the footage.
- Facial expression and muscle deformation in the film cannot be reproduced by the Universal Base skeletal rigs. On-phone frame rate, shader/device differences, and touch combat feel are untested here.

Rebuild the resources after editing authored targets with:

```sh
godot --headless --path game --script ../tools/ring_reference/bake.gd
```

Then run `res://tests/ring_reference_test.gd`, `player_animation_test.gd`, `enemy_attack_animation_test.gd` and the GL capture script. No APK was produced for this task.
