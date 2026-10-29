# Mobile ground detail comparison

The phone still runs poorly after rejecting floor fragments hidden by the
flashlight mask. This pass keeps the visible ash and crack pattern while
reducing work on the lit floor: the mobile shader keeps its two smooth broad
noise layers and original fracture lines, uses one cell hash for subtle fine
grit, and derives the warm stain from the existing smooth layers. Desktop
retains the original full-detail path. The 30 m edge, semicircle, player keep
area, camera, 5-zombie population, controls, map and Burning Horizon stay as
before.

The desktop rendered comparison found little clear change from FAST floor
alone: 79.31 ms FULL, 78.94 ms FAST, then 86.71 ms FULL. Turning off four
local lights measured 72.60 ms versus 82.19 ms with them on; mask OFF was
77.23 ms versus 81.98 ms ON. These are 60-frame software desktop samples with
the scene frozen, not Android GPU results. To test a stronger phone preset,
Android now starts at **0.50x 3D scale**, with local light passes OFF and floor
FAST. The lamp and brazier meshes remain emissive, and the white forward
flashlight, 30 m visibility and 2D HUD remain.

The debug profiler can switch **Floor FAST/FULL**, **Lights OFF/ON** and 3D
scale between 0.50x, 0.67x and 1.00x. On the phone, hold the empty top-right
corner for 1.5 seconds. At one camera position, Mask ON, Map ON and 15 normal
zombies, warm up and compare 20 seconds each at 0.50x, 0.67x and 1.00x.
Then at 0.50x compare Lights OFF/ON/OFF and Floor FAST/FULL/FAST. Record FPS,
frame processing, physics, draw calls, rendered objects, phone model and
whether the floor and lamps look good. Keep **Floor skip ON** throughout.

Only the phone comparison can establish an Android FPS gain. If changing scale
has little effect while the game remains slow, inspect animation, AI and
physics on device before further reducing visual detail.
