# Distorted-face zombie integration

The Godot runtime uses these models for the boss:

- `Retribution_Zombie_DistortedFace_Animated.glb` is the close-range boss model. Its `Idle`, `Walk`, `Chase`, `Attack`, `Hit`, and `Death` clips are mapped to the enemy controller.
- `Retribution_Zombie_DistortedFace_Crowd_LOD.glb` is the lower-detail distant boss model. The controller switches to it at 20 m and restores the animated model below 17.5 m.

Both models face -Z, use Y-up, and are about 2.29 m tall before scaling. The animated rig is separate from the Brutal V2 rig used by ordinary zombies, so the reconstructed body-part overlay remains on its existing close-range ordinary-zombie sample.
