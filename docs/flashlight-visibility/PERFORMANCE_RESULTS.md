# Performance results

Godot 4.7.2 headless benchmark comparison. The baseline is the verified gameplay commit `f42e27a8f61734a81699085cf9872085eac3d2be`; its benchmark runner was extended only to include the existing 69-zombie population. Final values come from one run of each scenario on the implementation branch. The runner measures concentrated fights and 50 m concealed approaches at 20, 69, 100, and 200 ordinary zombies.

| Population | Scenario | Baseline CPU avg (ms) | Final CPU avg (ms) | Baseline physics avg (ms) | Final physics avg (ms) | Baseline wall p95 (ms) | Final wall p95 (ms) | Peak selected rigs, baseline → final | Peak resident rigs, baseline → final | Peak memory, baseline → final (MiB) |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 20 | Concentrated | 8.386 | 9.132 | 78.081 | 86.083 | 8.683 | 8.888 | 20 → 5 | 20 → 5 | 49.2 → 48.8 |
| 69 | Concentrated | 4.130 | 5.181 | 6.557 | 4.815 | 10.704 | 10.896 | 20 → 20 | 20 → 20 | 51.5 → 51.7 |
| 100 | Concentrated | 6.275 | 8.131 | 5.073 | 5.536 | 12.484 | 11.909 | 20 → 20 | 20 → 20 | 53.0 → 53.2 |
| 200 | Concentrated | 7.107 | 14.946 | 12.972 | 7.235 | 16.691 | 15.421 | 20 → 20 | 20 → 20 | 57.7 → 57.9 |
| 20 | 50 m approach | 9.380 | 8.897 | 11.334 | 12.058 | 7.964 | 7.862 | 0 → 0 | 20 → 20 | 50.3 → 50.5 |
| 69 | 50 m approach | 2.221 | 1.383 | 6.897 | 2.723 | 9.836 | 8.834 | 0 → 0 | 20 → 20 | 52.1 → 52.4 |
| 100 | 50 m approach | 0.885 | 0.970 | 25.781 | 4.185 | 9.672 | 9.518 | 0 → 0 | 20 → 20 | 53.3 → 53.6 |
| 200 | 50 m approach | 1.973 | 2.865 | 20.584 | 7.561 | 11.211 | 10.826 | 1 → 0 | 20 → 20 | 57.2 → 57.5 |

The headless frame p95 is measured by the benchmark harness wall clock. The engine's `Engine` processing and physics averages vary substantially between isolated runs, so this single-run comparison does not establish a stable CPU improvement or regression. The clearest observed structural change is that the concentrated 20-zombie case selected five visible rigs instead of 20; at 69–200 the existing 20-rig cap remains in force. Memory stayed within 0.4 MiB of baseline in these samples. Model creations/reuses and all eight raw samples are in the workflow log.

| Measurement | Result |
|---|---|
| FPS / rendered frame time | N/A — headless run |
| Draw calls / rendered objects | N/A — headless run |
| Runtime model creation / reuse | Measured and emitted per scenario; no pool overflow in the captured runs |
| Shader errors | None reported by the successful import, shader compile, and Compatibility render-probe workflow |
| Android GPU time, FPS, heat, battery | Not measured; no 30/60 FPS claim |

The Compatibility software-rendered mask probe is reported separately from headless timings. Software Mesa does not represent Android GPU performance.
