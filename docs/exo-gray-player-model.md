# Exo Gray player model — integration notes

Source branch: `codex/player-mma-kick-20261030`. The integration lives on `codex/exo-gray-player-model-20261031`; `main` remains unchanged.

## Integration

1. Extract the provided `Bijatyka-ExoGray-player-asset.zip` into the repository root on the integration branch. Required file: `game/assets/characters/exo_gray/Exo_Gray_Player.glb`.
2. Commit/push that binary asset. Without it, the game intentionally falls back to Universal Base and the updated player quality test fails.
3. Run the existing Godot import, player animation, player character quality, gameplay and Android ARM64 export workflows.
4. Validate idle, walk, sprint, jump, dash, L/R punches and MMA kicks, airborne strikes, rooftop spawn, elevator travel, respawn, and boss/horde lighting on an actual Android device before releasing.

## Architecture and risks

The original 65-bone Universal Base imported rig and its AnimationPlayer are kept as the authoritative (hidden) gameplay animation source. Exo Gray is an **additional** visible, skinned 112-bone model. `player_exo_gray_retarget.gd` maps 20 body bones and computes rest-relative global pose differences every render frame, leaving finger and facial joints in their inherited rest-relative positions. Its root pelvis translation is scaled from Universal Base meters to Exo Gray centimeters. It preserves all original gameplay animation paths and combat contact times.

This is a safe first integration, not yet a production-optimized skin transplant. It adds a second animated rig and 31.7k visible triangles; measure FPS and thermal behavior. A later bake to a shared skeleton would avoid the per-frame retarget and duplicate rig. The Exo model has not been visually tested in Godot or on an Android device here. Validate model yaw, apparent height, hand/foot contacts, skin deformation, and camera clipping, then tune if necessary.

If the GLB is missing or the mapping fails, the original Universal Base model remains visible.

## Expected validation

- `game/tests/player_character_quality_test.gd`: visible Exo skin and triangle budget; hidden 65-bone source animation rig.
- `game/tests/player_animation_test.gd`: existing source rig, attack timing, MMA kicks and controls.
- Full Android ARM64 export after Godot import. A successful static check alone is not proof of retargeted motion quality.
