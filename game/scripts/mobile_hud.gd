extends CanvasLayer
class_name FoundationHUD

signal action_requested(action: String)
signal aura_chosen(aura_id: String)

const PLAYER_CONTROLLER := preload("res://scripts/player_controller.gd")
const AURA_LABELS := {
	"light": "LIGHT", "judgment": "JUDGMENT", "fire": "FIRE", "shadow": "SHADOW"
}
# L1 / LB and R1 / RB punch. L2 / LT quick-casts the first unlocked spell;
# R2 / RT quick-casts the second, falling back to the first. B casts the
# selected spell, while Y triggers the unlocked Fire-school Blast.
const CONTROL_HINT_TEXT := "A / CROSS: JUMP  •  X / SQUARE: FORWARD JUMP\nR3 x3: GRAB ESCAPE  •  L1 / LB + R1 / RB: PUNCH\nL2 / LT: FIRST SPELL  •  R2 / RT / K: SECOND SPELL*\nB / CIRCLE / L: SELECTED SPELL  •  Y / TRIANGLE: BLAST\n*R2 / RT / K uses the first spell until a second is unlocked."
const GAMEPAD_ACTIONS := {
	&"pad_jump": "jump", &"pad_jump_forward": "jump_forward", &"pad_cast_spell": "cast_spell",
	&"pad_escape_limb_grab": "escape_limb_grab",
	&"pad_punch_left": "punch_left", &"pad_punch_right": "punch_right",
	&"pad_blast": "blast",
	&"pad_magic_left": "magic_left", &"pad_magic_right": "magic_right",
	&"pad_spell_0": "spell_0", &"pad_spell_1": "spell_1",
	&"pad_spell_2": "spell_2", &"pad_spell_3": "spell_3"
}
const MELEE_HOLD_REPEAT_INTERVAL := PLAYER_CONTROLLER.TARGET_MELEE_CYCLE_SECONDS
const MELEE_TIMER_EPSILON := 0.0001
const TRIGGER_PRESS_THRESHOLD := 0.55
const TRIGGER_RELEASE_THRESHOLD := 0.35

var _root: Control
var _status_panel: PanelContainer
var _status: Label
var _controls_hint: Label
var _health_bar: ProgressBar
var _rage_bar: ProgressBar
var _magic_bar: ProgressBar
var _health_tag: Label
var _rage_tag: Label
var _magic_tag: Label
var _notice: Label
var _limb_grab_button: Button
var _active_grab_qte_session_id := 0
var _grab_qte_limb := ""
var _boss_marker: Label
var _elevator_prompt_panel: PanelContainer
var _elevator_prompt: Label
var _held_gamepad_actions: Dictionary = {}
var _left_trigger_rest_values: Dictionary = {}
var _right_trigger_rest_values: Dictionary = {}
var _selection_panel: PanelContainer
var _selection_options: Array[String] = []
var _selection_cards: Array[PanelContainer] = []
var _selection_cursor := 0
var _layout_size := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_capture_trigger_rest_values()
	_root = Control.new()
	_root.name = "HudCanvas"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	_build_status()
	_build_notice()
	_build_limb_grab_button()
	_build_boss_marker()
	_root.resized.connect(_layout)
	_layout()

func _process(delta: float) -> void:
	_poll_trigger_axes()
	if get_tree().paused or _selection_panel != null:
		# An input held across a menu must be released before it can act again.
		for key in _held_gamepad_actions:
			_held_gamepad_actions[key].blocked = true
		return
	for key in _held_gamepad_actions:
		var held: Dictionary = _held_gamepad_actions[key]
		if held.blocked or not _is_melee_action(held.action):
			continue
		var repeat_time := float(held.timer) - minf(delta, MELEE_HOLD_REPEAT_INTERVAL)
		if repeat_time <= MELEE_TIMER_EPSILON:
			_emit_action(held.action)
			repeat_time = MELEE_HOLD_REPEAT_INTERVAL
		held.timer = repeat_time

func _is_melee_action(action: String) -> bool:
	return action.begins_with("punch_")

func _build_status() -> void:
	var panel := PanelContainer.new()
	_status_panel = panel
	panel.name = "StatusPanel"
	panel.position = Vector2(18.0, 16.0)
	panel.custom_minimum_size = Vector2(420.0, 205.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.026, 0.038, 0.88)
	style.border_color = Color(0.72, 0.23, 0.15, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	var title := Label.new()
	title.text = "BIJATYKA"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.95, 0.77, 0.60))
	column.add_child(title)
	_status = Label.new()
	_status.text = "MAX RAGE 0  •  SPELL NONE"
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Color(0.78, 0.82, 0.86))
	column.add_child(_status)
	var hp_row := _create_meter_row("HP", Color(0.88, 0.16, 0.11))
	var rage_row := _create_meter_row("RAGE", Color(0.96, 0.36, 0.11))
	var magic_row := _create_meter_row("MAGIC", Color(0.25, 0.62, 0.96))
	column.add_child(hp_row["row"])
	column.add_child(rage_row["row"])
	column.add_child(magic_row["row"])
	_controls_hint = Label.new()
	_controls_hint.name = "CombatControlHint"
	_controls_hint.text = CONTROL_HINT_TEXT
	_controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls_hint.add_theme_font_size_override("font_size", 10)
	_controls_hint.add_theme_color_override("font_color", Color(0.72, 0.77, 0.82))
	column.add_child(_controls_hint)
	_health_bar = hp_row["bar"] as ProgressBar
	_rage_bar = rage_row["bar"] as ProgressBar
	_magic_bar = magic_row["bar"] as ProgressBar
	_health_tag = hp_row["tag"] as Label
	_rage_tag = rage_row["tag"] as Label
	_magic_tag = magic_row["tag"] as Label

func _create_meter_row(caption: String, fill_color: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	var tag := Label.new()
	tag.text = caption
	tag.custom_minimum_size.x = 52.0
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Color(0.82, 0.85, 0.87))
	row.add_child(tag)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size.y = 13.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.055, 0.064, 0.078, 1.0)
	track.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return {"row": row, "bar": bar, "tag": tag}


func _ensure_elevator_prompt() -> void:
	if _elevator_prompt_panel != null:
		return
	_elevator_prompt_panel = PanelContainer.new()
	_elevator_prompt_panel.name = "ElevatorPrompt"
	_elevator_prompt_panel.custom_minimum_size = Vector2(250.0, 48.0)
	_elevator_prompt_panel.size = _elevator_prompt_panel.custom_minimum_size
	_elevator_prompt_panel.position = Vector2(18.0, 162.0)
	_elevator_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.07, 0.90)
	style.border_color = Color(0.92, 0.43, 0.17, 0.96)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	_elevator_prompt_panel.add_theme_stylebox_override("panel", style)
	_elevator_prompt = Label.new()
	_elevator_prompt.name = "ElevatorPromptText"
	_elevator_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_elevator_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_elevator_prompt.add_theme_font_size_override("font_size", 15)
	_elevator_prompt.add_theme_color_override("font_color", Color(0.96, 0.96, 0.90))
	_elevator_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elevator_prompt_panel.add_child(_elevator_prompt)
	_elevator_prompt_panel.visible = false
	_root.add_child(_elevator_prompt_panel)

func set_elevator_prompt(prompt: String) -> void:
	if prompt.is_empty():
		if _elevator_prompt_panel != null:
			_elevator_prompt_panel.visible = false
		return
	_ensure_elevator_prompt()
	_elevator_prompt.text = "L3 / E  •  %s" % prompt
	_elevator_prompt_panel.visible = true

func _emit_action(action: String) -> void:
	if get_tree().paused or _selection_panel != null:
		return
	action_requested.emit(action)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_handle_gamepad_motion(event as InputEventJoypadMotion)
	elif event is InputEventJoypadButton:
		_handle_gamepad_button(event as InputEventJoypadButton)
	elif _selection_panel != null and event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		var handled := true
		match key_event.keycode:
			KEY_UP, KEY_LEFT:
				_move_aura_selection(-1)
			KEY_DOWN, KEY_RIGHT:
				_move_aura_selection(1)
			KEY_ENTER, KEY_KP_ENTER:
				_confirm_aura_selection()
			_:
				handled = false
		if handled:
			get_viewport().set_input_as_handled()

func _capture_trigger_rest_values() -> void:
	for device: int in Input.get_connected_joypads():
		_left_trigger_rest_values[device] = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		_right_trigger_rest_values[device] = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)

func _poll_trigger_axes() -> void:
	for device: int in Input.get_connected_joypads():
		if not _left_trigger_rest_values.has(device):
			_left_trigger_rest_values[device] = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		if not _right_trigger_rest_values.has(device):
			_right_trigger_rest_values[device] = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
		_update_left_trigger(device, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT))
		_update_right_trigger(device, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))

func _update_left_trigger(device: int, axis_value: float) -> void:
	_update_trigger_action(&"pad_magic_left", _left_trigger_rest_values, device, axis_value)

func _update_right_trigger(device: int, axis_value: float) -> void:
	_update_trigger_action(&"pad_magic_right", _right_trigger_rest_values, device, axis_value)

func _update_trigger_action(input_action: StringName, rest_values: Dictionary, device: int, axis_value: float) -> void:
	if not rest_values.has(device):
		rest_values[device] = 0.0
	var rest_value := float(rest_values[device])
	var pull_strength := clampf(absf(axis_value - rest_value), 0.0, 1.0)
	if pull_strength >= TRIGGER_PRESS_THRESHOLD:
		_set_gamepad_action(input_action, device, true)
	elif pull_strength <= TRIGGER_RELEASE_THRESHOLD:
		_set_gamepad_action(input_action, device, false)

func _handle_gamepad_button(event: InputEventJoypadButton) -> void:
	if _selection_panel != null:
		for input_action: StringName in GAMEPAD_ACTIONS:
			if not event.is_action(input_action):
				continue
			if event.pressed:
				match input_action:
					&"pad_spell_0", &"pad_spell_3":
						_move_aura_selection(-1)
					&"pad_spell_1", &"pad_spell_2":
						_move_aura_selection(1)
					&"pad_jump", &"pad_cast_spell":
						_confirm_aura_selection()
					_:
						pass
			else:
				_set_gamepad_action(input_action, event.device, false)
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		return
	for input_action: StringName in GAMEPAD_ACTIONS:
		if input_action in [&"pad_magic_left", &"pad_magic_right"] or not event.is_action(input_action):
			continue
		_set_gamepad_action(input_action, event.device, event.pressed)
		get_viewport().set_input_as_handled()
		return

func _handle_gamepad_motion(event: InputEventJoypadMotion) -> void:
	if event.axis == JOY_AXIS_TRIGGER_LEFT:
		_update_left_trigger(event.device, event.axis_value)
	elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
		_update_right_trigger(event.device, event.axis_value)
	else:
		return
	get_viewport().set_input_as_handled()

func _set_gamepad_action(input_action: StringName, device: int, pressed: bool) -> void:
	var key := "%d:%s" % [device, String(input_action)]
	if pressed:
		if not _held_gamepad_actions.has(key):
			var blocked := get_tree().paused or _selection_panel != null
			var action: String = GAMEPAD_ACTIONS[input_action]
			_held_gamepad_actions[key] = {"action": action, "timer": MELEE_HOLD_REPEAT_INTERVAL, "blocked": blocked}
			if not blocked:
				_emit_action(action)
	else:
		_held_gamepad_actions.erase(key)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_left_trigger_rest_values[device] = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT)
		_right_trigger_rest_values[device] = Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT)
		return
	_left_trigger_rest_values.erase(device)
	_right_trigger_rest_values.erase(device)
	for key in _held_gamepad_actions.keys():
		if str(key).begins_with("%d:" % device):
			_held_gamepad_actions.erase(key)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_held_gamepad_actions.clear()

func _build_notice() -> void:
	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", 24)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.83, 0.33))
	_notice.visible = false
	_root.add_child(_notice)

func _build_limb_grab_button() -> void:
	_limb_grab_button = Button.new()
	_limb_grab_button.name = "EscapeLimbGrab"
	_limb_grab_button.focus_mode = Control.FOCUS_NONE
	_limb_grab_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_limb_grab_button.add_theme_font_size_override("font_size", 19)
	_limb_grab_button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.04, 0.04, 0.94)
	style.border_color = Color(1.0, 0.40, 0.22)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_limb_grab_button.add_theme_stylebox_override("normal", style)
	_limb_grab_button.add_theme_stylebox_override("hover", style)
	_limb_grab_button.pressed.connect(_on_limb_grab_button_pressed)
	_limb_grab_button.visible = false
	_root.add_child(_limb_grab_button)

func _on_limb_grab_button_pressed() -> void:
	_emit_action("escape_limb_grab")

func _build_boss_marker() -> void:
	_boss_marker = Label.new()
	_boss_marker.name = "BossLocator"
	_boss_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_boss_marker.add_theme_font_size_override("font_size", 24)
	_boss_marker.add_theme_color_override("font_color", Color(1.0, 0.12, 0.08))
	_boss_marker.add_theme_color_override("font_shadow_color", Color(0.10, 0.02, 0.02, 0.95))
	_boss_marker.add_theme_constant_override("shadow_offset_x", 2)
	_boss_marker.add_theme_constant_override("shadow_offset_y", 2)
	_boss_marker.visible = false
	_root.add_child(_boss_marker)

func update_boss_marker(screen_position: Vector2, distance_m: float, is_behind: bool) -> void:
	if _boss_marker == null or _root == null:
		return
	var bounds := _root.size
	var center := bounds * 0.5
	var inside := Rect2(Vector2(16.0, 16.0), bounds - Vector2(32.0, 32.0)).has_point(screen_position) and not is_behind
	var marker_position := screen_position
	var direction := screen_position - center
	if not inside:
		if is_behind:
			direction = -direction
		if direction.length_squared() < 1.0:
			direction = Vector2(0.0, 1.0 if is_behind else -1.0)
		var half := bounds * 0.5 - Vector2(120.0, 72.0)
		var scale_x := half.x / maxf(0.001, absf(direction.x))
		var scale_y := half.y / maxf(0.001, absf(direction.y))
		marker_position = center + direction * minf(scale_x, scale_y)
		marker_position.y = maxf(70.0, marker_position.y)
	else:
		marker_position += Vector2(0.0, -38.0)
	var arrow := "→" if absf(direction.x) > absf(direction.y) and direction.x > 0.0 else ("←" if absf(direction.x) > absf(direction.y) else ("↓" if direction.y > 0.0 else "↑"))
	_boss_marker.text = "%s  BOSS  %dm" % ["▼" if inside else arrow, roundi(distance_m)]
	_boss_marker.size = Vector2(210.0, 44.0)
	_boss_marker.position = marker_position - _boss_marker.size * 0.5
	_boss_marker.visible = true

func hide_boss_marker() -> void:
	if _boss_marker != null:
		_boss_marker.visible = false

func _layout() -> void:
	if _root == null:
		return
	var size := _root.size
	if size == _layout_size or size.x < 1.0:
		return
	_layout_size = size
	var scale_factor := minf(size.x / 1280.0, size.y / 720.0)
	_notice.position = Vector2(size.x * 0.25, 28.0)
	_notice.size = Vector2(size.x * 0.5, 52.0)
	if _limb_grab_button != null:
		_limb_grab_button.size = Vector2(minf(size.x - 36.0, 600.0 * scale_factor), 66.0 * scale_factor)
		_limb_grab_button.position = Vector2((size.x - _limb_grab_button.size.x) * 0.5, size.y * 0.74)
	if _boss_marker != null and not _boss_marker.visible:
		_boss_marker.position = Vector2((size.x - 210.0 * scale_factor) * 0.5, 92.0 * scale_factor)
		_boss_marker.size = Vector2(210.0 * scale_factor, 44.0 * scale_factor)
	if _elevator_prompt_panel != null:
		_elevator_prompt_panel.position = Vector2(18.0 * scale_factor, 162.0 * scale_factor)
		_elevator_prompt_panel.custom_minimum_size = Vector2(250.0, 48.0) * scale_factor
		_elevator_prompt_panel.size = _elevator_prompt_panel.custom_minimum_size
	if _selection_panel != null:
		_selection_panel.position = (size - _selection_panel.size) * 0.5

func update_status(current_hp: int, max_hp: int, current_rage: float, max_rage: float, threshold: float, mana: float, school: String, _unlocked_spells: Array[String] = []) -> void:
	if _status == null:
		return
	var threshold_text := "--" if threshold <= 0.0 else "%.0f" % threshold
	var spell_text: String = "NONE" if school.is_empty() else str(AURA_LABELS.get(school, school.to_upper()))
	_status.text = "PEAK RAGE %.0f  •  CONDEMN %s  •  %s" % [max_rage, threshold_text, spell_text]
	if _health_bar != null:
		_health_bar.value = 100.0 * float(current_hp) / maxf(1.0, float(max_hp))
		_health_tag.text = "HP %d" % current_hp
	if _rage_bar != null:
		_rage_bar.value = clampf(current_rage, 0.0, 100.0)
		_rage_tag.text = "RAGE %d" % roundi(current_rage)
	if _magic_bar != null:
		_magic_bar.value = clampf(mana, 0.0, 100.0)
		_magic_tag.text = "MAGIC %d" % roundi(mana)

func show_notice(message: String, color: Color = Color(1.0, 0.83, 0.33)) -> void:
	if _notice == null:
		return
	_notice.text = message
	_notice.add_theme_color_override("font_color", color)
	_notice.visible = true
	get_tree().create_timer(1.55, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(_notice) and _selection_panel == null:
			_notice.visible = false)

func show_aura_selection(milestone: int) -> void:
	for key in _held_gamepad_actions:
		_held_gamepad_actions[key].blocked = true
	if _selection_panel != null:
		_selection_panel.queue_free()
	_selection_options.clear()
	_selection_options.append_array(["light", "judgment", "fire", "shadow"])
	_selection_cards.clear()
	_selection_cursor = 0
	_selection_panel = PanelContainer.new()
	_selection_panel.name = "AuraSelection"
	_selection_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_selection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_panel.custom_minimum_size = Vector2(430.0, 330.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.05, 0.97)
	panel_style.border_color = Color(0.93, 0.34, 0.15)
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 20.0
	panel_style.content_margin_right = 20.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	_selection_panel.add_theme_stylebox_override("panel", panel_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	_selection_panel.add_child(column)
	var title := Label.new()
	title.text = "RAGE %d — CHOOSE AN AURA" % milestone
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.68))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var hint := Label.new()
	hint.text = "D-pad: choose  •  A / B: confirm"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.81))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(hint)
	for aura_id: String in _selection_options:
		var card := PanelContainer.new()
		card.custom_minimum_size.y = 48.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.text = "%s  •  unlock %s spell" % [AURA_LABELS[aura_id], AURA_LABELS[aura_id]]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 15)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(label)
		column.add_child(card)
		_selection_cards.append(card)
	_root.add_child(_selection_panel)
	_selection_panel.size = _selection_panel.custom_minimum_size
	_selection_panel.position = (_root.size - _selection_panel.size) * 0.5
	_update_aura_selection_highlight()
	_notice.visible = false

func _move_aura_selection(direction: int) -> void:
	if _selection_options.is_empty():
		return
	_selection_cursor = (_selection_cursor + direction + _selection_options.size()) % _selection_options.size()
	_update_aura_selection_highlight()

func _update_aura_selection_highlight() -> void:
	for index in range(_selection_cards.size()):
		var selected := index == _selection_cursor
		var card := _selection_cards[index]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.31, 0.12, 0.07, 0.96) if selected else Color(0.07, 0.09, 0.12, 0.90)
		style.border_color = Color(1.0, 0.54, 0.22, 1.0) if selected else Color(0.25, 0.29, 0.34, 0.82)
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", style)
		var label := card.get_child(0) as Label
		if label != null:
			label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.82) if selected else Color(0.78, 0.82, 0.86))

func _confirm_aura_selection() -> void:
	if _selection_cursor < 0 or _selection_cursor >= _selection_options.size():
		return
	_emit_aura_choice(_selection_options[_selection_cursor])

func _emit_aura_choice(aura_id: String) -> void:
	aura_chosen.emit(aura_id)

func close_aura_selection() -> void:
	if _selection_panel != null:
		_selection_panel.queue_free()
		_selection_panel = null
	_selection_options.clear()
	_selection_cards.clear()
	_selection_cursor = 0

func show_enemy_telegraph(is_boss: bool) -> void:
	show_notice("BOSS STRIKE — EVADE" if is_boss else "ZOMBIE WINDING UP — EVADE", Color(1.0, 0.42, 0.24))

func show_limb_grab_windup(limb: String) -> void:
	show_notice("%s GRAB — EVADE" % limb, Color(1.0, 0.42, 0.24))

# One existing touch button and the R3 edge both go to the same player QTE.
func begin_grab_qte(session_id: int, _enemy: FoundationEnemy, limb: String, required_presses: int, duration_seconds: float) -> void:
	if _limb_grab_button == null or session_id <= 0:
		return
	_active_grab_qte_session_id = session_id
	_grab_qte_limb = limb
	if _notice != null:
		_notice.visible = false
	_limb_grab_button.visible = true
	update_grab_qte(session_id, 0, required_presses, duration_seconds)

func update_grab_qte(session_id: int, accepted_presses: int, required_presses: int, remaining_seconds: float) -> void:
	if session_id != _active_grab_qte_session_id or _limb_grab_button == null:
		return
	var label_text := "%s — %d/%d  •  %.1fs  TAP / R3" % [_grab_qte_limb, accepted_presses, required_presses, maxf(0.0, remaining_seconds)]
	if _limb_grab_button.text != label_text:
		_limb_grab_button.text = label_text

func finish_grab_qte(session_id: int, outcome: String) -> void:
	if session_id != _active_grab_qte_session_id:
		return
	_active_grab_qte_session_id = 0
	_grab_qte_limb = ""
	hide_limb_grab()
	if outcome == "escaped":
		show_notice("GRAB BROKEN — ESCAPED", Color(0.45, 0.97, 0.65))
	elif outcome == "timeout":
		show_notice("GRAB FAILED — TOO SLOW", Color(1.0, 0.3, 0.23))

# Compatibility for legacy HUD callers; current Stage 2 uses begin_grab_qte.
func show_limb_grab(limb: String) -> void:
	if _limb_grab_button != null:
		_limb_grab_button.text = "%s HELD — TAP / R3 / R" % limb
		_limb_grab_button.visible = true

func hide_limb_grab() -> void:
	if _limb_grab_button != null:
		_limb_grab_button.visible = false
	if _notice != null and _notice.text.ends_with("GRAB — EVADE"):
		_notice.visible = false

func set_player_action_state(_action: String) -> void:
	pass
