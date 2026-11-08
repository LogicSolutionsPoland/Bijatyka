# Visibility and rendering

The mask uses world-space depth rather than a screen-space wedge, so the ground footprint remains a 30 m forward semicircle under perspective. It is independent of camera frustum selection: an enemy must be inside both the lit sector and the camera view before its ordinary visual tier is prepared.

The shared manager uses five bands: visible close (0–18 m), visible distant (18–30 m), dark but combat-close (0–18 m), dark distant (18–30 m), and beyond the existing 30 m render boundary. An enemy's movement, AI, collision, damage, and death state are not changed by the band. Sector eligibility has 0.65 m hysteresis. The shader retains the existing 30 m radial limit and softly fades from 22 to 30 m.

`HordeFarVisuals` compacts only eligible low-poly silhouettes into the existing MultiMesh instance prefix. Full rigs are selected only from visible close actors and continue to share the 20-resident pool, including dying-actor reservations. No per-enemy flashlight, material, or light is created. Boss simulation and its HUD marker are independent of the ordinary-horde classifier.

The mode uses one full-screen pass because the world includes unshaded materials, emissive props, the Burning Horizon, and imported meshes that cannot all be forced into a single shared surface shader. It runs after transparent 3D effects and before CanvasLayer HUD. The Compatibility renderer supports screen and depth textures; no compute shader, shadow map, volumetric effect, or extra viewport is used.
