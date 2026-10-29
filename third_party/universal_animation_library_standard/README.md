# Quaternius Universal Animation Library — Standard

Publisher: https://quaternius.itch.io/universal-animation-library
License: **CC0 1.0 Universal**, original `License.txt`; attribution optional.
Edition: **Standard** (both root-motion and non-root-motion variants).

This directory contains the **complete original Standard pack** from the ZIP supplied for Bijatyka: 9 files, **63,648,179 uncompressed bytes**.

## Selecting animation files

| File | Purpose |
| --- | --- |
| `Unreal-Godot/UAL1_Standard.glb` | 43 humanoid clips, **without root motion**. Preferred for controller-driven movement. |
| `Unreal-Godot/UAL1_Standard_RM.glb` | Same 43 clips **with root motion**. Needs an explicit root-motion setup. |
| `Unity/UAL1_Standard.fbx`, `Unity/UAL1_Standard_RM.fbx` | Reference/retarget source exports for Unity. |
| `Godot_Setup.png`, `Unity_Setup.png`, `Unreal_Setup.png` | Original setup illustrations. |
| `README.txt`, `License.txt` | Original publisher instructions and CC0 license. |

Each GLB uses a 65-joint humanoid skin, **different** from KayKit's 23-joint source animation rig and not verified against Bijatyka's own player/zombie skeletons. Do not assign tracks without a tested retarget mapping, rest-pose comparison, facing, contact timing and root-motion policy.

## Android / performance policy

- **Source asset drop only** under `third_party/` outside the `game/` Godot project: no scenes, gameplay controls, shaders or Android export configuration modified.
- When integrating later, selectively retarget chosen clips and add only the required optimized GLB/animation to `game/assets/`. Do **not** export the complete FBX+GLB pack in the APK.
- Preserve the current 69-zombie gameplay population, 200-zombie stress scenario, 20 resident detailed zombie rigs, zombie animation tiers/pools, player attacks and mobile controls, Burning Horizon, protected base and flashlight.
- Retargeted animations must pass hit synchronization, lifecycle and Godot 4.7.2 validation. Real-device profiling is required for Android performance claims.

## Reproducibility

`manifest.json` pins the exact uploaded ZIP SHA-256, official free itch.io upload ID, and every file's length and SHA-256. The one-shot import GitHub Action downloads from the **publisher** and rejects any changed ZIP or extra/missing/mismatched files. Reproduce locally:

```sh
python3 tools/import_universal_animation_library.py --archive 'Universal Animation Library[Standard].zip'
```

Omit `--archive` to download from the pinned publisher source. The ZIP SHA-256 is `cc73fc4e495b82958207316596317a3f40b9fa38065bde1027937452da537724`.
