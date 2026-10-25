# Candidate 3D asset packs for Bijatyka

This document records a **source-only staging tool**, not a completed visual or combat integration. The four uploaded archive payloads are **not included** in this branch. Their contents, licenses, file counts, animations, sizes and suitability have **not** been verified.

## Intended source packs

| Uploaded archive | Staging folder | Proposed use (pending file inspection) |
| --- | --- | --- |
| `MeleeWeaponsPack.rar` | `third_party/candidate_asset_packs/melee_weapons` | Melee props and possible held weapons |
| `PSX Graveyard Demo.zip` | `third_party/candidate_asset_packs/psx_graveyard` | Cemetery environment or low-poly scenery |
| `Humane-Basics.rar` | `third_party/candidate_asset_packs/humane_basics` | Inspect first; potential character resources |
| `KayKit_FantasyWeaponsBits_1.0_FREE.zip` | `third_party/candidate_asset_packs/kaykit_fantasy_weapons` | Inspect first; potential weapon decoration |

Do not assume the archives contain Godot-compatible models based solely on their names. Inspect actual formats, model count, animation skeletons, readme and commercial redistribution license terms first.

## Offline staging

When the original four archives are present **on the same machine as the repository**:

```sh
python3 tools/stage_asset_packs.py --dry-run \
  "MeleeWeaponsPack.rar" "PSX Graveyard Demo.zip" \
  "Humane-Basics.rar" "KayKit_FantasyWeaponsBits_1.0_FREE.zip"

python3 tools/stage_asset_packs.py \
  "MeleeWeaponsPack.rar" "PSX Graveyard Demo.zip" \
  "Humane-Basics.rar" "KayKit_FantasyWeaponsBits_1.0_FREE.zip"
```

ZIP uses built-in Python. For RAR, install `rarfile` and a supported `unrar`, `unar` or `bsdtar` decompression backend. The tool accepts only the four exact archive basenames, prevents path traversal and symlink extraction, checks archive size budgets, refuses to overwrite existing staged packs, generates SHA-256 manifests and keeps assets outside `game/`.

Tests (no original archives necessary):

```sh
python3 -m unittest tools.test_stage_asset_packs
```

## Integration gates — not completed

1. **Legal review.** Inspect licenses in each original archive and confirm the rights to commit/repackage individual assets in a public GitHub repository and Android APK. Archive names that contain "FREE" do not themselves prove redistribution rights.
2. **Format and visual audit.** Inventory real mesh/material/texture files and identify exact assets to keep. Remove sample-project code and editor plugins; do not blindly import external Godot project settings.
3. **Curated Godot import.** Copy only selected permitted models and their textures to `game/assets/...`. Fix GLB/GLTF/FBX scales, material alpha settings and texture references. Reuse instanced resources; disable shadows consistent with the existing rendering policy.
4. **Playable integration.** Mount approved props into the arena without obstructing the player base, 30 m visibility, concealed 50 m spawning and 15 ordinary living zombie limit. Weapons must not alter manually triggered punches/kicks, damage, or touch/gamepad input until a specific weapon-system design is approved.
5. **Validation and APK budget.** Run Godot import and gameplay/lighting/render tests; measure loaded meshes/triangles/texture memory/Android frame time; retain the Godot 4.7.2 Compatibility renderer and ARM64 target. No device FPS or finished APK is claimed in this step.

Do not commit the unreviewed extracted pack payloads on this branch or merge this staging feature into the playable branch as a substitute for actual integration.
