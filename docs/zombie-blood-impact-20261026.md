# Animated zombie blood impact (2026-10-26)

## Implemented

- Source: `brackeys_vfx_bundle.zip`, `predrawn/blood_impact_6x5.png` (CC0).
- Derivative: `game/assets/vfx/brackeys_blood_impact_6x5.png`, downscaled from 414x300 to **138x100** with nearest-neighbour sampling. Verified Git blob: `bb2cfc66e88b6dbcb04ecba3a7756db267796538`.
- License and creator credits: `game/assets/vfx/BRACKEYS_LICENSE_AND_CREDITS.txt`.
- Existing `FoundationCombatFxPool.play_zombie_hit_flash` now displays a `Sprite3D` billboard with a 6x5 flipbook for 0.28 seconds instead of the previous glowing impact sphere.
- Frames 1–23 used; final empty atlas frames skipped. The splash fades before the effect ends.
- The sprite is offset toward the viewer by up to 35 cm to prevent its depth-tested image from being buried inside the struck zombie.
- Existing range-culling at 30 m remains and the `zombie_hit_flash` pool cap stays at six instances; no new collision, damage, or spawn logic.
- The entire original 28 MB bundle is **not** committed, only a single optimized 1.37 KB CC0 derivative.

## Runtime verification still required

Standalone test (introduced in this branch):
```bash
godot --headless --path game --script res://tests/blood_impact_test.gd
```

After a Godot 4.7.2 editor import:
```bash
godot --headless --editor --path game --import --quit
```

Test on Android Compatibility rendering: hit five ordinary zombies with both hands and kicks, verify blood is visible at the point of impact, does not float excessively, and disappears in under 300 ms. Check near/far culling and FPS impact on the target phone.

**Status:** committed to a dedicated feature branch. Static review and Git blob verification only. No Godot runtime tests, Android APK export, GitHub Actions run, PR merge, or change to `main` has been performed.
