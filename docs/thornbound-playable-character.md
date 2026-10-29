# Thornbound playable character

## Asset provenance

The supplied files were six Meshy viewer screenshots and a colored front/rear concept image. No downloadable Meshy mesh or editable Meshy project was included. The character geometry is an original procedural build shaped from those visual references; the screenshots were not used as mesh data. The existing Bijatyka 21-bone player rig and its `Idle`, `Walk`, `Sprint`, `Jump`, and `Sword_Slash` animations were retained. A pristine copy of that source rig is kept at `art/characters/thornbound/source/Thornbound_21Bone_Animation_Rig.glb` so the art build remains repeatable.

## Deliverables

- Runtime model: `game/assets/characters/thornbound/Retribution_Player_Thornbound_Warrior_MOBILE.glb`
- Editable Blender scene: `art/characters/thornbound/Thornbound_ConceptWarrior.blend`
- Procedural authoring scripts: `tools/build_thornbound_character.py` and `tools/generate_thornbound_textures.py`
- PBR textures: `art/characters/thornbound/textures/procedural/`
- Runtime action clips: `game/scripts/character_motion.gd`

The model has 68,562 triangles across ten skinned material meshes. Face planes, eyes, scars, hair locks, layered armor, straps, wrapped hands and legs, boots, sword, thorn halo, and the torn double-sided cloak are modeled geometry. The nine textured materials use 512 px maps, with 1024 px maps for skin, hair, and linen. The cloak uses one lightweight rig bone; there is no cloth simulation. Sword and halo geometry follow their existing named rig bones.

The original animation clips stay intact. The runtime adds left/right punch and kick clips with contact markers aligned to the existing hit windows, plus dash, landing, turning, four magic actions, hit reaction, and defeat clips. Existing mobile touch and gamepad actions remain in place, including L1/R1 punches and L2/R2 kicks. Ordinary zombies remain capped at five with the existing replacement flow.

## Rebuild

With Blender 4.2.3 and Python 3, NumPy, and Pillow available from the repository root:

```sh
python3 tools/generate_thornbound_textures.py
blender --background --python tools/build_thornbound_character.py
```

The build script imports the preserved rig source and writes the editable `.blend` and runtime `.glb` to the paths above. Godot imports the embedded GLB textures for Android.

## Verification

The local Godot 4.7.2 checks passed: 468 foundation gameplay and controls checks, 38 martial animation and hit-timing checks, and 33 character quality checks. The quality test reports five active zombies, 21 bones, ten skinned meshes, 68,562 triangles, and all ten added action clips. The scene also completed a 240-frame headless desktop smoke run. The PR validation workflow captures front, rear, movement, punch, and kick screenshots under Xvfb and uploads them as a workflow artifact. The Android ARM64 workflow exports and inspects the packaged APK on push to this branch.

No physical Android device was connected for this build, so there is no device FPS measurement. The headless scene smoke is not a mobile rendering benchmark.
