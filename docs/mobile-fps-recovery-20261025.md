# Mobile frame-rate recovery probe

The 25 October Android screenshots show Bijatyka's Thornbound HUD, protected orange base, new district scenery, and flashlight mask. They do not contain an FPS counter. The reported approximately 5 FPS is a phone observation and has not been independently measured here.

## Change

- Android now starts with 3D render scale `0.67` and Godot's bilinear upscaling. This reduces the 3D buffer's pixel count to about 45% of native. The 2D HUD and its touch positions stay at display resolution. Desktop and headless runs retain native 3D resolution.
- The flashlight shader fills uncovered sky with black before doing the depth-reconstruction matrices. The same 22 m bright, 30 m faded, forward half-disk and 2.1 m player keep area remain.
- Debug APKs expose `3D 0.50x`, `3D 0.67x`, `3D 1.00x`, and `Mask ON/OFF` in the existing F3 / top-right long-press profiler. The mask switch removes just the fullscreen pass for an A/B rendering comparison. It does not change zombie AI, physics, damage, or spawn count; turn it back on for normal play.

The source gives a plausible GPU load reduction, not a guaranteed FPS gain. A 5 FPS symptom can also come from the device's GPU driver, CPU frame work, debug build overhead, thermal throttling, or an unrelated regression.

## Android comparison

1. Install the `Bijatyka FPS Test` debug APK alongside the older build, leave the ordinary population at 5, and wait for the game and shaders to warm up. Hold the empty top-right corner for 1.5 seconds to open the profiler. This comparison package does not overwrite the existing Bijatyka app.
2. Keep the camera and encounter position fixed. Compare 20 seconds each at 1.00x, 0.67x, and 0.50x with the mask ON. Record FPS, frame processing, physics, draw calls, rendered objects, and phone model. Screenshot the profiler for each setting.
3. At 0.67x, switch only the mask OFF for 20 seconds, then ON again. This tests the fullscreen depth pass. Next switch the Map OFF and ON at the same position to isolate the district draw cost. OFF modes are diagnostic views, not normal gameplay.
4. Repeat with several zombies visible and again after several minutes of play. Check whether punch, kick, jump, dash, camera drag, boss marker, and the black region outside the semicircle still work.

If lowering scale raises FPS substantially, the bottleneck is likely GPU or per-pixel work. If scale does little while frame processing or physics is high, inspect CPU/AI and collisions. If disabling the mask raises FPS substantially at the same scale, investigate a cheaper flashlight implementation before increasing model or scenery complexity. These interpretations require on-device values; headless or desktop software rendering cannot establish phone performance.

## Local verification

Run Godot 4.7.2 import and the camera/flashlight, gameplay, horde, and scene checks. The GitHub validation workflow additionally samples the Compatibility flashlight pixels under Mesa. Export the complete ARM64 debug APK, check package contents, then do the Android comparison above.
