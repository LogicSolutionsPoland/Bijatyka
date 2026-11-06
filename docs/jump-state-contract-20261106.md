# Jump state contract

Ordinary Jump and forward Jump share one exclusive jump state. The first valid
request owns that state until the landing completes or respawn cancels it. A
later request cannot replace the active arc, re-arm the ordinary landing
impact, or emit a second jump's signals.

When both desktop actions are pressed in one input sample, ordinary Jump has
priority because the controller samples it before forward Jump. Separate HUD
or gamepad callbacks use the same first-request rule: whichever valid callback
arrives first owns the jump. The rule applies before the next physics step, so
the cached `is_on_floor()` result cannot admit a second jump after takeoff.

Forward Jump uses the configured 5 m travel and emits its start and landing
signals once on a completed arc. Wall contact stops horizontal travel while
the vertical arc continues to landing. It never arms the ordinary landing
impact. Respawn clears jump ownership and pending impact state.

`game/tests/jump_state_regression_test.gd` checks both request orders in the
same frame, a second request immediately after takeoff, normal landings, the
5 m forward path, and wall-obstructed travel. The Stage 6 integrated test also
checks the forward path and horde activation behavior.
