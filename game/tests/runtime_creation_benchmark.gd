extends SceneTree
## Focused baseline for the synchronous construction cost of short-lived combat FX.
## This measures call duration, not Android frame pacing or GPU/render time.

const Player := preload("res://scripts/player_controller.gd")
const WARMUP_CALLS := 4
const SAMPLE_CALLS := 24

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := Player.new() as FoundationPlayer
	root.add_child(player)
	await process_frame
	await _measure("attack_sweep", func() -> void: player._spawn_attack_sweep("punch", "right"))
	await _measure("attack_impact", func() -> void: player._spawn_attack_impact(Vector3(0.0, 1.0, -2.0), "punch"))
	await _measure("spell_burst", func() -> void: player._spawn_spell_burst(Vector3(0.0, 1.0, -2.0), "fire"))
	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: runtime creation baseline (synchronous effect construction timing only)")
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: runtime creation baseline (%d failures)" % failures.size())
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
		await process_frame
	var average_usec := float(total_usec) / float(SAMPLE_CALLS)
	print("RUNTIME_CREATION_SAMPLE " + JSON.stringify({
		"effect": label,
		"samples": SAMPLE_CALLS,
		"call_time_usec_average": snappedf(average_usec, 0.1),
		"call_time_usec_max": maximum_usec,
		"measure": "synchronous script-side construction and scene attachment; not frame pacing",
	}))
