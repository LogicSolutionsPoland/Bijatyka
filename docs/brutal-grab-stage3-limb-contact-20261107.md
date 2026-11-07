# Brutal Grab Stage 3 — bounded arm contact (2026-11-07)

Branch: `feat/jump-horde-stage1-20261105`; feature-only, no APK.

## Ownership and integration

`FoundationPlayer` still owns the sole grab session, attacker lock and Stage 2 QTE. The new `BrutalGrabLimbContact` component is a child of the player, observing `grab_qte_started(session_id, enemy, limb, ...)` and `grab_fully_ended(reason)`. It does not reserve attackers, submit QTE presses, change damage, move any `CharacterBody3D`, or create a second grab state machine. It rejects stale attacker/session IDs every render update and disables/queues the modifier and target markers for deletion when the session ends. A new valid session gets a fresh modifier and targets; no persistent global bone overrides are used.

The component starts after the established Stage 2 QTE signal. For **real detailed zombies**, the authoritative player runs a read-only skeleton, hand-frame, and reach preflight after selecting the Hit pose and updating the visible Exo retarget, but **before** starting Stage 2 QTE. An incompatible or out-of-reach imported limb causes `visual_contact_unreachable`, cleans the Stage 1 hold and releases the attacker without publishing a ghost QTE. This prevents invisible or unsupported grabs. The older Stage 1/2 headless dummy enemies have no detailed model and retain their original gameplay-only QTE path for backwards compatibility. The additional runtime component independently repeats its mapping, hand-frame, and reach checks and records `last_reject_reason`.

## Verified code-level bone names

| Rig | Left | Right |
| --- | --- | --- |
| Universal Base player (hidden 65-bone gameplay rig) | `lowerarm_l` → `hand_l` | `lowerarm_r` → `hand_r` |
| Exo Gray (visible 112-bone rig) | `LeftForeArm` → `LeftHand` | `RightForeArm` → `RightHand` |
| Universal Base enemy rig | `upperarm_l` → `lowerarm_l` → `hand_l` | `upperarm_r` → `lowerarm_r` → `hand_r` |

Mappings reflect `player_exo_gray_retarget.gd` and `universal_base_motion.gd` and are re-validated against **actual runtime bone indices and parent relations** at contact start. Exo Gray's rendered skeleton is selected when the retarget driver is present; otherwise the hidden Universal Base skeleton is used. This avoids attaching zombie hands to an invisible source pose.

The Exo rig is centimeter-origin with a 0.01 root model scale, while the enemy Universal Base is meter-based. Transformations use each `Skeleton3D.global_transform` to obtain world coordinates. No assumption is made that model local axes or rest bone rotations are identical. Upper/lower leg and foot mappings already exist in the player retarget script, but **leg contact is not enabled** in Stage 3.

## Active-hand orientation follow-up

Both imported rigs contain usable index, middle, ring, pinky, and thumb bone chains. The authored zombie punch clips key the hand and finger channels and leave the fingers clenched. The orientation correction derives a frame from the hand rest pose and finger hierarchy on each side; it does not assume left/right axes are mirrored perfectly. In hand-local rest space, `finger` points from the wrist toward the middle-finger tip, `lateral` points from index toward pinky after projection perpendicular to `finger`, and `palm = finger × lateral`.

Measured normalized frames from the imported GLBs:

| Skeleton / side | Finger axis | Lateral axis | Palm normal |
| --- | --- | --- | --- |
| Universal Base zombie left (`hand_l`) | `(0.0394, 0.997396, 0.060414)` | `(-0.002699, 0.060566, -0.998160)` | `(-0.999220, 0.039164, 0.005078)` |
| Universal Base zombie right (`hand_r`) | `(-0.0394, 0.997396, 0.060414)` | `(0.002699, 0.060567, -0.998160)` | `(-0.999220, -0.039164, -0.005078)` |
| Exo Gray player left (`LeftHand`) | `(0.000794, 0.999999, 0.001271)` | `(0.999995, -0.000790, -0.003104)` | `(-0.003103, 0.001274, -0.999994)` |
| Exo Gray player right (`RightHand`) | `(-0.000794, 0.999999, 0.001259)` | `(-0.999995, -0.000790, -0.003160)` | `(-0.003159, -0.001262, 0.999994)` |

The zombie frame uses `hand_l/r`, the matching `index_01_l/r` and `pinky_01_l/r` bones, and the full `middle_01` through `middle_04_leaf` chain. Exo Gray uses `Left/RightHand`, `Left/RightHandIndex1`, the corresponding `HandMiddle1` through `HandMiddle4` chain, and `HandPinky1`. The selected player's live forearm-to-wrist direction supplies the target finger axis; the live Exo palm/lateral frame supplies its roll reference. A `BrutalGrabHandOrientation` `SkeletonModifier3D` runs after the active arm `TwoBoneIK3D`, changes only that zombie wrist's basis, and shares the existing contact influence blend. It recomputes the target from current actor transforms each modifier update, so actor turns do not accumulate twist. On cleanup, both modifiers are disabled and removed; the animation-owned wrist pose is restored.

This frame correction aims the zombie palm and its clenched finger axis against the selected lower forearm. It does **not** pose individual zombie finger bones into a wrap or release grip; their authored punch pose remains intact. The rigs support fingers, but a convincing animated finger grasp is not established by this wrist-only correction.

## Solver and sampling

One `TwoBoneIK3D` (Godot 4.7.2 API) is created under the zombie's currently detailed skeleton for the selected three-bone arm chain. The end target is 82% along the player's elbow-to-wrist segment, approximating a lower-forearm grip; a pole marker is placed outside the current elbow. The zombie's punch animation remains the authored holding pose and the player's pre-existing `Hit` pose is unchanged. The solver blends in over 0.10 seconds and blends out over 0.08 seconds using `SkeletonModifier3D.influence`. Contact sampling and session ownership stop immediately on release; the short modifier fade then removes the IK node and target markers. Death, scene/model exit, lost ownership and out-of-reach reasons disable and clean it immediately. No extra animation tracks or new animation state are installed.

The solver runs on the animated **enemy** skeleton only. Target sampling runs on the render frame after Exo Gray's retarget node (priority 100 versus 200). The left/right bone indices and references are cached at activation; inactive zombies do no IK work. Each frame checks the current session, actor validity, model retention, health and shoulder-to-target reach. Maximum reach is measured from actual shoulder/elbow/wrist positions with a 0.03 m allowance, below the 0.05 m contact tolerance. If reach is lost during a live QTE, the component asks `FoundationPlayer` to cancel its owned session; it does not resolve the gameplay grab itself.

`TwoBoneIK3D` solves end-effector position; the follow-up modifier corrects wrist orientation after IK but does not deform the fingers. A measured hand-to-target distance below 0.05 m and palm/finger-frame angular error below 1 degree are checked on synthetic and imported rigs after their respective `modification_processed` callbacks. The component records the post-modifier world-space position and orientation errors. Those measurements prove solver output only; they do not prove a skin-to-skin or visually convincing grip.

## Validation

Local headless revalidation in this update (Godot 4.7.2, current implementation tree):
- `brutal_grab_state_machine_test.gd`: **PASS 50** (Stage 1).
- `brutal_grab_qte_test.gd`: **PASS 63** (Stage 2).
- `brutal_grab_limb_contact_test.gd`: **PASS 62** (synthetic left/right frames, pre-QTE and session-time missing-frame rejection, post-IK order, influence blend-in/out, small actor rotations, repeated sessions and modifier cleanup).
- `brutal_grab_real_rig_test.gd`: **PASS 60** (imported 112-bone Exo / 65-bone zombie skeletons, both arms, actual held punch clips, 5 cm hand-position check, palm/finger-frame error below 1 degree, actor rotations/translation, no CharacterBody3D movement, preflight rejection, QTE escape/timeout blend-out, reach-loss cancellation and authored wrist-pose restoration).
- `stage6_integrated_headless_test.gd`: **PASS 28**.
- `jump_state_regression_test.gd`: **PASS 25**.
- `test_runner.gd`: **PASS 215**.
- Godot project import: **PASS** (exit 0; Android build-tools directory is unavailable in this host environment).

Earlier CI run `42359524663` validated commit `848c1b244457e7964730d0000a05ef4c21adaa57`; its results are historical and precede the reach-loss regression added here.

Imported skeleton arm chain lengths: left/right **0.4947 m**. The rendered Exo lower-forearm target yielded **0.0000 m** world-space contact error and **0.0000°** palm/finger-frame error on both sides in the imported-rig headless regression. Left/right are not equivalent to visually verified fingertip wrap; the zombie fingers remain in the animation-authored closed-fist pose. The local checks are host results, not Redmi measurements.

**Outstanding visual acceptance:** real in-game videos of left/right grabs at 40% scale, finger/palm orientation on both Exo sleeves, crowd/wall/uneven-terrain clipping, and Redmi Android 16 FPS/thermal behavior. The QTE/IK implementation is headless-validated, but skin-to-skin realism and on-device 60 FPS are **not** established. No APK was built in this stage.

## Stage 4 camera contract (not implemented)

Only after the grab state is `GRABBED` and the active session ID is confirmed, Stage 4 may observe `grab_qte_started` and the selected `LEFT ARM` / `RIGHT ARM`. The camera should focus on the **visible Exo forearm contact point**, not the hidden source rig. On `grab_fully_ended` (or QTE finish with matching ID), reset the camera and discard old focus callbacks. Preserve movement, collision, player-enemy ownership and the existing 4 m fighting zone; never lock camera on windup alone, use global time scaling, or add new QTE inputs in Stage 4.

## Android and visual acceptance boundary

This update does not build an APK. No rendered or Redmi/device result is available. Headless hand-position and orientation checks do not validate visual palm contact, finger wrap, skin clipping, crowded/wall/uneven-terrain cases, or mobile frame pacing. Stage 3 remains visually unaccepted until the palm and finger grip are inspected in a rendered build.
