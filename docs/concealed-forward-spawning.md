# Concealed forward spawning and assault

Based on `codex/zombie-roaming-aggression` at `45cb63089d7a7b3ac1e5f8c02ffdcb497b52b667`.
The existing wasteland, camera, controls, ordinary zombie combat, infighting and boss behavior remain in place.

## New zombies

`concealed_spawn.gd` owns the initial fill and replacement queue. It maintains the existing cap of **200 ordinary zombies**, plus the existing separate boss. Death or unexpected removal queues exactly one replacement after **1 second**. Duplicate notifications are ignored. Initial fill is spread over physics ticks instead of instantiating 200 zombies in one frame.

The nominal arrival distance remains **50 m**. Candidates use a 46–54 m band so the full population can occupy a forward arc without stacking on a single circle. Horizontal movement determines forward when moving; otherwise the player's actual facing determines it. Camera yaw remains independent. The arc extends 80 degrees to either side of forward.

Placement requires ground support, a walkable surface normal, the existing 94 m boundary inset, clearance for a capsule, and 4 m of initial dash clearance. The safe return position has a 6 m exclusion. Physics areas with a nonzero collision layer reserve spawn space, including areas on layers other than world/enemies. Non-colliding skyline boxes are also excluded. Recent births reserve 2 m around their location; live body occupancy is checked by physics.

If no candidate is safe, the request remains queued and retries after 0.25 seconds. This can temporarily leave fewer than 200 living zombies when the player faces out of the arena. Turning inward resumes filling. There is no inward/rear fallback and no relocation of living enemies.

## Concealment

The existing **30 m visibility** setting is unchanged. A conservative 3 × 3.2 × 3 m envelope must be wholly beyond the visible range, wholly outside the actual camera frustum, or completely behind opaque cover. No current camera means no spawn.

Cover checks ray-test all eight envelope corners. All rays must hit the same shape of one static opaque box, whose visible box mesh matches its collider. Arena boxes are explicitly tagged `zombie_spawn_occluder`. Transparent, hidden, partial, narrow, non-matching, and character cover are rejected. This is deliberately conservative: arbitrary mesh silhouettes, multiple separate occluders and uncertain cover do not qualify. Default births at around 50 m use the distance cull and do not need occlusion rays. The newborn's existing distance LOD is applied before rendering, so its first frame is already concealed.

## Assault and handoff

Only newly spawned ordinary zombies receive the burst. They immediately face and move toward the player's current position at **3.2 × base movement speed** (8 m/s for a shambler). They steer through the existing staggered AI cadence for up to **4.5 seconds**. Culled assault animations stay stopped.

The burst ends within **6 m** of the player, on a wall collision, on a hit or stun, on expiry, or when the player is beyond the existing 70 m simulation limit. Slow effects still apply. Movement uses `CharacterBody3D.move_and_slide`, with collision cancellation checked immediately after movement; there is no teleport or collision bypass. The ordinary chase, target choice, infighting, telegraph and recovery logic then takes over. The burst itself deals no damage or contact hit. Ordinary zombie attacks still interrupt/slow without reducing player HP.

This reuses the current local movement and collision system; it does not add a navigation mesh or a pathfinder around arbitrary obstacles. A wall ends the burst and returns movement to existing AI.

## Work budget and checks

One director allows at most **8 candidates and 2 births per physics tick**, shared by all requests. Failed searches are throttled. Visibility and physics placement queries run only for pending births; there is no new all-zombie per-frame visibility/navigation pass. The existing distance-based AI cadence is retained.

Run with Godot 4.7.2:

```sh
godot --headless --editor --path game --import --quit
godot --headless --path game --script res://tests/concealed_spawn_test.gd
godot --headless --path game --script res://tests/test_runner.gd
godot --headless --path game --script res://tests/burning_horizon_test.gd
godot --headless --fixed-fps 60 --path game --quit-after 600
```

Focused checks exercise camera rotation, frustum-edge envelopes, complete/partial/transparent cover, unsupported ground, obstacles, protected areas, safe base, occupancy, recent spacing, startup to 200, replacement delay, duplicate notifications, query budgets, outward-facing boundaries, deferred recovery, unchanged visible/rear zombies, missing cameras, assault steering, slows, interruption, wall collision and normal attack windup.

Local results: 1,052 focused checks passed; 462 existing gameplay checks passed; Burning Horizon integration passed. Headless scene validation uses 600 frames at fixed 60 Hz so gradual filling and active horde AI actually run. Godot's existing MP3 playback resources can report an ObjectDB warning at shutdown (also present before this change). Sustained Android frame rate and visual quality need a physical-device check.

`.github/workflows/horde-validation.yml` runs these checks on `codex/concealed-forward-assault`. Its Android export job is skipped on this branch. No APK or release is produced for this change.
