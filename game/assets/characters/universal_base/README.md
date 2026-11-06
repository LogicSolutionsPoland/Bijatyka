# Universal Base Characters

This CC0 character pack now supplies all animated humanoid visuals:
- Male model: player and regular enemies.
- Female model: boss.

The matching 65-bone Universal Animation Library rig is merged into both GLBs. The game uses its 43 original animation clips for locomotion, combat, and spells. Spell casts play Quaternius' `Spell_Simple_Shoot` clip; the game maps its movement, hit, dash, landing, and defeat actions to matching library clips.

The character models and animation library are CC0. See `LICENSE_CC0.txt` and `third_party/universal_animation_library_standard/License.txt`.

Ordinary enemies use the male body with a 512 px outfit and skin texture, `../infected/Ashen_Worker.jpg`. The crowd mesh in that folder derives from the same CC0 male body in a blended walk and push pose. Its single surface shares the outfit texture with the animated actors. The integer portions of its UVs encode the limb and gait weight for the crowd shader.
