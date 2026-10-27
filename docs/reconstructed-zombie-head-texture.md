# Reconstructed zombie head texture — experimental

Branch based on codex/enemy-attack-animation-fix-20261027.

Ordinary enemy meshes and skeletons stay **Universal_Base_Characters_Male.glb**;
the boss stays **Universal_Base_Characters_Female.glb**. Nothing changes enemy
counts, gameplay, AI, animation, damage, controls, camera or flashlight.

The original **Retribution_Zombie_Reconstructed.glb** asset is reused from the
earlier model-assets integration branch. The new helper reads the reconstructed
head's front/back embedded *albedo* textures. A head-bone-weight masked,
face-aligned projection shader draws them over the existing animated male mesh.
It does NOT swap the geometry. It caches materials to avoid generating them for
every zombie. If the source head has no image or no head bone data, the model
stays unmodified and emits a warning.

**Important:** because source/target UV maps and proportions differ, this is a
visual experiment. A perfect anatomical transfer needs texture rebaking against
the male head UVs. Test on Android with the pencil-sketch filter and flashlight
enabled to check seams, orientation and performance before deciding to ship.

Manual headless check (requires Godot 4.7.2 and imported assets):

  godot --headless --editor --path game --quit
  godot --headless --path game --script res://tests/reconstructed_head_texture_test.gd

No APK was built or device-tested as part of this change.
