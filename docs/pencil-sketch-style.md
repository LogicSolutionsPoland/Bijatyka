# Pencil Sketch gameplay style

The helper and material, outline, and GL Compatibility screen shaders in `game/scripts/pencil.gd` and `game/shaders/pencil*.gdshader` come from the supplied Pencil project by Francisco Cidade (CC0; `game/shaders/PENCIL_LICENSE.txt`). The demo scene and art are not imported.

The real `foundation.gd` scene converts its lit, opaque character meshes after level setup and adds the Compatibility depth/paper screen pass to the active camera. The style manager shares materials and styles new zombies after spawning. The source shader draws visible, wavering graphite hatching; a second material pass draws irregular mesh outlines. The latest floor, ruin, and far-zombie graphite shaders remain in place. Custom ruin surfaces also receive a pencil outline.

Unshaded, emissive, additive, transparent, and custom shader materials retain their authored effects. The HUD and touch controls remain outside the 3D pass. The pencil composite renders at priority 126, before the flashlight darkens the final scene at priority 127. The earlier flashlight depth-edge ink was removed to avoid two competing screen outlines. Repeated calls for the same camera return the existing pass, while a new camera replaces the old pass in its viewport.

`tests/pencil_render_probe.gd` captures the actual game in GL Compatibility with five ordinary zombies moved into the camera view, checks material and screen-pass assignment, and compares rendered frames with the pass enabled and disabled. The build gate packages one ARM64 APK as `Bijatyka-PencilSketch-ARM64.apk` at version 0.1.4-pencil-drawn. Desktop software GL checks do not measure Android device performance or touch feel.
