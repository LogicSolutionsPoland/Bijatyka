# Distorted-face zombie assets for Bijatyka

These rigged Godot-ready GLBs are wired into gameplay:

- `Retribution_Zombie_DistortedFace_Animated.glb` — 13,335 triangles and a 16-bone rig; used by the boss at close range.
- `Retribution_Zombie_DistortedFace_Crowd_LOD.glb` — 5,641 triangles; used for every ninth spawned ordinary zombie and as the boss's distant LOD.

The boss switches to the crowd model at 20 m and back below 17.5 m. Ordinary zombies retain the existing 20-resident-rig cap; distorted-face models share that limit and use a separate rig pool so recycled standard models cannot change their appearance. The far-horde silhouette batch remains unchanged.

The models face -Z, use Y-up, and are about 2.29 m tall before scaling. Their clips are `Idle`, `Walk`, `Chase`, `Attack`, `Hit`, and `Death`. The enemy controller maps those names to its movement, hit, attack, and death states. The generic 0.42 s attack-contact point is an initial timing mapping for the supplied 0.90 s `Attack` clip and needs Godot/device visual review.

`reference/Horror_WideHead_Zombie_Reference.glb` is the archive's static, unrigged reference model. It is retained for art reference and is not instantiated during gameplay. The archive's older prototype installer is not used by this Godot project.
