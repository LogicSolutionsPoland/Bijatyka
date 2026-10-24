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

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Drag on left half |
| Camera | Drag on right half | Right stick | Swipe on right half |
| Punch | J (right) | Buttons await your layout | Left / right PUNCH |
| Kick | K (right) | Buttons await your layout | Left / right KICK |
| Jump | Space | Button awaits your layout | JUMP |
| Dash | Shift | Button awaits your layout | DASH |
| Cast unlocked spell | L (selected spell) | Buttons await your layout | Four direct MAGIC slots |
| Cycle unlocked spells | U | Button awaits your layout | Use the desired MAGIC slot directly |

The touch buttons form two columns at the screen edges, in this exact order:

| Left side | Right side |
|---|---|
| PUNCH (left arm) | PUNCH (right arm) |
| KICK (left leg) | KICK (right leg) |
| MAGIC (slot 1) | MAGIC (slot 2) |
| MAGIC (slot 3) | MAGIC (slot 4) |
| DASH | JUMP |

There is no on-screen analog stick: dragging on the left half moves, while swiping on the right half rotates the camera. The gamepad left stick moves and the right stick rotates the camera; gamepad skill buttons stay unbound until you provide their layout.
Magic slots fill in the order distinct spells are unlocked through aura choices.
All four stay visible while locked; unlocked slots show the spell name below MAGIC.
Spells stay in their slots through normal RAGE decay and all slots lock again on a soul reset.
A touch tap triggers one action immediately; holding a melee button repeats at 0.20-second intervals, up to five hit attempts per second. Independent fingers allow moving, looking, and attacking together. Combat input is blocked during aura selection.

Each attack press starts exactly one action. The player has four timed, full-body skeletal clips: left and right punches, plus left and right kicks. Every clip includes a chamber, contact, follow-through, and guarded recovery; the contact marker matches that move's existing hit timing. Punch and kick presses now play a bright, animated sweep across the center of the screen, so the move is visible even when it misses. A confirmed hit adds an expanding emissive burst at the target. The character keeps the model's imported idle animation between attacks. Holding a melee key repeats at the same cadence; every hit remains a distinct manual attack.

Both punch clips extend the striking fist along the player's forward direction at contact, including after the player turns. The unanimated fallback punch pose uses the same direction. The headless rig check measures each wrist relative to its shoulder and player heading.

The imported Thornbound rig has no finger joints, so the existing hand meshes remain unchanged.

The zombie rig is turned to face the same forward direction used by its approach and attack logic.

The camera uses a close **Resident Evil 4-style right-shoulder viewpoint** matching the provided composition reference. The follow pivot sits **1.55 m** above the player's ground origin, with **2.35 m** spring-arm reach, **0.75 m** right shoulder offset, a **6° downward** pitch and **60°** vertical field of view. The character stays to the left of screen center while the open center looks down the forward combat lane. The camera smoothly follows facing direction, the spring arm retracts near walls, and it ignores the player's own collision body. Heights are absolute offsets from the player origin, not an extra 1.5 m on top of another pivot.

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

The test build uses the Bijatyka app name and package ID so it installs beside earlier Retribution foundation APKs signed with a different debug key.
