extends SceneTree
## Software OpenGL desktop probe; runner results are not Android GPU measurements.

const SCENE := preload("res://scenes/foundation.tscn")
const WARMUP := 60
const SAMPLES := 120

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := SCENE.instantiate()
	root.add_child(game)
	await process_frame
	if not game.start_performance_scenario(20, "concentrated"):
		push_error("render probe failed to start the Phase 2 scenario")
		quit(1)
		return
	for frame in range(WARMUP):
		await process_frame
	var map_batches := 0
	var map_boxes := 0
	var nature_batches := 0
	var nature_instances := 0
	var road_mark_found := false
	for child in game.arena_map.get_children():
		if not child is MultiMeshInstance3D:
			continue
		var batch := child as MultiMeshInstance3D
		if child.is_in_group("nature_scenery_batch"):
			nature_batches += 1
			nature_instances += batch.multimesh.instance_count
			if batch.get_aabb().size.length_squared() <= 0.0:
				push_error("nature batch has an empty render bound")
				quit(1)
				return
			continue
		map_batches += 1
		map_boxes += batch.multimesh.instance_count
		if batch.get_aabb().size.length_squared() <= 0.0:
			push_error("static map batch has an empty render bound")
			quit(1)
			return
		for index in range(batch.multimesh.instance_count):
			if batch.multimesh.get_instance_transform(index).origin.distance_to(Vector3(0.0, 0.032, -19.2)) < 0.01:
				road_mark_found = true
	if map_batches != 7 or map_boxes != 103 or not road_mark_found or nature_batches != 4 or nature_instances != 20:
		push_error("static map geometry did not reach the Compatibility renderer")
		quit(1)
		return
	var process_total := 0.0
	var physics_total := 0.0
	var draws_total := 0.0
	var objects_total := 0.0
	var frames_before := Engine.get_frames_drawn()
	for frame in range(SAMPLES):
		await process_frame
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draws_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects_total += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var rendered := Engine.get_frames_drawn() > frames_before
	var report := {
		"scenario": "concentrated",
		"active_zombies": 20,
		"map_batches": map_batches,
		"map_boxes": map_boxes,
		"nature_batches": nature_batches,
		"nature_instances": nature_instances,
		"renderer": "Compatibility OpenGL software desktop",
		"rendered_frames": Engine.get_frames_drawn() - frames_before,
		"frame_processing_ms_avg": snappedf(process_total * 1000.0 / SAMPLES, 0.001),
		"physics_processing_ms_avg": snappedf(physics_total * 1000.0 / SAMPLES, 0.001),
		"fps": Performance.get_monitor(Performance.TIME_FPS) if rendered else "N/A",
		"draw_calls_avg": snappedf(draws_total / SAMPLES, 0.1) if rendered else "N/A",
		"rendered_objects_avg": snappedf(objects_total / SAMPLES, 0.1) if rendered else "N/A",
		"android_gpu_time": "N/A (phone measurement required)",
	}
	print("RENDERED_DESKTOP_ENVIRONMENT_SAMPLE " + JSON.stringify(report))
	# One frozen scene, alternating settings. These desktop software-renderer
	# samples help choose the next phone experiment; they are not Android FPS.
	game.set_process(false)
	game.player.set_physics_process(false)
	game.spawn_director.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		if enemy is FoundationEnemy:
			enemy.set_physics_process(false)
	await _sample_render_variant("floor_full_before")
	game._floor_material.set_shader_parameter("floor_fast_detail", true)
	await _sample_render_variant("floor_fast")
	game._floor_material.set_shader_parameter("floor_fast_detail", false)
	await _sample_render_variant("floor_full_after")
	var local_lights := game.find_children("*", "OmniLight3D", true, false)
	for light in local_lights:
		light.visible = false
	await _sample_render_variant("local_lights_off")
	for light in local_lights:
		light.visible = true
	await _sample_render_variant("local_lights_on")
	game._set_debug_mask_visible(false)
	await _sample_render_variant("mask_off")
	game._set_debug_mask_visible(true)
	await _sample_render_variant("mask_on")
	game.queue_free()
	await process_frame
	if not rendered:
		push_error("Compatibility shader validation did not render frames")
	quit(0 if rendered else 1)

func _sample_render_variant(label: String) -> void:
	for frame in range(12):
		await process_frame
	var process_total := 0.0
	var draws_total := 0.0
	for frame in range(60):
		await process_frame
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		draws_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("RENDERED_DESKTOP_COST_AB " + JSON.stringify({
		"variant": label, "frames": 60,
		"frame_processing_ms_avg": snappedf(process_total * 1000.0 / 60.0, 0.001),
		"draw_calls_avg": snappedf(draws_total / 60.0, 0.1),
		"renderer": "Compatibility OpenGL software desktop",
		"android_gpu_time": "N/A (phone measurement required)",
	}))
