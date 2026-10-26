# Camera configuration

| Setting | Value / rule |
|---|---|
| Follow pivot | 1.20 m above the player's ground origin |
| Follow distance | 2.50 m for a close third-person shoulder view |
| Vertical field of view | 66 degrees |
| Initial pitch | 16 degrees downward, with the existing touch and gamepad limits |
| Horizontal framing | Shoulder offset recomputed from viewport aspect to place the player at x = 35% |
| Tracking | Existing exponential follow smoothing, 7.5 response |
| Aim | Camera yaw; flashlight direction updates from the same yaw every rendered frame |
| Player world position | Existing protected-base start position, unchanged |

The tighter framing keeps the player large on the left while leaving the combat lane ahead visible. Camera tests project the player's feet into the viewport at 4:3, 16:9, and 21:9 sizes and exercise touch-drag, gamepad look input, follow movement, and vertical jump/dash movement. The screen-space composition is a camera projection; no model-only world-space translation is used.
