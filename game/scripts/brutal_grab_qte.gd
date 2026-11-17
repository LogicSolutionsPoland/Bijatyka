extends RefCounted
## Stage 2 progress/timer component. FoundationPlayer exclusively owns the grab state.
## No SceneTree timers, physics nodes, or per-enemy processing.
var _session_id := 0
var _enemy_ref: WeakRef
var _limb := ""
var _remaining_seconds := 0.0
var _required_presses := 0
var _press_count := 0

func begin(session_id: int, enemy: Node, limb: String, duration_seconds: float, required_presses: int) -> bool:
	if is_active() or session_id <= 0 or not is_instance_valid(enemy) or limb.is_empty():
		return false
	if duration_seconds <= 0.0 or required_presses < 1:
		return false
	_session_id = session_id
	_enemy_ref = weakref(enemy)
	_limb = limb
	_remaining_seconds = duration_seconds
	_required_presses = required_presses
	_press_count = 0
	return true

func is_active() -> bool:
	return _session_id > 0

func matches(session_id: int, enemy: Node, limb: String) -> bool:
	return is_active() and _session_id == session_id and is_instance_valid(enemy) and _enemy_ref != null and _enemy_ref.get_ref() == enemy and _limb == limb

func accept_press(session_id: int, enemy: Node, limb: String) -> bool:
	if not matches(session_id, enemy, limb) or _remaining_seconds <= 0.0 or _press_count >= _required_presses:
		return false
	_press_count += 1
	return true

func is_complete() -> bool:
	return is_active() and _press_count >= _required_presses

func advance(session_id: int, delta: float) -> bool:
	if not is_active() or session_id != _session_id:
		return false
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	return _remaining_seconds <= 0.0

func get_remaining_seconds() -> float:
	return _remaining_seconds if is_active() else 0.0

func get_press_count() -> int:
	return _press_count if is_active() else 0

func get_required_presses() -> int:
	return _required_presses if is_active() else 0

func cancel(expected_session_id: int = -1) -> void:
	if not is_active() or (expected_session_id >= 0 and expected_session_id != _session_id):
		return
	_session_id = 0
	_enemy_ref = null
	_limb = ""
	_remaining_seconds = 0.0
	_required_presses = 0
	_press_count = 0
