extends CanvasLayer
class_name GroundLoadingScreen

## Opaque overlay above the combat HUD and flashlight composite. All expensive
## ground rendering happens behind it, on the same viewport/GPU as gameplay.
var _cover: ColorRect
var _progress: ProgressBar
var _details: Label


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = ColorRect.new()
	_cover.name = "LoadingCover"
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.color = Color(0.013, 0.019, 0.029, 1.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.visible = false
	add_child(_cover)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(400.0, 0.0)
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)

	var title := Label.new()
	title.text = "BIJATYKA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.97, 0.35, 0.19))
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ŁADOWANIE DOLNEJ MAPY"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	column.add_child(subtitle)

	_progress = ProgressBar.new()
	_progress.name = "GroundLoadingProgress"
	_progress.custom_minimum_size = Vector2(400.0, 26.0)
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.show_percentage = false
	column.add_child(_progress)

	_details = Label.new()
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.add_theme_font_size_override("font_size", 17)
	_details.text = "Przygotowywanie świata..."
	column.add_child(_details)


func show_loading() -> void:
	_progress.value = 0.0
	_details.text = "Przygotowywanie świata..."
	_cover.visible = true


func set_progress(value: float, details: String) -> void:
	if _cover == null or not _cover.visible:
		return
	_progress.value = clampf(value, 0.0, 1.0) * 100.0
	_details.text = details


func hide_loading() -> void:
	if _cover != null:
		_cover.visible = false


func is_loading_visible() -> bool:
	return _cover != null and _cover.visible
