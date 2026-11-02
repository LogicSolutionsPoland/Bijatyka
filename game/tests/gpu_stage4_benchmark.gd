extends SceneTree
## Fixed 30-zombie ground scene. Headless timings are CPU/host scheduling only;
## rendered desktop monitors, when available, are not Android GPU timings.

const SCENE := preload("res://scenes/foundation.tscn")
const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 180

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := SCENE.instantiate()
	root.add_child(world)
	await process_frame
	world.player.global_position = Vector3(0.0, 0.05, -5.2)
	for visual in world._ground_map_visuals:
		visual.visible = true
	world._set_rooftop_render_profile(false)
	world._ground_map_ready = true
	world._ground_wave_started = true
	if not world.start_performance_scenario(30, "concentrated"):
		push_error("Cannot start the fixed 30-zombie scenario")
		quit(1)
		return
	var initial_population: int = world.spawn_director.ordinary_population_count()
	for frame in range(WARMUP_FRAMES):
		await process_frame
	var wall_samples: Array[float] = []
	var process_samples: Array[float] = []
	var physics_samples: Array[float] = []
	var draws := 0.0
	var objects := 0.0
	var memory_peak := 0.0
	var last_tick := Time.get_ticks_usec()
	var drawn_before := Engine.get_frames_drawn()
	for frame in range(SAMPLE_FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		wall_samples.append(float(now - last_tick) / 1000.0)
		last_tick = now
		process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		memory_peak = maxf(memory_peak, Performance.get_monitor(Performance.MEMORY_STATIC))
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var rendered := Engine.get_frames_drawn() > drawn_before
	var ordinary := 0
	for actor in get_nodes_in_group("enemies"):
		if actor is FoundationEnemy and not actor.is_boss and actor.hp > 0:
			ordinary += 1
	# A zombie killed during the sample can spend a few frames in its death
	# animation or the concealed replacement queue. Both retain a reserved
	# population slot, even though the count of living scene actors is 29.
	var slots: int = world.spawn_director._live.size() + world.spawn_director._dormant_population.size() + \
		world.spawn_director._pending.size() + world.spawn_director._initial_population_pending
	var report := {
		"scenario": "ground_concentrated_30", "samples": SAMPLE_FRAMES,
		"ordinary_zombies": ordinary, "initial_zombies": initial_population,
		"reserved_population_slots": slots,
		"headless_wall_ms_avg": _avg(wall_samples), "headless_wall_ms_p95": _p95(wall_samples),
		"process_ms_avg": _avg(process_samples), "physics_ms_avg": _avg(physics_samples),
		"static_memory_mib": snappedf(memory_peak / 1048576.0, 0.1),
		"courtyard_render_nodes": _count_courtyard_visuals(world),
		"rendered_frames": Engine.get_frames_drawn() - drawn_before,
		"draw_calls_avg": snappedf(draws / SAMPLE_FRAMES, 0.1) if rendered else "N/A (headless)",
		"rendered_objects_avg": snappedf(objects / SAMPLE_FRAMES, 0.1) if rendered else "N/A (headless)",
		"android_gpu_time": "N/A (device required)",
	}
	print("STAGE4_PERFORMANCE_SAMPLE " + JSON.stringify(report))
	if initial_population != 30 or slots != 30 or ordinary > 30 or \
		world.horde_far_visuals.get_resident_rig_count() > 7:
		push_error("Population or rig budget changed during the benchmark")
		quit(1)
		return
	print("PASS: Stage 4 fixed 30-zombie benchmark")
	world.queue_free()
	await process_frame
	quit(0)

func _count_courtyard_visuals(world: Node) -> int:
	var count := 0
	for node in world.get_children():
		if node is MeshInstance3D or node is MultiMeshInstance3D:
			count += 1
		for child in node.get_children():
			if child is MeshInstance3D or child is MultiMeshInstance3D:
				count += 1
	return count

func _avg(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return snappedf(total / values.size(), 0.001)

func _p95(values: Array[float]) -> float:
	values.sort()
	return snappedf(values[ceili(values.size() * 0.95) - 1], 0.001)
