extends SceneTree
## Paired shader-only A/B for the beam sheet material on a frozen 30-slot scene.
## The Stage 5 shader remains in tests as the exact reference implementation.

const SCENE := preload("res://scenes/foundation.tscn")
const STAGE5_BEAM := preload("res://tests/flashlight_beam_volume_stage5_reference.gdshader")
const WARMUP_FRAMES := 90
const SETTLE_FRAMES := 10
const SAMPLE_FRAMES := 50
const SPOTLIGHT_ENERGY := 1.6
const PAIRS := [
	{"id": "shader-1", "first": "reference", "second": "trial"},
	{"id": "shader-2", "first": "trial", "second": "reference"},
	{"id": "shader-3", "first": "reference", "second": "trial"},
]

var _failures: Array[String] = []
var _reference_times: Array[float] = []
var _trial_times: Array[float] = []
var _reference_draws: Array[float] = []
var _trial_draws: Array[float] = []
var _paired_deltas: Array[float] = []

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
		_fail("Cannot start fixed 30-slot beam shader scene")
		return
	for frame in range(WARMUP_FRAMES):
		await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED

	var manager = game.flashlight_visibility_manager
	var spotlight := manager.spotlight as SpotLight3D
	var sheets := spotlight.get_node_or_null("PlayerFlashlightBeamSheets") as MultiMeshInstance3D
	var sections := spotlight.get_node_or_null("PlayerFlashlightBeamSections") as MeshInstance3D
	var live_material := sheets.material_override as ShaderMaterial
	var reference_material := live_material.duplicate(true) as ShaderMaterial
	reference_material.shader = STAGE5_BEAM
	var trial_material := live_material.duplicate(true) as ShaderMaterial
	var slots: int = game.spawn_director._live.size() + game.spawn_director._dormant_population.size() + \
		game.spawn_director._pending.size() + game.spawn_director._initial_population_pending
	_check(slots == 30, "fixed scene has exactly 30 reserved zombie slots")
	_check(game._pencil_screen_pass.visible and manager._composite.visible,
		"Stage 5 Pencil and visibility mask stay enabled")
	_check(spotlight.visible and is_equal_approx(spotlight.light_energy, SPOTLIGHT_ENERGY),
		"spotlight lighting stays fixed at its production energy")
	_check(sheets.visible and sections.visible, "both translucent beam layers stay enabled")
	_check(Engine.max_fps == 60 and is_equal_approx(root.scaling_3d_scale, 0.40),
		"render scale and frame cap stay fixed")
	for uniform_name in ["beam_range", "beam_tangent", "beam_color", "beam_opacity", "core_opacity"]:
		_check(reference_material.get_shader_parameter(uniform_name) == trial_material.get_shader_parameter(uniform_name),
			"reference and trial have identical %s" % uniform_name)
	if not _failures.is_empty():
		_finish_failure()
		return

	# Compile both shader variants before capture or timing.
	sheets.material_override = reference_material
	for frame in range(SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw
	var reference_image := root.get_texture().get_image()
	sheets.material_override = trial_material
	for frame in range(SETTLE_FRAMES):
		await process_frame
	await RenderingServer.frame_post_draw
	var trial_image := root.get_texture().get_image()
	var diff := _compare_images(reference_image, trial_image)
	print("STAGE6_BEAM_SHADER_IMAGE " + JSON.stringify(diff))
	_check(int(diff["changed_over_1_lsb"]) == 0,
		"reference and zero-alpha trial renders match within one 8-bit color level")
	_save_capture(reference_image, "beam-shader-reference.png")
	_save_capture(trial_image, "beam-shader-trial.png")

	for pair_variant in PAIRS:
		var pair: Dictionary = pair_variant
		await _run_pair(sheets, reference_material, trial_material, pair)
	print("STAGE6_BEAM_SHADER_SUMMARY " + JSON.stringify({
		"reference_wall_ms_avg": _average(_reference_times),
		"reference_wall_ms_p95": _p95(_reference_times),
		"trial_wall_ms_avg": _average(_trial_times),
		"trial_wall_ms_p95": _p95(_trial_times),
		"reference_draw_calls_avg": _average(_reference_draws),
		"trial_draw_calls_avg": _average(_trial_draws),
		"trial_minus_reference_ms_avg": _average(_paired_deltas),
		"trial_minus_reference_ms_min": _minimum(_paired_deltas),
		"trial_minus_reference_ms_max": _maximum(_paired_deltas),
		"repeat_count": _paired_deltas.size(),
		"renderer": "GitHub Actions host, GL Compatibility, LIBGL_ALWAYS_SOFTWARE=1",
	}))
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: Stage 6 paired zero-alpha flashlight shader trial")
		quit(0)
	else:
		_finish_failure()

func _run_pair(sheets: MultiMeshInstance3D, reference: ShaderMaterial,
		trial: ShaderMaterial, pair: Dictionary) -> void:
	var pair_id := String(pair["id"])
	var first_variant := String(pair["first"])
	var second_variant := String(pair["second"])
	var phases: Array[Dictionary] = []
	phases.append(await _run_phase(sheets, reference, trial, first_variant, pair_id, 0))
	phases.append(await _run_phase(sheets, reference, trial, second_variant, pair_id, 1))
	phases.append(await _run_phase(sheets, reference, trial, second_variant, pair_id, 2))
	phases.append(await _run_phase(sheets, reference, trial, first_variant, pair_id, 3))
	var reference_runs: Array[float] = []
	var trial_runs: Array[float] = []
	var reference_draw_runs: Array[float] = []
	var trial_draw_runs: Array[float] = []
	for result in phases:
		if String(result["variant"]) == "reference":
			reference_runs.append(float(result["wall_ms_avg"]))
			reference_draw_runs.append(float(result["draw_calls_avg"]))
		else:
			trial_runs.append(float(result["wall_ms_avg"]))
			trial_draw_runs.append(float(result["draw_calls_avg"]))
	var delta := _average(trial_runs) - _average(reference_runs)
	_paired_deltas.append(delta)
	print("STAGE6_BEAM_SHADER_PAIR " + JSON.stringify({
		"pair": pair_id, "reference_ms_avg": _average(reference_runs),
		"trial_ms_avg": _average(trial_runs), "trial_minus_reference_ms": delta,
		"reference_draw_calls_avg": _average(reference_draw_runs),
		"trial_draw_calls_avg": _average(trial_draw_runs),
	}))

func _run_phase(sheets: MultiMeshInstance3D, reference: ShaderMaterial,
		trial: ShaderMaterial, variant: String, pair_id: String, phase: int) -> Dictionary:
	sheets.material_override = reference if variant == "reference" else trial
	for frame in range(SETTLE_FRAMES):
		await process_frame
	var times: Array[float] = []
	var draws: Array[float] = []
	var last_tick := Time.get_ticks_usec()
	var drawn_before := Engine.get_frames_drawn()
	for frame in range(SAMPLE_FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now - last_tick) / 1000.0)
		last_tick = now
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var rendered_frames := Engine.get_frames_drawn() - drawn_before
	_check(rendered_frames == SAMPLE_FRAMES,
		"rendered all frames for shader pair %s/%s" % [pair_id, phase])
	if variant == "reference":
		_reference_times.append_array(times)
		_reference_draws.append_array(draws)
	else:
		_trial_times.append_array(times)
		_trial_draws.append_array(draws)
	var result := {
		"variant": variant, "wall_ms_avg": _average(times),
		"wall_ms_p95": _p95(times), "draw_calls_avg": _average(draws),
	}
	print("STAGE6_BEAM_SHADER_SAMPLE " + JSON.stringify({
		"pair": pair_id, "phase": phase, "variant": variant,
		"wall_ms_avg": result["wall_ms_avg"], "wall_ms_p95": result["wall_ms_p95"],
		"draw_calls_avg": result["draw_calls_avg"], "rendered_frames": rendered_frames,
	}))
	return result

func _compare_images(a: Image, b: Image) -> Dictionary:
	if a == null or b == null or a.is_empty() or b.is_empty() or a.get_size() != b.get_size():
		_fail("Reference and trial image dimensions differ or are empty")
		return {"changed_over_1_lsb": -1, "max_delta_lsb": -1}
	var changed := 0
	var max_delta := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var left := a.get_pixel(x, y)
			var right := b.get_pixel(x, y)
			var delta := maxf(maxf(absf(left.r - right.r), absf(left.g - right.g)),
				maxf(absf(left.b - right.b), absf(left.a - right.a)))
			var lsb := roundi(delta * 255.0)
			max_delta = maxi(max_delta, lsb)
			if lsb > 1:
				changed += 1
	return {"changed_over_1_lsb": changed, "max_delta_lsb": max_delta, "size": a.get_size()}

func _save_capture(image: Image, filename: String) -> void:
	var directory := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	if directory.is_empty():
		return
	var error := image.save_png(directory.path_join(filename))
	_check(error == OK, "saved shader comparison capture %s" % filename)

func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += float(value)
	return snappedf(total / values.size(), 0.001)

func _p95(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(float(sorted[ceili(sorted.size() * 0.95) - 1]), 0.001)

func _minimum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := INF
	for value in values:
		result = minf(result, float(value))
	return snappedf(result, 0.001)

func _maximum(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var result := -INF
	for value in values:
		result = maxf(result, float(value))
	return snappedf(result, 0.001)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _fail(message: String) -> void:
	_failures.append(message)
	_finish_failure()

func _finish_failure() -> void:
	for failure in _failures:
		push_error(failure)
	print("FAIL: Stage 6 paired shader trial (%d failures)" % _failures.size())
	quit(1)
