# Test results

Local checks with Godot 4.7.2 stable (`ed1daf0bf`): project import and existing headless gameplay, animation, effect-pool, spawn, rig-budget, Burning Horizon, environment-material, and horde benchmark checks passed. The new flashlight camera suite passed 41 checks, including 4:3, 16:9, and ultrawide framing; touch and gamepad camera aim; jump and dash stability; 180-degree sector math; 22–30 m falloff; outside-sector classification; compacted MultiMesh visibility; and confirmation that flashlight rotation does not teleport or disable physics on hidden zombies.

The required headless population matrix ran all eight concentrated and 50 m approach scenarios at 20, 69, 100, and 200 zombies. It reported CPU/physics/memory/rig metrics; FPS, draw calls, and rendered-object counts are N/A in headless mode.

The pixel-level GL Compatibility software-render test is included in CI. It samples an unshaded object inside and outside the half-disk and checks the HUD and boss marker. It could not be run in the local container because no X server/Xvfb is available; the GitHub Actions result is pending. Android package validation and physical device testing are pending.

## Device checks

Android ARM64 package integrity and content checks are run by the existing export workflow. Physical installation, phone display composition, sustained FPS, GPU time, heat, and battery are reported only if measured on hardware.
