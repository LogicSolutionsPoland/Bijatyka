# Ashen quarantine district map

This pass turns the flat combat yard into a compact ruined city block around the existing orange safe ring.

- A cracked boulevard and cross street lead through the fight space.
- A handmade derelict transit car, entrance frame, lit route marker and shallow steps create a west-side landmark.
- An original memorial gate and stone markers create a second landmark to the east.
- Two broken facades frame the northern end of the road while keeping the center lane open for zombie approaches.
- A southern quarantine gate makes the area readable when the player turns around the safe base.
- All 103 static map boxes now share seven material-based MultiMesh draws, including the road marks, windows, curbs and debris. New scenery has no collision and casts no shadows, so it does not obstruct the direct-chase zombie behavior. The normal 30 m flashlight mask controls what is visible; the static batches use renderer frustum culling rather than per-box CPU distance culling.
- Surfaces reuse the existing procedural ruined-surface shader. No imported models, textures, lights or particles are added.

The map keeps the protected base, 15-zombie normal population, 50 m concealed arrivals, 30 m visibility/flashlight range, boss locator and combat controls. The user-provided scenery archive warns that its model licenses are unverified, so those third-party GLBs are excluded from this public source branch and any APK.

A Godot import, in-game render review and Android device visual check are still needed before calling the map visually verified.
