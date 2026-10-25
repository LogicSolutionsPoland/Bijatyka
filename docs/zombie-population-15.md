# Fifteen-zombie gameplay budget (Android)

## Shipped normal-game configuration

- Exactly **15 ordinary living zombies** are requested for the initial horde. Their starting positions are distributed in the concealed **36–64 m** ring around the player's protected base; they do not spawn directly in the visible 30 m area.
- The spawn director caps the ordinary living zombie population at **15** and keeps the replacement queue within this budget. After a normal zombie is defeated, it requests another zombie roughly **50 m** ahead of the player's movement/facing, outside the camera-visible envelope, without teleporting an existing live enemy. Spawn admission retains the existing query and per-frame spawn budgets.
- The **boss is a separate encounter** and does not count toward the 15 ordinary zombies. Consequently, there can be 15 ordinary zombies plus one boss.
- The 30 m visibility range, flashlight semicircle, player base, Burning Horizon, combat rules, on-screen controls, and Android rendering configuration are unchanged.
- Debug-only development profiling supports 15, 20, 69, 100 and 200 ordinary zombies as temporary stress scenarios, and pressing Stop restores 15. These stress scenarios are not the normal game mode.

## Animation and graphics capacity assessment

The normal 15-zombie limit reduces the maximum simultaneously living ordinary-enemy count by **54/69 (about 78%)** compared with the earlier 69-zombie game. This is **not** a measured 78% CPU, GPU, memory, FPS, or battery improvement.

The existing ordinary-enemy detailed-skeleton budget remains at 20 resident rigs and the existing visual tier scheduler still chooses detailed rigs based on distance, visibility, and combat priority. Therefore **up to all 15 living ordinary enemies can fit within the existing 20-rig budget**, when the scheduler considers them eligible. A few dying rigs may temporarily occupy slots. This does not automatically convert every distant or flashlight-hidden zombie into a rendered high-detail character.

The fog-silhouette MultiMesh retains capacity for 200 because debug stress scenarios explicitly require it; reserved capacity does **not** spawn additional ordinary zombies. The old 20-rig developer stress ceiling is retained to avoid invalidating existing performance regression tests.

The imported KayKit 1.1 and Quaternius Universal Animation Library Standard files are source libraries in `third_party/` and are not yet retargeted or active in gameplay. Raising texture resolution, increasing mesh complexity, or changing animation fidelity without Android measurements would be speculative.

## Required Android measurements before quality upgrades

Profile a normal 15-zombie scene on an actual target Android phone, with at least:
1. Fifteen active enemies outside the 30 m visibility boundary approaching the player.
2. Fifteen living enemies inside the visible 30 m ring, several in the 16–18.5 m detailed-rig transition band.
3. Multiple simultaneous animated attacks/deaths/replacements, both with flashlight and Burning Horizon active.
4. Warm and sustained GPU / CPU frame times, p95/p99 spikes, memory, heat and battery drain.

Compare measured frame time and resident rigs with the previous 69-zombie baseline on the same device. Only after these tests should the 3D mesh LOD distances, materials, texture budgets and bone animation quality be raised. No physical Android profiling was performed by this commit.

## Verification

The Godot tests cover the 15-zombie default and initial spawn distribution, the absence of a queued 16th zombie, the flashlight's preservation of the 15/200 normal/stress distinction, and the existing death/replacement path. Headless stress samples continue to exercise 15, 20, 69, 100, and 200 enemies, but they cannot establish on-device FPS.
