# Foundation inventory and assumptions

## Source and repository

- New game project: `game/` in `LogicSolutionsPoland/Bijatyka`, on `codex/retribution-godot-foundation`.
- The target repository's default branch contained only its README before the foundation work. All implementation is isolated to the feature branch.
- Source of legacy rules and assets: `LogicSolutionsPoland/Retribution-mark-of-sin`, main plus the RAGE design branch `feat/rage-1-0-20261022`.
- Current engine from source `project.godot`: Godot 4.7.2; GL Compatibility renderer; Android ARM64 export target. The foundation enables the Android ETC2/ASTC texture import setting required for Android exports. It does not upgrade that engine or renderer.

## Reused material

- Player model: `Retribution_Player_Thornbound_Warrior_MOBILE.glb`, supplied user asset pack; 21-joint rig with `Idle`, `Walk`, `Sprint`, `Jump`, and `Sword_Slash` clips. Attack poses are procedural because there are no dedicated punch/kick clips in the pack.
- Zombie model: `Retribution_Zombie_01_Brutal_V2_RIGGED_LOD1.glb`, source branch asset. Brute, stalker, and boss variants use the same authored zombie base with different scale, tint, silhouettes, attack timings, and stats.
- No music is imported or played. The initial slice uses generated visual spell bursts and has no sound assets.

## Confirmed legacy mechanics and conflicts

- Existing spells: Light heals 30 for 20 energy; Judgment deals 35, 18 m range, and stuns 0.7 s for 20; Fire deals 20, burns for four 4-damage ticks, 18 m range, 15 energy; Shadow deals 25, slows 40% for 5 s, heals 30% of direct damage, 18 m range, 20 energy. Energy regenerates at 5/s and solo mode has no spell cooldown. The slice follows these effects after RAGE unlocks a spell.
- Source `game/combat.gd` currently lets ordinary zombies deal 8 HP. `game/tests/combat_test.gd` and grounded cases in `game/tests/jump_test.gd` expect the resulting 92 HP; those legacy assertions conflict with the new approved rule that ordinary zombies cannot reduce player HP. This project applies the new rule and lets zombies interrupt, slow, and extend recovery. Bosses still deal damage. The source tests were not changed or run as part of this separate project.
- Source main uses held-attack repetition and a 5 m dash. This foundation uses one press per attack and the previously confirmed 15 m dash.
- The RAGE design branch confirms initial zero/no spells, effective-hit gain, continuous decay, the 10/30/50/70/90 aura-choice milestones, threshold-gated aura layers, persistent spells through ordinary decay, and max-RAGE-only condemnation with complete run reset. The numeric RAGE tuning in that branch is explicitly provisional; the foundation exposes it as configurable and labels it accordingly.
- The project source does not establish a full approved list of aura identities beyond existing magic schools and future examples. The first slice presents the four existing schools as selectable auras; repeated choices are allowed because uniqueness was left undecided.
- Lore references remain limited to the established chemical-war zombie apocalypse, combat robots, the Heaven/Hell pact, and souls in purgatory. No new RAGE authority or obedience story is introduced.

## Verification and constraints

- GitHub Actions access was confirmed with a lightweight validation workflow on a feature branch. It succeeded on an Ubuntu 24.04 x86_64 runner with Java 17.0.20.1; this confirms compatible runner access, not unlimited Actions quota.
- The full foundation workflow passed on commit `70223bb921edd7bed5e0a3d0708633502eab9cdf`: 49 headless checks, project import, and playable-scene smoke run passed. Android ARM64 debug export and artifact publication also passed.
- The Android artifact is `retribution-mark-of-sin-android-arm64`, approximately 31.8 MB, from Actions run `40019970976`. It is a debug package signed by the runner's debug keystore.
- The initial blockout uses procedural geometry and generated visual effects. Distance-based enemy animation, AI cadence, shadow, and visibility reductions are implemented, but handset performance has not been profiled and APK installation has not been tested. No target Android device was specified.
