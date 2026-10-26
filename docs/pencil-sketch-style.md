# Pencil Sketch gameplay style

The source shaders and helper in `game/scripts/pencil.gd` and `game/shaders/pencil*.gdshader` come from the supplied Pencil project by Francisco Cidade (CC0; `game/shaders/PENCIL_LICENSE.txt`). The demo assets and scene are not part of Bijatyka.

The real `foundation.gd` scene converts its lit, opaque character meshes after the level is built, sets a restrained wash, and adds the **GL Compatibility** depth and paper screen pass to the active camera. The `PencilSketchStyle` autoload shares material conversions and styles replacement zombies. The helper skips unshaded, emissive, additive, transparent, and custom shader materials, preserving the HUD, health indicators, flashlight, Burning Horizon and combat effects. Custom ruin surfaces keep their original weathering shader and receive a geometric pencil outline; the screen pass draws contours over their depth too.

The pencil screen material renders at priority 126 before the flashlight composite at priority 127. This keeps the half-map darkness black. Repeated calls for the same camera return the existing screen material, and attaching another camera disables and frees the old pass in the same viewport.

The actual five-zombie playable scene is captured by `tests/pencil_render_probe.gd` in the Compatibility renderer. Its pixel comparison checks that enabling the pass changes a substantial part of the rendered scene, while the captured image is available for visual review. This is desktop software GL validation; an Android phone is still required for device frame rate, thermal behavior, touch feel and GPU driver checks.
