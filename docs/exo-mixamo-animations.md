# Exo Gray: five Mixamo player clips (staged, no APK)

Base: `codex/exo-gray-player-model-20261031`, containing Exo Gray's visible GLB and original hidden Universal Base animation rig.

## Clips and hooks

| Source FBX | Clip key | Trigger |
| --- | --- | --- |
| Mma Kick (1).fbx | `mma_kick` | Right kick, primary/third ring variant |
| Chapa Giratoria 2.fbx | `roundhouse` | Right kick, second ring variant |
| Flying Kick.fbx | `fly_kick` | Right airborne kick |
| Jumping.fbx | `jump` | Visual preview only; original jump retained (leans horizontally without source root motion) |
| Run To Rolling.fbx | `roll` | Visual preview only; original dash retained (2.42s roll cannot be safely compressed into 0.30s) |

Left kicks, punches, zombie/boss animation, melee cadence, attack markers, controls, movement, and collision keep their established paths.

`player_exo_mixamo_overlay.gd` animates **only the visible Exo skeleton**. The source gameplay rig continues physics-driven combat and existing animations. The optional overlay is disabled until the generated `game/scripts/exo_mixamo_data.gd` replaces the empty checked-in scaffold.

## Data conversion

The supplied FBX clips have standard Mixamo bone names; the Exo GLB retains corresponding names without `mixamorig:`. Pre-baked 30 Hz quaternion tracks are retargeted via source rest-relative global bone rotations onto Exo Gray's GLB rest pose and quantized as signed 16-bit quaternion components. Only 20 principal joints are used to reduce runtime costs. Animation does not include Hips translation or CharacterBody3D/root movement.

The runtime library is built once at model initialization and contains no FBX parsing or 3D mesh import work. At each visible clip playback, the normal Exo pose copier is temporarily disabled; on completion it resumes. The visible animation duration is retimed to existing controller timing.

This is *a preliminary animation integration*, not yet a verified visual result. The FBX quaternions and skeleton topology were inspected; no Godot 4.7.2 rendering tests or Android tests have been completed. Check spin direction, angle of limbs, planted feet, jump/dash cuts, and whether short 0.48-second kicks look natural at the current 5-hit/s combat speed.

## Finish adding clips (Cloud Shell)

Download `ExoGray-5-Animations.zip`, upload to Cloud Shell, and run:

```sh
unzip -o ExoGray-5-Animations.zip
bash install_exo_mixamo.sh
```

The installer reuses an existing clean checkout, fetches `feat/exo-mixamo-clips-20261031`, fills in the clip bank and pushes a single commit. It does **not** start an APK workflow or create a PR. This branch is not listed in the Android export workflow's push branch allowlist.

Do not merge into main until actual Godot import, player visual checks, and mobile performance validation pass.

## Godot 4.7.2 visual review (2026-10-31)

PR #50 CI imported model and all five clips, validated controller/hit timing, and captured 15 visible Exo Gray poses. The source jump leans almost horizontally in the middle frame; roll collapses into a low crouch without root translation. They remain in the clip bank for review but are **not** used automatically during normal jump/dash. Retargeting both movements needs a locomotion-aware solution with floor placement and physical collision, not unconditional root motion on the mesh.

The source kick clips are 2.03–2.35s long while the strike window is 0.48s, so the preview demonstrates pose compatibility, not final combat realism at 5 hits/second. PR remains draft for visual and performance follow-up. No APK.
