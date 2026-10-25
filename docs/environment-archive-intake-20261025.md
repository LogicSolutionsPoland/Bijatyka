# Ten uploaded environment and character packs — local intake, 2026-10-25

This branch **does not distribute the uploaded binaries**. None of the ten archives contains an obvious LICENSE/README document authorizing public GitHub or APK redistribution. The user can run the local installer against original archives after confirming rights. Keep public PRs source-only until license/provenance review is complete.

## Verified archive inventory

| Archive | Actual contents | Proposed use | Current status |
| --- | --- | --- | --- |
| `Metro_PSX.rar` | 1 self-contained GLB (79 meshes, ~17,342 indexed triangles, 26 textures), FBX/DAE and images | Static isolated props: bin; later underground scene | Small local import supported |
| `FantasyStylizedPack.rar` | Nested RAR packs: Rocks, Cemetery, Trees, Asian, Medieval; Rocks and Cemetery contain embedded-texture GLBs | Rocks, graves, fence scenery; trees only after profiling | Rocks/Cemetery local import supported |
| `Abandoned_House.rar` | Self-contained GLB (568 meshes, ~66,138 indexed triangles), FBX, DAE, Blender, textures | Ruins/dedicated exploration area | Heavy opt-in import only; not active arena |
| `Roads.rar` | Blender and Collada road map, JPG/PNG textures | Optional road sections | Requires conversion / model partition |
| `House.rar` | House and collider FBX, many textures | Houses outside core combat loop | Requires selective import and mesh/texture optimization |
| `Sewer.rar` | Blender/FBX/DAE and textures | Sewer level | Requires new isolated level and navigation |
| `Hospital_assets.zip` | 1 Blender scene and 114 textures, ~564 MB uncompressed | Hospital level | **Not Android-ready**; Blender conversion and texture downscaling required |
| `TheWrapper V2.zip` | `MonsterPSX.fbx`, Blender source and PNG texture | Monster/NPC candidate | No rig/animation compatibility proven |
| `male_casual.zip` | FBX and PNG texture | Civilian/NPC candidate | No skeleton or license verified |
| `Free Sample.zip` | 10 PNG sprite sheets/images | Concept/UI assets only | Not 3D environment; manual suitability check |

Rocks GLB: 30 meshes, ~10,217 triangles; Cemetery GLB: 35 meshes, ~25,106 triangles. All checked local GLBs have embedded textures; they do not need external JPG/PNG references. The imported GLBs contain no skeletal animations. Counts are **source-file statistics**, not Android profiling.

## Local integration

The source-only code in this branch adds `game/scripts/community_props.gd` and an **off-by-default** hook in `foundation.gd`. The hook loads selected *individual nodes* from the local GLB libraries, with **no collision**. Props are placed outside the protected base. The feature does not touch the ordinary-zombie cap (15), 30 m vision, 50 m replacement spawns, Burning Horizon, shadow policy, camera, or controls.

When the archive originals are available on a computer with Python and libarchive, run:

```bash
python3 tools/install_environment_packs.py --source /path/to/original_archives --output game/assets/environment/community
python3 -m unittest tools.test_environment_import
```

Then reopen Godot 4.7.2, import assets and activate the local project setting `gameplay/enable_community_environment_packs=true` **only for development tests**. This is not enabled by default. Heavy assets are separate: `--include-heavy` stages Abandoned House and Trees but does not place them in the playable arena.

Do **not** commit `game/assets/environment/community/**/*.glb` or export a redistributed APK until the source licenses are verified. Public asset redistribution, Android GPU memory cost, mobile FPS and complete character/level integration **are not verified**. A standalone local content bundle was prepared from the uploaded archives for the user to install privately.
