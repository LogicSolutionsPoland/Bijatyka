# Bijatyka Stage 6 / P1 — Android grab animation and QTE diagnostics

> **LATEST OWNER ANDROID ACCEPTANCE — FAIL (2026-11-09): NO OBSERVABLE NATURAL ZOMBIE GRAB AND NO QTE in the delivered Stage 6 P1 APK.** Earlier CI PASS and Android PENDING statements below are historical; they do not supersede this physical-device result. No root cause established by this report.


Date: 2026-11-09. Scope: diagnose physical Android feedback initially reported as **"nie ma animacji chwytów ani qte"**, then clarified as **"nie ma miejsca zadne chwytanie gracza ani nic takiego, tego nie ma"**. Source frozen from the verified Stage 5B game commit `f1989c8c675357427e2214796e14a5103f1cef01`. Owner-reported Android test: **FAIL — no grab occurs in natural gameplay**. Actual device screenshots and logs have not been supplied. This document is diagnostic only, not proof of a repaired APK.

## Branch/safety

- Diagnostic branch: `fix/bijatyka-stage6-grab-qte-android-20261109`, created directly from `f1989c8c675357427e2214796e14a5103f1cef01`.
- Do not touch `main`, the Stage 5B integration branch, old APK, the original blackout, fog horizon, tip artwork, 20-zombie limit or gamepad mappings.
- Do not merge, publish a release, export an APK or start Stage 7.
- Work on tests/documentation only until the root cause is independently reproduced.

## Owner clarification — no grab is initiated at all

The observable defect is not merely missing animation or missing HUD. **No enemy-to-player limb grab ever occurs during the owner's actual Android gameplay**, so the player never enters an observable hold and QTE never begins. Mark physical-Android grab/QTE **FAIL** rather than PARTIAL. This supersedes earlier ambiguous language. No videos or device logs were provided; root cause is not yet established.

Five green CI suites test the mechanisms in artificially controlled states. They do not prove naturally initiated grabs. Do not label this as an animation-only defect or declare QTE functional on the owner's phone.

The next investigation must begin at `enemy.gd::_update_ai` -> `_try_begin_limb_grab` -> `_resolve_limb_grab` and collect the actual gate-rejection reasons before considering artwork or tweaking odds. Do not bypass validated contact / AI ownership checks.

---

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
- **Crucial interpretation:** all green tests prove that the framework *can* perform a hold and QTE when explicitly set up. They do **not** identify why the owner observes neither grab animation nor QTE during normal gameplay. Owner's Android **FAIL: no natural grab occurs** is still unresolved.

## Next minimal diagnostic gate

Record the *naturally initiated* grab in a normal 20-zombie scenario, without calling `try_reserve_limb_grab` or `begin_limb_grab` from a test fixture. Instrument refusal reasons per existing rules (rig detailed, visual visibility, slot, clip, player grounded, actual Exo hand reach, HUD signal), but do not weaken gates. At least one ordinary zombie must enter windup, make true skeletal contact, emit `grab_qte_started`, display QTE and allow three physical R3 edges. Capture gameplay + logs from a physical Android test before declaring the defect repaired.

**Current P1 status: AUTOMATED DIAGNOSTICS PASS; PHYSICAL ANDROID DEFECT OPEN. No gameplay/source/shader/art fixes made.**


---

## 2026-11-09 — P1 natural gameplay regression and isolated repair (supersedes the pre-repair status above)

### Confirmed failure in real production AI

The new deterministic `game/tests/stage6_p1_natural_grab_test.gd` instantiates `foundation.tscn`, completes the real elevator/ground activation, keeps the production spawn manager and AI Director running, and observes an ordinary live zombie. It controls only deterministic initial positioning; it does not directly reserve/start a grab, emit a QTE signal, assign an attacker slot, force an animation, or disable the actual AI.

- **Pre-repair run:** [#42701499716](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42701499716), SHA `ca0b9787d2a7d1a61982611ce45b07fe6fb025e1`, natural test **FAIL**.
- Real AI attempted 18 attacks and initiated 12 grab windups, but started **0 QTEs**.
- Captured rejection reasons: `visual_contact_unreachable` from visible-rig admission and `contact_failed` during final contact resolution. Existing attacker roles, visible rigs and player eligibility were present during the encounter.
- The initial minimal approach correction closed center-to-center distance from about 1.45 m to about 1.015 m but still failed: [#42702534923](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42702534923), SHA `935ed27fadbfe58d21b013d97ef36994dadd15d4`, natural test **FAIL**. This correction alone was insufficient.
- **Real arm geometry:** [#42703104494](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42703104494) measured zombie shoulder-to-Exo forearm target distances around **1.005 m** (selected left grip) and **0.669 m** (selected right grip). The actual shoulder–elbow–hand chain reached about **0.525 m**, including the existing safety margin. All four tested arm/hand combinations were outside valid reach. The obstacle was **geometric contact admission**, not missing QTE logic or AI attack selection.

### Scoped implementation — only `game/scripts/enemy.gd`

The zombie now approaches its selected arm from the **visible Exo Gray forearm side** during the existing natural grab windup. `_limb_grab_approach_point()` computes a local flank position from the forearm and player center. It leaves a center distance of approximately **0.84 m**, outside the original combined physical capsule radii (0.38 m player + 0.42 m ordinary zombie). Existing `CharacterBody3D` motion/collision via `move_and_slide()` remains authoritative, as do attack slots, line of sight, eligibility, real two-bone IK reach, QTE ownership and valid arm selection.

This is a real locomotion/collision-based approach, **not teleportation, enlarged IK tolerance, a forced QTE, or increased attack probability**. No shaders, blackout, fog horizon, tip artwork, camera, gamepad assignments, AI Director implementation, zombie population limits, Stage 5B branch or `main` were modified.

### Verified post-fix gates

- [**#42703726486**](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42703726486) at gameplay fix SHA `fdb3fe055b6d5b06c2f0bb75ac90cdcf987ee833`: **SUCCESS**. Natural ordinary zombie AI reached a real contact, established a grab and began/completed a QTE without test-forced admission. Five existing state/QTE/IK/rig/HUD suites **PASS**. Controlled Stage 5B Mesa OpenGL capture and blackout regression **PASS**. AI Director and jump regressions **PASS**. [Diagnostic artifact #13711744361](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42703726486/artifacts/13711744361).
- [**#42704177652**](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42704177652) at test SHA `f124d51a8e7e0492988733a2397c45fb9a0fbef5`: **SUCCESS**. Extended natural AI test passed with three separate simulated R3 press/release input events routed through the actual viewport/HUD, QTE shown and dismissed, and player returned to READY. Existing suites, Mesa-controlled rendering, AI Director and jump regressions also **PASS**.
- [**#42704672958**](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42704672958), test SHA `e2bb1097e1de2c97a540e366b8f4ca618a285853`: **COMPLETED / SUCCESS**. Five QTE/IK/HUD suites, natural headless AI grab with three R3 presses, controlled Stage 5B Mesa blackout render, AI Director and jump regressions all **PASS**. An additional naturally initiated Mesa/OpenGL run produced **seven actual 1280×720 screenshots**: `natural-approach.png`, `natural-windup.png`, `natural-hand-reaching.png`, `natural-contact-qte.png`, `natural-restrained.png`, `natural-escape.png`, `natural-recovery.png`. [Log and PNG artifact #13712019982](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42704672958/artifacts/13712019982) (no APK). The GL encounter recorded **7 ordinary attacks, 3 natural grab windups, 1 confirmed real contact/QTE and 3 separate R3 presses**, leading to `escaped`; **2 earlier windups were correctly refused** as visually unreachable. Visual inspection confirms zombie proximity/arm contact, temporary QTE HUD and return to combat; the existing punch-based windup still does not read as a polished distinct two-person grab animation.

### Remaining risks and explicit acceptance boundaries

- Original grab windup continues to use the existing punch-derived animation, although the opponent now physically moves into reachable forearm contact and the existing IK hold. The *aesthetic readability* of reach/hold/release still needs inspection of the seven GL frames and a phone test; do not claim AAA animation completion.
- Host Mesa/OpenGL and virtual R3 are **not** Android GPU, thermal or real Bluetooth/USB controller acceptance. Physical Android still **PENDING**. No APK was built or authorized. A future phone test needs separate APK authorization.
- No controlled comparative mobile FPS/thermal data exist for the new approach. Do not assert measured performance equivalence to the old phone APK.
- Zombie Fog Horizon owner-reported FAIL and flashlight-tip artwork PARTIAL remain **deferred and untouched**. Fullscreen Blackout remains under the existing regression suite.
- Do not merge to `main`, start Stage 7, release a build, alter source branch Stage 5B or replace the previous verified APK.
- **Working branch:** `fix/bijatyka-stage6-grab-qte-android-20261109`. Production source modification limited to `game/scripts/enemy.gd`; other changes are a dedicated natural gameplay test, a no-APK CI workflow, and this diagnosis.


---

## 2026-11-09 — Stage 6 P1: one final ARM64 debug APK (CI PASS, Android device PENDING)

### Source integrity and build provenance

- Exact Android export commit: `2949e9873ea64945ad508823b1878b7639a8aee8`.
- Previous verified P1 branch HEAD before export workflow: `192c8e91b2b21bce4242148e1674acde3e76a96b`.
- Verified gameplay repair commit: `fdb3fe055b6d5b06c2f0bb75ac90cdcf987ee833`.
- Last successful full pre-build CI game source: `e2bb1097e1de2c97a540e366b8f4ca618a285853` ([run #42704672958](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42704672958)).
- New workflow commit changes *only* `.github/workflows/bijatyka-stage6-p1-arm64-apk.yml`, not `game/**`. The workflow verified `git diff --quiet e2bb1097... HEAD -- game` and an unchanged `enemy.gd` against the repaired commit, while checking the active R3 input map. **No gameplay, graphics, controls, shaders, fog, blackout, elevator or Stage 5B code changed.**
- Existing Android export preset `Android ARM64` uses `arm64-v8a=true`, with other architectures disabled; Godot 4.7.2 and compatible Android export templates were used.

### CI build and verified artifact

- [**GitHub Actions run #42707639776**](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42707639776): **COMPLETED / SUCCESS**.
- Artifact ID: **13715370279**, named `Bijatyka-Stage6-P1-GrabQTE-ARM64-debug` ([verified download API URL](https://api.github.com/repos/LogicSolutionsPoland/Bijatyka/actions/artifacts/13715370279/zip)); the archive contains exactly one APK.
- APK filename: `Bijatyka-Stage6-P1-GrabQTE-ARM64-debug.apk`.
- APK SHA-256 as printed by the successful export job: **`ec20129f701f12b97361f28bfec07e27682affebdd469eedf770a39ef9b08c1a`**.
- Artifact ZIP download size reported by GitHub: 65,009,662 bytes (ZIP size, **not** independently verified raw APK size).
- Android package: `org.logicsolutionspoland.bijatyka`; ZIP archive integrity, Android manifest/badging, debug signing (`apksigner verify`), ARM64-only shared-library entries, `assets/project.binary`, compiled `assets/scripts/enemy.gdc`, player, foundation, HUD code and main scenes: **PASS**.
- Exact one APK output and exactly one APK artifact upload: **PASS**. No release was created; no old artifact was replaced.

### Pre-build and rendering results in this exact build workflow

1. Repository source/repair identity guard: **PASS**.
2. Godot project import and parse: **PASS**.
3. `brutal_grab_state_machine_test`: **PASS**.
4. `brutal_grab_qte_test`: **PASS**.
5. `brutal_grab_limb_contact_test`: **PASS**.
6. `brutal_grab_real_rig_test`: **PASS**.
7. `stage6_grab_qte_hud_diagnostic_test`: **PASS**.
8. `stage6_p1_natural_grab_test`: **PASS**, production AI natural contact and QTE, including three distinct simulated R3 inputs; no test-forced grip reservation or QTE start.
9. `ai_director_test` and `jump_state_regression_test`: **PASS**.
10. Stage 5B Mesa/OpenGL transition probe and Fullscreen Blackout regression: **PASS**.
11. Mesa/OpenGL production natural-grab capture: **PASS**; seven nonempty real rendered PNG frames covering approach, windup, reaching, contact/QTE, restraint, escape, and recovery.
12. ARM64 debug export, APK integrity, content and signing checks: **PASS**.

### Physical Android acceptance checklist — OWNER ACTION REQUIRED

These checks are **PENDING**, not inferred from CI.

- [ ] Install this exact APK, verify filename and optional SHA-256, launch, rooftop, elevator, ground activation and ordinary enemy population.
- [ ] Verify Fullscreen Blackout; movement, jumping, punches, magic, RAGE and original gamepad mappings.
- [ ] In ordinary combat with no developer-forced grab, observe an ordinary zombie naturally approach the Exo Gray forearm, enter windup, make visible hand-to-arm contact, restrain the player, reveal the QTE, then release the player.
- [ ] Confirm QTE starts with 1.5 seconds and expects exactly **three distinct R3 press/release events**; holding R3 must not count repeatedly.
- [ ] Confirm normal movement resumes after successful escape, HUD disappears, timeouts safely release the player and interruptions/death clear the active grip.
- [ ] Confirm no stuck attacker slot, permanently frozen player, lingering QTE widget, unnatural teleporting or severe skeletal deformation.
- [ ] Watch FPS, heat, stability and controller responsiveness on real hardware; report any regressions with a short video/log if possible.

### Explicit limitations and exclusions

- Not every natural grab is guaranteed or permitted: visually unreachable contacts remain correctly rejected.
- Existing punch-derived grab-windup animation and contact/release readability remain aesthetically imperfect; this P1 APK does not modify animations.
- No Android hardware GPU, FPS, thermals or controller timing measurements are available. Device acceptance remains **PENDING**.
- Owner-deferred Zombie Fog Horizon failure and flashlight-tip artwork partial result are **OUT OF SCOPE** for this P1 verdict.
- `main` unchanged by this task; Stage 5B branch unchanged; Stage 7 **not started**; no merge or release.
- This documentation update occurs *after* the build, so its new documentation-only commit is intentionally not the binary's exact source SHA. The verified APK source SHA remains `2949e9873ea64945ad508823b1878b7639a8aee8`.

**Final CI matrix:** P1 NATURAL ZOMBIE GRAB CI **PASS**; QTE/R3 CI **PASS**; NATURAL GRAB RENDERING **PASS**; ANDROID ARM64 BUILD **PASS**; APK INTEGRITY **PASS**; FULLSCREEN BLACKOUT PRESERVED **YES**; ANDROID DEVICE ACCEPTANCE **PENDING**; MAIN CHANGED **NO**; STAGE 7 STARTED **NO**; APK COUNT **1**.

---

## 2026-11-09 — FINAL OWNER PHYSICAL ANDROID FEEDBACK: FAIL (supersedes CI-only acceptance status)

**Owner's explicit on-device observation:** "nie ma ani qte ani grab" — there is **no observable natural zombie grab and no QTE** during gameplay.

- **Natural zombie grab, Android device:** **FAIL / NOT OBSERVED**.
- **QTE launch and HUD, Android device:** **FAIL / NOT OBSERVED**.
- **R3 escape on a genuine hold:** **NOT TESTABLE** because the natural hold and QTE never appeared.
- **Stage 6 / P1 Android acceptance:** **FAIL / OPEN**; do **not** declare the P1 defect repaired on a real device.
- APK under test (latest delivered P1 build): `Bijatyka-Stage6-P1-GrabQTE-ARM64-debug.apk`; artifact [#13715370279](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42707639776), build source SHA `2949e9873ea64945ad508823b1878b7639a8aee8`, SHA-256 `ec20129f701f12b97361f28bfec07e27682affebdd469eedf770a39ef9b08c1a`. The owner did not provide an independent on-device APK hash, recording or Android logs; the artifact reference identifies the delivered P1 build, **not independent forensic proof** of the file installed on the phone.
- Existing successful CI run [#42707639776](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42707639776) remains **CI PASS only**. It does **not** override real Android failure. The discrepancy requires root-cause investigation; do not assume that the remaining defect is solely a missing animation, a HUD rendering problem or a failed R3 binding.
- Do not modify the game, grab parameters, QTE, visuals, Android export, Stage 5B, or `main` as part of recording this report.
- No new APK, CI run, release, merge or Stage 7 was initiated for this feedback.
- Zombie Fog Horizon and flashlight-tip artwork remain separately deferred.

**Latest authoritative status:** P1 NATURAL ZOMBIE GRAB CI **PASS (previously)**; QTE / R3 CI **PASS (previously)**; REAL ANDROID NATURAL GRAB **FAIL**; REAL ANDROID QTE **FAIL**; ANDROID DEVICE ACCEPTANCE **FAIL / OPEN**.
