# Bijatyka character model mapping

- **Player:** `Retribution_Player_Thornbound_Warrior_MOBILE.glb` remains the playable character.
- **Ordinary zombies:** `Retribution_Zombie_01_Brutal_V2_RIGGED_LOD1.glb` remains the shared model for the five active zombies. The reconstructed model stays attached as the close-range detail sample for one ordinary zombie.
- **Boss:** the new DistortedFace animated GLB is used up close; its crowd LOD is selected at 20 m and the animated model returns below 17.5 m.
- **Bloodforged Sentinel:** its supplied Blender file is preserved under `art/characters/bloodforged_sentinel/source/`. It is source art only for now; a runtime export and rig review are still needed before the game can instantiate it.

The model assignments preserve the current five-zombie gameplay setup.
