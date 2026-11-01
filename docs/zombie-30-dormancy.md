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
zombies **farther than 10 m**, without an active assault, combat target,
grapple or hit/windup/recovery state, are converted into lightweight records:
`{position, hp, kind}`. Their CharacterBody3D, AI, animation, collision and
mesh are removed. This does not queue a replacement. Dying zombies and the
boss never enter this state.

At **5 m** or closer, a record is restored at its **last actual position**.
The game's original **30 m** rendering range remains unchanged, so sleeping
zombies are absent from the 5–30 m band and may visibly reappear around 5 m.
HP and variant are preserved. Restoring a record never increments the
ordinary population count.

While data-only, a zombie **does not move or fight**. This is deliberate:
unknown obstacle/navigation state cannot be approximated by teleporting or
simulating it across a wall.

## Mobile work budgets
- Imported full-detail ordinary zombie rigs: **7 on both Android and desktop**.
  Engaged near attackers retain animation-selection priority.
- Ordinary AI/physics outside 7 m ticks at **10 Hz**, including opening
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
`horde_performance_test.gd`, `rig_budget_lifecycle_test.gd` and `elevator_loading_test.gd`.

Before merging, verify on the Redmi Android 16 and Samsung Android 7:
30 population cap, visible 5 m reappearance, wall/collision behavior, boss,
return-to-roof reset, memory, heat and steady-state FPS. No performance
improvement is asserted until measured on devices.

## Stage 2b: render data-only zombies as batched silhouettes (2026-11-01)
- The existing enemy MultiMesh also draws stationary records from the dormancy
  director in its 5–30 m visual range, **without materializing physics actors**.
- Records store the original world position, HP, kind, facing angle, and a
  stable visual ID. The full actor still wakes only at <=5m.
- Dormant proxy visibility uses the same flashlight sector and screen-oval
  intersection as ordinary active silhouettes, classified at most every 0.12s.
  GPU depth testing hides covered fragments behind walls, preserving darkness.
- The shared mesh/shader remains one draw call, with static record transforms
  only uploaded when their compacted MultiMesh slot changes.
- The upstairs record-only population is never passed to the draw queue.
- Device checks must validate visual continuity on wake, motionless distant
  proxies, and flashlight occlusion from different camera angles.

## Stage 2: bounded AI neighbor broad-phase (2026-11-01)
- A shared 10 m spatial grid is rebuilt at **10 Hz**, not once per physics
  frame. Every zombie still queries its surrounding nine cells and validates
  live, non-queued enemies. New spawns invalidate the cache immediately.
- Ordinary zombies still use **10 Hz physics beyond 7 m**; their first far
  step is spread over ten phase slots to reduce simultaneous collision spikes.
- LOD updates no longer reassign mesh visibility when the distance tier is
  unchanged. Rig selection, flashlight changes, death and tier crossings still
  update visibility as before.
- The existing **10 m record / 5 m wake / 7 rigs / 30 population** thresholds
  remain unchanged. The boss, player and active combat behavior are untouched.
- Tests assert the 10 Hz grid buckets at 60 and 30 physics ticks per second.
  Hardware FPS and heat improvements still require a device A/B test.
