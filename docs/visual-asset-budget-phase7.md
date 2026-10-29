# Phase 7: visual environment and lore asset budget

## Inspected scene and scope

The Godot 4.7.2 Compatibility arena has a 220 m collision floor with a 30 m radial visual edge, one sun without shadows, two quarantine lamps and two braziers with local shadowless lights. The Burning Horizon is four 40 x 6 m translucent quads 20 m from the player, using one shared procedural shader. It follows player position and height with fixed world yaw; the camera may rotate freely. Sky smoke is procedural in the sky shader; there are no smoke particles. The ground, ruins, sky, and horizon make no texture reads. The ground has five value-noise evaluations per visible fragment, the sky has two, the horizon has one plus silhouette, window, and fire math. The ruin shader formerly evaluated nine noise projections and three crack projections per fragment, even on flat axis-aligned boxes. Most static boxes have flat axis-aligned faces. The 14 yaw-rotated rubble boxes retain full triplanar blending.

Phase 7 uses one ruin projection on axis-aligned faces (three noise evaluations and one crack projection), and keeps three projections on rotated surfaces. The original noise, colors, illumination, ground and horizon formulas are unchanged. Matching ruin and emissive material resources are reused at arena construction; local light count, ranges, energy, and visibility behavior are unchanged. This reduces shader arithmetic on qualifying prop faces and duplicate material allocations. It does not establish a device FPS gain.

Existing GLB file sizes are about 4.3 MiB for the player and 616 KiB for the zombie source; source file size is not a VRAM or triangle count. The player has a 21-bone rig. The horde has at most 20 selected ordinary full rigs, with remaining visible zombies in one low-poly MultiMesh. Those budgets are gameplay constraints, not a license to add similar detail to every lore prop.

## Guide for future lore assets

| Area | Current reference and safe direction | Measure before setting a hard cap |
| --- | --- | --- |
| Materials | Reuse the existing ruin shader and the same `ShaderMaterial` for equal color/roughness/metal values. Reserve unique materials for visibly distinct props. | Material and draw-call deltas in the 20/100/200 scenarios on a phone. |
| Textures | Current environment shaders use zero texture reads; keep new lore decals and atlases shared and mipmapped. Prefer a small atlas when many props share motifs. | Source dimensions, GPU compressed format, resident texture memory, and quality at the 18/30 m tiers. No fixed pixel size has been validated. |
| Models | Static arena geometry is mostly simple boxes, rings, cylinders; decorative rubble has 14 pieces. Keep distant silhouettes simple and reuse meshes for repeated lore signs or architecture. | Visible triangle count, draw calls, and frame time at 20/100/200 zombies before selecting per-prop triangle limits. |
| Lights | One shadowless directional light and four shadowless local lights already support combat. Place lore highlights within existing lighting where possible; keep player and target legible. | Per-light overdraw and Compatibility frame time on target phones before adding local lights. |
| Transparency | Four horizon panels are the major intentional translucent backdrop. Opaque scenery and decals should take priority over layered transparent smoke. | Pixel overdraw, alpha edge stability, and 360-degree appearance on the phone. |
| Distance tiers | 0–18 m is combat detail; 18–30 m is reduced zombie motion/detail; beyond 30 m ordinary world detail is hidden. Horizon stays visible at its 20 m square boundary and follows the player. | Prop-specific fade/cull behavior while walking, turning, jumping, and flying; avoid culling large near objects by center alone. |

## Measurement record

The same local Godot binary and Phase 2 headless benchmark were used before and after, sequentially on this runner. Average frame processing time in ms:

| Scenario | 20 before → after | 100 before → after | 200 before → after |
| --- | ---: | ---: | ---: |
| Concentrated | 8.474 → 7.618 | 9.385 → 10.335 | 17.208 → 15.436 |
| Concealed 50 m approach | 4.960 → 4.772 | 1.792 → 1.831 | 1.374 → 1.113 |

The mixed changes are normal run variation; headless runs do not execute the revised pixel shader. They cannot demonstrate a rendering speedup. The benchmark logs also report physics time, active rig counts, and memory for each scenario. Headless FPS, draw calls and rendered objects are unavailable.

The validation workflow runs a separate software-rendered desktop Compatibility probe with the 20-zombie concentrated scenario and logs `RENDERED_DESKTOP_ENVIRONMENT_SAMPLE`. It compiles the actual shaders and reports rendered frame count, process/physics time, FPS, draw calls, and object count. There is no pre-change desktop rendered baseline in this environment. Device GPU time, thermal stability, and appearance are **unmeasured** until the final phone APK build. Do not compare a headless CPU time to a rendered desktop frame or call either an Android result.
