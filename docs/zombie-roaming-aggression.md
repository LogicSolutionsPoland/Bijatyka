# Roaming and aggression

Based on codex/endless-invasion-40 at ed3e2a3, retaining 200 zombies, 50 m replacement spawns and 30 m visibility. Retribution main game/zombie_ai.gd supplied the idle/wander and staggered decision pattern; infighting is a new Bijatyka extension.

Ordinary zombies pause 0.6–2.5 seconds, walk in random directions at 1.5 m/s for 3–8 seconds, acquire rivals within 6 m, and prioritize players detected within 14 m with a world-obstruction ray test. Player detection alerts neighbours within 10 m. Targets are retained out to 24 m. Attack windup locks selection; hits recheck distance and obstruction. Rivals take 12 damage and retaliate; infighting grants no RAGE. Ordinary zombies still only interrupt/slow players, while bosses retain HP damage. Existing death signals replenish the population.

Shared 10 m spatial buckets avoid scanning all pairs for target selection. Decision timers are staggered at 0.35–0.55 seconds; existing distance AI cadence and visibility remain. Wandering turns at walls and arena edges. This is local steering, not a full navigation mesh/pathfinder. Android performance under active combat still requires physical-device measurement; a screenshot cannot establish 200 simultaneous draw calls or sustained frame rate.

Validation: gameplay regression suite plus targeted rival damage, retaliation, player priority, group alert, idle/wander and dead-target checks; headless scene smoke via Horde and visibility validation. No APK requested in this change.

Local validation completed with Godot 4.7.2: import succeeded, 462/462 gameplay checks passed, and 600-frame headless scene smoke completed without script errors. Both runs report two ObjectDB instances leaked at shutdown; device performance and this shutdown warning remain unverified. GitHub push was blocked by automatic approval review pending explicit authorization; Actions has not run.
