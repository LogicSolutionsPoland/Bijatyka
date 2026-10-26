# Mobile ground detail comparison

The phone still runs poorly after rejecting floor fragments hidden by the
flashlight mask. This pass keeps the visible ash and crack pattern while
reducing work on the lit floor: the mobile shader keeps its two smooth broad
noise layers and original fracture lines, uses one cell hash for subtle fine
grit, and derives the warm stain from the existing smooth layers. Desktop
retains the original full-detail path. The 30 m edge, semicircle, player keep
area, camera, 15-zombie population, controls, map and Burning Horizon stay as
before.

The debug profiler shows **Floor FAST** on Android and **Floor FULL** on
desktop; tap it to switch between the paths. On the phone, hold the empty
top-right corner for 1.5 seconds, keep the same camera position, 0.67x scale,
Mask ON, Map ON, and 15 normal zombies. After warmup, record three 20-second
readings in this order: FAST, FULL, FAST. Record FPS, frame processing, physics,
draw calls, rendered objects, phone model and whether the floor looks good.
The prior **Floor skip** control should stay ON for both modes.

The Compatibility software-rendered probe now records alternating full/fast
floor, local-light, and mask costs on a frozen scene. These results can identify
promising Android experiments, but only the phone comparison can establish a
mobile FPS gain. If scale and mask toggles were tested, use those readings to
decide whether the next change belongs in rendering or CPU/physics work.
