extends SceneTree
## Deterministic Stage 2 host regression. Does not claim real Android results.
const WORLD := preload("res://scenes/foundation.tscn")
const ENEMY := preload("res://scripts/enemy.gd")

class Ledger extends Node:
	var locks: Dictionary = {}
	func grant(enemy: FoundationEnemy) -> void:
		locks[enemy.get_instance_id()] = true
	func can_maintain_limb_grab(enemy: FoundationEnemy) -> bool:
		return locks.has(enemy.get_instance_id())
	func release_attacker(enemy: FoundationEnemy) -> void:
		locks.erase(enemy.get_instance_id())

var checks := 0
var failures: Array[String] = []
var world: Node3D
var player: FoundationPlayer
var ledger: Ledger

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("Stage 2 QTE: " + description)

func _settle() -> bool:
	player.set_physics_process(true)
	player.global_position = Vector3(20.0, 1.2, 20.0)
	player.velocity = Vector3.ZERO
	for frame in range(130):
		await physics_frame
		if frame > 2 and player.is_on_floor() and is_zero_approx(player.velocity.y):
			player.set_physics_process(false)
			return true
	player.set_physics_process(false)
	return false

func _enemy() -> FoundationEnemy:
	var zombie := ENEMY.new() as FoundationEnemy
	zombie.set_physics_process(false)
	world.add_child(zombie)
	zombie.set_physics_process(false)
	zombie._player = player
	zombie.attack_director = ledger
	zombie.global_position = player.global_position + Vector3(1.25, 0.0, 0.0)
	ledger.grant(zombie)
	return zombie

func _reserve(enemy: FoundationEnemy, limb: String = "LEFT ARM") -> bool:
	player._limb_grab_cooldown = 0.0
	enemy.state = "limb_grab_windup"
	enemy._limb_grab_limb = limb
	return player.try_reserve_limb_grab(enemy, limb)

func _hold(enemy: FoundationEnemy, limb: String = "LEFT ARM") -> bool:
	if not _reserve(enemy, limb):
		return false
	enemy.state = "limb_hold"
	enemy.state_time = player.limb_grab_hold_seconds
	return player.begin_limb_grab(enemy, limb)

func _run() -> void:
	world = WORLD.instantiate()
	root.add_child(world)
	await process_frame
	player = world.get("player") as FoundationPlayer
	ledger = Ledger.new()
	world.add_child(ledger)
	_check(await _settle(), "player reaches floor")
	var starts: Array[int] = []
	var finishes: Array[Dictionary] = []
	player.grab_qte_started.connect(func(id: int, _enemy: FoundationEnemy, _limb: String, _presses: int, _seconds: float) -> void:
		starts.append(id)
	)
	player.grab_qte_finished.connect(func(id: int, reason: String) -> void:
		finishes.append({"id": id, "reason": reason})
	)
	var first := _enemy()
	var second := _enemy()
	_check(_reserve(first), "WINDUP accepted")
	_check(starts.is_empty() and player.get_active_grab_session_id() == 0 and not player._grab_qte.is_active(), "WINDUP cannot start QTE")
	_check(not player.try_escape_limb_grab() and not player.try_reserve_limb_grab(second, "RIGHT ARM"), "no early escape or second attacker")
	first.state = "limb_hold"
	_check(player.begin_limb_grab(first, "LEFT ARM"), "GRABBED transition accepted")
	var id := player.get_active_grab_session_id()
	_check(id > 0 and starts.size() == 1 and starts[0] == id, "one QTE starts on GRABBED")
	_check(player.get_active_grab_enemy() == first and player.get_grab_limb() == "LEFT ARM", "correct attacker and limb")
	_check(is_equal_approx(player.get_grab_qte_remaining_seconds(), 1.5) and player.get_grab_qte_required_presses() == 3, "configured 1.5-second, three-press QTE")
	_check(not player._grab_qte.begin(id + 1, second, "RIGHT ARM", 1.5, 3), "simultaneous second QTE rejected")
	_check(not player.try_escape_limb_grab(id + 10) and player.get_grab_qte_progress() == 0, "stale session press rejected")
	var hud := world.get("hud") as FoundationHUD
	hud._set_gamepad_action(&"pad_escape_limb_grab", 0, true)
	_check(player.get_grab_qte_progress() == 1 and player.get_grab_state() == FoundationPlayer.GrabState.GRABBED, "R3 counts one press without escape")
	hud._set_gamepad_action(&"pad_escape_limb_grab", 0, true)
	_check(player.get_grab_qte_progress() == 1, "duplicate held R3 event rejected")
	hud._set_gamepad_action(&"pad_escape_limb_grab", 0, false)
	hud._on_limb_grab_button_pressed()
	_check(player.get_grab_qte_progress() == 2 and player.get_grab_state() == FoundationPlayer.GrabState.GRABBED, "touch shares gamepad QTE")
	_check(player.try_escape_limb_grab(id) and player.get_grab_state() == FoundationPlayer.GrabState.READY, "third accepted edge escapes")
	_check(not player._grab_qte.is_active() and player.get_grab_qte_progress() == 0 and player.get_active_grab_session_id() == 0, "escape fully cleans QTE")
	_check(finishes.size() == 1 and finishes.back().id == id and finishes.back().reason == "escaped", "success signalled once with ID")
	_check(not ledger.locks.has(first.get_instance_id()) and first.state == "recovery", "attacker returned to recovery")

	var timed := _enemy()
	_check(_hold(timed, "RIGHT ARM"), "timeout case starts")
	var timed_id := player.get_active_grab_session_id()
	player._update_limb_grab(1.48)
	_check(player.get_grab_state() == FoundationPlayer.GrabState.GRABBED, "QTE alive before timeout")
	player._update_limb_grab(0.03)
	_check(finishes.back().id == timed_id and finishes.back().reason == "timeout" and not player._grab_qte.is_active(), "timeout fails and cleans")

	var paused_enemy := _enemy()
	_check(_hold(paused_enemy), "pause case starts")
	var remaining := player.get_grab_qte_remaining_seconds()
	paused = true
	player._update_limb_grab(9.0)
	paused = false
	_check(is_equal_approx(player.get_grab_qte_remaining_seconds(), remaining), "pause freezes timer")
	var cancelled_id := player.get_active_grab_session_id()
	player.cancel_limb_grab("cancelled")
	var finished_count := finishes.size()
	player.cancel_limb_grab("cancelled")
	_check(finishes.size() == finished_count and finishes.back().id == cancelled_id and not player._grab_qte.is_active(), "cancel and repeated cleanup safe")

	var victim := _enemy()
	_check(_hold(victim), "enemy death case starts")
	var victim_id := player.get_active_grab_session_id()
	victim.receive_hit(victim.hp + 1)
	_check(finishes.back().id == victim_id and finishes.back().reason == "enemy_died" and not player._grab_qte.is_active(), "death cancels proper QTE")
	var despawn := _enemy()
	_check(_hold(despawn), "enemy despawn case starts")
	var despawn_id := player.get_active_grab_session_id()
	despawn.queue_free()
	await process_frame
	_check(finishes.back().id == despawn_id and player.get_grab_state() == FoundationPlayer.GrabState.READY, "despawn releases QTE")
	var lost := _enemy()
	_check(_hold(lost), "ownership-loss case starts")
	var lost_id := player.get_active_grab_session_id()
	ledger.locks.erase(lost.get_instance_id())
	player._update_limb_grab(0.01)
	_check(finishes.back().id == lost_id and finishes.back().reason == "reservation_lost", "lost role cancels QTE")

	var fatal := _enemy()
	_check(_hold(fatal), "player death case starts")
	var fatal_id := player.get_active_grab_session_id()
	player.take_boss_damage(player.health)
	_check(finishes.back().id == fatal_id and finishes.back().reason == "player_dead", "player death cancels QTE")
	player._reset_at_safe_base()
	_check(player.get_active_grab_session_id() == 0 and not player._grab_qte.is_active(), "respawn has no stale QTE")
	_check(await _settle(), "respawn floor restored")
	var respawn := _enemy()
	_check(_hold(respawn), "respawn during grab case starts")
	player._reset_at_safe_base()
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and not player._grab_qte.is_active(), "respawn during hold releases it")
	_check(await _settle(), "player grounded before rapid sessions")

	var previous := id
	for index in range(4):
		var enemy := _enemy()
		_check(_hold(enemy, "RIGHT ARM" if index % 2 else "LEFT ARM"), "rapid grab starts %d" % index)
		var current := player.get_active_grab_session_id()
		_check(current > previous and not player.try_escape_limb_grab(previous) and player.get_grab_qte_progress() == 0, "old event rejected for rapid grab %d" % index)
		if index % 2 == 0:
			_check(player.try_escape_limb_grab(current) and player.try_escape_limb_grab(current) and player.try_escape_limb_grab(current), "rapid three-press escape %d" % index)
		else:
			player.cancel_limb_grab("cancelled")
		_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and not player._grab_qte.is_active(), "rapid cleanup %d" % index)
		previous = current

	var last := _enemy()
	_check(_hold(last), "scene change case starts")
	var last_id := player.get_active_grab_session_id()
	finished_count = finishes.size()
	world.queue_free()
	await process_frame
	_check(finishes.size() == finished_count + 1 and finishes.back().id == last_id, "scene change finishes once with correct ID")
	_check(not is_instance_valid(player), "scene change releases QTE owner")

	if failures.is_empty():
		print("PASS: %d brutal grab Stage 2 QTE checks" % checks)
		quit(0)
	else:
		for issue in failures:
			push_error(issue)
		print("FAIL: %d / %d brutal grab Stage 2 QTE checks" % [failures.size(), checks])
		quit(1)
