# Retribution: Mark of Sin — Thornbound Trial

A separate Godot 4.7.2 Compatibility renderer project for a playable third-person combat foundation. The original Retribution repository is not included or restructured by this project.

## Run

Open `game/project.godot` in Godot 4.7.2, or run from a shell:

```sh
godot --path game
```

The test runner is headless and dependency-free:

```sh
godot --headless --editor --path game --quit
godot --headless --path game --script res://tests/test_runner.gd
```

## Controls

| Action | Keyboard | Touch |
|---|---|---|
| Move | WASD / arrows | Left virtual stick |
| Punch | J (right) | Left / right PUNCH |
| Kick | K (right) | Left / right KICK |
| Jump | Space | JUMP |
| Dash | Shift | DASH |
| Cast unlocked spell | L (selected spell) | Four direct MAGIC slots |
| Cycle unlocked spells | U | Use the desired MAGIC slot directly |

The touch buttons form two columns at the screen edges, in this exact order:

| Left side | Right side |
|---|---|
| PUNCH (left arm) | PUNCH (right arm) |
| KICK (left leg) | KICK (right leg) |
| MAGIC (slot 1) | MAGIC (slot 2) |
| MAGIC (slot 3) | MAGIC (slot 4) |
| DASH | JUMP |

The movement stick sits just inside the left column, without overlapping a button.
Magic slots fill in the order distinct spells are unlocked through aura choices.
All four stay visible while locked; unlocked slots show the spell name below MAGIC.
Spells stay in their slots through normal RAGE decay and all slots lock again on a soul reset.
Touch actions trigger once on finger-down. Holding or dragging a finger never queues another attack;
independent fingers allow moving and attacking together. Combat input is blocked during aura selection.

Each attack press starts exactly one action. The player has four timed, full-body skeletal clips: left and right punches, plus left and right kicks. Every clip includes a chamber, contact, follow-through, and guarded recovery; the contact marker matches that move's existing hit timing. A held key never chains attacks.

The imported Thornbound rig has no finger joints, so the existing hand meshes remain unchanged.

The zombie rig is turned to face the same forward direction used by its approach and attack logic.

The camera follows behind the player from a close right-shoulder viewpoint. The character stays left of center while the open center of the screen looks down the combat lane. The spring arm retracts near walls and ignores the player's own collision body.

## Carried-forward rules and current scope

- The Thornbound mobile GLB player and rigged LOD1 zombie were copied from user-supplied Retribution assets; no music is used.
- The yard's enemies have telegraphed windups. Ordinary zombies can interrupt, slow, or lengthen recovery but never reduce HP. The boss can damage the player.
- Shadows are disabled on every scene light, imported player/enemy model, and procedural mesh. Distance-based enemy detail never switches them back on, and the HUD notice has no text shadow.
- Jump landing impacts can hit and damage enemies. Dash uses the previously selected 15 m mobility distance.
- RAGE begins at zero, only confirmed positive damage adds RAGE, it continuously decays, missed attacks do not count, aura choices occur at 10/30/50/70/90, aura layers gate on current RAGE, and unlocked spells persist until a soul reset. Condemnation depends on the run maximum and is one-shot.
- The provisional values (+3 per effective hit, 1 per second decay, cap 1000, threshold `max(3, 25% of run maximum)`) are source-design defaults, not approved balance. They are configurable in `rage_progression.gd`.
- The selected aura unlocks the matching existing magic school (`light`, `judgment`, `fire`, `shadow`). The foundation keeps the existing spell costs, direct damage, healing, judgment stun, fire burn, and shadow slow/lifesteal behaviors, with solo energy regeneration and no spell cooldown.

## Android

The project uses the source-confirmed Godot 4.7.2 Compatibility renderer, ETC2/ASTC texture import, and ARM64 as the intended Android architecture. The Android export preset and package build are validated in GitHub Actions. Device performance has not been measured yet; no Android hardware result is claimed.
