# Bijatyka Stage 6 / P1 — Android grab animation and QTE diagnostics

Date: 2026-11-09. Scope: diagnose physical Android feedback **"nie ma animacji chwytów ani qte"**. Source frozen from the verified Stage 5B game commit `f1989c8c675357427e2214796e14a5103f1cef01`. Owner-reported Android test: **PARTIAL**. Actual device screenshots and logs have not been supplied. This document is diagnostic only, not proof of a repaired APK.

## Branch/safety

- Diagnostic branch: `fix/bijatyka-stage6-grab-qte-android-20261109`, created directly from `f1989c8c675357427e2214796e14a5103f1cef01`.
- Do not touch `main`, the Stage 5B integration branch, old APK, the original blackout, fog horizon, tip artwork, 20-zombie limit or gamepad mappings.
- Do not merge, publish a release, export an APK or start Stage 7.
- Work on tests/documentation only until the root cause is independently reproduced.

## Verified code path

1. `game/scripts/enemy.gd` attempts an enemy-to-player grab in attack combat path only on `_attack_sequence % 3 == 1`, and only after an attacker slot is acquired.
2. `_try_begin_limb_grab()` returns false unless enemy is an ordinary zombie actively targeting the player, with full detailed model and *visible* `_visual_root`, non-null skeleton and animation player, valid director attacker permission, compatible bone mapping, existing side-specific attack clip and successful player reservation.
3. The current attack pose for grab windup is deliberately a **punch** clip from the enemy combat animation library. There is no distinct grab-windup clip in this path. The enemy holds the punch contact frame after a successful grab.
4. `_resolve_limb_grab()` requires distance within `min(attack_range+0.18,1.65)`, clear line of sight and valid attacker slot. `player_controller.gd` adds grounded/eligible-state guards and actual imported-rig `can_reach_contact` for the visible Exo skeleton.
5. If preflight returns `visual_contact_unreachable` then the session is cleaned up **before** publishing QTE. This is a plausible natural-gameplay rejection, not verified as the owner's cause.
6. The player freezes a `Hit` animation pose when grabbed. `game/scripts/brutal_grab_limb_contact.gd` adds a two-bone IK modifier to the zombie arm for forearm contact, with hand orientation. The IK is **not** an authored complete two-character grab animation.
7. QTE is 1.5 seconds / 3 presses by default in the player code. On success it emits `grab_qte_started`, handled by `mobile_hud.gd::begin_grab_qte`, which makes a single escape button visible and shows progress. R3 is mapped to `pad_escape_limb_grab` in `game/project.godot` and relayed by the HUD to `foundation.gd`, then player escape.
8. Existing `brutal_grab_qte_test`, `brutal_grab_state_machine_test` and `brutal_grab_real_rig_test` validate synthetic or controlled preconditions. The Stage 5B transition fixture also deliberately arranges contact and freezes unrelated AI. Consequently green tests do not prove that normal Android encounters naturally start visible grabs.

## Working hypotheses — not confirmed root causes

- **H1 / encounter gate:** ordinary zombies never reach all detailed rig, camera visibility, attacker-slot and distance/preflight conditions simultaneously in real gameplay.
- **H2 / visible Exo mismatch:** side/target selection in `enemy.gd::_nearest_arm_and_hand()` uses player base skeleton, whereas contact admission and visible hand IK use Exo target skeleton. This may select the wrong arm or target.
- **H3 / presentation:** a punch clip and static Hit pose do not read as a genuine grabbing animation even if QTE logic functions.
- **H4 / session too brief:** QTE appears only for 1.5 seconds and may instantly end after failed contact / reservation loss; no in-game diagnostic tracing currently distinguishes these cases.
- **H5 / controller/UI:** signal is emitted but the QTE widget or R3 action does not appear/respond correctly on Android. It can be checked at host level but ultimately needs device evidence.

## Diagnostic gates (safe, NO APK)

- Import Godot 4.7.2 project without new parsing failures.
- Repeat 4 pre-existing suites: `brutal_grab_state_machine_test`, `brutal_grab_qte_test`, `brutal_grab_limb_contact_test`, `brutal_grab_real_rig_test`.
- Run `stage6_grab_qte_hud_diagnostic_test` to verify the actual QTE widget, progress text, session-filtered dismissal and simulated R3 action via the existing input map.
- Run the Stage 5B Mesa/OpenGL transition fixture with captures, as a regression baseline. Its controlled setup is **not** a natural encounter or mobile FPS test.
- Collect exact source SHA, full log files, and explicit PASS/FAIL per suite. None of these checks proves hardware functionality.

## Follow-up real-device diagnostic target

After the basic CI gate, create a separate authorized *diagnostic Android APK* **only if justified**, with short, non-sensitive counters for these named events: `attempt`, `no_full_rig`, `not_visible`, `attacker_denied`, `no_side_clip`, `reservation_denied`, `windup_started`, `contact_failed`, `visual_contact_unreachable`, `qte_started`, `qte_finished`, `hud_shown`, `escape_r3`. This must not change gameplay acceptance guards, AI, rates or timeout merely to pass a test. Confirm original APK SHA and device/Android version before comparing.

No owner device observations beyond the reported partial outcome are currently available, and there is no basis to declare any one hypothesis proven.

## Repair order after reproducing

1. Fix genuine root cause in encounter admission, Exo bone targeting or HUD signal path without bypassing validations.
2. Implement a recognizable distinct grab approach/hold/release visual sequence only if gameplay remains valid but presentation is insufficient.
3. Confirm visible QTE display, 3 accepted R3 edges, timeouts and cleanup, ordinary combat/jumps/AI stability, and blackout/fog regression protection.
4. Rebuild one explicitly authorized debug APK **from a separately tested fix SHA**, then repeat owner physical acceptance. Never replace the already validated Stage 6 binary.

## Executed CI result — 2026-11-09

- [GitHub Actions #42696826410](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42696826410): **COMPLETED / SUCCESS**, test HEAD `218595208d51d823d9c0520b7956bdb004e0a2c1`.
- Godot 4.7.2 import and parse: **PASS**.
- Existing state machine: **PASS**.
- Existing QTE logic: **PASS**.
- Existing limb-contact IK: **PASS**.
- Existing imported-rig grab checks: **PASS**.
- New HUD/QTE/virtual R3 input routing: **PASS**.
- **Five suites passed, zero failed.** No underlying gameplay file was modified relative to `f1989c8c675357427e2214796e14a5103f1cef01`.
- Stage 5B controlled real Mesa/OpenGL transition capture: **PASS**. The test is scripted/controlled, not a naturally initiated Android encounter.
- Log and PNG [artifact #13708699202](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42696826410/artifacts/13708699202); no APK exported.
- **Crucial interpretation:** all green tests prove that the framework *can* perform a hold and QTE when explicitly set up. They do **not** identify why the owner observes neither grab animation nor QTE during normal gameplay. Owner's Android **PARTIAL** finding is still unresolved.

## Next minimal diagnostic gate

Record the *naturally initiated* grab in a normal 20-zombie scenario, without calling `try_reserve_limb_grab` or `begin_limb_grab` from a test fixture. Instrument refusal reasons per existing rules (rig detailed, visual visibility, slot, clip, player grounded, actual Exo hand reach, HUD signal), but do not weaken gates. At least one ordinary zombie must enter windup, make true skeletal contact, emit `grab_qte_started`, display QTE and allow three physical R3 edges. Capture gameplay + logs from a physical Android test before declaring the defect repaired.

**Current P1 status: AUTOMATED DIAGNOSTICS PASS; PHYSICAL ANDROID DEFECT OPEN. No gameplay/source/shader/art fixes made.**
