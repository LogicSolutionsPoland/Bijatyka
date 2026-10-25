# Zombie animation connections — Phase 3

Verified with Godot 4.7.2 by importing `Retribution_Zombie_01_Brutal_V2_RIGGED_LOD1.glb` and inspecting its root `AnimationPlayer` library. All clips below are present under their exact unprefixed names:

| Clip | Duration | Use |
| --- | ---: | --- |
| `Idle` | 2.60 s | Stationary without a target; looped |
| `Walk` | 1.25 s | Wandering and ordinary approach; looped |
| `Sprint` | 0.71 s | Concealed-spawn assault and high-speed stalker chase; looped |
| `Attack_Swipe_L` | 1.05 s | Target on the zombie's left |
| `Attack_Swipe_R` | 1.05 s | Target on the zombie's right |
| `Attack_Bite` | 0.95 s | Close target, within 68% of current attack range |
| `Hit_React` | 0.66 s | Nonlethal hit reaction |
| `Death_Forward` | 1.55 s | Knockback points against the zombie's facing direction |
| `Death_Backward` | 1.55 s | Knockback points along the zombie's facing direction |
| `Spawn_Recovery` | 1.38 s | Available, but intentionally unused |

## Attack contact timing

The source has no animation event tracks. Inspecting the authored bone rotation keys shows the striking `UpperArm_L` / `Forearm_L` peaks at 0.367 s in `Attack_Swipe_L`; the right-arm peaks at the same 0.367 s in `Attack_Swipe_R`. The `Spine` and `Head` reach their forward-lunge peak at 0.533 s in `Attack_Bite`. These authored peaks are used as contact poses. At the existing AI windup start, playback speed is set so the selected peak aligns with the existing `state_time` expiry. When damage/interrupt resolution runs, the animation is corrected to that contact frame and continues at normal speed. AI windup, damage, range, and hit resolution are unchanged.

`Spawn_Recovery` is not used because births currently transition directly into an immediate concealed assault; playing a recovery/stand-up clip would contradict that behavior. Animation transitions blend briefly. Missing clips are skipped safely; lethal animation absence retains the prior scale-down fallback.

Ordinary zombies still interrupt/slow the player without dealing HP damage; infighting and boss damage paths are unchanged. Dead zombies immediately stop AI and collision, are removed and queued for replacement only when the death clip or fallback completes.
