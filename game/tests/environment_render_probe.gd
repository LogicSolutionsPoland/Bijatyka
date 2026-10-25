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
	game.queue_free()
	await process_frame
	if not rendered:
		push_error("Compatibility shader validation did not render frames")
	quit(0 if rendered else 1)
