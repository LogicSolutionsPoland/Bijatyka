# Flashlight visibility implementation

The default mode is configured by `gameplay/flashlight_visibility_enabled` in `game/project.godot`. Set it to `false` to restore the prior dusk sky, ambient tint, fog, horizon glow, radial-only zombie rendering, and disable the flashlight screen mask.

The enabled mode uses a single Compatibility spatial shader on a camera-local full-screen quad. It reconstructs the opaque depth sample with `INV_PROJECTION_MATRIX` and `INV_VIEW_MATRIX`, using the renderer-appropriate NDC depth conversion for GL Compatibility, computes the world-space ground offset from the player, and darkens pixels outside the forward half-disk. The 180-degree plane edge is softened over 0.44 m to avoid shimmer; radius is 30 m, with a smooth 22–30 m fade. A 2.1 m player keep radius preserves the third-person character at the camera edge. HUD and touch controls remain in CanvasLayers above the 3D pass, including the red boss locator.

The environment switches to black background, neutral white ambient and key light, no fog, and no glow while the mode is enabled. The existing Burning Horizon node, geometry, shaders, and follow behavior remain present; its distant pixels fall outside the 30 m lit disk and are masked by the same shader. Turning the configuration option off restores the former environment setup.

`FlashlightVisibilityManager` tracks ordinary enemies registered by the existing horde owner. It classifies them every 120 ms using squared distance, a dot product against the camera aim direction, a separate camera-frustum check, and 0.65 m sector hysteresis. The high-frequency shader uniform update follows camera yaw each frame. Only visible actors are eligible for the shared silhouette MultiMesh and detailed-rig scheduler. Gameplay AI, collisions, health, attacks, and replacement remain active in darkness.

## Camera

The existing 4.1 m follow distance, raised 1.55 m pivot, 66-degree perspective, pitch range, spring-arm collision, touch drag, and right-stick control are retained. The shoulder offset is derived from the viewport's horizontal field of view to keep the player near 38% screen width across landscape ratios; the player remains at the existing base position in world space.

## Measurement limits

Headless timing is CPU and scene-processing data only. The Compatibility software-rendered probe checks shader compilation and mask pixels on desktop Mesa; it does not establish Android frame rate, sustained GPU cost, thermal behavior, battery use, or phone-specific appearance.
