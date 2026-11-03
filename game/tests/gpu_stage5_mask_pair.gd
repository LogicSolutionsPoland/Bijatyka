extends SceneTree
## Alternate the committed Stage 4 and optimized mask on the same frozen
## 20-zombie ground scene. Both keep Pencil, the beam, and floor skipping on.
## The result is desktop software OpenGL time, not Android GPU time.

const SCENE := preload("res://scenes/foundation.tscn")
const STAGE4_MASK := preload("res://tests/flashlight_visibility_stage4_reference.gdshader")
const SAMPLE_FRAMES := 50
const SEQUENCE := ["stage4", "optimized", "stage4", "optimized", "stage4", "optimized"]

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
	if not game.start_performance_scenario(20, "concentrated"):
		push_error("Cannot start 20-zombie mask comparison")
		quit(1)
		return
	for frame in range(90):
		await process_frame
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
	var mask: MeshInstance3D = game.flashlight_visibility_manager._composite as MeshInstance3D
	var optimized := mask.material_override as ShaderMaterial
	var stage4 := optimized.duplicate(true) as ShaderMaterial
	stage4.shader = STAGE4_MASK
	stage4.render_priority = optimized.render_priority
	for parameter in ["flashlight_origin", "flashlight_forward", "bright_radius", "max_radius",
			"player_keep_radius", "oval_center_uv", "oval_radius_uv", "oval_feather",
			"flashlight_enabled", "rooftop_sky_visible"]:
		if stage4.get_shader_parameter(parameter) != optimized.get_shader_parameter(parameter):
			push_error("Stage 4 mask has a mismatched uniform: " + parameter)
			quit(1)
			return
	if not mask.visible or not game._pencil_screen_pass.visible or not game.flashlight_visibility_manager.spotlight.visible or \
		game.spawn_director.ordinary_population_count() != 20:
		push_error("Mask A/B lost the screen passes, 3D beam, or 20 zombies")
		quit(1)
		return
	# Compile both shaders before collecting timings.
	mask.material_override = stage4
	for frame in range(10):
		await process_frame
	mask.material_override = optimized
	for frame in range(10):
		await process_frame
	var index := 0
	for variant in SEQUENCE:
		mask.material_override = stage4 if variant == "stage4" else optimized
		for frame in range(10):
			await process_frame
		var samples: Array[float] = []
		var last_tick := Time.get_ticks_usec()
		var frames_before := Engine.get_frames_drawn()
		for frame in range(SAMPLE_FRAMES):
			await process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now - last_tick) / 1000.0)
			last_tick = now
		print("STAGE5_MASK_PAIR " + JSON.stringify({
			"index": index, "variant": variant, "wall_ms_avg": _avg(samples),
			"wall_ms_p95": _p95(samples), "rendered_frames": Engine.get_frames_drawn() - frames_before,
			"render_scale": root.scaling_3d_scale, "fps_cap": Engine.max_fps,
		}))
		index += 1
	game.queue_free()
	await process_frame
	print("PASS: Stage 5 paired Stage 4 and optimized flashlight masks")
	quit(0)

func _avg(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return snappedf(total / values.size(), 0.001)

func _p95(values: Array[float]) -> float:
	values.sort()
	return snappedf(values[ceili(values.size() * 0.95) - 1], 0.001)
