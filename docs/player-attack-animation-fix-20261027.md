# Player attack animation fix

Base: `codex/universal-base-characters-integration-20261027` at
`6c6dbdac3209297433ebf0de26ae078c49281666`.

The Universal Base player used rotations authored for the retired character's
different bone bases. World-space sampling showed both fists extending behind
the player, and each attack began and ended in the imported T-pose. Replaying
the same attack did not reliably restart its animation. Turning/landing could
also replace the visual while its damage timer continued.

The player now uses the supplied UAL `Punch_Jab` and `Punch_Cross`, resampled to
reach full extension at the existing 0.10-second damage boundary. Separate left
and right front kicks start from the source clip's complete closed-fist guard,
convert the kick axis into each bone's actual basis, chamber and extend at the
0.12-second contact boundary, and return to guard with the support foot planted.
The rear leg has additional hip travel to compensate for the source stance.
Original imported clips are preserved. No additional model downloads are needed.

Every accepted attack explicitly restarts playback. Player animation runs on the
physics clock and contact is synchronized with damage. Cosmetic actions cannot
replace an active melee animation; hit and defeat reactions retain priority.
Damage, reach, input mappings, five-strikes-per-second cadence, five ordinary
zombies, and the new player/enemy models remain unchanged.

The scene also referenced a deleted high-detail enemy property during startup,
preventing the HUD signal connections from completing. That obsolete shadow
comparison loop is removed; the current enemies retain their shadow-free setup.

Validation on Godot 4.7.2:

- The corrected regression suite exposed 32 failures against the original player
  controller; all 134 player animation checks pass after the fix.
- Gameplay/control checks include world-space fist direction, held-input cadence,
  all touch/gamepad actions, completed HUD initialization, and five-zombie setup.
- `player_attack_capture.gd` renders 16 deterministic guard, chamber, contact, and
  recovery views of the real player model for visual inspection.
- The Android export workflow gates the APK on animation/control checks, a
  240-frame playable-scene smoke run, rendered poses, and package content checks.

Android package version: `0.1.6-player-attacks`, code `6`, ARM64 debug.
Desktop Compatibility software rendering is verified; physical-phone motion,
touch feel, and frame rate still require on-device testing.
