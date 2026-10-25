extends SceneTree
## Headless comparison run. Render-only monitors are explicitly reported as N/A.

const POPULATIONS := [15, 20, 69, 100, 200]
const MODES := ["concentrated", "approach"]
const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 120
const MAX_APPROACH_PHYSICS_FRAMES := 1200

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
					if frame % 10 == 0 and _active_zombies(game) == population:
						reached = true
						break
				if not reached:
					_fail("50 m approach reached %d/%d zombies after %d physics frames (%d pending)" % [
						_active_zombies(game), population, MAX_APPROACH_PHYSICS_FRAMES, game.spawn_director._pending.size()])
					game.stop_performance_scenario()
					await process_frame
					continue
			for frame in range(WARMUP_FRAMES):
				await process_frame
			var counts := _horde_counts(game)
			if int(counts.active) != population:
				_fail("%d/%s active population was %d" % [population, mode, counts.active])
				continue

			var process_ms: Array[float] = []
			var physics_ms: Array[float] = []
			var physics_tick_ms: Array[float] = []
			var wall_ms: Array[float] = []
			var last_tick := Time.get_ticks_usec()
			var last_physics_frame := Engine.get_physics_frames()
			var memory_start: Variant = _memory_mib()
			var memory_peak: Variant = memory_start
			var resident_peak := 0
			var initial_fx: Dictionary = game.combat_fx_pool.get_profile_stats()
			for frame in range(SAMPLE_FRAMES):
				await process_frame
				var now := Time.get_ticks_usec()
				wall_ms.append(float(now - last_tick) / 1000.0)
				last_tick = now
				var process_seconds := Performance.get_monitor(Performance.TIME_PROCESS)
				var physics_seconds := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
				if process_seconds > 0.0:
					process_ms.append(process_seconds * 1000.0)
				var physics_frame := Engine.get_physics_frames()
				if physics_frame != last_physics_frame and physics_seconds > 0.0:
					physics_tick_ms.append(physics_seconds * 1000.0)
				if physics_seconds > 0.0:
					physics_ms.append(physics_seconds * 1000.0)
				last_physics_frame = physics_frame
				var memory_now: Variant = _memory_mib()
				if memory_now is float and memory_peak is float:
					memory_peak = maxf(float(memory_peak), float(memory_now))
				resident_peak = maxi(resident_peak, game.horde_far_visuals.get_resident_rig_count())
				if resident_peak > FoundationEnemy.FULL_ANIMATION_BUDGET:
					_fail("%d/%s exceeded the 20-resident-rig cap" % [population, mode])
					break
			counts = _horde_counts(game)
			if int(counts.active) != population:
				_fail("%d/%s changed population to %d during sample" % [population, mode, counts.active])
			var rendered := Engine.get_frames_drawn() > 0
			var rig_stats: Dictionary = game.horde_far_visuals.get_rig_pool_stats()
			var fx_stats: Dictionary = game.combat_fx_pool.get_profile_stats()
			var flashlight_counts: Dictionary = game.flashlight_visibility_manager.get_classification_counts()
			var report := {
				"population": population,
				"scenario": mode,
				"active_zombies": counts.active,
				"detailed_0_18m": counts.detailed,
				"low_poly_18_30m": counts.low_poly,
				"outside_30m": counts.outside,
				"full_rig_zombies": counts.full_rigs,
				"selected_detailed_rigs": counts.full_rigs,
				"resident_detailed_rigs": rig_stats.resident,
				"resident_detailed_rigs_peak": resident_peak,
				"dying_detailed_rigs": rig_stats.dying,
				"reduced_motion_visible_zombies": counts.reduced_motion,
				"flashlight_visible_close": flashlight_counts.visible_close,
				"flashlight_visible_distant": flashlight_counts.visible_distant,
				"flashlight_dark_close_combat": flashlight_counts.dark_close_combat,
				"flashlight_dark_distant": flashlight_counts.dark_distant,
				"flashlight_beyond_30m": flashlight_counts.beyond_render,
				"multimesh_visible_instances": game.horde_far_visuals.multimesh.visible_instance_count,
				"active_animated_skeletons": counts.skeletons,
				"frame_processing_ms_avg": _average_ms(process_ms),
				"physics_processing_ms_avg": _average_ms(physics_ms),
				"physics_process_per_tick_ms_avg": _average_ms(physics_tick_ms),
				"physics_process_per_tick_samples": physics_tick_ms.size(),
				"headless_wall_frame_ms_avg": _average_ms(wall_ms),
				"headless_wall_frame_ms_p95": _percentile(wall_ms, 0.95),
				"headless_wall_frame_ms_p99": _percentile(wall_ms, 0.99),
				"headless_wall_frame_ms_max": _percentile(wall_ms, 1.0),
				"rig_models_created": rig_stats.created,
				"rig_models_reused": rig_stats.reused,
				"rig_pool_overflow": rig_stats.overflow,
				"fx_pool_created": fx_stats.created,
				"fx_pool_reused_during_sample": int(fx_stats.reused) - int(initial_fx.reused),
				"fx_pool_overflow": fx_stats.overflow,
				"fps": Performance.get_monitor(Performance.TIME_FPS) if rendered else "N/A (headless)",
				"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) if rendered else "N/A (headless)",
				"rendered_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)) if rendered else "N/A (headless)",
				"static_memory_mib": _memory_mib(),
				"static_memory_mib_before_sample": memory_start,
				"static_memory_mib_peak": memory_peak,
				"rendering_measurements_are_device_performance": false,
			}
			print("HEADLESS_HORDE_SAMPLE " + JSON.stringify(report))
			game.stop_performance_scenario()
			await process_frame

	if failures.is_empty():
		print("PASS: horde scenario benchmark (%d scenarios; headless CPU/scene metrics only)" % (POPULATIONS.size() * MODES.size()))
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
	var result := {"active": 0, "detailed": 0, "low_poly": 0, "outside": 0, "skeletons": 0, "full_rigs": 0, "reduced_motion": 0}
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
		if enemy._full_animation_selected:
			result.full_rigs += 1
		elif distance_squared <= 900.0:
			result.reduced_motion += 1
		if enemy._animation_player != null and enemy._animation_player.is_playing() and enemy._model != null:
			var skeletons: Array[Node] = enemy._model.find_children("*", "Skeleton3D", true, false)
			if not skeletons.is_empty() and skeletons[0] is Skeleton3D and (skeletons[0] as Skeleton3D).is_visible_in_tree():
				result.skeletons += 1
	return result

func _average_ms(values: Array[float]) -> Variant:
	if values.is_empty():
		return "N/A"
	var total := 0.0
	for value in values:
		total += value
	return snappedf(total / float(values.size()), 0.001)

func _percentile(values: Array[float], fraction: float) -> Variant:
	if values.is_empty():
		return "N/A"
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(sorted[clampi(ceili(fraction * sorted.size()) - 1, 0, sorted.size() - 1)], 0.001)

func _memory_mib() -> Variant:
	var bytes := Performance.get_monitor(Performance.MEMORY_STATIC)
	return snappedf(bytes / 1048576.0, 0.1) if bytes > 0.0 else "N/A (monitor unavailable)"

func _fail(message: String) -> void:
	failures.append(message)
