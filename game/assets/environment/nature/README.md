# Nature scenery from Zasoby

Source: `Stylized Nature MegaKit[Standard].zip` by Quaternius, from the user's
`/Zasoby` folder. The included `LICENSE_CC0.txt` declares CC0 1.0. The four
selected glTF models, their `.bin` buffers, and required PNG textures are
included; the rest of the pack is not copied into the game.

The dead-tree bark is reduced to 1024 px, and its normal map and rock texture
to 512 px for the Android build. The glTF mesh geometry and material references
are unchanged. `arena_map_upgrade.gd` places six dead trees, eight rocks, and
six shrubs as four non-colliding `MultiMeshInstance3D` batches along the outer
fence. These do not affect the protected base, five-zombie population, boss,
enemy spawning, or combat lanes.
