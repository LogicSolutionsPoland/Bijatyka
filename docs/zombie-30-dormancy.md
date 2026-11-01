# Bijatyka: up to 30 ordinary zombies with dormant data entries

Implementation branch: `feat/zombie-30-dormancy-20261101`, based on PR #53
(`feat/elevator-call-loading-screen-20261031`). The boss is excluded from
the ordinary population.

## Population policy
- On the roof and during elevator travel: **4 stored records**, no ordinary actors.
- On ground-floor arrival: materialize **4** concealed zombies in the original annulus.
- A completed ordinary death opens up to **2** replacement slots until the living
  population reaches **30**. At 30, one death means one replacement (no overshoot).
- At most **4** ordinary zombies may hold a player attack slot at once.
- Living population = active actors + data-only dormant records; queued births
  reserve slots separately.

## Dormancy and wake
A scheduler runs at 5 Hz with up to 2 changes per scan. Unalerted ordinary
zombies **farther than 44 m**, without an active assault, combat target,
grapple or hit/windup/recovery state, are converted into lightweight records:
`{position, hp, kind}`. Their CharacterBody3D, AI, animation, collision and
mesh are removed. This does not queue a replacement. Dying zombies and the
boss never enter this state.

At **36 m** or closer, a record is restored at its **last actual position**,
which remains outside the game's **30 m** drawn area. Its remaining HP and
variant are restored. It enters the regular collision-aware pursuit path
without an extra ordinary zombie appearing in the population.

While data-only, a zombie **does not move or fight**. This is deliberate:
unknown obstacle/navigation state cannot be approximated by teleporting or
simulating it across a wall.

## Mobile work budgets
- Imported full-detail ordinary zombie rigs: **10 on Android**, 20 on desktop.
  Near attackers retain full animation selection priority.
- Ordinary AI/physics outside 30 m ticks at **10 Hz**, including opening
  assaults. Physical `move_and_slide()` and collision remain in use.
- Other ordinary zombies inside the visual area use the existing shader-
  animated MultiMesh silhouette and flashlight classification.
- Original 40% 3D render scale and 60 FPS cap are unchanged. The cap is not
  a measured FPS result.
- Debug profiling retains its high-population 69/100/200 diagnostic scenarios
  with dormancy **disabled** to avoid masking true load.

## Verification
The dedicated `zombie-30-validation.yml` workflow executes Godot 4.7.2
import, `zombie_30_optimization_test.gd`, `concealed_spawn_test.gd`,
`horde_performance_test.gd` and `elevator_loading_test.gd`.

Before merging, verify on the Redmi Android 16 and Samsung Android 7:
30 population cap, no mid-camera pop-ins, wall/collision behavior, boss,
return-to-roof reset, memory, heat and steady-state FPS. No performance
improvement is asserted until measured on devices.
