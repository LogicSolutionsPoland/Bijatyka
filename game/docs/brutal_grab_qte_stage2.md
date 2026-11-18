# Brutal Grab — Stage 2 QTE and Stage 3 integration contract

## Ownership

`FoundationPlayer` is the **only** owner of the Stage 1 grab state, active enemy, limb and session identity.
`brutal_grab_qte.gd` is a lightweight `RefCounted` progress/deadline helper, not a second grab state machine. It has no Node timer or per-enemy processing. Attacker slots remain managed by the existing AI/spawn director.

## Lifecycle and defaults

`READY → WINDUP → GRABBED → ESCAPED / FAILED → RECOVERY → READY` is unchanged.
The QTE begins **only** after `GRABBED`. Defaults: 1.5 seconds; 3 distinct presses. Configure per player with `grab_qte_duration_seconds` and `grab_qte_required_presses`.
The player's physics tick advances the QTE deadline; a paused scene does not advance it. The legacy `_limb_grab_time` mirrors the QTE countdown for compatibility; it is no longer a second timer.
One press increments progress and leaves the grab intact. The third press calls the existing authoritative `_finish_limb_grab("escaped")` path. Timeout calls `_finish_limb_grab("timeout")`.
A dead/despawned attacker, invalid role reservation, player death/respawn, scene exit or explicit cancellation invokes existing interruption cleanup and cancels QTE immediately.

## Read-only API for Stage 3 IK

Obtain the player from the active scene. Never mutate its `grab_state`, `_limb_grab_owner`, or attacker slots.

- `grab_established(enemy: FoundationEnemy, limb: String)` is the canonical Stage 1 contact event.
- `get_active_grab_enemy() -> FoundationEnemy` and `get_grab_limb() -> String` return the currently held attacker and selected left/right arm.
- `get_active_grab_session_id() -> int` returns a monotonic, nonzero session ID only in `GRABBED`; returns 0 otherwise.
- `grab_qte_started(session_id: int, enemy: FoundationEnemy, limb: String, required_presses: int, duration_seconds: float)` fires once for the committed grab after `grab_established`. Bind future IK attachment to this exact enemy, limb and ID.
- `grab_qte_progress(session_id: int, accepted_presses: int, required_presses: int, remaining_seconds: float)` emits on the initial contact, on accepted presses, and during remaining-time updates. The HUD uses this; IK should normally ignore updates.
- `grab_qte_finished(session_id: int, outcome: String)` fires once at the **end** of cleanup, after `grab_fully_ended`. `outcome` is `escaped`, `timeout`, or an existing interruption reason, e.g. `enemy_died`, `enemy_despawned`, `player_dead`, `respawn`, `reservation_lost`, `cancelled`, or `scene_exit`.
- Existing `grab_escaped(enemy, limb)`, `grab_failed(enemy, limb)`, `grab_interrupted(reason, enemy, limb)`, `limb_grab_ended` and `grab_fully_ended(reason)` retain Stage 1 meaning.
- `get_grab_qte_progress()`, `get_grab_qte_required_presses()`, and `get_grab_qte_remaining_seconds()` are read-only UI helpers. All return zero outside a held QTE.

**Stage 3 safety:** store the bound session ID and weak attacker reference on contact; ignore mismatched later events. Detach procedural contact on `grab_escaped`, `grab_failed`, `grab_interrupted` or `grab_fully_ended` regardless of reason, then ignore duplicate `grab_qte_finished`. Never create a second grab owner or hold onto a freed enemy.

## Input edges

- Gamepad R3: `pad_escape_limb_grab` → existing HUD action `escape_limb_grab`; HUD's held-action dictionary emits once on press and requires release before another press. Duplicate pressed events while held do not count.
- Touch: existing `EscapeLimbGrab` Button `pressed` → same HUD action. Each button press is one edge.
- Keyboard R: `escape_limb_grab` `Input.is_action_just_pressed()` → same player API.
- `try_escape_limb_grab(session_id: int = -1) -> bool` accepts a press only while grabbed and unpaused. A supplied stale session ID fails without changing progress. The return value means an input was **accepted**, not that the grab has ended.
- Normal attacks, jumps and magic are blocked by the existing Stage 1 guards while `GRABBED`.

## Test and release

The no-APK GitHub Actions workflow `.github/workflows/brutal-grab-stage1-validation.yml` imports Godot 4.7.2 and runs Stage 1, new Stage 2, integrated Stage 6, jump and gameplay headless scripts. A host PASS is **not** an Android device result. Stage 3 should not start until these checks succeed and gameplay is reviewed.
