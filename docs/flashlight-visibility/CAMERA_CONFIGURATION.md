# Camera configuration

| Setting | Value / rule |
|---|---|
| Follow pivot | 1.55 m above player ground origin |
| Follow distance | 4.1 m |
| Vertical field of view | 66 degrees |
| Initial pitch | 4 degrees, with existing touch and gamepad limits |
| Horizontal framing | Shoulder offset recomputed from viewport aspect to target the player at x = 38% |
| Tracking | Existing exponential follow smoothing, 7.5 response |
| Aim | Camera yaw; flashlight direction updates from the same yaw every rendered frame |
| Player world position | Existing protected-base start position, unchanged |

Camera tests project the player feet into the viewport at 4:3, 16:9, and 21:9 sizes and exercise touch-drag, gamepad look input, follow movement, and vertical jump/dash movement. The screen-space composition is a camera projection; no model-only world-space translation is used.
