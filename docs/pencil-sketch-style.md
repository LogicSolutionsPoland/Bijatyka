# Pencil Sketch 3D style

## Runtime style

The default project autoload applies one shared spatial shader material per source material to opaque, lit StandardMaterial3D surfaces. It keeps the original albedo texture and tint, reduces saturation, quantizes a simple camera-stable light into four graphite tones, adds UV-space crosshatching in shadows, and darkens view-facing edges for an ink contour. A double-sided variant preserves surfaces such as the torn cloak.

The style runs on the animated player, normal zombie rigs, and the reconstructed close-range zombie without changing their meshes, skeletons, animations, collision, or controls. Materials that are emissive, transparent, unshaded, or already use a custom shader are left intact so the Burning Horizon, flashlight composite, and red, orange, and magic effects keep their intended accents.

The existing ruined-surface and radial-ground shaders add restrained desaturation and world-space hatching. The distant zombie MultiMesh keeps one draw and receives matching graphite tones and contours in its existing crowd shader. No full-screen effect, outline pass, extra geometry, or additional draw call was added.

## Android budget

Character style shaders use one optional albedo sample, one shared material instance per source material, a few scalar operations, and anti-aliased procedural lines. They do not sample normal or roughness maps. Existing textures and geometric detail remain in place; the shader simplifies lighting and specular work.

## Validation and limits

The Compatibility renderer shader compile, actual scene capture, existing gameplay/combat/spawning/flashlight tests, and the ARM64 package checks run in GitHub Actions. CI CPU timings and software-rendered screenshots are not Android GPU measurements. A real device is needed to measure phone frame pacing, heat, and battery impact.

The edge contour is a Fresnel-style darkening in the material shader rather than a second-pass geometric outline. Hatching follows the source UVs on models and world axes on the arena surfaces. Emissive visual effects intentionally retain their authored colors.
