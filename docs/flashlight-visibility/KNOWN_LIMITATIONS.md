# Known limitations

- The mask adds one full-screen Compatibility pass. This gives consistent darkness for custom, unshaded, emissive, and imported materials, with fixed cost per pixel rather than per zombie. Mobile GPU cost still requires measurement on a representative Android device.
- Transparent 3D effects are drawn before the high-priority mask. The depth test uses the opaque world surface behind them; effects close to the player are retained by the player keep radius.
- The world-space beam assumes a flat ground plane for its range and 180-degree sector test. Tall buildings and elevated props inherit visibility from their ground-plane position, matching a ground footprint rather than a volumetric cone.
- The existing 30 m outer rendering boundary means distant Burning Horizon geometry is black in flashlight mode. The environment remains configured and can be restored by turning the mode off.
- Headless performance results cannot establish Android GPU frame rate, sustained 30/60 FPS, battery consumption, or thermal behavior.
