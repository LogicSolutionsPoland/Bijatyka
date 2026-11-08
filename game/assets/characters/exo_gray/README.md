# Exo Gray mobile player visual

The player loads `Exo_Gray_Player.glb` from this directory.

The binary is **not in the repository yet**. The finished 6 MB GLB is supplied in the ChatGPT downloadable Exo Gray integration ZIP, which must be unpacked into the branch before enabling the final visual and running Android CI.

The GLB was derived from the uploaded `Exo Gray.fbx`:
- 8 skinned meshes, 112 Mixamo bones, about 31.7k triangles.
- Existing embedded textures compressed to the mobile version.
- `mixamorig:` bone-name prefixes stripped for Godot Skeleton3D compatibility.
- One unused short root-translation take removed.
- Retains centimeter-to-meter root transform already present in the source.
- GLB is **not** an animated replacement for the gameplay rig; the player controller keeps the existing Universal Base 65-bone rig driving its animation, combat and physics.

This GLB must be reviewed for use rights inherited from the original uploaded FBX.

Do not merge/release this branch until the GLB is committed and the player visual and combat tests run inside Godot and on Android.
