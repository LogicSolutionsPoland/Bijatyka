# Burning horizon prototype

Based on `codex/zombie-horde-30m` at `7a6ab5868baf611dbf61f8ffa3414975be09dac7`.
Open `game/project.godot` in Godot 4.7.2 and run the main scene. The effect is enabled by default.

The original prototype used four 40 m wide, 6 m tall quads with a 20 m side offset, giving square corners about 28.29 m from the player. The current ground-level Zombie Horizon replaces that square with a circular fog wall whose radius is shared with `FlashlightVisibilityManager.MAX_RADIUS`: **10 m**. Its 96-sided open cylinder follows player position and elevation but never camera rotation. It is decorative scenery, not a gameplay wall, and is shown only by the ground-floor render profile. The rooftop city panorama and sky shader remain separate.

The circular mesh uses four compressed 1024 × 576 WebP source images across six equal arc sectors in the sequence 1, 2, 3, 4, 3, 2. At a 10 m radius, each sector covers about 10.47 m of arc and is 6 m tall, close to the source images' 16:9 proportions. The mesh has no caps, colliders, shadows, lights, particles, or physics work. Android GPU cost has not been measured.

The backdrop subtree is exempt from distance culling. The flashlight's maximum range is also 10 m, so the forward-facing fog horizon meets the beam at its range limit; the flashlight remains directional, and the horizon's circular placement does not light the area behind the player. Gameplay zombie visibility, spawning, and the boss locator remain separate. Floor color fades to the backdrop haze between 24 and 30 m. Sky below the horizon covers the space between the circular floor boundary and the panorama. Following player elevation is intentional for aerial dash coverage.

On the 20 m starting and respawn rooftop, the supplied burning-city photograph is a direction-fixed panoramic sky behind the arena. Its visible streets and zombie crowd remain part of the static photograph; they do not add simulated enemies to the gameplay horde. The rooftop camera rises and widens to clear the tower parapet and frame the city crowd. The zombie-fog horizon and close combat camera return on the ground floor. The flashlight retains its normal world geometry mask; sky pixels reveal the panorama on the rooftop and return to black at ground level. The photograph adds one 1536 × 768 JPEG (~380 KB) and no collision or light sources.

Validation for the original procedural prototype:

- Godot 4.7.2 asset import completed without script/load errors.
- Existing gameplay suite: 453 checks pass.
- `res://tests/burning_horizon_test.gd`: integration passes, including culling exemption, dimensions, shadows, collision absence, translation/elevation and camera rotation.
- Dedicated workflow repeats tests and runs the actual Compatibility renderer using software OpenGL to compile shaders.
- Physical Android appearance and performance still require device validation.

Those historical checks do not cover the 5 November 2026 image-based circular horizon or its 10 m radius update. The current validation is recorded below. No Android device check or APK build was performed.

Manual check: walk and turn through 360 degrees, approach world boundaries, jump, use an airborne dash, look up/down, and return to base. Confirm scenery stays present, the horde crosses the horizon unobstructed, and the boss marker stays usable. No APK or release is produced by this feature workflow.

## Rooftop lower hemisphere (28 October 2026)

The 1536x768 burning-city photograph is the **bottom of the starting-tower skybox**, not a complete sphere. The image's skyline (roughly 45% of the picture height) is aligned with the sky horizon; the photo's fiery clouds occupy the lower part of the upper view and its zombie crowds occupy the downward view. The original procedural cloud sky fills higher elevations, with a soft transition from about 34° to 45° above the horizon. The panorama remains camera-direction-fixed, has no physics or simulated zombie instances, and does not change the foreground arena.

On the roof, the flashlight shader now leaves sky pixels untouched, so the environment renders one consistent sky (rather than sampling the image again at a conflicting projection). At ground level, the Burning Horizon and black flashlight sky remain. The rooftop-to-ground and respawn checks continue to cover this switch. A single 2:1 concept painting is not a true seamless 360° equirectangular photograph; its side join should be inspected on a physical phone.

## Moving zombie-fog horizon (5 November 2026)

The ground-floor horizon uses the four generated fog images as six equal sectors around the player: image 1, 2, 3, 4, 3, then 2. A subtle animated fog warp keeps the silhouettes from looking like a static strip. The open circular mesh has a 10 m radius sourced directly from the flashlight visibility manager's 10 m maximum, so the horizon sits at the flashlight's distance boundary around the player. It follows player position including elevation and remains independent of camera yaw. It is shown only by the ground-floor render profile.

The flashlight remains a forward-facing 3D cone with a 10 m maximum. Its existing mask and enemy-reveal rules are unchanged. The rooftop city panorama and rooftop visibility behavior are unchanged. Geometry remains a single open mesh without collision, shadows, lights, particles, or physics work.

The ground-floor blackout renders at transparent priority 126. The fog material
renders at priority 127 so its artwork remains visible at the 10 m edge after
the flashlight's range has faded to black. This changes only the decorative
backdrop's draw order; it does not extend illumination or reveal enemies.

## Verification of the 10 m circular horizon (5 November 2026)

Godot 4.7.2 software Compatibility validation ran on PR #68 commit
`8f928e736f22c47e77638a8a390b61d5f51ee0f1` in the existing
`tower-lower-skybox-validation.yml` workflow,
[run 42013011213](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42013011213).
It passed the project import, the horizon, flashlight visibility and whole-enemy
reveal, environment, elevator, and 207-check gameplay suites. It also passed
the rendered six-sector fog/alpha/motion probe, rooftop and ground flashlight
mask pixels, beam volume, and environment render probe. The ring's shortest
radial distance between vertices is `10 cos(π/96) ≈ 9.994646 m`; the test
compares the mesh and this midpoint against the shared 10 m flashlight maximum.

The first isolated renderer probe passed on
[run 42012120785](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42012120785),
but an added full-mask pixel check exposed a real defect on
[run 42012772540](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/42012772540):
the blackout covered the horizon completely (red channel 0.0 with and
without the fog). After moving only the fog to priority 127, the same
Compatibility probe read 0.0 with the horizon hidden and 0.482 with it shown.

The import emitted the pre-existing eight duplicate imported animation-name
diagnostics (Idle, Jump, Sprint and Walk in two models); no script or resource
load failure occurred. These desktop software-rendered checks do not measure
Android appearance, frame time, heat, or the panorama's physical-phone seam.
No APK was built.
