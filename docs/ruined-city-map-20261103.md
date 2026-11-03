# Ruined city ground map

Base: `feat/gamepad-only-controls-20261103` (the Stage 6 flashlight branch plus gamepad-only controls). The original tower, elevator, central arena, four rooftop zombie records, thirty-zombie ground cap, flashlight radius and boss encounter are unchanged.

The old district covered roughly 46 m across a 220 m ground plane. The ground now contains connected asphalt streets and burned blocks across roughly 176 m from side to side. Sixteen charred building cores and sixteen vehicle chassis have static collision. Wrecks sit toward the road shoulders so the major lanes remain open. Broken upper floors, windows, rebar, embers, rubble and fourteen extra dead trees, rocks and shrubs add detail without dynamic lights, particles, new textures or shadows.

The city boxes reuse the existing ruined-surface shader and are batched by material and 24 m cell, with explicit rotated bounds. The 30 m flashlight profile distance-culls finished ground-level city cells. During an elevator ride, the existing coordinator reveals the new batches progressively behind its loading overlay. The 32 solid obstacles are registered as spawn blockers before the director begins; players and zombies collide with them, while concealed births cannot occur inside them.

The enemy AI still uses local direct pursuit rather than navigation around every building. Wide open streets preserve multiple approaches, but Android playtesting should confirm that zombies do not linger behind cover during a prolonged fight. The headless tests verify collision and street continuity, map batching, rooftop/ground switching, elevator loading, concealed spawning and gamepad gameplay. A rendered GL Compatibility review and phone frame-time check remain useful before merging into a release.
