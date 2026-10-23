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
	panel.position = Vector2(20.0, 18.0)
	panel.custom_minimum_size = Vector2(390.0, 96.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.05, 0.84)
	style.border_color = Color(0.73, 0.22, 0.15, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)
	_status = Label.new()
	_status.text = "RETRIBUTION  |  RAGE 0 / 100\nHP 100   •   MAGIC 100\nWASD move   J punch   K kick   Space jump   Shift dash"
	_status.add_theme_color_override("font_color", Color(0.92, 0.93, 0.88))
	_status.add_theme_font_size_override("font_size", 15)
	panel.add_child(_status)

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
	var threshold_text := "inactive" if threshold <= 0.0 else "%.1f" % threshold
	var spell_text: String = "NO SPELL" if school.is_empty() else str(AURA_LABELS.get(school, school.to_upper()))
	_status.text = "RETRIBUTION  |  RAGE %.0f / %.0f  •  MAX %.0f\nHP %d / %d   •   MAGIC %.0f   •   %s\nCondemnation %s  •  Manual attacks, no queued combos" % [current_rage, 1000.0, max_rage, current_hp, max_hp, mana, spell_text, threshold_text]
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
