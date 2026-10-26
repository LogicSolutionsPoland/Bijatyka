# Skip covered ground shading

The 220 m ground plane already rejects fragments farther than 30 m, but it
previously calculated four procedural noise layers and the crack pattern for
nearby floor pixels that the flashlight's later full-screen pass turns fully
black. The ground shader now rejects these pixels before doing that work. Its
test matches the mask's `-0.22 m` soft sector edge and keeps the full `2.1 m`
player area; the 22–30 m radial fade, floor detail in visible areas, and
30 m distance cutoff remain intact. Camera yaw and ground uniforms update in
the same frame. With the flashlight disabled, the ground follows its previous
path.

The development profiler adds **Floor skip ON/OFF**. Hold the top-right corner
for 1.5 seconds or press F3. Compare 20 seconds ON, OFF, ON at the same camera
position, with the mask ON, map ON, 0.67x rendering and normal 5 zombies.
Record FPS, frame processing, draw calls and device temperature after warmup.
The **Mask OFF** comparison also turns floor skipping off so it still isolates
the entire visibility pass. This optimization does not change zombie AI,
collision, spawning, combat, controller bindings, HUD or the Burning Horizon.

Godot 4.7.2 local headless import, gameplay, visibility, environment and scene
smoke checks cover the wiring. The Compatibility pixel probe in CI covers the
lit and black sectors at native and 0.67x scales. Headless checks cannot
measure GPU fragment cost, and desktop software rendering is not a phone FPS
measurement. Retain or expand this change based on the Android ON/OFF result.
