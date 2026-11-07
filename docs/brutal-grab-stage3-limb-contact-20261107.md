# Brutal Grab Stage 3 — bounded arm contact (2026-11-07)

Branch: `feat/jump-horde-stage1-20261105`; feature-only, no APK.

## Ownership and integration

`FoundationPlayer` still owns the sole grab session, attacker lock and Stage 2 QTE. The new `BrutalGrabLimbContact` component is a child of the player, observing `grab_qte_started(session_id, enemy, limb, ...)` and `grab_fully_ended(reason)`. It does not reserve attackers, submit QTE presses, change damage, move any `CharacterBody3D`, or create a second grab state machine. It rejects stale attacker/session IDs every render update and disables/queues the modifier and target markers for deletion when the session ends. A new valid session gets a fresh modifier and targets; no persistent global bone overrides are used.

The component starts after the established Stage 2 QTE signal. If a dummy actor has no rig, or a real rig is incompatible or out of reach, it rejects **visual contact** only; the existing Stage 1/2 gameplay session continues. The rejection reason is available via `last_reject_reason`. This is deliberate to preserve existing Stage 1/2 host tests that create enemies without detailed models. A runtime scene test with real zombie models is needed to validate real contact activation frequency.

## Verified code-level bone names

| Rig | Left | Right |
| --- | --- | --- |
| Universal Base player (hidden 65-bone gameplay rig) | `lowerarm_l` → `hand_l` | `lowerarm_r` → `hand_r` |
| Exo Gray (visible 112-bone rig) | `LeftForeArm` → `LeftHand` | `RightForeArm` → `RightHand` |
| Universal Base enemy rig | `upperarm_l` → `lowerarm_l` → `hand_l` | `upperarm_r` → `lowerarm_r` → `hand_r` |

Mappings reflect `player_exo_gray_retarget.gd` and `universal_base_motion.gd` and are re-validated against **actual runtime bone indices and parent relations** at contact start. Exo Gray's rendered skeleton is selected when the retarget driver is present; otherwise the hidden Universal Base skeleton is used. This avoids attaching zombie hands to an invisible source pose.

The Exo rig is centimeter-origin with a 0.01 root model scale, while the enemy Universal Base is meter-based. Transformations use each `Skeleton3D.global_transform` to obtain world coordinates. No assumption is made that model local axes or rest bone rotations are identical. Upper/lower leg and foot mappings already exist in the player retarget script, but **leg contact is not enabled** in Stage 3.

## Solver and sampling

One `TwoBoneIK3D` (Godot 4.7.2 API) is created under the zombie's currently detailed skeleton for the selected three-bone arm chain. The end target is 82% along the player's elbow-to-wrist segment, approximating a lower-forearm grip; a pole marker is placed outside the current elbow. The zombie's punch animation remains the authored holding pose and the player's pre-existing `Hit` pose is unchanged. The solver is blended in over 0.10 seconds using `SkeletonModifier3D.influence`; the existing 0.08-second enemy Idle/attack animation blend handles the exit. At release the IK is disabled and its influence reset immediately for safe cleanup. No extra animation tracks or new animation state are installed.

The solver runs on the animated **enemy** skeleton only. Target sampling runs on the render frame after Exo Gray's retarget node (priority 100 versus 200). The left/right bone indices and references are cached at activation; inactive zombies do no IK work. Each frame checks the current session, actor validity, model retention, health and shoulder-to-target reach. Maximum reach is measured from actual shoulder/elbow/wrist positions with only 0.06 m allowance; out-of-reach contact is released without teleporting or stretching the player/enemy.

`TwoBoneIK3D` solves end-effector **position**, not guaranteed palm/finger wrap. The enemy still has the original closed-fist punch/holding animation; **real wrist grasp appearance and finger orientation require visual inspection**, and may need an additional bounded hand-only orientation/finger modifier later. A measured hand-to-target distance below 0.05 m is the synthetic-rig headless target, not proof of a skin-to-skin grip. This limitation prevents claiming final photorealistic limb grabbing without visual evidence.

## Validation

Headless suite: `game/tests/brutal_grab_limb_contact_test.gd`. The same GitHub Actions workflow also runs Stage 1 and Stage 2 grabs, integrated combat, jump and control regressions. CI status must be checked on the **final** feature branch HEAD before acceptance. Never claim Redmi FPS, real IK contact accuracy on the shipped rigs, or clipping quality from synthetic headless skeletons.

Missing evidence to collect before declaring full Stage 3 visual acceptance: runtime scene measurements with the imported Exo Gray GLB and Universal Base zombie GLB, left/right grab video at 40% render scale, wall/crowd/terrain cases, and actual Redmi Android 16 thermal/FPS/60 FPS cap. No APK is permitted in this stage.

## Stage 4 camera contract (not implemented)

Only after the grab state is `GRABBED` and the active session ID is confirmed, Stage 4 may observe `grab_qte_started` and the selected `LEFT ARM` / `RIGHT ARM`. The camera should focus on the **visible Exo forearm contact point**, not the hidden source rig. On `grab_fully_ended` (or QTE finish with matching ID), reset the camera and discard old focus callbacks. Preserve movement, collision, player-enemy ownership and the existing 4 m fighting zone; never lock camera on windup alone, use global time scaling, or add new QTE inputs in Stage 4.
