# Test results

Local checks with Godot 4.7.2 stable (`ed1daf0bf`): project import and existing headless gameplay, animation, effect-pool, spawn, rig-budget, Burning Horizon, environment-material, and horde benchmark checks passed. The new flashlight camera suite passed 41 checks, including 4:3, 16:9, and ultrawide framing; touch and gamepad camera aim; jump and dash stability; 180-degree sector math; 22–30 m falloff; outside-sector classification; compacted MultiMesh visibility; and confirmation that flashlight rotation does not teleport or disable physics on hidden zombies.

The required headless population matrix ran all eight concentrated and 50 m approach scenarios at 20, 69, 100, and 200 zombies. It reported CPU/physics/memory/rig metrics; FPS, draw calls, and rendered-object counts are N/A in headless mode.

The pixel-level GL Compatibility probe passed in GitHub Actions run [#21](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/40207977832) on commit `edd74d7554017d8657a36a4ab4249924dec0bc2f`. On Ubuntu Mesa/llvmpipe, it sampled an in-sector red value `(1.0, 0.0353, 0.0078)`, an out-of-sector black value `(0.0, 0.0, 0.0)`, and a readable player sample `(0.5647, 0.5059, 0.4588)`. The HUD, boss marker, environment shader probe, shader compile, and 600-frame scene smoke also passed. An earlier run exposed the OpenGL depth-range mismatch; the renderer-specific NDC conversion fixed it. This software-render test does not measure Android GPU performance. Android package validation and physical device testing are pending.

## Device checks

Android ARM64 package integrity and content checks are run by the existing export workflow. Physical installation, phone display composition, sustained FPS, GPU time, heat, and battery are reported only if measured on hardware.
