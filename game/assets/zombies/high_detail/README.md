# High-detail zombie visual slice

`Retribution_Zombie_Reconstructed.glb` is a 156,276-triangle, textured model split into body-part meshes. It has no skin or animation tracks. The runtime attaches those parts to matching bones on the existing animated zombie rig, so the current locomotion, hit, death, and player-derived punch/kick animations continue to drive the visible model.

The high-detail layer is used for one ordinary zombie within 12 m of the player, with a 14 m exit distance to avoid visual popping. Beyond that range the existing lightweight rigged model remains visible. The normal population limit stays at five zombies.
