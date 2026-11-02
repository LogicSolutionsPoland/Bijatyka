# Five-zombie normal gameplay budget (Android)

## Normal-game configuration

- Exactly **5 ordinary living zombies** are requested for the initial horde. Their starting positions are distributed in the concealed **36–64 m** ring around the player's protected base; they do not spawn directly in the visible 30 m area.
- The spawn director caps the ordinary living zombie population at **5** and keeps the replacement queue within this budget. After a normal zombie is defeated, it requests another zombie roughly **50 m** ahead of the player's movement/facing, outside the camera-visible envelope, without teleporting an existing live enemy.
- The **boss is a separate encounter** and does not count toward the five ordinary zombies. Normal play can contain five ordinary zombies plus one boss.
- The 30 m visibility range, flashlight semicircle, player base, Burning Horizon, combat rules, on-screen controls, and Android rendering configuration are unchanged.
- Debug-only profiling retains 15, 20, 69, 100 and 200 zombie stress scenarios. Pressing Stop restores the normal five-zombie population.

## Animation and graphics capacity

The normal five-zombie limit reduces the maximum ordinary-enemy count by **10/15 (about 67%)** compared with the previous normal population of 15. This is an entity-count reduction, not a measured 67% improvement in CPU, GPU, memory, FPS or battery use.

The existing ordinary-enemy detailed-skeleton budget remains at 20 resident rigs. All five living ordinary enemies can fit within that budget when the scheduler considers them eligible; dying rigs may temporarily occupy slots. The fog-silhouette MultiMesh retains capacity for 200 because debug stress scenarios use it. Reserved capacity does not spawn additional ordinary zombies.

## Android measurements

Profile the normal five-zombie scene on the target Android phone with the profiler. Compare the same camera position and rendering settings before and after, including frame time, physics time, memory, heat, and battery drain. Also check several simultaneous attacks, deaths, and replacements while the flashlight and Burning Horizon are active. Headless and desktop software-renderer samples cannot establish phone FPS.

## Verification

The existing gameplay checks cover the five-zombie default and initial spawn distribution, the absence of a queued sixth ordinary zombie, the flashlight's preservation of the 5/200 normal/stress distinction, and the death/replacement path. Debug headless stress scenarios continue to exercise 15, 20, 69, 100 and 200 zombies.