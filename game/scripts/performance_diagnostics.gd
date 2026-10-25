extends CanvasLayer
class_name FoundationPerformanceDiagnostics
## Development-only profiler. It samples at 2 Hz and creates its UI once.

signal scenario_requested(population: int, mode: String)
signal stop_requested

const SAMPLE_INTERVAL := 0.5
const POPULATIONS := [20, 100, 200]
const MODES := ["concentrated", "approach"]

var _panel: PanelContainer
var _readout: Label
var _visible := false
var _sample_elapsed := 0.0
var _corner_hold := false
var _corner_hold_elapsed := 0.0

func _ready() -> void:
	layer = 100
	_build_ui()
	_panel.visible = false
	set_process(true)
	set_process_input(true)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ProfilerPanel"
	_panel.position = Vector2(14.0, 14.0)
	_panel.custom_minimum_size = Vector2(370.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.045, 0.94)
	style.border_color = Color(0.75, 0.34, 0.14, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "DEVELOPMENT PROFILER"
	title.add_theme_font_size_override("font_size", 18)
	column.add_child(title)

	_readout = Label.new()
	_readout.text = "Waiting for first sample…"
	_readout.add_theme_font_size_override("font_size", 14)
	column.add_child(_readout)

	for mode in MODES:
		var mode_label := Label.new()
		mode_label.text = "Concentrated horde" if mode == "concentrated" else "Normal 50 m approach"
		column.add_child(mode_label)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		column.add_child(row)
		for population in POPULATIONS:
			var count := int(population)
			var scenario_mode := String(mode)
			var button := Button.new()
			button.text = "%d" % count
			button.custom_minimum_size = Vector2(70.0, 38.0)
			button.pressed.connect(func() -> void:
				scenario_requested.emit(count, scenario_mode)
			)
			row.add_child(button)

	var stop := Button.new()
	stop.text = "Stop scenario / restore normal 200"
	stop.pressed.connect(func() -> void: stop_requested.emit())
	column.add_child(stop)

	var hint := Label.new()
	hint.text = "F3 toggles • phone: hold the top-right corner for 1.5 s"
	hint.add_theme_font_size_override("font_size", 12)
	column.add_child(hint)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		_toggle()
	elif event is InputEventScreenTouch:
		var size := get_viewport().get_visible_rect().size
		var touch := event as InputEventScreenTouch
		if touch.pressed and touch.position.x >= size.x * 0.88 and touch.position.y <= size.y * 0.12:
			_corner_hold = true
			_corner_hold_elapsed = 0.0
		elif not touch.pressed:
			_corner_hold = false
			_corner_hold_elapsed = 0.0

func _process(delta: float) -> void:
	if _corner_hold:
		_corner_hold_elapsed += delta
		if _corner_hold_elapsed >= 1.5:
			_corner_hold = false
			_toggle()
	if not _visible:
		return
	_sample_elapsed += delta
	if _sample_elapsed < SAMPLE_INTERVAL:
		return
	_sample_elapsed = 0.0
	_update_readout()

func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_sample_elapsed = SAMPLE_INTERVAL
		_update_readout()

func _update_readout() -> void:
	var counts := _collect_horde_counts()
	var fx_stats := _collect_effect_pool_stats()
	var rig_stats := _collect_rig_pool_stats()
	var rendered := Engine.get_frames_drawn() > 0
	var fps := "N/A (headless/no rendered frame)"
	var draw_calls := "N/A (headless/no rendered frame)"
	var render_objects := "N/A (headless/no rendered frame)"
	if rendered:
		fps = "%.0f" % Performance.get_monitor(Performance.TIME_FPS)
		draw_calls = "%d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		render_objects = "%d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	var process_seconds := Performance.get_monitor(Performance.TIME_PROCESS)
	var physics_seconds := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	var static_bytes := Performance.get_monitor(Performance.MEMORY_STATIC)
	var process_ms := "%.2f ms" % (process_seconds * 1000.0) if process_seconds > 0.0 else "N/A"
	var physics_ms := "%.2f ms" % (physics_seconds * 1000.0) if physics_seconds > 0.0 else "N/A"
	var memory := "%.1f MiB" % (static_bytes / 1048576.0) if static_bytes > 0.0 else "N/A (unavailable in this build)"
	_readout.text = (
		"FPS: %s\nFrame processing: %s   Physics: %s\n"
		+ "Active zombies: %d\n"
		+ "Detailed 0–18 m: %d   Low-poly 18–30 m: %d\n"
		+ "Outside 30 m: %d   Selected zombie rigs: %d / %d (+ boss: %d)\n"
		+ "Resident rigs: %d   Dying: %d   Spare: %d\n"
		+ "Reduced-motion silhouettes: %d   Active animated skeletons: %d\n"
		+ "Draw calls: %s   Rendered objects: %s\n"
		+ "Combat FX pool: %d reused / %d created   active: %d   overflow: %d\n"
		+ "Zombie rigs: %d reused / %d created   overflow: %d\n"
		+ "Engine static memory: %s"
	) % [
		fps, process_ms, physics_ms, counts.active, counts.detailed,
		counts.low_poly, counts.outside, counts.full_rigs, FoundationEnemy.FULL_ANIMATION_BUDGET, counts.boss_rigs,
		rig_stats.resident, rig_stats.dying, rig_stats.spare,
		counts.reduced_motion, counts.skeletons,
		draw_calls, render_objects, fx_stats.reused, fx_stats.created,
		fx_stats.active, fx_stats.overflow,
		rig_stats.reused, rig_stats.created, rig_stats.overflow, memory
	]

func _collect_rig_pool_stats() -> Dictionary:
	var fallback := {"resident": 0, "dying": 0, "spare": 0, "created": 0, "reused": 0, "overflow": 0}
	if not is_instance_valid(get_parent()):
		return fallback
	var batch: Node = get_parent().get("horde_far_visuals") as Node
	return batch.call("get_rig_pool_stats") as Dictionary if is_instance_valid(batch) else fallback

func _collect_effect_pool_stats() -> Dictionary:
	var fallback := {"created": 0, "reused": 0, "active": 0, "overflow": 0}
	if not is_instance_valid(get_parent()):
		return fallback
	var pool: Node = get_parent().get("combat_fx_pool") as Node
	if not is_instance_valid(pool) or not pool.has_method("get_profile_stats"):
		return fallback
	return pool.call("get_profile_stats") as Dictionary

func _collect_horde_counts() -> Dictionary:
	var result := {
		"active": 0,
		"detailed": 0,
		"low_poly": 0,
		"outside": 0,
		"skeletons": 0,
		"full_rigs": 0,
		"reduced_motion": 0,
		"boss_rigs": 0,
	}
	if not is_instance_valid(get_parent()):
		return result
	var player := get_parent().get("player") as Node3D
	if not is_instance_valid(player):
		return result
	var enemies := get_tree().get_nodes_in_group("enemies")
	for node in enemies:
		if not node is FoundationEnemy:
			continue
		var enemy := node as FoundationEnemy
		if enemy.hp <= 0:
			continue
		if enemy.is_boss:
			if enemy._animation_player != null and enemy._animation_player.is_playing():
				result.boss_rigs += 1
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
