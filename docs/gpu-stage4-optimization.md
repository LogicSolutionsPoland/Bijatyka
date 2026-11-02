# GPU Stage 4 — Android textures, geometry and transparent fill

Base: PR #57 head `37a82556ce21e166e63730b49169c443e047d1fc` (the Godot 4.7.2 regression job passed). Branch: `feat/gpu-stage4-android-resources-20261102`. The first branch commit, `dc321a441f555086e9fd5fb7a4d9f398fd1e1418`, adds the unchanged 30-zombie benchmark and repairs the typed-array runtime error found by that benchmark. No APK was exported.

## Audit and changes

| Area | Observed at PR #57 | Stage 4 action |
| --- | --- | --- |
| Courtyard boxes | 62 decorative boxes had their own mesh and scene node, despite shared ruin materials. The nature pack already uses four MultiMesh batches and 103 map boxes already share seven batches. | Group only the 62 decorative boxes by material and 12 m spatial cell into 33 MultiMeshes with one shared unit box. This reduces direct courtyard render nodes from 108 to 79. Mesh positions, nonuniform size, rotation, ruin materials, physical cover and 35 spawn blockers are retained. Each cell has an explicit world-correct bound, so a cell can be frustum culled and the existing 120 ms distance pass can reject it conservatively. No per-frame batch rebuild or scene scan was added. |
| Dormant silhouettes | The `Node.call()` result was an untyped `Array` assigned to `Array[Dictionary]`, producing a script error each 30 Hz crowd refresh. One shared silhouette MultiMesh has a conservative 220 m AABB and 200 slots for debug scenarios. | Correct the assignment and skip an unchanged `visible_instance_count` upload. Keep the shared mesh, record visibility, 7-rig budget, 10/5 m sleep/wake rules and spawn system. The large bound remains to prevent missing moving silhouettes. |
| Flashlight | Three longitudinal sheets already share one MultiMesh and seven transverse quads share one mesh/surface. The circular section fade has identically zero alpha at radius >= 1, but the square's corners still execute the rest of the fragment shader and blend. | Discard only those zero-alpha corners before the remaining shading. Preserve all seven sections, three full-volume sheets, intensity, opacity, range, depth test and rooftop off-switch. |
| Texture imports | The active tree bark (1024²), bark normal (512²) and rock diffuse (512²) were imported losslessly without mipmaps in the Godot 4.7.2 baseline. The GLTF scenes resolve the shared external files. | Track explicit VRAM-compressed ETC2/S3TC imports with mipmaps at their original resolutions. The model's material references still resolve the same `res://` textures and runtime inspection confirms mipmaps. Their uncompressed source pixels total about 5.75 MiB before GPU format and mip levels; actual Android VRAM savings have not been measured. |
| Other textures | The 1024² alpha cutout leaves, 1536×768 rooftop photo and embedded Exo Gray, Universal Base, boss and other model textures are visually sensitive or have separate model import paths. | Keep their source resolution and import choices until on-device image comparisons justify a change. No redundant runtime texture load was found in the inspected active paths. |
| Pencil / loading | The Compatibility screen pass samples the finished image and depth; Stage 3 already skips depth/normal work where graphite lines cannot contribute. The elevator reveals the existing map batches over frames and warms the ground profile. | Preserve the shader, roof toggle, loading steps and camera-independent ride-start trigger. Smaller courtyard node count also shortens the existing visibility walk. |

The flashlight's full-screen visibility mask, Pencil screen shader, transparent Burning Horizon, silhouette batch bounds and large embedded character textures remain candidates for measured work. Aggressive grouping of the entire 220 m map would defeat per-cell frustum culling; changing the beam or photo without rendered comparisons risks visible differences.

## Reproducible measurement

Godot 4.7.2 command after `godot --headless --editor --path game --import --quit`:

```sh
godot --headless --path game --script res://tests/gpu_stage4_benchmark.gd
```

The benchmark starts a fixed 30-zombie concentrated ground scene, warms up for 90 frames and samples 180 frames. It prints `STAGE4_PERFORMANCE_SAMPLE`, including both living actors and reserved population slots: an actor may die during a sample while its animation or concealed replacement reserves its slot. Desktop software OpenGL uses the same script under `xvfb-run` with `LIBGL_ALWAYS_SOFTWARE=1`, `--rendering-driver opengl3` and dummy audio in GitHub Actions. These are host CPU and software-renderer samples, not Android FPS or GPU time.

| Local headless host, one sample | Pre-geometry baseline (array error repaired) | Stage 4 working tree |
| --- | ---: | ---: |
| Wall interval average, ms | 6.958 | 6.916 |
| Wall interval P95, ms | 8.737 | 8.614 |
| Process monitor average, ms | 39.368 | 49.893 |
| Physics monitor average, ms | 130.937 | 156.867 |
| Static memory monitor peak, MiB | 144.3 | 139.7 |
| Direct courtyard render nodes | 108 | 79 |
| Rendered draw calls / rendered objects | N/A (headless) | N/A (headless) |
| GPU frame time / Android FPS / Android VRAM | N/A | N/A |

The first uncorrected run at PR #57 logged repeated `SCRIPT ERROR` messages and is **not** a valid performance baseline. The corrected one-run CPU timing differences are small and noisy; they do not establish an Android FPS improvement. The 29-node reduction is deterministic.

| GitHub Actions, 180 samples | Corrected baseline `dc321a4` | Stage 4 `2c78b9e` |
| --- | ---: | ---: |
| Headless wall interval average / P95, ms | 6.922 / 8.068 | 6.934 / 8.292 |
| Headless static memory monitor peak, MiB | 144.3 | 139.6 |
| Desktop software OpenGL wall interval average / P95, ms | 173.840 / 188.549 | 176.172 / 185.696 |
| Desktop software OpenGL draw calls average | 191.1 | 179.8 |
| Desktop software OpenGL rendered objects average | 399.0 | 389.7 |
| Desktop software OpenGL static memory monitor peak, MiB | 70.6 | 70.3 |
| Android GPU frame time / VRAM / FPS | N/A | N/A |

The baseline [Actions run](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/41374742180) passed. The implementation [Actions run](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/41375075797) passed import, all headless tests and both benchmarks; its final rendered-probe step then reported GL textures retained at process shutdown after test-only texture image readbacks. Restoring the roof and clearing the Pencil test cache alone did not remove this warning in [the next run](https://github.com/LogicSolutionsPoland/Bijatyka/actions/runs/41375465907). The rendered test now checks `Texture2D.has_mipmaps()` directly instead of `get_image()`, which fetches image data from the GPU; the headless dummy renderer still checks the CPU image because its texture properties are unavailable. A rerun must pass before PR #58 is ready for mobile review. The draw-call reduction is observed on the desktop software renderer; the small timing shifts run in opposite directions and cannot establish Android throughput or thermal gains. Phone GPU measurements remain outstanding.

## Validation and device checklist

The Stage 4 workflow imports with Godot 4.7.2, runs the 30-zombie benchmark plus the existing movement, animation, zombie, flashlight, roof, elevator, boss and resource tests, then runs Compatibility software-rendered shader/pixel probes. It rejects `SCRIPT ERROR` and `ERROR` lines and uploads logs. `gpu_stage4_test.gd` checks 62 placements in 33 cells, shared mesh/materials, conservative bounds, collisions and blockers, rooftop/ground effects, compressed mipmapped textures, four rooftop records and the seven-rig budget. A rendered run additionally reads back MultiMesh transforms because Godot's headless dummy renderer returns identity for those reads.

On **Redmi (Android 16)**, use one eventual Stage 4-inclusive APK after later stages: warm up the phone consistently, record 30-zombie ground combat and elevator descent for at least five minutes, compare against the Stage 3 APK at the same 40% 3D scale and 60 FPS cap, and collect average/P95 frame time, draw calls, GPU time, VRAM/RAM and temperature if the device profiler exposes them. Capture matched screenshots of roof, full 3D beam through and behind cover, Pencil ground, silhouettes, tree leaves/bark, rocks, boss and close Exo Gray. Confirm combat pressure, wake/dormancy, four attackers and no pop-in or transition hitch.

On **Samsung (Android 7)**, first confirm that the later ARM64 GL Compatibility build installs and launches. If compatible, repeat the same visual and 30-zombie/elevator checks at identical settings; report unavailable GPU counters as unavailable. A CI software OpenGL pass cannot substitute for either phone test.

## Stage 5 recommendation

Profile representative Redmi combat and descent traces. Prioritize the measured largest of Pencil screen fill, flashlight mask/transparent beam, model materials/embedded textures, or 120 ms CPU visibility spikes. Make any adaptive quality optional and stable, then compare images and frame-time percentiles before changing release graphics.
