# KayKit Character Animations 1.1 — source assets

Publisher: Kay Lousberg / KayKit  
Official page: https://kaylousberg.itch.io/kaykit-character-animations  
License: **CC0 1.0** (see `License.txt`). Attribution is optional.

This directory contains the **free** KayKit Character Animations 1.1 pack
supplied for Bijatyka. The 33 animation/model/texture files total
42,940,665 bytes (before Git compression), split into `Animations/fbx/`,
`Animations/gltf/`, and `Mannequin Character/`.

## Import policy

- This is a **source-only asset drop**, deliberately stored outside `game/`.
  Existing gameplay, performance, combat clips, mobile controls, rig budgets
  and Android export are unchanged.
- Godot 4.7.2 should preferentially consume selected `.glb` files from
  `Animations/gltf/Rig_Medium/` or `Rig_Large/`, after skeleton compatibility,
  retargeting, animation names, orientation, root motion and hit timing
  have been tested.
- `.fbx` files are retained as exchange/reference sources. Do not copy both
  format variants into the runtime asset directory without a concrete need.
- Never attach one animation player or fully animated skeleton per zombie in a
  200-zombie scene. Reuse the current detailed-rig cap, tiers, pooled visuals
  and performance tests.
- The mannequin files are rigging references, **not** final player/zombie models.
- No `.blend` source/extra-tier content and no marketing `.url` shortcuts from
  third-party sources are included.
- A later gameplay change must explicitly choose relevant animations, retarget
  them if required, and validate timing/Android performance before use.

## Reproducibility

`manifest.json` records the paths, lengths and *Git blob SHA-1* checksums of
the exact binary files in the supplied `KayKit_Character_Animations_1.1.zip`.
It also records the uploaded ZIP's SHA-256 and a pinned public GitHub mirror
revision. The importer verifies **every file before writing**:

```bash
python3 tools/import_kaykit_1_1.py
```

The GitHub Actions workflow that performed the initial import is intentionally
a one-shot setup workflow; normal development and APK builds do not run it.
