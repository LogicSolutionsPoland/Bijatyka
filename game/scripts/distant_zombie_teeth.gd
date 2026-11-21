extends Control
## Screen-space tooth glints belonging only to actual tracked enemies.
## Synthetic mouths and floating teeth textures are intentionally absent.

var _glints: Array[Dictionary] = []

func configure(_view_camera: Camera3D, _game_player: Node3D, _manager: Node) -> void:
	pass

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_glints(points: Array[Dictionary]) -> void:
	_glints = points
	queue_redraw()

func _draw() -> void:
	# Preserve every real enemy's original glint geometry and occlusion rules.
	for entry in _glints:
		var center: Vector2 = entry["center"]
		var strength: float = entry["strength"]
		var scale: float = entry["scale"]
		var pearl := Color(0.86, 0.94, 1.0, strength * 0.93)
		draw_circle(center, 5.0 * scale, Color(0.45, 0.72, 0.95, strength * 0.065), true, -1.0, true)
		draw_line(center + Vector2(-2.3, -0.5) * scale, center + Vector2(2.3, -0.5) * scale,
			Color(0.66, 0.83, 1.0, strength * 0.32), 1.0 * scale, true)
		for tooth in range(4):
			var x := (float(tooth) - 1.5) * 1.35 * scale
			var lower := (1.1 if tooth == 0 or tooth == 3 else 1.6) * scale
			draw_line(center + Vector2(x, -0.6 * scale), center + Vector2(x, lower),
				pearl, 0.95 * scale, true)
