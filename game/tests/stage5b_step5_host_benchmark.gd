extends SceneTree
## Identical test script copied to Step4 tested SHA and current Step5 checkout.
## Mesa CPU/software OpenGL measurements must not be extrapolated to Android.
const WORLD := preload("res://scenes/foundation.tscn")
const WARMUP := 15
const SAMPLES := 48
const REPEATS := 2
const SCENARIOS := ["roof_idle", "ground_idle", "player_move", "camera_aim",
	"forced_profile_switch", "combat_20", "director_20", "combined_20_static",
	"mask_off_20_static", "horizon_off_20_static", "tip_off_20_static"]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scale := 0.40
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--scale="):
			scale = float(arg.trim_prefix("--scale="))
	if not [1.0, 0.67, 0.40].has(scale):
		push_error("invalid benchmark scale")
		quit(1)
		return
	root.scaling_3d_scale = scale
	Engine.max_fps = 60
	var game := WORLD.instantiate()
	root.add_child(game)
	game.game_music_player.stop()
	for i in range(24):
		await process_frame
	var manager = game.flashlight_visibility_manager
	var combat_started := false
	for scenario in SCENARIOS:
		if scenario == "roof_idle":
			game._set_rooftop_render_profile(true)
		else:
			game.player.global_position = Vector3(20.0, 0.05, 20.0)
			for v in game._ground_map_visuals:
				v.visible = true
			game._ground_map_ready = true
			game._set_rooftop_render_profile(false)
		if scenario == "combat_20" or scenario == "director_20":
			if combat_started:
				game.stop_performance_scenario()
				await process_frame
			if not game.start_performance_scenario(20, "concentrated"):
				failures.append("could not create 20 ordinary zombies")
				break
			combat_started = true
			if scenario == "director_20":
				game.ai_director.activate()
		if scenario == "combined_20_static":
			game.ai_director.deactivate()
			game.spawn_director.set_physics_process(false)
			for value in game.spawn_director._live.values():
				if is_instance_valid(value):
					value.set_physics_process(false)
		# A/B only, with the same frozen AI and geometry as combined_20_static.
		if scenario == "mask_off_20_static":
			manager.set_composite_visible_for_comparison(false)
		elif scenario == "horizon_off_20_static":
			game.burning_horizon.visible = false
		elif scenario == "tip_off_20_static":
			manager._tip_silhouettes.material.set_shader_parameter("silhouette_opacity", 0.0)
		for repeat_index in range(REPEATS):
			for i in range(WARMUP):
				advance(game, scenario, i)
				await process_frame
			var wall: Array[float] = []
			var proc: Array[float] = []
			var physics: Array[float] = []
			var draws: Array[float] = []
			var objects: Array[float] = []
			var memory_peak := 0.0
			var drawn_before := Engine.get_frames_drawn()
			var tick := Time.get_ticks_usec()
			for i in range(SAMPLES):
				advance(game, scenario, i + WARMUP)
				await process_frame
				var now := Time.get_ticks_usec()
				wall.append(float(now - tick))
				tick = now
				proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000000.0)
				physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000000.0)
				draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
				objects.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
				memory_peak = maxf(memory_peak, Performance.get_monitor(Performance.MEMORY_STATIC))
			var count: int = game.spawn_director.ordinary_population_count()
			if count > 20 or game.horde_far_visuals.get_resident_rig_count() > 7:
				failures.append("population / animation rig budget violated in " + scenario)
			var rendered := Engine.get_frames_drawn() > drawn_before
			print("STEP5_HOST_PERF_SAMPLE " + JSON.stringify({
				"sha": OS.get_environment("BIJATYKA_BENCH_SHA"),
				"driver": OS.get_environment("BIJATYKA_BENCH_RENDERER"),
				"scale": scale, "scenario": scenario, "repeat": repeat_index,
				"warmup": WARMUP, "samples": SAMPLES, "fps_cap": Engine.max_fps,
				"ordinary_count": count, "rendered_frames": Engine.get_frames_drawn() - drawn_before,
				"wall_us": stats(wall), "process_us": stats(proc),
				"physics_us": stats(physics),
				"draw_calls": stats(draws) if rendered else {},
				"rendered_objects": stats(objects) if rendered else {},
				"static_memory_peak_mib": snappedf(memory_peak / 1048576.0, 0.01),
				"android_gpu_or_thermals": "NOT MEASURED"
			}))
		if scenario == "mask_off_20_static":
			manager.set_composite_visible_for_comparison(true)
		elif scenario == "horizon_off_20_static":
			game.burning_horizon.visible = true
		elif scenario == "tip_off_20_static":
			manager._tip_silhouettes.material.set_shader_parameter("silhouette_opacity", 0.40)
		if scenario == "forced_profile_switch":
			game._set_rooftop_render_profile(false)
	if not manager._composite.visible or not game.burning_horizon.visible:
		failures.append("benchmark left a required ground effect disabled")
	game.queue_free()
	if failures.is_empty():
		print("PASS: Step5 host CPU and software OpenGL benchmark")
		quit(0)
	else:
		for failure in failures:
			push_error("Step5 host benchmark: " + failure)
		print("FAIL: Step5 host benchmark (%d failures)" % failures.size())
		quit(1)

func advance(game: Node, scenario: String, frame: int) -> void:
	if scenario == "player_move":
		game.player.global_position = Vector3(20.0 + 2.0 * sin(frame * 0.12),
			0.05, 20.0 + 2.0 * cos(frame * 0.12))
	elif scenario == "camera_aim":
		game._apply_camera_look(0.013, 0.0)
	elif scenario == "forced_profile_switch" and frame % 18 == 0:
		game._set_rooftop_render_profile(not game._rooftop_sky_active)

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {}
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var sum_value := 0.0
	for x in ordered:
		sum_value += x
	return {"median": snappedf(ordered[ordered.size() / 2], 0.01),
		"p95": snappedf(ordered[ceili(ordered.size() * 0.95) - 1], 0.01),
		"mean": snappedf(sum_value / ordered.size(), 0.01),
		"min": snappedf(ordered[0], 0.01), "max": snappedf(ordered[-1], 0.01)}
