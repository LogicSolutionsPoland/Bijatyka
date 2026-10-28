extends CanvasLayer
class_name FoundationHUD

signal action_requested(action: String)
signal aura_chosen(aura_id: String)
signal camera_dragged(delta: Vector2)
signal elevator_requested

const MOUSE_POINTER_ID := -2
const NO_POINTER_ID := -1
const MOVE_DRAG_MAX_DISTANCE := 96.0
const MOVE_DRAG_DEADZONE := 0.12
const CAMERA_GESTURE_SPLIT := 0.5
const AURA_LABELS := {
	"light": "LIGHT", "judgment": "JUDGMENT", "fire": "FIRE", "shadow": "SHADOW"
}
const ACTION_ROWS := [
	["punch_left", "punch_right"],
	["kick_left", "kick_right"],
	["spell_0", "spell_1"],
	["spell_2", "spell_3"],
	["dash", "jump"]
]
# L1 / LB and R1 / RB punch; L2 / LT and R2 / RT kick. B casts the
# selected spell, while Y triggers the unlocked Fire-school Blast.
const GAMEPAD_ACTIONS := {
	&"pad_jump": "jump", &"pad_dash": "dash", &"pad_cast_spell": "cast_spell",
	&"pad_punch_left": "punch_left", &"pad_punch_right": "punch_right",
	&"pad_blast": "blast",
	&"pad_kick_left": "kick_left", &"pad_kick_right": "kick_right",
	&"pad_spell_0": "spell_0", &"pad_spell_1": "spell_1",
	&"pad_spell_2": "spell_2", &"pad_spell_3": "spell_3"
}
const MELEE_HOLD_REPEAT_INTERVAL := 0.50
const MELEE_TIMER_EPSILON := 0.0001
const TRIGGER_PRESS_THRESHOLD := 0.55
const TRIGGER_RELEASE_THRESHOLD := 0.35

var _root: Control
var _status_panel: PanelContainer
var _status: Label
var _health_bar: ProgressBar
var _rage_bar: ProgressBar
var _magic_bar: ProgressBar
var _health_tag: Label
var _rage_tag: Label
var _magic_tag: Label
var _notice: Label
var _boss_marker: Label
var _action_buttons: Dictionary = {}
var _elevator_button: Button
var _pressed_pointers: Dictionary = {}
var _held_melee_repeat_timers: Dictionary = {}
var _held_gamepad_actions: Dictionary = {}
var _left_trigger_rest_values: Dictionary = {}
var _right_trigger_rest_values: Dictionary = {}
var _gesture_modes: Dictionary = {}
var _movement_pointer_id := NO_POINTER_ID
var _movement_origin := Vector2.ZERO
var _movement_position := Vector2.ZERO
var _selection_panel: PanelContainer
var _layout_size := Vector2.ZERO

func _ready() -> void:
	add_to_group("mobile_controls")
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_capture_trigger_rest_values()
	_root = Control.new()
	_root.name = "HudCanvas"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	_build_status()
	_build_controls()
	_build_notice()
	_build_boss_marker()
	_root.resized.connect(_layout)
	_layout()

func _process(delta: float) -> void:
	_poll_trigger_axes()
	if get_tree().paused or _selection_panel != null:
		_held_melee_repeat_timers.clear()
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
			repeat_time += MELEE_HOLD_REPEAT_INTERVAL
		held.timer = repeat_time
	for raw_pointer_id in _pressed_pointers.keys():
		var pointer_id := int(raw_pointer_id)
		var button := _pressed_pointers[raw_pointer_id] as Button
		if button == null or not is_instance_valid(button) or button.disabled:
			_held_melee_repeat_timers.erase(pointer_id)
			continue
		var action := str(button.get_meta("action", ""))
		if not _is_melee_action(action):
			_held_melee_repeat_timers.erase(pointer_id)
			continue
		var repeat_time := float(_held_melee_repeat_timers.get(pointer_id, MELEE_HOLD_REPEAT_INTERVAL))
		repeat_time -= minf(delta, MELEE_HOLD_REPEAT_INTERVAL)
		if repeat_time <= MELEE_TIMER_EPSILON:
			_emit_action(action)
			repeat_time += MELEE_HOLD_REPEAT_INTERVAL
		_held_melee_repeat_timers[pointer_id] = repeat_time

func _is_melee_action(action: String) -> bool:
	return action.begins_with("punch_") or action.begins_with("kick_")

func get_move_vector() -> Vector2:
	if _movement_pointer_id == NO_POINTER_ID:
		return Vector2.ZERO
	var movement := (_movement_position - _movement_origin) / MOVE_DRAG_MAX_DISTANCE
	if movement.length() > 1.0:
		movement = movement.normalized()
	return Vector2.ZERO if movement.length() < MOVE_DRAG_DEADZONE else movement

func _build_status() -> void:
	var panel := PanelContainer.new()
	_status_panel = panel
	panel.name = "StatusPanel"
	panel.position = Vector2(18.0, 16.0)
	panel.custom_minimum_size = Vector2(332.0, 138.0)
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


func _build_controls() -> void:
	for row in ACTION_ROWS:
		for action: String in row:
			var caption := action.get_slice("_", 0).to_upper()
			if action.begins_with("spell_"):
				caption = "MAGIC"
			var button := _create_action_button(caption, action, Vector2.ZERO)
			if action.begins_with("spell_"):
				button.disabled = true
				button.tooltip_text = "Unlock a spell through a RAGE aura choice."

func _create_action_button(caption: String, action: String, at: Vector2, dimensions: Vector2 = Vector2(88.0, 82.0)) -> Button:
	var button := Button.new()
	button.text = caption
	button.name = action.to_pascal_case() + "Button"
	button.set_meta("action", action)
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
	# Pointer events are handled below so every finger is independent and an
	# emulated mouse click cannot repeat a touch action.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.toggle_mode = true
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.add_theme_font_size_override("font_size", 17 if dimensions.x > 80.0 else 13)
	button.add_theme_color_override("font_color", Color(0.96, 0.96, 0.90))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.12, 0.16, 0.82)
	normal.border_color = Color(0.76, 0.29, 0.18, 0.92)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.38, 0.13, 0.10, 0.95)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.06, 0.08, 0.11, 0.72)
	disabled_style.border_color = Color(0.35, 0.37, 0.42, 0.7)
	button.add_theme_stylebox_override("disabled", disabled_style)
	_root.add_child(button)
	_action_buttons[action] = button
	button.pressed.connect(_emit_action.bind(action))
	return button

func _ensure_elevator_button() -> void:
	if _elevator_button != null:
		return
	_elevator_button = Button.new()
	_elevator_button.name = "ElevatorButton"
	_elevator_button.position = Vector2(18.0, 162.0)
	_elevator_button.size = Vector2(156.0, 62.0)
	_elevator_button.text = "LIFT"
	_elevator_button.focus_mode = Control.FOCUS_NONE
	_elevator_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_elevator_button.toggle_mode = true
	_elevator_button.process_mode = Node.PROCESS_MODE_ALWAYS
	_elevator_button.add_theme_font_size_override("font_size", 15)
	_elevator_button.add_theme_color_override("font_color", Color(0.96, 0.96, 0.90))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.10, 0.09, 0.07, 0.90)
	normal.border_color = Color(0.92, 0.43, 0.17, 0.96)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	_elevator_button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.38, 0.16, 0.08, 0.96)
	_elevator_button.add_theme_stylebox_override("pressed", pressed)
	_root.add_child(_elevator_button)

func set_elevator_prompt(prompt: String) -> void:
	if prompt.is_empty():
		if _elevator_button != null:
			_elevator_button.visible = false
		return
	_ensure_elevator_button()
	_elevator_button.text = prompt
	_elevator_button.visible = true

func _emit_action(action: String) -> void:
	if get_tree().paused or _selection_panel != null:
		return
	action_requested.emit(action)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		_handle_gamepad_motion(event as InputEventJoypadMotion)
	elif event is InputEventJoypadButton:
		_handle_gamepad_button(event as InputEventJoypadButton)
	elif event is InputEventScreenTouch:
		var handled := false
		if event.pressed and not event.canceled:
			handled = _handle_pointer(event.index, event.position, true)
			if not handled:
				handled = _start_gesture(event.index, event.position)
		else:
			handled = _handle_pointer(event.index, event.position, false)
			if _end_gesture(event.index):
				handled = true
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _update_gesture(event.index, event.position, event.relative):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var pointer_id := MOUSE_POINTER_ID
		var handled := false
		if event.pressed:
			handled = _handle_pointer(pointer_id, event.position, true)
			if not handled:
				handled = _start_gesture(pointer_id, event.position)
		else:
			handled = _handle_pointer(pointer_id, event.position, false)
			if _end_gesture(pointer_id):
				handled = true
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _update_gesture(MOUSE_POINTER_ID, event.position, event.relative):
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
	_update_trigger_action(&"pad_kick_left", _left_trigger_rest_values, device, axis_value)

func _update_right_trigger(device: int, axis_value: float) -> void:
	_update_trigger_action(&"pad_kick_right", _right_trigger_rest_values, device, axis_value)

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
	for input_action: StringName in GAMEPAD_ACTIONS:
		if input_action in [&"pad_kick_left", &"pad_kick_right"] or not event.is_action(input_action):
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

func _start_gesture(pointer_id: int, screen_position: Vector2) -> bool:
	if get_tree().paused or _selection_panel != null or _gesture_modes.has(pointer_id):
		return false
	if _is_over_status_panel(screen_position):
		return false
	var viewport_width := _root.size.x
	if viewport_width <= 1.0:
		return false
	if screen_position.x < viewport_width * CAMERA_GESTURE_SPLIT:
		if _movement_pointer_id != NO_POINTER_ID:
			return false
		_movement_pointer_id = pointer_id
		_movement_origin = screen_position
		_movement_position = screen_position
		_gesture_modes[pointer_id] = "move"
	else:
		_gesture_modes[pointer_id] = "camera"
	return true

func _update_gesture(pointer_id: int, screen_position: Vector2, relative: Vector2) -> bool:
	if not _gesture_modes.has(pointer_id):
		return false
	if get_tree().paused or _selection_panel != null:
		return true
	match str(_gesture_modes[pointer_id]):
		"move":
			_movement_position = screen_position
		"camera":
			camera_dragged.emit(relative)
	return true

func _end_gesture(pointer_id: int) -> bool:
	if not _gesture_modes.has(pointer_id):
		return false
	var mode := str(_gesture_modes[pointer_id])
	_gesture_modes.erase(pointer_id)
	if mode == "move" and _movement_pointer_id == pointer_id:
		_movement_pointer_id = NO_POINTER_ID
		_movement_origin = Vector2.ZERO
		_movement_position = Vector2.ZERO
	return true

func _is_over_status_panel(screen_position: Vector2) -> bool:
	if _status_panel == null or not _status_panel.is_visible_in_tree():
		return false
	var local_position := _status_panel.get_global_transform_with_canvas().affine_inverse() * screen_position
	return Rect2(Vector2.ZERO, _status_panel.size).has_point(local_position)

func _handle_pointer(pointer_id: int, screen_position: Vector2, pressed: bool) -> bool:
	if not pressed:
		if not _pressed_pointers.has(pointer_id):
			return false
		var released_button: Button = _pressed_pointers[pointer_id]
		_pressed_pointers.erase(pointer_id)
		_held_melee_repeat_timers.erase(pointer_id)
		released_button.set_pressed_no_signal(_pressed_pointers.values().has(released_button))
		return true
	if _pressed_pointers.has(pointer_id):
		return true
	if get_tree().paused or _selection_panel != null:
		return false
	if _elevator_button != null and _elevator_button.is_visible_in_tree():
		var elevator_local := _elevator_button.get_global_transform_with_canvas().affine_inverse() * screen_position
		if Rect2(Vector2.ZERO, _elevator_button.size).has_point(elevator_local):
			_pressed_pointers[pointer_id] = _elevator_button
			_elevator_button.set_pressed_no_signal(true)
			elevator_requested.emit()
			return true
	for button: Button in _action_buttons.values():
		var local := button.get_global_transform_with_canvas().affine_inverse() * screen_position
		if button.is_visible_in_tree() and Rect2(Vector2.ZERO, button.size).has_point(local):
			if not button.disabled:
				_pressed_pointers[pointer_id] = button
				button.set_pressed_no_signal(true)
				var action := str(button.get_meta("action"))
				if _is_melee_action(action):
					_held_melee_repeat_timers[pointer_id] = MELEE_HOLD_REPEAT_INTERVAL
				_emit_action(action)
			return true
	return false

func _release_pointers() -> void:
	for button: Button in _pressed_pointers.values():
		button.set_pressed_no_signal(false)
	_pressed_pointers.clear()
	_held_melee_repeat_timers.clear()
	_gesture_modes.clear()
	_movement_pointer_id = NO_POINTER_ID
	_movement_origin = Vector2.ZERO
	_movement_position = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_pointers()
		_held_gamepad_actions.clear()

func _build_notice() -> void:
	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", 24)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.83, 0.33))
	_notice.visible = false
	_root.add_child(_notice)

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
	var margin := 20.0 * scale_factor
	var dimensions := Vector2(108.0, 88.0) * scale_factor
	var gap := 12.0 * scale_factor
	var top := size.y - margin - dimensions.y * 5.0 - gap * 4.0
	for row_index in range(ACTION_ROWS.size()):
		for column in range(2):
			var button := _button_for_action(ACTION_ROWS[row_index][column])
			button.add_theme_font_size_override("font_size", maxi(12, roundi(17.0 * scale_factor)))
			button.size = dimensions
			button.position = Vector2(margin if column == 0 else size.x - margin - dimensions.x, top + row_index * (dimensions.y + gap))
	_notice.position = Vector2(size.x * 0.25, 28.0)
	_notice.size = Vector2(size.x * 0.5, 52.0)
	if _boss_marker != null and not _boss_marker.visible:
		_boss_marker.position = Vector2((size.x - 210.0 * scale_factor) * 0.5, 92.0 * scale_factor)
		_boss_marker.size = Vector2(210.0 * scale_factor, 44.0 * scale_factor)
	if _selection_panel != null:
		_selection_panel.position = (size - _selection_panel.size) * 0.5

func _button_for_action(action: String) -> Button:
	return _action_buttons.get(action) as Button

func update_status(current_hp: int, max_hp: int, current_rage: float, max_rage: float, threshold: float, mana: float, school: String, unlocked_spells: Array[String] = []) -> void:
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
	for slot in range(4):
		var button := _button_for_action("spell_%d" % slot)
		var unlocked := slot < unlocked_spells.size()
		button.disabled = not unlocked
		button.text = "MAGIC\n%s" % str(AURA_LABELS.get(unlocked_spells[slot], unlocked_spells[slot].to_upper())) if unlocked else "MAGIC"
		button.tooltip_text = "Cast %s" % unlocked_spells[slot] if unlocked else "Unlock a spell through a RAGE aura choice."



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
	_release_pointers()
	for key in _held_gamepad_actions:
		_held_gamepad_actions[key].blocked = true
	if _selection_panel != null:
		_selection_panel.queue_free()
	_selection_panel = PanelContainer.new()
	_selection_panel.name = "AuraSelection"
	_selection_panel.process_mode = Node.PROCESS_MODE_ALWAYS
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
	column.add_child(title)
	var hint := Label.new()
	hint.text = "The spell remains unlocked for this soul."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.81))
	column.add_child(hint)
	for aura_id in ["light", "judgment", "fire", "shadow"]:
		var button := Button.new()
		button.text = "%s  •  unlock %s spell" % [AURA_LABELS[aura_id], AURA_LABELS[aura_id]]
		button.custom_minimum_size.y = 48.0
		button.process_mode = Node.PROCESS_MODE_ALWAYS
		button.focus_mode = Control.FOCUS_NONE
		column.add_child(button)
		button.pressed.connect(_emit_aura_choice.bind(aura_id))
	_root.add_child(_selection_panel)
	_selection_panel.size = _selection_panel.custom_minimum_size
	_selection_panel.position = (_root.size - _selection_panel.size) * 0.5
	_notice.visible = false

func _emit_aura_choice(aura_id: String) -> void:
	aura_chosen.emit(aura_id)

func close_aura_selection() -> void:
	if _selection_panel != null:
		_selection_panel.queue_free()
		_selection_panel = null

func show_enemy_telegraph(is_boss: bool) -> void:
	show_notice("BOSS STRIKE — EVADE" if is_boss else "ZOMBIE WINDING UP — EVADE", Color(1.0, 0.42, 0.24))

func show_condemnation() -> void:
	show_notice("A soul run ends when RAGE falls below its threshold.", Color(0.82, 0.52, 1.0))

func set_player_action_state(_action: String) -> void:
	pass
