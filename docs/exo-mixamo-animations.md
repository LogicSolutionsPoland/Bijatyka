# Exo Gray: five Mixamo player clips (staged, no APK)

Base: `codex/exo-gray-player-model-20261031`, containing Exo Gray's visible GLB and original hidden Universal Base animation rig.

## Clips and hooks

| Source FBX | Clip key | Trigger |
| --- | --- | --- |
| Mma Kick (1).fbx | `mma_kick` | Right kick, primary/third ring variant |
| Chapa Giratoria 2.fbx | `roundhouse` | Right kick, second ring variant |
| Flying Kick.fbx | `fly_kick` | Right airborne kick |
| Jumping.fbx | `jump` | Ground jump |
| Run To Rolling.fbx | `roll` | Dash |

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
