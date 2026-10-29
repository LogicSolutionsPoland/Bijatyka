# Bijatyka graphics pass

This pass pushes the current mobile arena toward a gritty, readable Tekken-style survival stage while keeping the existing Thornbound and zombie assets.

- Ruined concrete, rusty trim, and arena props use a shared world-space weathering shader. Triplanar noise avoids visible texture stretching on box-shaped geometry.
- The 30 m ground surface adds ash variation, broken concrete seams, soot patches, rust stains, and a small number of low-energy ember glows.
- The existing 20 m burning-horizon planes gain a second skyline layer, scattered lit windows, moving smoke, and localized flame flicker. The custom sky gains a low sunset glow and slow smoke bands.
- The pass adds no texture downloads, particle systems, or additional lights. Shadows remain disabled.
- Gameplay limits remain 200 zombies, 50 m concealed arrivals, and 30 m visibility. The render path remains Godot 4.7.2 GL Compatibility for Android.

The Actions workflow validates asset and shader import, gameplay and spawn behavior, burning-horizon integration, and a headless scene smoke run, then exports an Android ARM64 debug APK. A successful CI export does not measure sustained performance or appearance on a physical phone.
