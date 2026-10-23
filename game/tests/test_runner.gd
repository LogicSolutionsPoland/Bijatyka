extends SceneTree

const Rage := preload("res://scripts/rage_progression.gd")
const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	_test_rage_rules()
	_test_multiple_milestones_and_reset()
	await _test_manual_attack_and_hit_window()
	_test_jump_and_enemy_interrupt_rules()
	_test_boss_damage_rule()
	if failures.is_empty():
		print("PASS: %d foundation checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d checks failed" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _test_rage_rules() -> void:
	var rage := Rage.new(10.0, 1.0, 100.0) as RageProgression
	_check(rage.rage == 0.0 and rage.maximum_rage == 0.0 and rage.unlocked_spells.is_empty(), "new soul starts with no RAGE or spell")
	_check(not rage.record_effective_hit(0.0), "zero damage does not build RAGE")
	_check(not rage.record_effective_hit(-5.0), "negative damage does not build RAGE")
	_check(rage.record_effective_hit(12.0), "positive effective damage builds RAGE")
	_check(rage.rage == 10.0 and rage.maximum_rage == 10.0, "effective hit updates current and maximum RAGE")
	_check(rage.pending_milestone() == 10, "crossing the first milestone queues its choice")
	_check(not rage.resolve_selection("unknown"), "invalid aura selection is rejected")
	_check(rage.resolve_selection("fire"), "player may choose any aura from the supported pool")
	_check(rage.aura_is_active(10) and rage.unlocked_spells.has("fire"), "chosen aura is active at threshold and spell is unlocked")
	rage.advance(2.0)
	_check(not rage.aura_is_active(10), "aura turns off below its selection threshold")
	_check(rage.unlocked_spells.has("fire"), "unlocked spell persists while RAGE decays")
	rage.advance(5.0)
	_check(not rage.current_soul_condemned, "equality with condemnation threshold is not condemnation")
	rage.advance(0.01)
	_check(rage.current_soul_condemned, "strictly falling below the maximum-based threshold condemns")
	var maximum_before := rage.maximum_rage
	rage.advance(2.0)
	_check(rage.maximum_rage == maximum_before, "maximum RAGE never decreases within a soul")
	rage.reset_soul()
	_check(rage.rage == 0.0 and rage.unlocked_spells.is_empty() and rage.aura_choices.is_empty(), "soul reset clears RAGE, spells, and aura choices")
	_check(rage.record_effective_hit(1.0), "new soul can record a new effective hit")
	var value_before_pause := rage.rage
	rage.advance(5.0, false)
	_check(rage.rage == value_before_pause, "paused gameplay does not decay RAGE")

func _test_multiple_milestones_and_reset() -> void:
	var rage := Rage.new(95.0, 0.0, 100.0) as RageProgression
	_check(rage.record_effective_hit(1.0), "one verified hit may cross several thresholds")
	_check(rage.pending_milestones == [10, 30, 50, 70, 90], "crossed milestones queue in ascending order")
	_check(rage.maximum_rage == 95.0, "maximum tracks the run peak")
	for aura_id in ["light", "judgment", "fire", "shadow", "light"]:
		_check(rage.resolve_selection(aura_id), "milestone selection accepts the full pool and repeated choices")
	_check(rage.pending_milestones.is_empty() and rage.claimed_milestones.size() == 5, "each milestone selection resolves once")
	_check(rage.aura_choices[10] == "light" and rage.aura_choices[90] == "light", "aura choices stay mapped to their milestone")
	rage.reset_soul()
	_check(rage.maximum_rage == 0.0 and rage.claimed_milestones.is_empty(), "new soul clears run peak and claimed milestones")

func _test_manual_attack_and_hit_window() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	root.add_child(player)
	var target := Enemy.new() as FoundationEnemy
	target.configure("shambler")
	target.position = Vector3(0.0, 0.0, -1.1)
	target.set_physics_process(false)
	root.add_child(target)
	await process_frame
	_check(player.request_attack("punch"), "punch press starts one attack")
	_check(not player.request_attack("punch") and player.attack_count == 1, "second press during recovery cannot queue a combo")
	player._update_attack(0.15)
	_check(target.hp < target.starting_health, "punch hit window detects an in-range enemy")
	_check(player.rage.rage == 3.0, "only a confirmed positive hit increases RAGE")
	for _frame in range(80):
		player._update_attack(0.01)
	await process_frame
	_check(player.request_attack("kick") and player.attack_count == 2, "a fresh kick press after recovery starts its own action")
	target.hp = target.starting_health
	player.attack_phase = "ready"
	player.attack_kind = ""
	target.position = Vector3(4.0, 0.0, 0.0)
	_check(player.request_attack("kick"), "kick input starts its distinct action")
	player._update_attack(0.24)
	_check(target.hp == target.starting_health, "missed kick does not damage or build RAGE")
	_check(player.rage.rage == 3.0, "missed kick does not increase RAGE")
	player.queue_free()
	target.queue_free()
	await process_frame

func _test_jump_and_enemy_interrupt_rules() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	root.add_child(player)
	var zombie := Enemy.new() as FoundationEnemy
	zombie.configure("shambler")
	zombie.position = Vector3(0.0, 0.0, -1.3)
	zombie.set_physics_process(false)
	root.add_child(zombie)
	await process_frame
	player._resolve_jump_impact()
	_check(zombie.hp < zombie.starting_health, "jump impact damages an enemy")
	_check(player.rage.rage == 3.0, "effective jump impact contributes RAGE")
	var hp_before := player.health
	zombie._player = player
	zombie._resolve_enemy_attack(1.2)
	_check(player.health == hp_before, "ordinary zombie attack cannot reduce player HP")
	_check(player.movement_slow_factor < 1.0, "ordinary zombie attack applies a readable slow")
	_check(zombie.state == "recovery", "enemy telegraph resolves into a recoverable attack state")
	player.queue_free()
	zombie.queue_free()
	await process_frame

func _test_boss_damage_rule() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	root.add_child(player)
	var boss := Enemy.new() as FoundationEnemy
	boss.configure("boss", true)
	boss.position = Vector3(0.0, 0.0, -2.0)
	boss.set_physics_process(false)
	root.add_child(boss)
	await process_frame
	boss._player = player
	boss._resolve_enemy_attack(2.0)
	_check(player.health == player.MAX_HEALTH - 22, "boss attack may reduce player HP")
	player.queue_free()
	boss.queue_free()
	await process_frame
