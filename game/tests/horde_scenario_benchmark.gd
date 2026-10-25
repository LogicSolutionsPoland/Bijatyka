extends SceneTree
## Headless comparison run. Render-only monitors are explicitly reported as N/A.

const POPULATIONS := [20, 100, 200]
const MODES := ["concentrated", "approach"]
const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 120
const MAX_APPROACH_PHYSICS_FRAMES := 360

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := FOUNDATION_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	for mode_value in MODES:
		for population_value in POPULATIONS:
			var mode := String(mode_value)
			var population := int(population_value)
			if not game.start_performance_scenario(population, mode):
				_fail("scenario could not start: %d/%s" % [population, mode])
				continue
			if mode == "approach":
				var reached := false
				for frame in range(MAX_APPROACH_PHYSICS_FRAMES):
					await physics_frame
					if _active_zombies(game) == population:
						reached = true
						break
				if not reached:
					_fail("approach scenario did not reach population %d" % population)
					continue
			for frame in range(WARMUP_FRAMES):
				await process_frame
			var counts := _horde_counts(game)
			if int(counts.active) != population:
				_fail("%d/%s active population was %d" % [population, mode, counts.active])
				continue

			var process_sum := 0.0
			var physics_sum := 0.0
			var process_samples := 0
			var physics_samples := 0
			for frame in range(SAMPLE_FRAMES):
				await process_frame
				var process_seconds := Performance.get_monitor(Performance.TIME_PROCESS)
				var physics_seconds := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
				if process_seconds > 0.0:
					process_sum += process_seconds
					process_samples += 1
				if physics_seconds > 0.0:
					physics_sum += physics_seconds
					physics_samples += 1
			var rendered := Engine.get_frames_drawn() > 0
			var report := {
				"population": population,
				"scenario": mode,
				"active_zombies": counts.active,
				"detailed_0_18m": counts.detailed,
				"low_poly_18_30m": counts.low_poly,
				"outside_30m": counts.outside,
				"active_animated_skeletons": counts.skeletons,
				"frame_processing_ms_avg": _average_ms(process_sum, process_samples),
				"physics_processing_ms_avg": _average_ms(physics_sum, physics_samples),
				"fps": Performance.get_monitor(Performance.TIME_FPS) if rendered else "N/A (headless)",
				"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) if rendered else "N/A (headless)",
				"rendered_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)) if rendered else "N/A (headless)",
				"static_memory_mib": _memory_mib(),
				"rendering_measurements_are_device_performance": false,
			}
			print("HEADLESS_HORDE_SAMPLE " + JSON.stringify(report))
			game.stop_performance_scenario()
			await process_frame

	if failures.is_empty():
		print("PASS: horde scenario benchmark (6 scenarios; headless CPU/scene metrics only)")
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: horde scenario benchmark (%d failures)" % failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _active_zombies(game: Node) -> int:
	return int(_horde_counts(game).active)

func _horde_counts(game: Node) -> Dictionary:
	var result := {"active": 0, "detailed": 0, "low_poly": 0, "outside": 0, "skeletons": 0}
	var player: Node3D = game.player
	for node in get_nodes_in_group("enemies"):
		if not node is FoundationEnemy:
			continue
		var enemy := node as FoundationEnemy
		if enemy.hp <= 0 or enemy.is_boss:
			continue
		result.active += 1
		var distance_squared := enemy.global_position.distance_squared_to(player.global_position)
		if distance_squared <= 324.0:
			result.detailed += 1
		elif distance_squared <= 900.0:
			result.low_poly += 1
		else:
			result.outside += 1
		if enemy._animation_player != null and enemy._animation_player.is_playing() and enemy._model != null:
			var skeleton := enemy._model.find_child("*", "Skeleton3D", true, false)
			if skeleton is Skeleton3D and skeleton.is_visible_in_tree():
				result.skeletons += 1
	return result

func _average_ms(total_seconds: float, samples: int) -> Variant:
	return snappedf(total_seconds * 1000.0 / float(samples), 0.001) if samples > 0 else "N/A"

func _memory_mib() -> Variant:
	var bytes := Performance.get_monitor(Performance.MEMORY_STATIC)
	return snappedf(bytes / 1048576.0, 0.1) if bytes > 0.0 else "N/A (monitor unavailable)"

func _fail(message: String) -> void:
	failures.append(message)
