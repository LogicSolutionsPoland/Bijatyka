# Bijatyka Stage 5B — cross-chat state and safety checkpoint

Checkpoint date: 2026-11-09. Step 0 PASS; Step 1 PASS; Step 2 PASS (Actions #42649851614); Step 3 PASS (Actions #42654026061, tested SHA 8b641fe390c2de99d1859b2ea9130496f52a807e); Step 4 PASS (Actions #42659365244, tested SHA 64893ab496ec6cc28f0ad4287cf0697c1ce30a34). This document is the single persistent coordination record for Stage 5B Steps 0–6. It must be consulted and updated by future steps on the dedicated integration branch. Inspect current GitHub refs before every edit; SHA values below describe Step 0 inspection, not permanent branch locks. Do not rely on a chat summary as the source of truth.

## A. Project identity and scope

- Repository: LogicSolutionsPoland/Bijatyka
- Engine: Godot 4.7.2
- Renderer: GL Compatibility / opengl3
- Android target: ARM64; gamepad-first controls
- Godot project: game/project.godot
- Main game scene: game/scenes/foundation.tscn, with runtime setup in game/scripts/foundation.gd
- Previous completed stage: Stage 5
- Current stage at checkpoint creation: Stage 5B / Step 0 — audit and safe setup (completed)
- Previous completed stage: Stage 5B / Step 2 — Circular Zombie Fog Horizon Integration (PASS)
- Previous completed stage: Stage 5B / Step 3 — Flashlight-Tip Zombie Artwork Integration from PR #70 (PASS)
- Current completed stage: Stage 5B / Step 4 — Combined Real-Rendering Verification (PASS)
- Next stage: Stage 5B / Step 5 — Full Gameplay Regression and CPU/Render Profiling (NOT STARTED)

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

| Step | Responsibility | Latest status | Evidence / blocker |
| --- | --- | --- | --- |
| 0 | Audit live refs, rendering, source PRs, CI; protect baseline and create this checkpoint | PASS | Read-only audit, workflow-trigger inspection, dedicated branch and docs-only checkpoint; verify pushed SHA in the Step 0 report |
| 1 | Restore ground-floor fullscreen blackout on Stage 5B, preserve roof/HUD/beam; test real pixels | PASS | Code SHA `738eb0064a02ba3aca13af31f3829733c695e40e`; [NO-APK Actions #42641061088](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42641061088) SUCCESS: 20/20 suites, 600-frame smoke, Mesa beam probe, 43 pixel blackout checks at 100/67/40%, rooftop no-mask, CPU samples and screenshots. Artist post leakage fixed |
| 2 | Adapt PR #68 circular animated zombie fog horizon | PASS | Implemented `a5d4c3e5bc722d3db8da840365974d5ac72bccb1`, final tested SHA `a51ed9c4de20df3126b0865f781b1a9a89ab9051`, NO-APK Actions [#42649851614](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42649851614) SUCCESS: 20/20 regression suites, 600 frames, 43 blackout checks, Mesa beam and six-sector fog captures/animation at 100/67/40%; see section L |
| 3 | Adapt PR #70 flashlight-tip artwork, movement, 13 Hz slices | PASS | Original WebP and shader integrated; implementation 2fb61fdc..., test correction 8b641fe...; [NO-APK Actions #42654026061](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42654026061) SUCCESS, 20/20 suites and real OpenGL tip probe (21 checks); see section M |
| 4 | Verify combined effects by actual software OpenGL framebuffer images and comparisons | PASS | [NO-APK Actions #42659365244](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42659365244) SUCCESS at `64893ab496ec6cc28f0ad4287cf0697c1ce30a34`, new 59-check real-frame matrix; artifact #13692569684; see N |
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

## I. Step 1 — completed implementation and verified evidence

Step 1 outcome: **PASS** (2026-11-09). Last TESTED implementation SHA:
`738eb0064a02ba3aca13af31f3829733c695e40e`.
GitHub Actions run **#42641061088**: https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42641061088 — **SUCCESS**, exact head SHA above.
Evidence artifact (no APK): https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42641061088/artifacts/13686035749
The current branch HEAD may become a later docs-only descendant after writing this handoff. Always fetch the live HEAD before editing.

Changes on this branch, and nowhere else:
- game/scripts/flashlight_visibility.gd: restored the former, camera-attached full-viewport blackout composite and existing shader at transparent priority 126. Existing cached classifier, deferred 3D beam geometry, 10 m range, debug mask visibility switch, 0.12 s update cadence, uniform deduplication and tip artwork manager remain intact.
- game/scripts/foundation.gd: added `flashlight_visibility_composite` to independent visibility groups so Stage 5's cached culling never hides the mask; preserved Stage 5's existing floor policy, camera, combat, map, and mobile settings.
- game/shaders/flashlight_visibility.gdshader: retained the previously implemented depth-reconstructing full-screen mask; restricted the nearby character visibility exemption to the actual player region in normalized screen space. The original unrestricted exemption illuminated tall tower/elevator posts far outside the cone. After the fix, those off-beam posts are fully black in screenshots while player and HUD remain readable.
- Adjusted tests only where older Stage 5 assertions incorrectly required no blackout: game/tests/flashlight_visibility_test.gd, stage5_visibility_regression_test.gd, flashlight_enemy_reveal_test.gd, general_cpu_optimization_test.gd and flashlight_beam_volume_test.gd. Tests continue checking existing mechanics and deduplicated uniforms.
- game/tests/flashlight_render_probe.gd now captures real OpenGL frames and verifies lit center objects, black off-beam pixels, four additional off-beam tower-post points (outside HUD), player visibility, rooftop sky/disabled mask, boss indicator/HUD, at 3 render scales.
- .github/workflows/bijatyka-stage5-integration-validation.yml: dedicated Stage 5B branch added to the existing explicitly NO-APK validation workflow, with true Mesa/Xvfb Compatibility framebuffer test, saved screenshots and QA-only artifacts. The original Stage 5 branch itself was not changed. All APK workflows remain untouched.

Exact verified tests on the implementation commit:
1. Godot 4.7.2 project import and script parse: PASS (pre-existing duplicate animation-name diagnostics remain).
2. All **20/20** previous Stage 5 gameplay, rendering, camera, AI/zombies, elevator, controls and CPU-regression suites: PASS.
3. Playable scene smoke **600 frames**: PASS.
4. Real software Mesa OpenGL 3D beam shaft pixel/opaque wall occlusion and rooftop beam absence: PASS.
5. Real software Mesa OpenGL fullscreen blackout test **43 checks**: PASS. Green outside-beam sample RGB=(0,0,0) at all 1.00, 0.67 and 0.40 render scales; lit red sample remains visible; player and HUD remain readable. Four post-leak sample points black at all three scales. Rooftop remains unmasked.
6. Paired pre/post host-only visibility CPU benchmark: PASS; no Android GPU, FPS, thermal or device claim.
7. Screenshots in artifact: `captures/ground-blackout-1.00.png`, `captures/ground-blackout-0.67.png`, `captures/ground-blackout-0.40.png`, `captures/rooftop-no-blackout.png`. Logs include `blackout-gl.log`, `flashlight-gl.log` and each of the 20 suite logs.
8. No APK/AAB, no release, no merge and no changes to original `main`, Stage 5, PR #68 or PR #70.
9. Earlier failing transient CI runs were diagnostic: outdated assertions expecting absent blackout and an initial tower-post light leak. These were explicitly corrected; #42641061088 is the final implementation verification.

The narrow final design requirement remains: on the ground, game-world pixels outside the effective flashlight illumination must be black, except intended screen UI, kept-visible player and explicitly approved artistic fog/tip layers in later steps. Do not weaken fullscreen blackout to a black sky, a dark vignette, or actor-only hiding.

## J. Next chat: Stage 5B / Step 2 — circular Zombie Fog Horizon

**Previous completed stage:** Stage 5B / Step 1 (fullscreen blackout restored, PASS).
**Current starting point for new AI:** Stage 5B / Step 2 (NOT STARTED).
**Next stage after Step 2:** Stage 5B / Step 3 — flashlight-tip zombie fog artwork (PR #70).

1. Read this file, fetch the LIVE HEAD of `integration/bijatyka-stage5b-blackout-fog-20261109` and compare to tested code commit `738eb0064a02ba3aca13af31f3829733c695e40e`. A later docs-only status commit is expected. Check recent changes before edits. Do not base on `main` or overwrite Stage 5, PR #68 or PR #70.
2. Before writes, re-inspect all GitHub Actions triggers and ensure no APK or release is triggered. Keep the verified Stage 5B NO-APK workflow and its 20 regression suites, GL beam probe, and 43-check blackout pixel probe.
3. Inspect PR #68 live status, head, and narrow source diffs. Its last verified HEAD at Step 0 was `63ea5a80c007bdedddbd7da41d2d62cdf1e9f6d4`. Adapt ONLY the four `game/assets/environment/zombie_fog_0*.webp` images, `game/scripts/burning_horizon.gd`, `game/shaders/burning_horizon.gdshader`, focused `foundation.gd` references if required, ring-related regressions, and `game/tests/zombie_fog_render_probe.gd`. Do not merge/cherry-pick the historical PR or import unrelated workflow changes.
4. Build a 96-segment, 6 m tall, capless player-following fog circle at `FlashlightVisibilityManager.MAX_RADIUS`=10 m, six image sectors ordered 1/2/3/4/3/2, subtle shader animation, and ground-floor only. Preserve rooftop panorama/camera and all Stage 5 systems.
5. Resolve priority sorting against the **existing priority-126 blackout** and priority-127 3D beam and tip. PR #68 renders fog at priority 127 so it remains visible at the 10 m boundary. Precisely confine its artwork to the intended boundary and avoid leaking world geometry or general illumination outside the flashlight. The blackout must NEVER be removed or replaced by merely black sky.
6. Update old four-panel horizon assertions in `burning_horizon_test.gd`, `environment_render_test.gd`, `flashlight_visibility_test.gd` and any tip regression expecting four panels. Keep the 43-check Stage 5B blackout regression, and add/use real Mesa/Xvfb framebuffer probes for six sectors, alpha, motion, 10 m ring radius, off-axis darkness, rooftop visibility and coexistence with the 3D beam.
7. Run NO-APK GitHub Actions on the actual new Step 2 implementation HEAD, inspect artifacts and actual captures, handle failures rather than claiming success, then update this document's Step 2 status, exact tested SHA, run IDs, residual risks and Step 3 instructions. Final report in Polish.

No PR #70 artwork integration in Step 2; it belongs to Step 3. Do not build an APK or merge to main.

## K. Persistent progress and safety protocol

For each new chat: read STATE file; fetch live Git refs/PR state; check potential concurrent edits; inspect existing workflows; execute ONLY that step; validate; record exact evidence and any failures; update STEP status; explicitly hand over to the next step. Never assume a previous job passed based on written intent. Keep original Stage 5, main, and both PRs untouched. Do not build APK or merge at any Stage 5B step absent a separate explicit authorization.

## L. Stage 5B / Step 2 — circular fog horizon, completed and tested (2026-11-09)

**Previous completed stage:** Stage 5B / Step 1 — Fullscreen Blackout Restoration, PASS.
**Current completed stage:** Stage 5B / Step 2 — Circular Zombie Fog Horizon Integration, PASS.
**Next stage:** Stage 5B / Step 3 — Flashlight-Tip Zombie Artwork Integration from PR #70, NOT STARTED.

### Verified Git and implementation record
- Working branch: `integration/bijatyka-stage5b-blackout-fog-20261109`.
- Initial Step 2 HEAD: `10415b53a53bc7f3bdb402d2e9f70b9715f5e211` (Step 1 docs checkpoint).
- First implementation commit: `a5d4c3e5bc722d3db8da840365974d5ac72bccb1`. Imports PR #68's four original byte-identical WebP assets; reworks `game/scripts/burning_horizon.gd` and `game/shaders/burning_horizon.gdshader`; updates old horizon expectations, adds the real-frame fog probe and updates only the existing NO-APK Stage 5/5B CI workflow.
- Follow-up narrow test-correction commit and **exact successful implementation/test HEAD**: `a51ed9c4de20df3126b0865f781b1a9a89ab9051`. Replaces obsolete `_pencil_screen_pass` test assumptions with the actual character-only Stage 5 Pencil Sketch pipeline. The production shader/mesh were NOT altered by this correction.
- This state-document update is a later docs-only commit; distinguish the current branch HEAD from the **exact tested implementation SHA** above. Do not count documentation alone as a new rendering test.
- Unmodified protected refs verified immediately before documentation: `main` = `ac12a215d95ce85d982f68b469aea99e75542883`; original Stage 5 = `b052aaf876f5cb141547494b62b8c2fdb473e6c4`; PR #68 source = `63ea5a80c007bdedddbd7da41d2d62cdf1e9f6d4`; PR #70 source = `65ec3780a6c1d3035494316170ea41db04481ae7`. Verify live again at Step 3 start.

### Integrated PR #68 details and compatibility decisions
- Imported **original, unmodified source images** `game/assets/environment/zombie_fog_01.webp` through `_04.webp` with source-identical Git blob SHAs `ac439b6723de2eeabae24a3902cfd7e23f979cf5`, `6bdb5b5c84fe35d0f58d64f8651bd0fab31ddcf7`, `da314476df4c60b4ca1007991721c9ccfafefd45`, `ad87b8aa139c79fa67e65a4823f08fad3bf5b3ee`.
- One capless, six-meter-high `CylinderMesh` with exactly 96 radial segments and 10 m top/bottom radius from `FlashlightVisibilityManager.MAX_RADIUS`; centered on and following player, independent of camera yaw; group `distant_backdrop`; no collision or shadow casting, no mesh reconstruction per frame.
- Single fog shader with four samplers, six texture sectors `1 → 2 → 3 → 4 → 3 → 2`, TIME-dependent image UV warp, fog-alpha motion, ordinary depth test, transparent render priority 127. Oval footprint uniforms are passed from the verified shared flashlight manager; shader discards fog outside the effective oval, so it cannot globally reveal the city. This is **decorative artwork only**, not environmental illumination.
- Unchanged fullscreen blackout shader and manager, including priority 126 and rooftop mode; unchanged 3D beam, original pre-Step-3 tip overlay, native HUD, Stage 5 visibility registry, 20-zombie capacity, 40% mobile resolution preset and 60 FPS cap.
- `game/scripts/foundation.gd` only changes an outdated comment; existing `follow_player()`, rooftop/ground switching, elevator, gameplay and cached visibility logic remain. Tests confirm ring outside cached culling registry. No wholesale PR merge/cherry-pick, no modifications to PR #68 or PR #70.

### Genuine CI results and evidence
- First diagnostic run: [Actions #42648523723](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42648523723) **FAILURE** at the new `burning_horizon_test.gd`: it incorrectly referred to nonexistent Stage 5 `_pencil_screen_pass`. Core 20 regression suites, 600-frame scene smoke, GL beam, 43-check real blackout and CPU samples were PASS. `zombie_fog_render_probe.gd` was skipped due the failed earlier step. Narrowly corrected test in `a51ed9c...`; no blackout assertions weakened.
- Final [Actions #42649851614](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42649851614) **SUCCESS**, exact HEAD `a51ed9c4de20df3126b0865f781b1a9a89ab9051`. Import/parser PASS; **20/20** Stage 5 baseline suites PASS; playable-scene **600 frames** PASS; real Mesa/Xvfb OpenGL flashlight beam test PASS; **43** real fullscreen blackout checks PASS (100%, 67%, 40%, off-beam tower structure darkness, lit red sample, player, rooftop, HUD); new `burning_horizon_test.gd` PASS; original `flashlight_tip_silhouettes_test.gd` PASS (18 checks); real `zombie_fog_render_probe.gd` PASS (six sectors and all scales, edge mask, temporal animation); host visibility CPU benchmark PASS.
- QA artifact: [`bijatyka-stage5-no-apk-qa-logs` — artifact 13688209795](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42649851614/artifacts/13688209795). Contains `blackout-gl.log`, `flashlight-gl.log`, `zombie-fog-gl.log`, twenty suite logs, `visibility-before.log`, `visibility-after.log`, 18 sector PNGs (six × three scales), 3 `zombie-mask-*.png`, animation before/after PNGs, 3 `ground-blackout-*.png`, and `rooftop-no-blackout.png`.
- Real framebuffer measurements: red boundary/fog compositing control **0.0000 → 0.48235** with horizon enabled at each of scales 1.00/0.67/0.40; off-oval dark pixel **(0,0,0)** in all three. Separate ground-screen blackout probe dark object RGB **(0,0,0)** at all scales; lit red intensity 0.9843 (1.00), 0.9569 (0.67), 0.8078 (0.40), while character and HUD remained readable. Sector 1–6 center pixel colors at full scale in 8-bit RGB: (126,2,2), (3,86,3), (2,2,165), (85,85,3), (2,2,162), (3,99,3), matching test swatches for source indices 1,2,3,4,3,2.
- Temporal comparison of two real 1280×720 screenshots ~1 second apart finds nonzero RGB changes on 12,282 of 921,600 pixels, maximum 2/255 on one channel, so animation is real **but quite subtle**; later end-to-end visual verification must assess perceived motion, seam aliasing and Android appearance.
- Host-only CPU comparison within final CI run: older Stage 4 baseline median (roof/ground) **759 µs / 1056 µs**; current Stage 5B **211 µs / 329 µs** (180 samples per scene; p95 Stage4 777/1075 µs, Stage5B 220/338 µs). This represents Stage 5 optimization vs Stage 4, **not an isolated measurement of added fog cost**; do NOT infer real-device Android frame rate, thermals, or GPU cost from this.
- No APK/AAB build/export, release, branch deletion, force push or merge performed; source branches, `main`, and original Stage 5 remain unchanged.

### Residual risks and handoff
- Existing beam, tip and horizon all draw at transparent priority 127 above blackout priority 126; real isolated fog/mask and earlier beam probes pass. **A combined multi-layer occlusion and camera-rotation visual matrix is still a later Step 4 responsibility**; identical priority is not a universal ordering guarantee. Do not silently declare every angle/occlusion configuration proven by the Step 2 isolated probe.
- Fog temporal animation is visible to a pixel comparator but subtle to a viewer (max ~2/255 in 1s). Preserve the original artwork and inspect perceptual motion, edge seams, backface behavior and any mobile overdraw in later steps without weakening blackout.
- Hardware Android performance and thermal behavior untested; no APK authorized.
- **Step 3 task only:** inspect the live current branch HEAD and this document; inspect PR #70 at live HEAD; adapt only the original `game/assets/effects/flashlight_tip_zombie_fog.webp` plus narrowly scoped `flashlight_tip_silhouettes.gd`, `flashlight_tip_silhouettes.gdshader`, relevant tests / safe NO-APK Mesa probes. Require **40% tip artwork opacity**, animated fog, short horizontal glitch slices, approximately **13 flicker steps/s**, live projected beam end tracking (pitch/yaw), appropriate occlusion/depth, rooftop absence; preserve this validated **priority-126 fullscreen blackout**, 10 m/96-segment/6-sector circular horizon and all Stage 5 optimizations. Do not import PR #70's Android export workflow changes, do not merge PRs or begin Step 4. Execute CI and update this file with exact SHA, outputs, and Step 4 handoff. No APK, main merge, release, or source-branch edit.

**Historical section J is the archived Step 1 → Step 2 handoff and is superseded for future work by this verified Step 2 → Step 3 record.**


## M. Stage 5B / Step 3 — implemented and verified, 2026-11-09

**Status: PASS.** Previous completed stage: **Stage 5B / Step 2 — Circular Zombie Fog Horizon Integration**. Current stage: **Stage 5B / Step 3 — Flashlight-Tip Zombie Artwork Integration**. Next stage: **Stage 5B / Step 4 — Combined Real-Rendering Verification** (**NOT STARTED**). Step 5 and Step 6 are NOT STARTED.

### Exact repository history and protection
- Dedicated working ref: `integration/bijatyka-stage5b-blackout-fog-20261109`; initial verified HEAD before Step 3: `61db5d77f688b2be5a5658c93cacb7d8387c4505`.
- Original source PR #70 (OPEN/DRAFT, not merged): `feat/flashlight-tip-user-image-20261107`, HEAD `65ec3780a6c1d3035494316170ea41db04481ae7`; original source PR #68: `63ea5a80c007bdedddbd7da41d2d62cdf1e9f6d4`.
- **Production implementation commit:** `2fb61fdc3ca284fdeb9093f16c2af7aa8843a29a`. Narrow import, exact artwork + original PR #70 shader, adapted assertions, Mesa framebuffer probe, safe NO-APK CI probe step.
- **Diagnostic test-only correction / exact successfully tested implementation SHA:** `8b641fe390c2de99d1859b2ea9130496f52a807e`. Changed only one printf-style assertion string (`40%` was mistaken for a formatting directive); no production code or shader changes.
- The documentation-only commit containing this section is **later than the tested SHA**. Its exact SHA is the live HEAD of the Stage 5B branch, obtainable through `git rev-parse HEAD` / GitHub ref inspection; it is NOT the SHA used by the successful visual test. The final Step 3 report must give that observed final ref SHA.
- Protected refs independently verified after implementation: `main` = `ac12a215d95ce85d982f68b469aea99e75542883`; original Stage 5 = `b052aaf876f5cb141547494b62b8c2fdb473e6c4`; PR #68 source = `63ea5a80c007bdedddbd7da41d2d62cdf1e9f6d4`; PR #70 source = `65ec3780a6c1d3035494316170ea41db04481ae7`. Neither source branch nor main was modified.
- No merges, force pushes, deletions, APK/AAB builds, Android exports or release publication. No changes to Android export workflows.

### Precisely integrated source content
- Added **byte-identical source** `game/assets/effects/flashlight_tip_zombie_fog.webp`, Git blob SHA `7412ef0d087174c366c01003d5ec3596d0693693`, 768×512 imported texture (59,028 source bytes).
- `game/scripts/flashlight_tip_silhouettes.gd`: imported exact PR #70 version. One persistent quad, original projection and floor-intercept behavior, shared 10 m beam range/cone, original source texture bound as `tip_artwork`, 0.40 silhouette opacity, 0.72 fog opacity, render priority 127.
- `game/shaders/flashlight_tip_silhouettes.gdshader`: exact PR #70 shader. RGBA artwork sampling, moving/warped fog and density, five localized horizontal glitch slices, `floor(TIME * animation_time_scale * 13.0)` discrete glitch frames, conditional horizontal sampling offset. Existing `depth_test_disabled` and priority 127 preserved from the prior tip-overlay architecture; not a newly added pass.
- `game/tests/flashlight_tip_silhouettes_test.gd`: updated for source texture, 768×512 size, five/13 Hz shader logic, existing 126-priority blackout, shared endpoint and downward ground intersection, rooftop/flashlight-off transitions. **22 checks PASS**.
- `game/tests/flashlight_tip_silhouette_render_probe.gd`: extended REAL framebuffer capture and comparison in the live Foundation scene at scales 1.00, 0.67 and 0.40; on/off, 0%/40% artwork-only, time-separated animation, ground/off-beam blackout, circular horizon and rooftop profile. **21 checks PASS**.
- `.github/workflows/bijatyka-stage5-integration-validation.yml`: one new focused Mesa/Xvfb OpenGL test step and PNG/log assertions; preserves original 20 suites and ALL established blackout/horizon tests; remains explicitly **NO APK**. Existing Android-export workflows remain unmodified.
- `game/shaders/flashlight_visibility.gdshader`, `game/scripts/flashlight_visibility.gd`, circular horizon script/shader/mesh, 3D beam shaders, `foundation.gd`, gameplay systems, rooftop sky, native HUD, visibility registry, 20-enemy capacity, 40% mobile render scale and 60 FPS cap are **unchanged**.

### Actual GitHub Actions runs and artifacts
1. Diagnostic [#42652879855](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42652879855), commit `2fb61fdc...`, **FAILURE** only in newly added tip framebuffer probe: a literal `40%` in a GDScript string formatted with `% scale` threw `unsupported format character`; command later reached timeout 124. Existing 20/20 suites, 600-frame smoke, real beam, 43-check blackout probe, source-tip unit test, circular horizon and fog animation tests, and host CPU samples all passed. Failure artifact [#13690613269](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42652879855/artifacts/13690613269). The production renderer was not identified as the cause.
2. Final [#42654026061](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42654026061), tested commit **`8b641fe390c2de99d1859b2ea9130496f52a807e`**, **SUCCESS**. Godot 4.7.2 resource import/parser PASS; **20/20** Stage 5 suites (`STAGE5_FAILED_SUITES=0`); **600 frames** playable smoke PASS; actual Mesa OpenGL beam PASS; **43** real blackout pixel checks PASS; tip unit **22** checks PASS; six-sector circular fog render and time animation PASS; new tip OpenGL probe **21** checks PASS; paired host visibility CPU benchmark PASS.
3. Final NO-APK artifact: [`bijatyka-stage5-no-apk-qa-logs` #13691217850](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42654026061/artifacts/13691217850), 4,303,242 bytes zipped. Includes new `flashlight-tip-gl.log`, images `tip-hidden-{1.00,0.67,0.40}.png`, `tip-visible-*.png`, `tip-artwork-40pct-*.png`, `tip-animation-start.png`, `tip-animation-after-120ms.png`, `tip-animation-after-920ms.png`, `tip-rooftop-profile.png`, plus existing blackout and six-sector fog PNGs/logs, tests and CPU benchmarks.

### Genuine framebuffer evidence, units and limitations
- Pixel-comparison values below are **maximum Euclidean RGB deltas in a sampled region**, NOT physically measured alpha, percent opacity or frame rate. Exact `silhouette_opacity=0.40` and `fog_opacity=0.72` are verified shader parameters and visually tested by paired render toggles.
- At 1.00 scale: tip enabled/disabled max delta **0.80679**; artwork-only 0%→40% max delta **0.81529**; off-beam pixel **(0,0,0)**.
- At 0.67 scale: tip enabled/disabled **0.90707**; artwork-only 0%→40% **0.70123**; off-beam pixel **(0,0,0)**.
- At 0.40 scale: tip enabled/disabled **0.90259**; artwork-only 0%→40% **0.84869**; off-beam pixel **(0,0,0)**.
- Temporal pixels at fixed projection changed: **0.63864** max delta after ~120 ms, **0.62562** after ~920 ms. Five glitch slices and nominal **13 Hz** stepping are verified by the original shader formula; **13 Hz was not independently measured using a high-precision visual timing instrument**. Both image frames and the earlier/later differences are archived.
- Real fullscreen blackout probe continued to pass at all three scales: off-beam ground sample RGB **(0,0,0)**; lit target red component **1.0000 / 1.0000 / 0.9961** at 1.00/0.67/0.40; player visible, rooftop panorama pixel `(0.6784,0.5765,0.5451)`; **43 checks**.
- Circular horizon isolated mask test: 10 m 96 radial segments / six sectors from Step 2, unchanged and passing; boundary red **0.00000 → 0.48235** with horizon at each scale, off-oval pixel **(0,0,0)**. Ring animated texture comparison still PASS.
- Beam test: real soft-OpenGL shaft blue sample **0.44314**, opaque wall cutoff **0.28235** after vs **0.44314** before. The new tip shader does not replace the beam.
- Host CPU benchmark in this run (180 samples/scene): older Stage 4 comparison median roof/ground **1069/1434 µs** (p95 **1105/1462 µs**); Stage 5B with tip **273/430 µs** (p95 **285/440 µs**). This is a **cross-stage comparison**, not isolated cost of Step 3, not GPU timing, and NOT Android FPS, frame pacing or heat evidence.
- No real Android device testing; no APK authorized.

### Residual risks reserved for Step 4
- Shared priority 127 among circular fog, beam, and new tip, with priority 126 blackout: measured Step 3 captures pass, but transparent depth ordering is **not comprehensively proved** for all yaw/pitch ranges, foreground walls, roof transitions, overlap with camera-near geometry, or HUD simultaneously.
- The original tip shader has `depth_test_disabled` as inherited; verify potential drawing over foreground occluders during Step 4 rather than blindly assuming depth correctness. Inspect all new PNG frames for texture-rectangle edges and perceptual fog motion; automated pixel success alone does not prove artistic quality.
- Confirm beam-tip position and ground interception in gameplay-specific camera pitch and movement with a broader combined camera matrix. The narrow tests already verify shared endpoint/yaw/movement and basic floor interception.
- Exact hardware Android GPU cost, thermal behavior and long-session FPS remain unknown without a separately authorized later device build.

### STAGE 5B — STEP 3 TO STEP 4 HANDOFF
- **Repository:** `LogicSolutionsPoland/Bijatyka`.
- **Branch:** `integration/bijatyka-stage5b-blackout-fog-20261109`. Inspect live HEAD before future edits; documentation commit follows the tested commit.
- **Successfully tested Step 3 implementation SHA:** `8b641fe390c2de99d1859b2ea9130496f52a807e`; production art/renderer first committed `2fb61fdc3ca284fdeb9093f16c2af7aa8843a29a`.
- **Step 1 PASS** verified run #42641061088; **Step 2 PASS** run #42649851614; **Step 3 PASS** run #42654026061. **Step 4 NOT STARTED; Step 5 NOT STARTED; Step 6 NOT STARTED**.
- Original PR #70 WebP, 0.40 opacity, moving 0.72 fog, five horizontal 13 Hz glitch slices integrated; fullscreen blackout and circular 10 m 96-segment six-sector animated Zombie Fog Horizon preserved; 3D beam preserved.
- Step 3 SUCCESS evidence [Actions #42654026061](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42654026061), [artifact #13691217850](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42654026061/artifacts/13691217850). One diagnosed test-string failure [run #42652879855](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42652879855) was corrected.
- **Step 4 objective only:** read this entire document; revalidate refs and workflow safety; create and run more comprehensive *combined* Godot 4.7.2 Mesa/Xvfb OpenGL framebuffer tests with ground, rooftop, return-from-elevator, respawn, player translation, camera yaw/pitch sweeps, beam on/off, terrain intersection, foreground wall occlusion, six-sector ring at 10 m, new tip 40% artwork, moving fog/13 Hz glitches, blackout darkness outside cone, HUD readability, three rendering scales and screen-edge/rectangle checks. Collect numeric pixel comparisons and actual screenshots with exact tested SHA; fix only evidenced Step 4 defects, then update Step 4 status in this same file. Do not preemptively start Stage 5B Step 5 or Step 6.
- **Safety:** Stage 5B branch ONLY; never merge PR #68/#70 or main, never change original Stage 5 or source PR branches, no APK/AAB export, no releases, no force push or branch deletion, do not weaken blackout/horizon regression tests. No Android build without new explicit authorization.


## N. Stage 5B / Step 4 — combined real-rendering verification (PASS, 2026-11-09)

**Previous completed:** Step 3 PASS. **Current completed:** Step 4 PASS. **Next:** Step 5 NOT STARTED. Step 6 NOT STARTED.

### Exact Git checkpoints and safety
- Repository: `LogicSolutionsPoland/Bijatyka`. Dedicated branch: `integration/bijatyka-stage5b-blackout-fog-20261109`.
- Step 4 initial HEAD: `cea024938e8dbe1a89bfd43b5aef438fe6fd582b` (Step 3 document checkpoint).
- **Last fully tested Step 4 implementation SHA: `64893ab496ec6cc28f0ad4287cf0697c1ce30a34`**. This documentation update is a later docs-only checkpoint; do not confuse new docs HEAD with tested code.
- Exact protected refs re-verified before this update: `main` = `ac12a215d95ce85d982f68b469aea99e75542883`; original Stage 5 = `b052aaf876f5cb141547494b62b8c2fdb473e6c4`; source PR #68 = `63ea5a80c007bdedddbd7da41d2d62cdf1e9f6d4`; source PR #70 = `65ec3780a6c1d3035494316170ea41db04481ae7`.
- No APK/AAB exports, releases, main merges, force pushes, source-PR changes or modifications to APK-capable workflows. The Step 4 test step was added ONLY to the existing NO-APK Stage5/5B workflow.

### Tested implementation and diagnostic history
1. `8bdd2b5619c42ec027ba7f35dcd665e4bf0423b5` — added `game/tests/stage5b_combined_render_probe.gd` plus the safe Mesa/Xvfb real OpenGL CI gate. [Run #42656387916](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42656387916) diagnosed a GDScript test-only inferred type error.
2. `a11256a52597e170abb4ceceb42e71d438f82277` — explicitly typed camera inputs. [Run #42656901513](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42656901513) **revealed a genuine depth bug**: the inherited `depth_test_disabled` tip shader drew over a foreground opaque wall; ON/OFF maximum Euclidean RGB delta **0.471078**. Some separate failure assertions were caused by freezing the Foundation process without manually following player position in the test fixture.
3. `819c43bfb5d2da5ebbad30c6081537ec7fc7694d` — removed only `depth_test_disabled` from `game/shaders/flashlight_tip_silhouettes.gdshader`, preserving unshaded transparent blending, priority 127, original 40% artwork, 0.72 fog, moving five glitch slices and 13-Hz nominal shader formula. Corrected test fixture ring-follow. [Run #42657700543](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42657700543) proved **0.0** wall A/B delta but identified another production issue: distance culling reactivated tip on roof (`mask:false`, `horizon:false`, `tip:true`).
4. `e6a7c7c55d3b21c7ff21c2692113c910675077dd` — grouped tip MeshInstance3D with the already independently managed `flashlight_beam` render objects so cached distance visibility cannot override roof-mode hiding; added smooth alpha feather to texture quad border (fix visibly rectangular fog tip). Added an alpha-border A/B check. [Run #42658573715](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42658573715) passed legacy gates and 58/59 new checks, including depth and roof. The one failing assertion was a test setup sampling the tip when it was *properly* depth occluded by actual geometry.
5. `64893ab496ec6cc28f0ad4287cf0697c1ce30a34` — test-only correction: edge A/B captures use a temporarily unobstructed short-range artwork sample with actual mask/ring/beam still running; restore all map, tower, player geometry and the normal 10 m tip before wall A/B. No production shader changes in this last commit. **Final PASS**.

### Final real-rendering CI
- **[GitHub Actions #42659365244](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42659365244): SUCCESS** for exact tested SHA `64893ab496ec6cc28f0ad4287cf0697c1ce30a34`. Godot 4.7.2 resource import/parser PASS; **20/20** Stage 5 regression suites (`STAGE5_FAILED_SUITES=0`); playable-scene **600-frame smoke** PASS; real Mesa/OpenGL flashlight beam **7 checks** PASS; fullscreen blackout **43 framebuffer checks** PASS; original source tip **22 unit checks** PASS; all six zombie-horizon texture sectors and fog temporal animation framebuffer PASS; real PR70 tip **21 framebuffer checks** PASS; **NEW combined Step 4 matrix 59/59 checks PASS**; paired host-only CPU visibility benchmark PASS.
- **[NO-APK QA evidence artifact #13692569684](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42659365244/artifacts/13692569684)** (`bijatyka-stage5-no-apk-qa-logs`, 8,322,680 zipped bytes). Contains `step4-combined-gl.log`, **20 actual Step4 PNG images** (3 render scales × 3 camera yaw/pitch combinations; roof before/after; ground return; player translation; downward floor intersection; HUD on/off; opaque wall tip on/off; tip quad border on/off), plus all original blackout/horizon/tip captures, logs and host benchmark evidence.
- Combined ground matrix: scales **1.00, 0.67, 0.40**; camera yaw **-0.38, 0.0, +0.38 rad** and pitch **-0.14, -0.06, +0.05 rad**. With blackout, circular horizon, beam and artwork all active, **two tested off-beam screen-edge pixels are black with max RGB 0.0 at every scale/pose**. This is measured at those points, not exhaustive proof that every world pixel at every angle is black.
- Foreground wall **visible green `0.282353`**; tip artwork ON/OFF through-wall max RGB delta **`0.0`**, down from the genuine original **`0.471078`**. Shader has ordinary depth testing again and does not paint through that wall.
- Tip artwork ON/OFF in unoccluded border A/B: **center max RGB delta `0.414371`** (art remains visible), while the greatest sampled rectangle-border delta is only **`0.0039216`** (no visually hard quad border). These are RGB image differences, *not* opacity percentages.
- HUD on/off max Euclidean RGB difference **`1.630873`**, boss marker visible. Initial roof now has **`on_roof:true, mask:false, horizon:false, tip:false`**, preserved panorama; return to ground restores effects. Player movement repositions fog and beam, downward projection remains above ground, with separate actual screenshots.
- Original priority-126 fullscreen blackout, ring 10 m / 96 segments / six sectors, original PR70 WebP, 40% silhouette opacity, 0.72 fog, nominal five/13-Hz glitch formula, priority-127 fog/beam/tip, and Stage 5 gameplay/CPU optimizations are retained. We did **not** replace blackout with a vignette or black sky.

### Honest limits and Step 4 -> Step 5 handoff
- Mesa/Xvfb/Linux software OpenGL captures are **not Android device FPS, GPU timing, battery, heat, performance or stability**. Timing of apparent 13-Hz glitches remains source-formula-verified rather than high-speed visual instrument measured.
- Combined visual test directly switched actual rooftop/ground render profiles, moved player and camera, tested floor, wall and HUD. It did **not capture a full physically ridden elevator or animated respawn sequence in the real framebuffer**; existing elevator/gameplay *headless* suites remain PASS. More extreme angle/sorting cases and real Android performance remain unverified and should not be claimed complete.
- **Step 5 instruction:** Read the entire state file, inspect current HEAD and workflow safety, start **Stage 5B / Step 5 — complete gameplay regression plus paired host CPU/render profiling** only. Keep the all-green Step4 59-check combined GL gate, previous 20 suites, blackout 43 checks, ring, beam, tip and screenshot evidence. Diagnose newly found failures before modifying the game. Do not start Step6, make APK/AAB, merge into main, or edit source PR #68/#70. Explicitly separate host-software results from hardware Android measurements.

## O. Stage 5B / Step 5 — gameplay regression, combined rendering and paired host profiling (PASS CI, 2026-11-09)

**Previous completed stage:** Step 4 PASS. **Current completed stage:** Step 5 PASS for the automated, host-based verification scope. **Next stage:** Step 6 NOT STARTED. This PASS does **not** certify Android hardware FPS, GPU cost, frame pacing, thermals or real-device usability.

### Live branch and exact immutable evidence
- Repository: `LogicSolutionsPoland/Bijatyka`; working branch: `integration/bijatyka-stage5b-blackout-fog-20261109`.
- Initial Step 5 HEAD: `e745c48f2615bfb940aa354bd5f9310a15189fe8` (Step 4 documentation-only descendant); last fully tested Step 4 implementation: `64893ab496ec6cc28f0ad4287cf0697c1ce30a34`.
- **Exact fully tested Step 5 implementation/test SHA: `2cd5329f28f640b7e03d13bc3dd5bd88fa48e098`.**
- **[GitHub Actions run #42667212473](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42667212473): COMPLETED / SUCCESS** (2026-11-09); the run's `head_sha` is exactly `2cd5329f28f640b7e03d13bc3dd5bd88fa48e098`.
- **[QA-only artifact #13699241582](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42667212473/artifacts/13699241582): `bijatyka-stage5-no-apk-qa-logs`**, 11,616,935 bytes; not expired at review. Includes test logs, real software OpenGL screenshots, and `build/stage5/step5-performance-samples.json` and `build/stage5/step5-performance-comparison.csv`.
- The documentation-only commit adding this Step 5 record is a **later branch HEAD**; do not mistake it for a newly tested code SHA. Inspect the LIVE branch HEAD at Step 6 start.
- Protected refs checked immediately before this state update: `main` = `ac12a215d95ce85d982f68b469aea99e75542883`; original Stage 5 = `b052aaf876f5cb141547494b62b8c2fdb473e6c4`; PR #68 source = `63ea5a80c007bdedddbd7da41d2d62cdf1e9f6d4`; PR #70 source = `65ec3780a6c1d3035494316170ea41db04481ae7`. None was targeted by the Step 5 writes.

### Step 5 changes (tests and safe workflow ONLY)
- Added `game/tests/stage5b_step5_transition_probe.gd`: actual Foundation/elevator interaction, accelerated elevator endpoint to bound automated test duration, actual imported Exo/zombie combat-grab reach and admission, player camera/movement, respawn callback, ground/roof rendering transitions, and extra forced ground-profile capture. These test accelerations/forced profiles are **not proof of a fully timed, physically ridden production elevator and respawn sequence**.
- Added `game/tests/stage5b_step5_host_benchmark.gd`: paired Step 4 vs Step 5 workload script with 11 scenarios (roof/ground idle, moving/aiming, profile switches, combat and director with up to 20 enemies, combined mask/ring/tip effects and A/B toggles); 2 repeats per scenario, warmup and sampled frames.
- Extended **only** `.github/workflows/bijatyka-stage5-integration-validation.yml` (explicitly NO APK) to collect the new Mesa transition captures, paired baseline/candidate host and software GL samples at scales 1.00/0.67/0.40, and headless scale 0.40, storing logs/screenshots/JSON/CSV as a QA artifact. Baseline compared against exact Step 4 code SHA `64893ab...`; test runner copied identically into baseline and candidate checkouts.
- **No production gameplay, shader, art asset or rendering-source changes during Step 5**. Fullscreen ground blackout (priority 126), 10 m six-sector/96-segment fog horizon, 3D flashlight shaft, original PR #70 40% tip art and feathered depth-correct overlay, roof profile, HUD, combat, elevator, cached visibility and cap of 20 enemies were preserved.
- Earlier diagnostic CI runs #42664373215, #42665541433, #42666692522 failed in the newly added transition fixture (position/IK reach or test-call error), not established gameplay/blackout gates. Test-only corrections culminated in `2cd5329...`; final #42667212473 passed all gates. Do not substitute these failed runs for the successful exact-SHA evidence.

### Final workflow gates verified as SUCCESS
1. Godot 4.7.2 resource import and script parsing completed. Existing duplicate animation-name import diagnostics appeared in logs; do not characterize these as wholly warning-free.
2. **20/20** established Stage 5 gameplay, animation, controls, AI, enemy, physics, combat, elevator, camera, optimization and visual suites: **PASS**.
3. **600-frame** playable scene smoke run: **PASS**.
4. Real Mesa/Xvfb OpenGL volumetric flashlight shaft, wall occlusion and rooftop tests: **PASS**.
5. Real fullscreen ground blackout **43 checks** and rooftop preservation: **PASS**, also in the prior verified scales/captures. No mask removal, vignette or black-sky substitution.
6. Circular animated six-sector fog horizon tests and 22-check tip source regression: **PASS**; original tip real-frame render probe **21 checks PASS**.
7. Existing Step 4 combined real-frame matrix **59/59 checks PASS** (yaw/pitch, scales, off-beam darkness, occlusion, roof, tip alpha edge, HUD): maintained, not weakened.
8. New Step 5 real transition/grab/respawn **32 checks PASS**. Fixture log `STEP5_TRANSITION_SCOPE actual_elevator_interact=YES endpoint_accelerated=YES grab=YES respawn_callback=YES final_profile_forced=YES`. Actual reach admission `acquired=true, begun=true, reachable=true, reserved=true`; 9 named Step 5 PNG captures archived.
9. Paired older visibility CPU benchmark and **new Step 5 paired Step 4 vs Step 5 host/software OpenGL benchmark PASSED**, yielding `STEP5_PROFILE_WINDOWS 176` and structured JSON+CSV. Coverage: Mesa software GL scales 1.00 / 0.67 / 0.40, plus headless 0.40 for both code versions. This confirms **execution and collection**, not a quantified performance non-regression verdict: detailed per-scenario comparative statistics have **not** been independently audited in this state update.
10. Artifact `bijatyka-stage5-no-apk-qa-logs` uploaded successfully. GitHub workflow/job overall **SUCCESS**. No APK/AAB build/export, release, merge, force push, branch deletion or Android export workflow change.

### Limitations, next stage handoff
- The automated checks run on GitHub-hosted Linux software Mesa OpenGL and headless Godot. They do **not** measure actual Android ARM64 GPU time, FPS, temperature, thermal throttling, touch/gamepad ergonomics, or long-session stability. Do not report them as mobile-device certification.
- Host runner noise and difference between software OpenGL and mobile GPU mean `176` recorded measurement windows alone cannot establish whether every scenario improved; inspect JSON/CSV before making any quantitative CPU/non-regression claim.
- Step 5 render transition probe accelerates elevator completion and forces one final profile, and invokes the respawn callback; actual full-duration real-device elevator transitions remain pending future authorized validation.
- **Step 6 starting instructions:** Read this entire persistent document; verify live branch refs/HEAD vs exact tested Step 5 SHA, check NO-APK workflow safety, inspect run #42667212473 and artifact #13699241582 (including comparative benchmark JSON/CSV and captures); decide and execute **only the separately scoped Step 6 task** after the user supplies/authorizes it. Preserve the complete working feature set and full-screen blackout. No APK/AAB, merge to `main`, source-PR modification or release merely by moving to Step 6.
