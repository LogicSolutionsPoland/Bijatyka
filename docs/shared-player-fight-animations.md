# Shared player combat animations for enemies

The player and detailed enemy rigs now use the same generated fight pose frames from `game/scripts/fight_animation.gd`.

- The player keeps the existing `thornbound_combat` clips and hit synchronization.
- Zombies and the boss receive matching `enemy_combat` punch and kick clips using an explicit bone-name map for the Brutal V2 rig.
- The player model faces local -Z while the enemy asset faces local +Z before its existing 180-degree model rotation. The retargeter mirrors forward/back pitch for enemy clips.
- Each enemy clip's contact marker matches that variant's existing windup boundary. AI decisions, damage, ranges, cooldowns, and zombie population limits stay unchanged.
- Enemy idle, walk, sprint, hit-reaction, and death clips remain sourced from the zombie model. The imported swipe and bite clips remain available when a rig cannot accept the shared fight clips.
- Generated enemy clips are installed only on detailed rigs, so far crowd visuals do not gain extra animated skeletons.

The Android ARM64 APK is built by the repository workflow; no on-device performance claim is made.
