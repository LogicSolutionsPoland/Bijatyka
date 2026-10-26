# Pencil drawn 3D style

## What appears in the game

The default autoload converts opaque, lit character and prop materials to a
warm paper and dark graphite palette. Player and zombie textures still inform
shading, but the original saturated diffuse colors no longer dominate the
scene. Broad diagonal pencil lines cross in deep shadows. Strokes use screen
pixels rather than tiny model UV islands so they remain visible at the default
Android 0.50x 3D render scale. The two-sided variant covers torn cloth.

The ground, ruin shader, and far-zombie crowd shader share the paper and lead
values. Existing soot, grit, wear, and fractures become changes in graphite
density. The flashlight's existing full-screen pass samples four nearby depth
values inside the lit area to draw silhouettes and contact edges without a
second pass or duplicate geometry. Darkness beyond the forward sector remains
black. Emissive fire, magic, combat feedback, and HUD retain color and
readability.

## Validation

Godot 4.7.2 imports and the material integration test check the player and
zombie skeletons, textures, and pencil material assignment. The performance
workflow compiles the Compatibility shaders, captures five actual scene views,
and checks flashlight visibility. The Android export checks for one ARM64 APK
at version 0.1.4-pencil-drawn. The preceding 0.1.3 shader was too subtle:
near-black map colors swallowed its marks, and dense UV hatching disappeared
when scaled for a phone. This revision addresses both causes.

The extra depth samples do cost fragment work inside the flashlight sector.
CI software rendering cannot establish Android frame rate, heat, or battery
impact; those need a physical device test. Geometry and map detail are still
the existing models and procedural ruins, and transparent/emissive surfaces
retain their authored materials.
