extends SceneTree
## Paired software-renderer A/B on one frozen 30-zombie ground scene.
## The 40% scale and 60 FPS cap match the mobile profile; host timings do not.

const SCENE := preload("res://scenes/foundation.tscn")
const WARMUP_FRAMES := 90
const SETTLE_FRAMES := 10
const SAMPLE_FRAMES := 50
const SEQUENCE := ["both", "mask", "both", "pencil", "both", "neither", "both"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.scaling_3d_scale = 0.40
	Engine.max_fps = 60
	var game := SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.player.global_position = Vector3(0.0, 0.05, -5.2)
	for visual in game._ground_map_visuals:
		visual.visible = true
	game._set_rooftop_render_profile(false)
	game._ground_map_ready = true
	game._ground_wave_started = true
	if not game.start_performance_scenario(30, "concentrated"):
		push_error("Cannot start 30-zombie effect comparison")
		quit(1)
		return
	for frame in range(WARMUP_FRAMES):
		await process_frame
	# Freeze simulation for paired A/B: the same zombie positions, beam,
	# shadows and map stay on screen through all seven samples.
	game.set_process(false)
	game.player.set_physics_process(false)
	game.spawn_director.set_physics_process(false)
	game.horde_far_visuals.set_process(false)
	game.flashlight_visibility_manager.set_process(false)
	for enemy in get_nodes_in_group("enemies"):
		if enemy is FoundationEnemy:
			enemy.set_physics_process(false)
			if enemy._animation_player != null:
				enemy._animation_player.pause()
	var slots: int = game.spawn_director._live.size() + game.spawn_director._dormant_population.size() + \
		game.spawn_director._pending.size() + game.spawn_director._initial_population_pending
	if slots != 30 or game.horde_far_visuals.get_resident_rig_count() > 7:
		push_error("The fixed comparison lost its 30 slots or seven-rig cap")
		quit(1)
		return
	var index := 0
	for mode in SEQUENCE:
		game._pencil_screen_pass.visible = mode in ["both", "pencil"]
		game.flashlight_visibility_manager.set_composite_visible_for_comparison(mode in ["both", "mask"])
		for frame in range(SETTLE_FRAMES):
			await process_frame
		var samples: Array[float] = []
		var draws := 0.0
		var last_tick := Time.get_ticks_usec()
		var frames_before := Engine.get_frames_drawn()
		for frame in range(SAMPLE_FRAMES):
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - last_tick) / 1000.0)
			last_tick = now
			draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		print("STAGE5_PAIRED_SAMPLE " + JSON.stringify({
			"index": index, "mode": mode, "zombie_slots": slots,
			"render_scale": root.scaling_3d_scale, "fps_cap": Engine.max_fps,
			"floor_skip_enabled": game._floor_material.get_shader_parameter("floor_skip_enabled"),
			"wall_ms_avg": _avg(samples), "wall_ms_p95": _p95(samples),
			"draw_calls_avg": snappedf(draws / SAMPLE_FRAMES, 0.1),
			"rendered_frames": Engine.get_frames_drawn() - frames_before,
			"renderer": "host software OpenGL or headless (check rendered_frames)",
		}))
		index += 1
	game.queue_free()
	await process_frame
	print("PASS: Stage 5 paired 30-zombie screen-effect comparison")
	quit(0)

func _avg(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return snappedf(total / values.size(), 0.001)

func _p95(values: Array[float]) -> float:
	values.sort()
	return snappedf(values[ceili(values.size() * 0.95) - 1], 0.001)
