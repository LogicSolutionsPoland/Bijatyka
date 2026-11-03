# Local encounter Director and 20 ordinary zombies

## Source and scope

The branch starts from ruined-city PR #62 at `072b423922bdc646491cf5960a8ceb6fad44e32a`.
The owner's confirmed working Stage 6 APK came from `0a4eccc9e52494141bfcebcbb7dc7901b8b71c24`.
These commits are siblings from the same Stage 6 game tree; the APK source adds
an export workflow, while PR #62 adds gamepad-only controls and the ruined city.
The latest ruined-city head passed its performance validation workflow before
this branch was created. Neither `main` nor the working APK was modified.

## Decision and ownership

`game/scripts/ai_director.gd` runs locally and evaluates once per second,
with immediate reevaluation after damage and confirmed ordinary-zombie deaths.
It reads the existing spawn manager's cached live actors and attacker slots.
Health, recent damage, nearby actors, attackers, kills over six seconds,
horizontal speed, relative player position, quiet time and boss proximity feed
a normalized intensity score. A damaging hit starts a short FRENZY; it does not
reduce attacker count or slow the replacement pace. Boss proximity only bounds
ordinary reinforcements; the boss AI, damage and attack logic remain unchanged.
Ordinary zombies commit to the player after a spawn assault or once within 14 m,
keep that target through distance and cover, and do not switch to other zombies.
When one detects the player, it alerts nearby allies, which spread the pursuit
through the horde. Ray probes steer active pursuers around nearby solid obstacles;
collision and attack line-of-sight checks remain authoritative.

| State | Ordinary attacker target | Replacement delay | Entry condition |
| --- | ---: | ---: | --- |
| PRESSURE | 4 | 1.0 s | Default active ground combat |
| SURGE | 4 | 0.8 s | Quiet combat with few nearby enemies |
| PEAK | 4 | 0.65 s | Three quick kills with sufficient intensity |
| FRENZY | 4 | 0.55 s | Player takes damage; repeated hits refresh the 4 s duration |

States use bounded, varying durations rather than a fixed time cycle. All active
states retain four attack slots; only the replacement delay changes. FRENZY lasts
at least four seconds after damage and refreshes on repeated hits. Quiet periods
can reserve at most two new ordinary reinforcements per one-second evaluation.
The original concealed spawn implementation still checks camera/frustum, opaque
cover, collision, ground and navigation before any birth. Its one-spawn-per-mobile-
tick budget is unchanged. The Director biases sampling toward the less occupied
forward flank and never moves an existing zombie.

The existing spawn manager remains the sole owner of live actors, dormant data
records, pending reservations, wake transitions and attacker slots. Its maximum
ordinary population is 20 even if profiling or a caller requests a larger cap.
The boss is excluded. Rooftop entries remain four data records and the Director
activates only on the real elevator ground-arrival event. Returning to the roof
or respawning stops its timer and clears its policy. The maximum number of
simultaneous ordinary attackers remains four; the seven detailed rig budget,
10 m dormancy and 5 m wake thresholds, and distant 10 Hz physics remain intact.

## Validation and limitations

Phase 1 was committed and validated at `3a94d0384b1355ad031dc5ea8e6a6effb1e3e8bd`
in [Godot 4.7.2 validation run #1](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/41648203384).
Import, Director state/queue checks, 206 gameplay checks, 464 concealed-spawn
checks, dormancy, elevator and scene smoke passed. Its CI host measured about
4.15 microseconds per strategic evaluation with four tracked actors, excluding
Android rendering and whole-frame scheduling. This number is not an Android FPS,
CPU, GPU, battery, memory or thermal comparison.

Phase 2's tests cover 20 live/record slots, prevention of over-cap profiling,
replacement queues, boss exclusion, rig lifecycle and ground/roof transitions.
The legacy 30-zombie graphics benchmarks now run the same comparisons with 20
and retain their historical Stage numbers; results across different population
counts cannot be compared as an isolated graphics optimization. Sustained
Android gamepad play, FPS percentiles, temperature and GPU timing remain the
next validation gate. No APK is produced by this branch.
