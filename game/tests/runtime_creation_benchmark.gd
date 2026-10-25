extends SceneTree
## Focused baseline for the synchronous construction cost of short-lived combat FX.
## This measures call duration, not Android frame pacing or GPU/render time.

const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Pool := preload("res://scripts/combat_fx_pool.gd")
const WARMUP_CALLS := 4
const SAMPLE_CALLS := 24
const FRAMES_BETWEEN_CALLS := 6

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := Player.new() as FoundationPlayer
	var enemy := Enemy.new() as FoundationEnemy
	var pool := Pool.new() as FoundationCombatFxPool
	root.add_child(player)
	pool.visibility_origin = player
	root.add_child(pool)
	root.add_child(enemy)
	player.combat_fx_pool = pool
	enemy.combat_fx_pool = pool
	for _frame in range(24):
		await process_frame
	await process_frame
	await _measure("attack_sweep", func() -> void: player._spawn_attack_sweep("punch", "right"))
	await _measure("attack_impact", func() -> void: player._spawn_attack_impact(Vector3(0.0, 1.0, -2.0), "punch"))
	await _measure("zombie_hit_flash", func() -> void: enemy._show_impact_flash(false))
	await _measure("spell_burst", func() -> void: player._spawn_spell_burst(Vector3(0.0, 1.0, -2.0), "fire"))
	player.queue_free()
	enemy.queue_free()
	print("RUNTIME_FX_POOL_SAMPLE " + JSON.stringify(pool.get_profile_stats()))
	pool.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: runtime pooled effect benchmark (headless acquisition timing; not frame pacing)")
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: runtime pooled effect benchmark (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _measure(label: String, create_effect: Callable) -> void:
	var total_usec := 0
	var maximum_usec := 0
	for index in range(WARMUP_CALLS + SAMPLE_CALLS):
		var start_usec := Time.get_ticks_usec()
		create_effect.call()
		var elapsed_usec := int(Time.get_ticks_usec() - start_usec)
		if index >= WARMUP_CALLS:
			total_usec += elapsed_usec
			maximum_usec = maxi(maximum_usec, elapsed_usec)
		for _frame in range(FRAMES_BETWEEN_CALLS):
			await process_frame
	var average_usec := float(total_usec) / float(SAMPLE_CALLS)
	print("RUNTIME_CREATION_SAMPLE " + JSON.stringify({
		"effect": label,
		"samples": SAMPLE_CALLS,
		"call_time_usec_average": snappedf(average_usec, 0.1),
		"call_time_usec_max": maximum_usec,
		"measure": "pooled acquisition, effect reset and scene update; not frame pacing",
	}))
