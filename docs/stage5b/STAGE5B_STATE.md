# Bijatyka Stage 5B — cross-chat state and safety checkpoint

Checkpoint date: 2026-11-09. This document is the single persistent coordination record for Stage 5B Steps 0–6. It must be consulted and updated by future steps on the dedicated integration branch. Inspect current GitHub refs before every edit; SHA values below describe Step 0 inspection, not permanent branch locks. Do not rely on a chat summary as the source of truth.

## A. Project identity and scope

- Repository: LogicSolutionsPoland/Bijatyka
- Engine: Godot 4.7.2
- Renderer: GL Compatibility / opengl3
- Android target: ARM64; gamepad-first controls
- Godot project: game/project.godot
- Main game scene: game/scenes/foundation.tscn, with runtime setup in game/scripts/foundation.gd
- Previous completed stage: Stage 5
- Current stage at checkpoint creation: Stage 5B / Step 0 — audit and safe setup
- Next stage: Stage 5B / Step 1 — Fullscreen Blackout Implementation

## B. Verified Git state (live at Step 0)

- Source Stage 5 branch: integration/bijatyka-stage5-complete-20261109
- Source Stage 5 HEAD: b052aaf876f5cb141547494b62b8c2fdb473e6c4
- Stage 5B dedicated branch: integration/bijatyka-stage5b-blackout-fog-20261109
- Stage 5B base: the exact Stage 5 source SHA above. Do not rebase onto main or either PR branch.
- Stage 4 branch: integration/bijatyka-current-20261109
- Stage 4 HEAD: 86ddc8cdb8e883a83f0b8978e7f94f69df27f3b0
- main HEAD at Step 0: ac12a215d95ce85d982f68b469aea99e75542883
- PR #68: https://github.com/LogicSolutionsPoland/Bijatyka/pull/68
  - OPEN, DRAFT, NOT MERGED; head feat/zombie-fog-horizon-20261105, SHA 63ea5a80c007bdedddbd7da41d2d62cdf1e9f6d4
  - Its base is perf/general-cpu-20261104; 14 changed files; do not merge/cherry-pick wholesale.
- PR #70: https://github.com/LogicSolutionsPoland/Bijatyka/pull/70
  - OPEN, DRAFT, NOT MERGED; head feat/flashlight-tip-user-image-20261107, SHA 65ec3780a6c1d3035494316170ea41db04481ae7
  - Its base is feat/jump-horde-stage1-20261105; 5 changed files; do not merge/cherry-pick wholesale.
- Source Stage 5 was eight commits ahead of Stage 4 with no behind commits at inspection.
- PR #68 and PR #70 diverged from Stage 5. Preserve all Stage 5 functionality and manually adapt their narrow features.
- Stage 5 successful baseline Actions: https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42623536580
  - Exact tested SHA b052aaf876f5cb141547494b62b8c2fdb473e6c4, push, SUCCESS on 2026-11-09.
  - Godot import; 20 automated regression suites; 600-frame playable scene smoke; true Mesa/Xvfb/OpenGL flashlight beam volume test; paired visibility CPU samples; no APK.
- Existing repository instructions: AGENTS.md was absent in root, game/, and docs/ at Step 0 inspection.

## C. Nonnegotiable final requirements

1. Ground-floor FULLSCREEN BLACKOUT must be implemented: game-world pixels outside the effective flashlight illumination region must be black, subject only to deliberately justified player/HUD visibility exceptions. The absence of blackout in Stage 5 is NOT binding design authority.
2. Preserve the directional illuminated flashlight region and the visible 3D beam, with coherent camera/gamepad yaw and camera pitch.
3. Adapt PR #68's player-following, 10 m radius, 96-segment, six-sector circular animated zombie-fog horizon (four source textures).
4. Adapt PR #70's flashlight-tip fog-zombie artwork, 40% image opacity, animated fog, short horizontal glitch slices, approximately 13 flicker steps/s, at the projected beam end.
5. HUD, boss locator, and gamepad/touch controls must remain readable; rooftop scene must remain free of ground-floor blackout and flashlight effects.
6. Preserve all Stage 5 gameplay, combat, animations, enemies, elevator, camera behavior, pooled FX, visibility registry, render optimizations, and performance limits. Stage 5 source currently defines 20 ordinary-zombie capacity, 10 m flashlight range, 30 m geometry visibility, 40% mobile 3D resolution, and 60 FPS cap. Never silently change these constants.
7. No APK or AAB builds, Android exports, releases, merges into main, force pushes, branch deletion, history rewrite, or modifications to original Stage 5 or either source PR. An APK requires separately explicit authorization in a future task.
8. Future implementation/test work belongs on Stage 5B branch, in designated steps only. Step 0 changes documentation ONLY.

## D. Seven-step execution plan

| Step | Responsibility | Status at Step 0 | Evidence / blocker |
| --- | --- | --- | --- |
| 0 | Audit live refs, rendering, source PRs, CI; protect baseline and create this checkpoint | PASS | Read-only audit, workflow-trigger inspection, dedicated branch and docs-only checkpoint; verify pushed SHA in the Step 0 report |
| 1 | Implement ground-floor fullscreen blackout on Stage 5B, preserve roof/HUD/beam; test real pixels | NOT STARTED | Old shader exists but live manager allocates no composite. Existing tests assert absence and must be intentionally updated |
| 2 | Adapt PR #68 circular animated zombie fog horizon | NOT STARTED | New mesh/texture layout and render priority require integration; do not copy its old foundation wholesale |
| 3 | Adapt PR #70 flashlight-tip artwork, movement, 13 Hz slices | NOT STARTED | Use narrow shader/script/assets/test changes; exclude Android workflow edits |
| 4 | Verify combined effects by actual software OpenGL framebuffer images and comparisons | NOT STARTED | Need real sampling of blackout, fog, tip, beam, HUD, rooftop and animation |
| 5 | Full gameplay regression + comparative CPU/render profiling | NOT STARTED | Preserve Stage 5 20-suite gate and host-only performance limitations; no APK |
| 6 | Final CI validation, evidence collection, integration freeze and cross-chat handoff | NOT STARTED | No main merge; no APK; future step to update final exact SHA |

Each step must first read this file, inspect the live branch HEAD and recent work, carry the previous step's evidence forward, update only accurate progress entries, and name the following step. Never mark an unexecuted step PASS.

## E. Ground-floor blackout and rendering audit

Current Stage 5 / Stage 4 inherited architecture:
- game/scripts/flashlight_visibility.gd explicitly documents removal of the previously broken full-screen composite. configure() builds distant-teeth CanvasLayer, 3D flashlight Spotlight, and projected tip art but DOES NOT call _build_composite(). The retained _material and _composite variables are null; set_composite_visible_for_comparison() is currently a no-op.
- The old screen-pass shader nevertheless still exists at game/shaders/flashlight_visibility.gdshader. It is a screen-space, depth-reconstructing, transparent black pass; uses flashlight_origin, flashlight_forward, 7.333333 m bright radius, 10 m max radius, camera-space oval center (0.44, 0.60), oval radii (0.29, 0.22), and a 2.1 m player readability exemption.
- PR #68 source at its HEAD retains _build_composite() in flashlight_visibility.gd. Its old implementation attaches a 2x2 QuadMesh to Camera3D, sets material render_priority=126, adds it to group flashlight_visibility_composite and sets shader uniforms; do NOT replace the Stage 5 manager wholesale because Stage 5 caches state and throttles uniform writes.
- Camera: foundation.gd creates behind-player Camera3D on SpringArm3D; _apply_camera_look and _process synchronize yaw through set_aim_yaw. The manager derives beam pitch from -camera.global_basis.z and yaw from horizontal aim; _upload_shader_parameters() deduplicates uploads. The 3D beam, light and tip use common MAX_RADIUS=10.0, BEAM_TANGENT=0.46630766 and beam_origin at player+1.55 m. CPU classifiers update at 0.12 s; teeth at 0.033 s. Avoid reintroducing per-frame redundant scene traversal or draw calls.
- Actual beam shaders: game/shaders/flashlight_beam_volume.gdshader (three crossed sheets) and game/shaders/flashlight_beam_sections.gdshader (cross-sections). Geometry uses depth testing and currently render priority 127. Do not remove or regress these.
- Rooftop: foundation.gd _set_rooftop_render_profile(true) selects rooftop city sky, hides burning_horizon, calls manager.set_rooftop_sky_visible(true), and disables Pencil on roof. Manager _sync_rooftop_render_visibility hides the SpotLight, tooth CanvasLayer, and tip overlay. Integrate blackout into this same toggle; guard elevator loading/respawn transitions. _update_rooftop_sky avoids changing profiles during elevator loading.
- HUD: game/scripts/mobile_hud.gd extends CanvasLayer and is instantiated separately from 3D in foundation._build_hud(). Ground teeth glints live on CanvasLayer layer 0. A camera-attached 3D mask MUST NOT darken the HUD, notices, boss locator, inputs or other CanvasLayer content.
- Stage 5 cached visibility: foundation.INDEPENDENT_VISIBILITY_GROUPS contains distant_backdrop, nature_scenery_batch, flashlight_beam and pencil_screen_pass. Legacy recursive guard also knows flashlight_visibility_composite. A restored composite must be explicitly excluded from the NEW cached registry (for example, by safe grouping), or distance culling might disable it. Independently managed horizon is in distant_backdrop and should remain outside the registry.
- Ground floor uses 40% 3D scaling on mobile and canvas_items UI at full size. Test 1.00, 0.67 and 0.40 render scales when practicable.
- floor_skip_enabled is forcibly false in the current foundation._update_floor_skip_enabled() because the blackout was removed; do not blindly restore an obsolete floor skip optimization. Validate depth reconstruction, sky-depth special cases, player exemption, alpha and transparent sorting with actual framebuffer pixels before adopting old shader unchanged.
- NOTE: The Stage 5 branch did not itself remove the mask between Stage 4 and Stage 5: the eight-commit comparison shows flashlight_visibility.gd unchanged; Stage 5 inherited an already absent composite and enshrined that state in new tests. This nuance matters for blame/history.

Expected draw ordering, pending measured verification: ground geometry; ground full-screen black mask at priority 126; beam/fog/tip transparent features at priority 127; independent HUD CanvasLayer after 3D. All three overlays sharing 127 are NOT guaranteed to blend in the desired order. Explicit scene/depth/material design and real pixel probes are required. The horizon must remain visible at the 10 m edge while pixels OUTSIDE the effective light elsewhere remain black; document any intentional artwork exception precisely.

## F. PR #68 integration classification

Source files:
- SAFE TO ADAPT: game/assets/environment/zombie_fog_01.webp through zombie_fog_04.webp; game/scripts/burning_horizon.gd; game/shaders/burning_horizon.gdshader; game/tests/zombie_fog_render_probe.gd.
- REQUIRES CONFLICT RESOLUTION: game/scripts/foundation.gd (current Stage 5 has cache optimization and rooftop/elevator logic; adapt only narrow horizon-related changes); game/tests/burning_horizon_test.gd; game/tests/environment_render_test.gd; game/tests/flashlight_visibility_test.gd. Their old four-panel, mask and Stage 5 assumptions need coordinated updates.
- DOCUMENTATION OPTIONAL/REWRITE FOR CURRENT BASELINE: docs/burning-horizon.md; docs/visual-asset-budget-phase7.md, historical budget changes. Do not overwrite Stage 5 docs indiscriminately.
- EXCLUDE FROM AUTO-IMPORT: .github/workflows/tower-lower-skybox-validation.yml changes to unrelated branch triggers; build a dedicated safe no-APK test strategy as needed.
- PR #68 source uses CylinderMesh radius FlashlightVisibilityManager.MAX_RADIUS, 96 radial segments, 6 m height, no caps, render_priority 127, four 1024x576 textures mapped across six sectors (1,2,3,4,3,2), player-following world position but not camera yaw. Retain distant_backdrop group and no collision/shadows.
- Files and byte sizes checked live: zombie_fog_01.webp 38,730; 02 23,906; 03 25,956; 04 45,040.
- PR #68's zombie_fog_render_probe.gd uses actual Compatibility framebuffer samples (sector swatches, translucency, temporal pixel differences, and visible horizon after mask), a useful later adaptation. The PR text cites successful prior CI; this is not a fresh Stage 5B execution.
- Risk: priority-127 ring could render over darkness globally at range edge, produce backface/sorting artifacts, leak lit world outside cone, or conflict with tip and beam. Need 360-degree and rooftop/ground pixel coverage, not only asset-loading tests.

## G. PR #70 integration classification

- SAFE TO ADAPT (during Step 3 only): game/assets/effects/flashlight_tip_zombie_fog.webp (59,028 bytes, new); targeted modifications to game/scripts/flashlight_tip_silhouettes.gd and game/shaders/flashlight_tip_silhouettes.gdshader.
- REQUIRES UPDATING ASSERTIONS: game/tests/flashlight_tip_silhouettes_test.gd. Current Stage 5 binds zombie_contour_mask, while PR #70 binds tip_artwork.
- EXCLUDE ENTIRELY: .github/workflows/android-arm64-export.yml modifications. They add PR #70's feature branch to push-triggered APK export and change APK content checks. Stage 5B is strictly no-APK.
- Preserve existing overlay lifetime and live tip projection code (world-space tip, camera.unproject_position, footprint based on cone/range, early rejection when behind camera or outside view, rooftop disable). Do not copy old foundation or controller code.
- PR #70 shader uses RGBA image density times silhouette_opacity=0.40, fog_opacity=0.72, animated warp, five short hard-edged horizontal scan slices, and floor(TIME * animation_time_scale * 13.0) glitch frame. Preserve existing moving fog and correct transparent composition.
- Risks: 127-priority overlay may blend/sort incorrectly relative to blackout, ring and beam; test the 40% alpha pixel delta at the projected end, 13 Hz visual changes, pitch/yaw updates, rooftop off and foreground occlusion. No physical device FPS claims.

## H. Test inventory, CI safety and real-render plan

CI audit of 23 workflows in .github/workflows/ as of Step 0: relevant push triggers are branch-specific. A documentation-only push to integration/bijatyka-stage5b-blackout-fog-20261109 is not in any observed push or pull_request branch match; Step 0 opens no PR and dispatches no workflow. Never infer that any workflow_dispatch is safe to run without checking its body.
- NO-APK existing Stage 5 integration workflow: .github/workflows/bijatyka-stage5-integration-validation.yml, push ONLY integration/bijatyka-stage5-complete-20261109, or manual dispatch. Do not push original Stage 5 branch. Its exact prior successful run #42623536580 is the baseline, not proof for future modifications.
- Additional no-APK probes/workflows include stage4 integration validation, gpu-stage5-screen-effects, gpu-stage6-beam, tower-lower-skybox, flashlight-tip-silhouettes, general-cpu, performance, and other feature validations; their push triggers also target different branches.
- APK-capable workflows include android-arm64-export.yml, elevator-loading-arm64-apk.yml, spawn-arm64-export.yml and player-ring-reference.yml; they have targeted push branches and some manual dispatch or PR triggers. Do not invoke them or amend their branch filters.
- Verified runner patterns: Godot 4.7.2 via chickensoft setup, Ubuntu 24.04, xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --audio-driver Dummy --rendering-driver opengl3 --path game --script res://tests/..., with artifacts/upload-artifact@v4. Existing Stage 5 run successfully completed a Mesa software-OpenGL flashlight beam probe; Xvfb environment and artifact logging are usable.
- Relevant existing baseline tests: game/tests/stage5_visibility_regression_test.gd, flashlight_visibility_test.gd, burning_horizon_test.gd, environment_render_test.gd, flashlight_render_probe.gd, flashlight_beam_volume_test.gd, flashlight_volume_test.gd, flashlight_tip_silhouettes_test.gd, flashlight_tip_silhouette_render_probe.gd, environment_render_probe.gd, gpu_stage5_mask_pair.gd, gpu_stage5_visual_capture.gd, scene_visibility_benchmark.gd. Existing probe files are NOT automatically evidence of current Stage 5 success. Some old scripts may crash against null _composite and must be deliberately rehabilitated before use.
- Explicit outdated assertions to revise in Step 1: stage5_visibility_regression_test.gd asserts _composite == null; flashlight_visibility_test.gd asserts _material == null / _composite == null and multiple diagnostics/rooftop no-mask paths; flashlight_render_probe.gd and flashlight_tip_silhouette_render_probe.gd already EXPECT _composite.visible and thus cannot pass unchanged on current Stage 5. PR #68's burning_horizon_test.gd also assumes active mask. Keep assertions for Stage 5 cached visibility, FX lifecycle, controls and gameplay. Test design changes must never conceal an actual failure.
- Step 2 will intentionally replace old four-panel assertions in burning_horizon_test.gd, environment_render_test.gd, flashlight_visibility_test.gd and flashlight_tip_silhouettes_test.gd with appropriate ring checks.
- Proposed actual framebuffer matrix (Steps 1/4): roof vs ground, camera yaw left/front/right and pitch, depth/sky occlusion, screen center and outside oval, no-light back/side, 7.33 to 10 m fade, lit foreground object, visible player, native CanvasLayer HUD and boss marker, 3D beam retained, 40% scaled scene. Sample raw RGB and save images with fixed scene/camera/lighting. Require world pixels outside effective light to be black to chosen measured tolerance; do not allow an opaque screen-sized overlay over HUD.
- Step 2/4: render 6 horizon swatches and real textures at 10 m, inspect all 360 degrees, alpha/texture continuity, mask occlusion ordering, live movement follow and timed fog changes; use actual root.get_texture().get_image() after RenderingServer.frame_post_draw.
- Step 3/4: capture tip artwork on/off pairs, compare pixel deltas against 0.40 configured alpha, verify short horizontal slices change across 13 Hz steps, test world projection on yaw/pitch and floor interception, verify no tip on rooftop.
- Step 4: combined scene renders with beam, blackout, ring, tip and UI simultaneously; paired screenshots and sampled pixels including failure case where ring/tip overlays leak illumination into unrelated world. Store frame captures, numerical summaries, Godot logs and exact tested SHA as CI artifacts.
- Step 5: repeat all 20 Stage 5 regression suites plus added specific shader and visual tests, 600-frame playable scene, and paired host CPU/GPU-approx samples. Report no real Android FPS, thermal or stability acceptance without device test.
- Do not implement any new test or workflow during Step 0. No fresh Godot tests were run at Step 0; source/CI audit was read-only.

## I. Step 1 instructions for new AI session

1. Fetch this document and live HEAD of integration/bijatyka-stage5b-blackout-fog-20261109, compare it with Stage 5 base b052aaf876f5cb141547494b62b8c2fdb473e6c4. Confirm the only Step 0 difference is docs/stage5b/STAGE5B_STATE.md. Detect unrelated changes and stop rather than overwrite.
2. Inspect the live .github/workflows/ trigger patterns BEFORE any write or workflow dispatch. Preserve no-APK rule. Work only on the dedicated branch, never main or source Stage 5.
3. Inspect current game/scripts/foundation.gd, game/scripts/flashlight_visibility.gd, game/shaders/flashlight_visibility.gdshader, game/shaders/flashlight_beam_volume.gdshader, game/shaders/flashlight_beam_sections.gdshader, game/scripts/mobile_hud.gd, game/scripts/flashlight_tip_silhouettes.gd, game/scenes/foundation.tscn and relevant tests.
4. Implement real full-screen ground-floor blackout with a correct 3D-rendered composite/mask (potentially reusing PR #68's narrow _build_composite patterns) while preserving Stage 5 deduplicated uniforms, cached visibility, 3D beam and camera/gamepad aim; keep rooftop zero-blackout and canvas HUD readable.
5. Add/update truthful headless plus REAL software OpenGL pixel tests for darkness, illuminated pixels, HUD, rooftop and beam; run no-APK CI on the actual implementation HEAD and collect artifacts. Do not claim static script tests establish visual correctness.
6. Do NOT integrate PR #68 ring or PR #70 new image in Step 1; those are strictly Steps 2 and 3.
7. Update this state file with Step 1 status, implementation/ref SHA, tests and blockers, and pass precise instructions to Step 2. Report in Polish.

## J. Persistent progress and safety protocol

For each new chat: read STATE file; fetch live Git refs/PR state; check potential concurrent edits; inspect existing workflows; execute ONLY that step; validate; record exact evidence and any failures; update STEP status; explicitly hand over to the next step. Never assume a previous job passed based on written intent. Keep original Stage 5, main, and both PRs untouched. Do not build APK or merge at any Stage 5B step absent a separate explicit authorization.
