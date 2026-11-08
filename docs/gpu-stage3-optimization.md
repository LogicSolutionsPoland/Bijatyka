# Bijatyka GPU stage 3 — beam, Pencil Sketch and lighting

Branch: `feat/gpu-stage3-light-pencil-20261101`; base is the head of PR #56.

## Audit findings and changes

1. **3D flashlight beam**: three separately rendered crossing transparent
   `MeshInstance3D` sheets used the same quad, material and vertex shader.
   They are now three `MultiMesh` instances in **one draw object**, leaving
   the shared section mesh, 30 m range, 25° cone, source colour, opacity,
   shader-driven expansion, render priority and depth testing unchanged.
   The conservative custom AABB includes the entire expanded 30 m cone.
   This reduces the three sheet submissions to one (four beam geometry
   objects to two, including the already-batched cross-sections).

2. **Pencil screen pass**: the Compatibility shader now skips depth and
   normal reconstruction when the existing graphite fade is exactly zero.
   It also skips crease reconstruction where the already-solid silhouette
   makes `max(silhouette, crease)` identical regardless of the crease value.
   Paper fibres, grain, line colour, wobble, fade distances and all shader
   uniform defaults remain intact; the existing rooftop toggle still
   disables Pencil Sketch. This is a safe conditional reduction, **not**
   a new lower-quality preset or a change to the game's sketch style.

3. **Map lighting / distance culling**: the existing 120 ms visibility
   scan now avoids assigning `visible` to lights and static meshes when
   their state is unchanged. Distances, light energy/colour/range, no-shadow
   policy, 40% Android render scale and profiling A/B light toggle are unchanged.
   Mobile continues to start with local OmniLights disabled.

## Verification
The `gpu_stage3_test.gd` validates beam batch and geometry, original
shader parameters, roof/ground toggling, retained Pencil shader selection
and invariants, plus local light visibility. Existing zombie, spawn,
rig-budget and elevator CI regressions remain mandatory.

GitHub headless testing **does not measure physical GPU frame time, phone
temperature or visual equivalence**. Measure render draw calls and 10-minute
combat FPS on the final Android APK, and compare screenshots of beam,
Pencil and local light cases before merging to the release branch.

No APK exported at this stage. `main` remains untouched.

## Additional full-scene smoke validation
The dedicated `full_gameplay_smoke_test.gd` creates the real Foundation scene,
asserts player/boss/4 rooftop records, checks the shared 3D flashlight and
Pencil screen mask are OFF on the roof, ON after switching to ground profile,
and OFF again after restoring the roof. Merely switching camera graphics
must not start the downstairs 30-zombie wave. It runs in GitHub CI.
This does not replace on-device image/FPS tests.
