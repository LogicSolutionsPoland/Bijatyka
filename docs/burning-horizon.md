# Burning horizon prototype

Based on `codex/zombie-horde-30m` at `7a6ab5868baf611dbf61f8ffa3414975be09dac7`.
Open `game/project.godot` in Godot 4.7.2 and run the main scene. The effect is enabled by default.

The first Burning Horizon is placed 20 m from the player: four 40 m wide, 6 m tall quads form a closed square, with corners approximately 28.29 m away. Later 5 m distance tiers through 100 m are not part of this first placement. This is decorative scenery, not a gameplay wall. It follows player position, including elevation, but never camera rotation. A smoky sky covers views above it. Ruins, window glow, fire flicker and smoke are procedural prototype art, not the detailed concept painting.

Cost: four quads / eight triangles, one shared unshaded opaque material, plus a static sky shader. No added textures, colliders, shadows, lights, particles or physics work. Shaders still have a fragment cost; no Android FPS gain is claimed without device measurement. Existing level geometry is retained.

The backdrop subtree is exempt from distance culling. Gameplay remains at 30 m visibility, with 20 ordinary zombies spawning at 50 m and the existing boss locator. Floor color fades to the backdrop haze between 24 and 30 m. Sky below the horizon covers the space between the circular floor boundary and square panorama. Following player elevation is intentional for aerial dash coverage, so the skyline behaves like an artificial skybox rather than world-anchored architecture.

On the 20 m starting and respawn rooftop, the supplied burning-city photograph is a direction-fixed panoramic sky behind the arena. Its visible streets and zombie crowd remain part of the static photograph; they do not add simulated enemies to the gameplay horde. The rooftop camera rises and widens to clear the tower parapet and frame the city crowd. The procedural four-panel Burning Horizon and close combat camera return on the ground floor. The flashlight retains its normal world geometry mask; sky pixels reveal the panorama on the rooftop and return to black at ground level. The photograph adds one 1536 × 768 JPEG (~380 KB) and no collision or light sources.

Validation:

- Godot 4.7.2 asset import completed without script/load errors.
- Existing gameplay suite: 453 checks pass.
- `res://tests/burning_horizon_test.gd`: integration passes, including culling exemption, dimensions, shadows, collision absence, translation/elevation and camera rotation.
- Dedicated workflow repeats tests and runs the actual Compatibility renderer using software OpenGL to compile shaders.
- Physical Android appearance and performance still require device validation.

Manual check: walk and turn through 360 degrees, approach world boundaries, jump, use an airborne dash, look up/down, and return to base. Confirm scenery stays present, the horde crosses the horizon unobstructed, and the boss marker stays usable. No APK or release is produced by this feature workflow.

## Rooftop lower hemisphere (28 October 2026)

The 1536x768 burning-city photograph is the **bottom of the starting-tower skybox**, not a complete sphere. The image's skyline (roughly 45% of the picture height) is aligned with the sky horizon; the photo's fiery clouds occupy the lower part of the upper view and its zombie crowds occupy the downward view. The original procedural cloud sky fills higher elevations, with a soft transition from about 34° to 45° above the horizon. The panorama remains camera-direction-fixed, has no physics or simulated zombie instances, and does not change the foreground arena.

On the roof, the flashlight shader now leaves sky pixels untouched, so the environment renders one consistent sky (rather than sampling the image again at a conflicting projection). At ground level, the original Burning Horizon and black flashlight sky remain. The rooftop-to-ground and respawn checks continue to cover this switch. A single 2:1 concept painting is not a true seamless 360° equirectangular photograph; its side join should be inspected on a physical phone.
