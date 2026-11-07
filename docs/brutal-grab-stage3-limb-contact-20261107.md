# Brutal Grab Stage 3 — bounded arm contact (2026-11-07)

Branch: `feat/jump-horde-stage1-20261105`; feature-only, no APK.

## Ownership and integration

`FoundationPlayer` still owns the sole grab session, attacker lock and Stage 2 QTE. The new `BrutalGrabLimbContact` component is a child of the player, observing `grab_qte_started(session_id, enemy, limb, ...)` and `grab_fully_ended(reason)`. It does not reserve attackers, submit QTE presses, change damage, move any `CharacterBody3D`, or create a second grab state machine. It rejects stale attacker/session IDs every render update and disables/queues the modifier and target markers for deletion when the session ends. A new valid session gets a fresh modifier and targets; no persistent global bone overrides are used.

The component starts after the established Stage 2 QTE signal. For **real detailed zombies**, the authoritative player runs a read-only skeleton/reach preflight after selecting the Hit pose and updating the visible Exo retarget, but **before** starting Stage 2 QTE. An incompatible or out-of-reach imported limb causes `visual_contact_unreachable`, cleans the Stage 1 hold and releases the attacker without publishing a ghost QTE. This prevents invisible grabs. The older Stage 1/2 headless dummy enemies have no detailed model and retain their original gameplay-only QTE path for backwards compatibility. The additional runtime component independently repeats its mapping/reach checks and records `last_reject_reason`.

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

`TwoBoneIK3D` solves end-effector **position**, not guaranteed palm/finger wrap. The enemy still has the original closed-fist punch/holding animation; **real wrist grasp appearance and finger orientation require visual inspection**, and may need an additional bounded hand-only orientation/finger modifier later. A measured hand-to-target distance below 0.05 m is checked both on synthetic arm chains and **actual imported Exo/zombie skeletons**, after the deferred `modification_processed` callback. The component's `last_hand_error_m` records that post-solver world-space error, not a misleading pre-IK hand position. This position metric alone is not proof of a skin-to-skin grip. This limitation prevents claiming final photorealistic limb grabbing without visual evidence.

## Validation

Headless suites (Godot 4.7.2, Ubuntu GitHub Actions):
- `brutal_grab_state_machine_test.gd`: **PASS 50** (Stage 1).
- `brutal_grab_qte_test.gd`: **PASS 63** (Stage 2).
- `brutal_grab_limb_contact_test.gd`: **PASS 45** (synthetic arm IK, mapping, rejection and cleanup).
- `brutal_grab_real_rig_test.gd`: **PASS 41** (imported 112-bone Exo / 65-bone zombie skeletons, actual held punch clips, 5 cm threshold, measured elbow bending, minor actor rotations/translation, no CharacterBody3D movement, out-of-reach preflight before QTE, successful QTE escape release).
- `stage6_integrated_headless_test.gd`: **PASS 28**.
- `jump_state_regression_test.gd`: **PASS 25**.
- `test_runner.gd`: **PASS 215**.

Imported skeleton arm chain lengths: left/right **0.4947 m**. The rendered Exo lower-forearm target yielded **0.0000 m** world-space contact error on both sides when sampled after the held-punch IK modifier update in the real-rig headless regression. Left/right are not equivalent to visually verified fingertip wrap; the hand's punch pose remains the animation-authored orientation. These figures were produced by CI, not measured on Redmi. Validation run: `https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42359524663`.

**Outstanding visual acceptance:** real in-game videos of left/right grabs at 40% scale, finger/palm orientation on both Exo sleeves, crowd/wall/uneven-terrain clipping, and Redmi Android 16 FPS/thermal behavior. The QTE/IK implementation is headless-validated, but skin-to-skin realism and on-device 60 FPS are **not** established. No APK was built in this stage.

## Stage 4 camera contract (not implemented)

Only after the grab state is `GRABBED` and the active session ID is confirmed, Stage 4 may observe `grab_qte_started` and the selected `LEFT ARM` / `RIGHT ARM`. The camera should focus on the **visible Exo forearm contact point**, not the hidden source rig. On `grab_fully_ended` (or QTE finish with matching ID), reset the camera and discard old focus callbacks. Preserve movement, collision, player-enemy ownership and the existing 4 m fighting zone; never lock camera on windup alone, use global time scaling, or add new QTE inputs in Stage 4.

## Post-stage Android device acceptance build request (2026-11-07)

The owner explicitly requested a new Android ARM64 debug APK after Stage 3 implementation, to inspect the real visual grab on a Redmi phone before planning Stage 4. This is a build/test checkpoint only, not Stage 4 implementation or proof of mobile visual acceptance. The prior headless test evidence and limitations remain unchanged. The CI commit starting with `build(stage10-apk-export):` deliberately permits the existing Android export workflow on this branch; any APK must be checked against its exact resulting commit SHA before distribution.
