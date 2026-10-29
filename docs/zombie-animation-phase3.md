# Zombie animation connections — Phase 3

Verified with Godot 4.7.2 by importing `Retribution_Zombie_01_Brutal_V2_RIGGED_LOD1.glb` and inspecting its root `AnimationPlayer` library. All clips below are present under their exact unprefixed names:

| Clip | Duration | Use |
| --- | ---: | --- |
| `Idle` | 2.60 s | Stationary without a target; looped |
| `Walk` | 1.25 s | Wandering and ordinary approach; looped |
| `Sprint` | 0.71 s | Concealed-spawn assault and high-speed stalker chase; looped |
| `Attack_Swipe_L` | 1.05 s | Fallback left swipe if shared player combat clips cannot bind |
| `Attack_Swipe_R` | 1.05 s | Fallback right swipe if shared player combat clips cannot bind |
| `Attack_Bite` | 0.95 s | Fallback close attack if shared player combat clips cannot bind |
| `Hit_React` | 0.66 s | Nonlethal hit reaction |
| `Death_Forward` | 1.55 s | Knockback points against the zombie's facing direction |
| `Death_Backward` | 1.55 s | Knockback points along the zombie's facing direction |
| `Spawn_Recovery` | 1.38 s | Available, but intentionally unused |

## Reusing the player combat animations

The player's four generated fight clips (`left_punch`, `right_punch`, `left_kick`, and `right_kick`) are installed on each detailed zombie rig and the boss. The same pose frames from `game/scripts/fight_animation.gd` are retargeted through the model's explicit left/right bone names. The enemy asset faces +Z before its existing 180-degree model rotation, so the retargeter flips forward/back pitch while preserving the mirrored attack sides.

The generated clips use each enemy variant's existing windup and recovery durations. Their `contact` marker is placed at the end of the existing windup; damage, interrupt, range, target selection, and recovery values are unchanged. Ordinary zombies favor punches at close range and vary punches with kicks at longer range; stalkers kick at range; brutes and the boss alternate at range.

The imported `Attack_Swipe_L`, `Attack_Swipe_R`, and `Attack_Bite` clips remain available as a safe fallback if the player moves cannot bind to a rig. Zombie `Hit_React` and `Death_Forward` / `Death_Backward` clips remain in use. `Spawn_Recovery` remains unused because births immediately begin their concealed sprint.

Ordinary zombies still interrupt/slow the player without dealing HP damage; infighting and boss damage paths are unchanged. Dead zombies immediately stop AI and collision, are removed and queued for replacement only when the death clip or fallback completes.
