extends SceneTree
## Frozen 30-zombie GL Compatibility benchmark for the two translucent flashlight meshes.
## Timings from the CI software renderer are host measurements, never Android GPU times.

const SCENE := preload("res://scenes/foundation.tscn")
const WARMUP_FRAMES := 90
const SETTLE_FRAMES := 10
const SAMPLE_FRAMES := 50
const SPOTLIGHT_ENERGY := 1.6
const BEAM_PAIRS := [
	{"id": "none-1", "first": "complete", "second": "none", "candidate": "none"},
	{"id": "none-2", "first": "none", "second": "complete", "candidate": "none"},
	{"id": "none-3", "first": "complete", "second": "none", "candidate": "none"},
	{"id": "sheets-1", "first": "complete", "second": "sheets_only", "candidate": "sheets_only"},
	{"id": "sheets-2", "first": "sheets_only", "second": "complete", "candidate": "sheets_only"},
	{"id": "sheets-3", "first": "complete", "second": "sheets_only", "candidate": "sheets_only"},
	{"id": "sections-1", "first": "complete", "second": "sections_only", "candidate": "sections_only"},
	{"id": "sections-2", "first": "sections_only", "second": "complete", "candidate": "sections_only"},
	{"id": "sections-3", "first": "complete", "second": "sections_only", "candidate": "sections_only"},
]
const SPOTLIGHT_PAIRS := [
	{"id": "spot-1", "first": "on", "second": "off"},
	{"id": "spot-2", "first": "off", "second": "on"},
	{"id": "spot-3", "first": "on", "second": "off"},
]
const BEAM_MODES := ["complete", "none", "sheets_only", "sections_only"]

var _failures: Array[String] = []
var _phase_index := 0
var _beam_wall: Dictionary = {}
var _beam_draws: Dictionary = {}
var _beam_pair_deltas: Dictionary = {"none": [], "sheets_only": [], "sections_only": []}
var _beam_draw_deltas: Dictionary = {"none": [], "sheets_only": [], "sections_only": []}
var _spot_wall: Dictionary = {"on": [], "off": []}
var _spot_draws: Dictionary = {"on": [], "off": []}
var _spot_pair_deltas: Array[float] = []

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
		_fail("Cannot start the fixed 30-zombie ground scene")
		quit(1)
		return

	for frame in range(WARMUP_FRAMES):
		await process_frame

	# Freeze scene/gameplay after the same warm-up for every configuration.
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var manager: Node = game.flashlight_visibility_manager
	var spotlight := manager.spotlight as SpotLight3D
	var sheets := spotlight.get_node_or_null("PlayerFlashlightBeamSheets") as MultiMeshInstance3D
	var sections := spotlight.get_node_or_null("PlayerFlashlightBeamSections") as MeshInstance3D
	_check(sheets != null and sheets.multimesh != null, "one batched crossed-sheet beam exists")
	_check(sections != null and sections.mesh != null and sections.mesh.get_surface_count() == 1,
		"one cross-section beam mesh exists")
	_check(game._pencil_screen_pass.visible, "Stage 5 Pencil pass stays enabled")
	_check(manager._composite.visible, "Stage 5 flashlight visibility mask stays enabled")
	_check(spotlight.visible, "spotlight stays enabled for translucent-beam comparisons")
	_check(is_equal_approx(root.scaling_3d_scale, 0.40), "render scale is fixed at 40 percent")
	_check(Engine.max_fps == 60, "frame cap is fixed at 60 FPS")
	_check(bool(game._floor_material.get_shader_parameter("floor_skip_enabled")),
		"Stage 5 ground shader settings stay unchanged")
	var slots: int = game.spawn_director._live.size() + game.spawn_director._dormant_population.size() + \
		game.spawn_director._pending.size() + game.spawn_director._initial_population_pending
	_check(slots == 30, "the frozen ordinary-zombie population has exactly 30 reserved slots")
	_check(game.spawn_director.ordinary_population_count() == 30, "the game reports exactly 30 ordinary zombies")
	_check(game.horde_far_visuals.get_resident_rig_count() <= 7, "resident zombie rigs stay within the seven-rig cap")
	if not _failures.is_empty():
		_finish_failure()
		return

	for mode in BEAM_MODES:
		_beam_wall[mode] = []
		_beam_draws[mode] = []
	for pair_variant in BEAM_PAIRS:
		var pair: Dictionary = pair_variant
		await _run_beam_pair(game, spotlight, sheets, sections, pair)

	# The spotlight is measured separately: keep both translucent meshes visible
	# and change only light_energy, so its surface-lighting work is not counted
	# as transparent beam overdraw.
	for pair_variant in SPOTLIGHT_PAIRS:
		var pair: Dictionary = pair_variant
		await _run_spotlight_pair(spotlight, sheets, sections, pair)

	for mode in BEAM_MODES:
		var wall_samples: Array = _beam_wall[mode]
		var draw_samples: Array = _beam_draws[mode]
		print("STAGE6_BEAM_SUMMARY " + JSON.stringify({
			"mode": mode,
			"host_wall_ms_avg": _average(wall_samples),
			"host_wall_ms_p95": _p95(wall_samples),
			"draw_calls_avg": _average(_beam_draws[mode]),
			"measured_frames": wall_samples.size(),
			"render_scale": root.scaling_3d_scale,
			"fps_cap": Engine.max_fps,
			"zombie_slots": slots,
			"spotlight_energy": SPOTLIGHT_ENERGY,
			"pencil_enabled": game._pencil_screen_pass.visible,
			"mask_enabled": manager._composite.visible,
			"floor_skip_enabled": game._floor_material.get_shader_parameter("floor_skip_enabled"),
			"renderer": "GitHub Actions host, GL Compatibility, LIBGL_ALWAYS_SOFTWARE=1",
		}))
	for mode in ["none", "sheets_only", "sections_only"]:
		print("STAGE6_BEAM_PAIRED_RESULT " + JSON.stringify({
			"candidate": mode,
			"paired_delta_ms_avg": _average(_beam_pair_deltas[mode]),
			"paired_delta_ms_min": _minimum(_beam_pair_deltas[mode]),
			"paired_delta_ms_max": _maximum(_beam_pair_deltas[mode]),
			"paired_draw_delta_avg": _average(_beam_draw_deltas[mode]),
			"repeat_count": _beam_pair_deltas[mode].size(),
		}))
	print("STAGE6_SPOTLIGHT_SUMMARY " + JSON.stringify({
		"on_wall_ms_avg": _average(_spot_wall["on"]),
		"on_wall_ms_p95": _p95(_spot_wall["on"]),
		"off_wall_ms_avg": _average(_spot_wall["off"]),
		"off_wall_ms_p95": _p95(_spot_wall["off"]),
		"on_draw_calls_avg": _average(_spot_draws["on"]),
		"off_draw_calls_avg": _average(_spot_draws["off"]),
		"paired_delta_ms_avg": _average(_spot_pair_deltas),
		"paired_delta_ms_min": _minimum(_spot_pair_deltas),
		"paired_delta_ms_max": _maximum(_spot_pair_deltas),
		"repeat_count": _spot_pair_deltas.size(),
		"translucent_beam": "both meshes enabled throughout",
		"renderer": "GitHub Actions host, GL Compatibility, LIBGL_ALWAYS_SOFTWARE=1",
	}))
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: Stage 6 frozen 30-zombie flashlight beam profile")
		quit(0)
	else:
		_finish_failure()

func _run_beam_pair(game: Node, spotlight: SpotLight3D, sheets: MultiMeshInstance3D,
		sections: MeshInstance3D, pair: Dictionary) -> void:
	var pair_id := String(pair["id"])
	var first_mode := String(pair["first"])
	var second_mode := String(pair["second"])
	var candidate := String(pair["candidate"])
	var phases: Array[Dictionary] = []
	phases.append(await _run_beam_phase(game, spotlight, sheets, sections, first_mode, pair_id, 0))
	phases.append(await _run_beam_phase(game, spotlight, sheets, sections, second_mode, pair_id, 1))
	phases.append(await _run_beam_phase(game, spotlight, sheets, sections, second_mode, pair_id, 2))
	phases.append(await _run_beam_phase(game, spotlight, sheets, sections, first_mode, pair_id, 3))
	var baseline_values: Array[float] = []
	var candidate_values: Array[float] = []
	var baseline_draws: Array[float] = []
	var candidate_draws: Array[float] = []
	for result in phases:
		if String(result["mode"]) == "complete":
			baseline_values.append(float(result["wall_ms_avg"]))
			baseline_draws.append(float(result["draw_calls_avg"]))
		elif String(result["mode"]) == candidate:
			candidate_values.append(float(result["wall_ms_avg"]))
			candidate_draws.append(float(result["draw_calls_avg"]))
	var paired_delta := _average(candidate_values) - _average(baseline_values)
	_beam_pair_deltas[candidate].append(paired_delta)
	_beam_draw_deltas[candidate].append(_average(candidate_draws) - _average(baseline_draws))
	print("STAGE6_BEAM_PAIR " + JSON.stringify({
		"pair": pair_id,
		"candidate": candidate,
		"complete_ms_avg": _average(baseline_values),
		"candidate_ms_avg": _average(candidate_values),
		"candidate_minus_complete_ms": paired_delta,
		"complete_draw_calls_avg": _average(baseline_draws),
		"candidate_draw_calls_avg": _average(candidate_draws),
		"candidate_minus_complete_draw_calls": _average(candidate_draws) - _average(baseline_draws),
	}))

func _run_beam_phase(game: Node, spotlight: SpotLight3D, sheets: MultiMeshInstance3D,
		sections: MeshInstance3D, mode: String, pair_id: String, phase: int) -> Dictionary:
	_set_beam_mode(spotlight, sheets, sections, mode)
	for frame in range(SETTLE_FRAMES):
		await process_frame
	var wall_samples: Array[float] = []
	var draw_samples: Array[float] = []
	var last_tick := Time.get_ticks_usec()
	var drawn_before := Engine.get_frames_drawn()
	for frame in range(SAMPLE_FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		wall_samples.append(float(now - last_tick) / 1000.0)
		last_tick = now
		draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var rendered_frames := Engine.get_frames_drawn() - drawn_before
	_check(rendered_frames == SAMPLE_FRAMES, "rendered all frames for beam sample %s/%s" % [pair_id, phase])
	_beam_wall[mode].append_array(wall_samples)
	_beam_draws[mode].append_array(draw_samples)
	var result := {
		"mode": mode,
		"wall_ms_avg": _average(wall_samples),
		"wall_ms_p95": _p95(wall_samples),
		"draw_calls_avg": _average(draw_samples),
		"rendered_frames": rendered_frames,
	}
	print("STAGE6_BEAM_SAMPLE " + JSON.stringify({
		"pair": pair_id, "phase": phase, "mode": mode,
		"wall_ms_avg": result["wall_ms_avg"], "wall_ms_p95": result["wall_ms_p95"],
		"draw_calls_avg": result["draw_calls_avg"], "rendered_frames": rendered_frames,
		"render_scale": root.scaling_3d_scale, "fps_cap": Engine.max_fps,
		"spotlight_energy": spotlight.light_energy,
		"pencil_enabled": game._pencil_screen_pass.visible,
		"mask_enabled": game.flashlight_visibility_manager._composite.visible,
	}))
	return result

func _run_spotlight_pair(spotlight: SpotLight3D, sheets: MultiMeshInstance3D,
		sections: MeshInstance3D, pair: Dictionary) -> void:
	var pair_id := String(pair["id"])
	var first_mode := String(pair["first"])
	var second_mode := String(pair["second"])
	var phases: Array[Dictionary] = []
	phases.append(await _run_spotlight_phase(spotlight, sheets, sections, first_mode, pair_id, 0))
	phases.append(await _run_spotlight_phase(spotlight, sheets, sections, second_mode, pair_id, 1))
	phases.append(await _run_spotlight_phase(spotlight, sheets, sections, second_mode, pair_id, 2))
	phases.append(await _run_spotlight_phase(spotlight, sheets, sections, first_mode, pair_id, 3))
	var on_values: Array[float] = []
	var off_values: Array[float] = []
	for result in phases:
		if String(result["mode"]) == "on":
			on_values.append(float(result["wall_ms_avg"]))
		else:
			off_values.append(float(result["wall_ms_avg"]))
	var delta := _average(off_values) - _average(on_values)
	_spot_pair_deltas.append(delta)
	print("STAGE6_SPOTLIGHT_PAIR " + JSON.stringify({
		"pair": pair_id, "on_ms_avg": _average(on_values), "off_ms_avg": _average(off_values),
		"off_minus_on_ms": delta,
	}))

func _run_spotlight_phase(spotlight: SpotLight3D, sheets: MultiMeshInstance3D,
		sections: MeshInstance3D, mode: String, pair_id: String, phase: int) -> Dictionary:
	spotlight.visible = true
	spotlight.light_energy = SPOTLIGHT_ENERGY if mode == "on" else 0.0
	sheets.visible = true
	sections.visible = true
	for frame in range(SETTLE_FRAMES):
		await process_frame
	var wall_samples: Array[float] = []
	var draw_samples: Array[float] = []
	var last_tick := Time.get_ticks_usec()
	var drawn_before := Engine.get_frames_drawn()
	for frame in range(SAMPLE_FRAMES):
		await process_frame
		var now := Time.get_ticks_usec()
		wall_samples.append(float(now - last_tick) / 1000.0)
		last_tick = now
		draw_samples.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var rendered_frames := Engine.get_frames_drawn() - drawn_before
	_check(rendered_frames == SAMPLE_FRAMES, "rendered all frames for spotlight sample %s/%s" % [pair_id, phase])
	_spot_wall[mode].append_array(wall_samples)
	_spot_draws[mode].append_array(draw_samples)
	var result := {
		"mode": mode,
		"wall_ms_avg": _average(wall_samples),
		"wall_ms_p95": _p95(wall_samples),
		"draw_calls_avg": _average(draw_samples),
		"rendered_frames": rendered_frames,
	}
	print("STAGE6_SPOT_SAMPLE " + JSON.stringify({
		"pair": pair_id, "phase": phase, "spotlight": mode,
		"wall_ms_avg": result["wall_ms_avg"], "wall_ms_p95": result["wall_ms_p95"],
		"draw_calls_avg": result["draw_calls_avg"], "rendered_frames": rendered_frames,
		"translucent_beam": "complete",
	}))
	return result

func _set_beam_mode(spotlight: SpotLight3D, sheets: MultiMeshInstance3D,
		sections: MeshInstance3D, mode: String) -> void:
	spotlight.visible = true
	spotlight.light_energy = SPOTLIGHT_ENERGY
	sheets.visible = mode == "complete" or mode == "sheets_only"
	sections.visible = mode == "complete" or mode == "sections_only"

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
	print("FAIL: Stage 6 flashlight beam profile (%d failures)" % _failures.size())
	quit(1)
