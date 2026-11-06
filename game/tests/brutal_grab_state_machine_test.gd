extends SceneTree
## Stage 1 grab lifecycle regression. Host-only: not an Android hardware result.

const WORLD := preload("res://scenes/foundation.tscn")
const ENEMY := preload("res://scripts/enemy.gd")

class SlotLedger extends Node:
	var locks: Dictionary = {}
	var releases := 0
	func grant(enemy: FoundationEnemy) -> void:
		locks[enemy.get_instance_id()] = true
	func can_maintain_limb_grab(enemy: FoundationEnemy) -> bool:
		return locks.has(enemy.get_instance_id())
	func release_attacker(enemy: FoundationEnemy) -> void:
		if locks.erase(enemy.get_instance_id()):
			releases += 1

var checks := 0
var failures: Array[String] = []
var world: Node3D
var player: FoundationPlayer
var ledger: SlotLedger

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("Brutal grab Stage 1: " + message)

func _settle(at: Vector3) -> bool:
	player.set_physics_process(true)
	player.global_position = at
	player.velocity = Vector3.ZERO
	for frame in range(130):
		await physics_frame
		if frame > 2 and player.is_on_floor() and is_zero_approx(player.velocity.y):
			player.set_physics_process(false)
			return true
	player.set_physics_process(false)
	return false

func _actor() -> FoundationEnemy:
	var zombie := ENEMY.new() as FoundationEnemy
	zombie.set_physics_process(false)
	world.add_child(zombie)
	zombie.set_physics_process(false)
	zombie._player = player
	zombie.attack_director = ledger
	zombie.global_position = player.global_position + Vector3(1.25, 0.0, 0.0)
	ledger.grant(zombie)
	return zombie

func _reserve(zombie: FoundationEnemy, limb: String = "LEFT ARM") -> bool:
	player._limb_grab_cooldown = 0.0
	zombie.state = "limb_grab_windup"
	zombie._limb_grab_limb = limb
	return player.try_reserve_limb_grab(zombie, limb)

func _hold(zombie: FoundationEnemy, limb: String = "LEFT ARM") -> bool:
	if not _reserve(zombie, limb):
		return false
	zombie.state = "limb_hold"
	zombie.state_time = player.limb_grab_hold_seconds
	return player.begin_limb_grab(zombie, limb)

func _run() -> void:
	world = WORLD.instantiate()
	root.add_child(world)
	await process_frame
	player = world.get("player") as FoundationPlayer
	ledger = SlotLedger.new()
	world.add_child(ledger)
	_check(await _settle(Vector3(20.0, 1.2, 20.0)), "player must settle on a floor")

	var events := {"windup": 0, "started": 0, "escaped": 0, "failed": 0, "ended": 0, "interrupted": [], "finished": [], "states": []}
	player.grab_windup_started.connect(func(_enemy: FoundationEnemy, _limb: String) -> void: events["windup"] = int(events["windup"]) + 1)
	player.grab_established.connect(func(_enemy: FoundationEnemy, _limb: String) -> void: events["started"] = int(events["started"]) + 1)
	player.grab_escaped.connect(func(_enemy: FoundationEnemy, _limb: String) -> void: events["escaped"] = int(events["escaped"]) + 1)
	player.grab_failed.connect(func(_enemy: FoundationEnemy, _limb: String) -> void: events["failed"] = int(events["failed"]) + 1)
	player.grab_interrupted.connect(func(reason: String, _enemy: FoundationEnemy, _limb: String) -> void: events["interrupted"].append(reason))
	player.grab_fully_ended.connect(func(reason: String) -> void: events["finished"].append(reason))
	player.grab_state_changed.connect(func(state: int, _enemy: FoundationEnemy, _limb: String) -> void: events["states"].append(state))
	player.limb_grab_ended.connect(func() -> void: events["ended"] = int(events["ended"]) + 1)

	var first := _actor()
	var second := _actor()
	_check(_reserve(first), "eligible attacker reserves the first arm")
	_check(player.get_grab_state() == FoundationPlayer.GrabState.WINDUP and player.get_active_grab_enemy() == first and player.get_grab_limb() == "LEFT ARM", "WINDUP owns exactly one enemy and limb")
	_check(not player.try_reserve_limb_grab(second, "RIGHT ARM"), "simultaneous reservation rejected without replacing first owner")
	_check(player.begin_limb_grab(first, "LEFT ARM"), "contact commits the reserved attacker")
	first.state = "limb_hold"
	_check(player.get_grab_state() == FoundationPlayer.GrabState.GRABBED and player.get_active_grab_enemy() == first, "GRABBED state established")
	_check(not player.request_attack("punch") and not player.try_jump() and not player.try_parabolic_jump(), "punch and both jumps blocked during hold")
	_check(player._jump_state == FoundationPlayer.JumpState.READY and not player._parabolic_jump_active, "blocked jumps leave current jump state unchanged")
	_check(not player.cast_spell_slot(0) and not player.cast_spell(), "spell routing cannot cast while held")
	_check(player.try_escape_limb_grab(), "R3/touch shared escape handler succeeds")
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and first.state == "recovery" and not ledger.locks.has(first.get_instance_id()), "escape fully cleans player, enemy and attacker lock")
	_check(int(events["escaped"]) == 1 and int(events["ended"]) == 1 and int(events["started"]) == 1 and events["finished"].size() == 1, "escape emits exactly one success and completion")
	player.cancel_limb_grab("duplicate")
	first.release_limb_grab(player)
	_check(int(events["ended"]) == 1 and events["finished"].size() == 1, "repeated release cannot duplicate completion")
	_check(player.request_attack("punch"), "normal punches work after escape")
	player._finish_attack()
	ledger.release_attacker(second) # Its original, non-grab combat slot remains unrelated.

	var timer_enemy := _actor()
	_check(_hold(timer_enemy), "second hold starts after cooling down is explicitly reset")
	player._update_limb_grab(player.limb_grab_hold_seconds + 0.1)
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and int(events["failed"]) == 1 and events["finished"].back() == "timeout", "expiry becomes FAILED, then RECOVERY and READY")
	_check(not ledger.locks.has(timer_enemy.get_instance_id()), "timeout releases attacker slot")
	var completed: int = events["finished"].size()
	player._update_limb_grab(1.0)
	player.cancel_limb_grab("duplicate")
	_check(events["finished"].size() == completed and int(events["failed"]) == 1, "timeout cleanup is idempotent")

	var cancelled := _actor()
	_check(_reserve(cancelled, "RIGHT ARM"), "windup can be reserved after expiry cooldown is reset")
	cancelled.cancel_limb_grab_windup(player)
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and not ledger.locks.has(cancelled.get_instance_id()), "windup interruption clears candidate and slot")
	_check(events["interrupted"].has("windup_cancelled"), "windup cancellation carries explicit reason")

	var lost := _actor()
	_check(_hold(lost), "hold starts for reservation-loss test")
	ledger.locks.erase(lost.get_instance_id())
	player._update_limb_grab(0.05)
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and events["interrupted"].has("reservation_lost"), "lost attacker role interrupts active grab")

	var victim := _actor()
	_check(_hold(victim), "hold starts for enemy-death test")
	victim.receive_hit(victim.hp + 1)
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and events["interrupted"].has("enemy_died") and not ledger.locks.has(victim.get_instance_id()), "killed owner releases the player and slot")

	var vanished := _actor()
	_check(_hold(vanished), "hold starts for despawn test")
	vanished.queue_free()
	await process_frame
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and events["interrupted"].has("enemy_despawned"), "enemy scene exit releases hold")

	var paused_enemy := _actor()
	_check(_hold(paused_enemy), "hold starts for pause test")
	var remaining := player._limb_grab_time
	paused = true
	player._update_limb_grab(99.0)
	_check(is_equal_approx(player._limb_grab_time, remaining) and player.get_grab_state() == FoundationPlayer.GrabState.GRABBED, "pause never consumes escape timer")
	paused = false
	player._update_limb_grab(remaining + 0.01)
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY, "resume restores timer progression and timeout")

	var fatal := _actor()
	_check(_hold(fatal), "hold starts for player-death test")
	player.take_boss_damage(player.health)
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and events["interrupted"].has("player_dead") and not ledger.locks.has(fatal.get_instance_id()), "player death cancels hold without a false escape")
	player._reset_at_safe_base()
	_check(player.health == FoundationPlayer.MAX_HEALTH and player.get_grab_state() == FoundationPlayer.GrabState.READY, "respawn leaves no stale grab session")
	_check(await _settle(Vector3(20.0, 1.2, 20.0)), "player settles again after respawn")

	var respawn_enemy := _actor()
	_check(_hold(respawn_enemy), "new hold possible after respawn")
	player._reset_at_safe_base()
	_check(player.get_grab_state() == FoundationPlayer.GrabState.READY and not ledger.locks.has(respawn_enemy.get_instance_id()), "respawn during hold releases all ownership")
	_check(await _settle(Vector3(20.0, 1.2, 20.0)), "jump-evasion test begins grounded")
	var jumper := _actor()
	_check(_reserve(jumper), "jump windup starts")
	_check(player.try_jump() and player._jump_state == FoundationPlayer.JumpState.ORDINARY and player.get_grab_state() == FoundationPlayer.GrabState.READY, "ordinary jump evades WINDUP without losing jump ownership")
	_check(events["interrupted"].has("jump_evaded") and not ledger.locks.has(jumper.get_instance_id()), "jump evasion releases grab reservation")

	_check(int(events["windup"]) == int(events["started"]) + 2, "each started hold had one windup; two windups were cancelled")
	_check(int(events["escaped"]) == 1 and int(events["failed"]) == 2, "terminal escape and timeout results are not duplicated")
	_check(events["finished"].size() == int(events["ended"]) + 2, "each hold ends once and each cancelled windup ends once")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: %d brutal grab Stage 1 lifecycle checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d / %d brutal grab Stage 1 checks" % [failures.size(), checks])
		quit(1)
