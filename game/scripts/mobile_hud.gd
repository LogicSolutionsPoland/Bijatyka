extends CanvasLayer
class_name FoundationHUD

signal action_requested(action: String)
signal aura_chosen(aura_id: String)

const TouchStickScript := preload("res://scripts/touch_stick.gd")
const AURA_LABELS := {
	"light": "LIGHT", "judgment": "JUDGMENT", "fire": "FIRE", "shadow": "SHADOW"
}

var _root: Control
var _stick: TouchStick
var _status: Label
var _health_bar: ProgressBar
var _rage_bar: ProgressBar
var _magic_bar: ProgressBar
var _health_tag: Label
var _rage_tag: Label
var _magic_tag: Label
var _notice: Label
var _spell_button: Button
var _selection_panel: PanelContainer
var _layout_size := Vector2.ZERO

func _ready() -> void:
	add_to_group("mobile_controls")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "HudCanvas"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)
	_build_status()
	_build_controls()
	_build_notice()
	_root.resized.connect(_layout)
	_layout()

func get_move_vector() -> Vector2:
	return _stick.get_vector() if _stick != null else Vector2.ZERO

func _build_status() -> void:
	var panel := PanelContainer.new()
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
	title.text = "RETRIBUTION  /  THORNBOUND"
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
	_stick = TouchStickScript.new()
	_stick.name = "MovementStick"
	_root.add_child(_stick)
	_create_action_button("PUNCH", "punch", Vector2.ZERO)
	_create_action_button("KICK", "kick", Vector2.ZERO)
	_create_action_button("JUMP", "jump", Vector2.ZERO)
	_create_action_button("DASH", "dash", Vector2.ZERO)
	_spell_button = _create_action_button("MAGIC", "spell", Vector2.ZERO)
	_spell_button.disabled = true
	_spell_button.tooltip_text = "Unlock a spell through a RAGE aura choice."
	_create_action_button("CYCLE", "cycle_spell", Vector2.ZERO, Vector2(76.0, 54.0))

func _create_action_button(caption: String, action: String, at: Vector2, dimensions: Vector2 = Vector2(88.0, 82.0)) -> Button:
	var button := Button.new()
	button.text = caption
	button.set_meta("action", action)
	button.position = at
	button.size = dimensions
	button.focus_mode = Control.FOCUS_NONE
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
	_root.add_child(button)
	button.pressed.connect(_emit_action.bind(action))
	return button

func _emit_action(action: String) -> void:
	action_requested.emit(action)

func _build_notice() -> void:
	_notice = Label.new()
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.add_theme_font_size_override("font_size", 24)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.83, 0.33))
	_notice.add_theme_color_override("font_shadow_color", Color(0.02, 0.03, 0.04, 0.95))
	_notice.add_theme_constant_override("shadow_offset_x", 2)
	_notice.add_theme_constant_override("shadow_offset_y", 2)
	_notice.visible = false
	_root.add_child(_notice)

func _layout() -> void:
	if _root == null:
		return
	var size := _root.size
	if size == _layout_size or size.x < 1.0:
		return
	_layout_size = size
	if _stick != null:
		_stick.position = Vector2(34.0, size.y - 192.0)
		_stick.size = Vector2(156.0, 156.0)
	var punch := _button_for_action("punch")
	var kick := _button_for_action("kick")
	var jump := _button_for_action("jump")
	var dash := _button_for_action("dash")
	var magic := _spell_button
	var cycle := _button_for_action("cycle_spell")
	punch.position = Vector2(size.x - 212.0, size.y - 196.0)
	kick.position = Vector2(size.x - 114.0, size.y - 196.0)
	jump.position = Vector2(size.x - 212.0, size.y - 102.0)
	dash.position = Vector2(size.x - 114.0, size.y - 102.0)
	magic.position = Vector2(size.x - 310.0, size.y - 102.0)
	cycle.position = Vector2(size.x - 306.0, size.y - 196.0)
	_notice.position = Vector2(size.x * 0.25, 28.0)
	_notice.size = Vector2(size.x * 0.5, 52.0)

func _button_for_action(action: String) -> Button:
	for node in _root.get_children():
		if node is Button and node.has_meta("action") and node.get_meta("action") == action:
			return node as Button
	return _create_action_button(action.to_upper(), action, Vector2.ZERO)

func update_status(current_hp: int, max_hp: int, current_rage: float, max_rage: float, threshold: float, mana: float, school: String) -> void:
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
	if _spell_button != null:
		_spell_button.disabled = school.is_empty()
		_spell_button.text = "MAGIC" if school.is_empty() else spell_text


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
