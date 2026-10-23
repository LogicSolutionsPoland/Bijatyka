extends Control
class_name TouchStick

var value := Vector2.ZERO
var _finger_id := -1
var _mouse_active := false
@export var deadzone := 0.12
@export var radius := 68.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(156.0, 156.0)

func get_vector() -> Vector2:
	return value

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger_id == -1:
			_finger_id = event.index
			_update_touch(_screen_to_local(event.position))
		elif not event.pressed and event.index == _finger_id:
			_finger_id = -1
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _finger_id:
		_update_touch(_screen_to_local(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_active = event.pressed
		if _mouse_active:
			_update_touch(event.position)
		else:
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventMouseMotion and _mouse_active:
		_update_touch(event.position)

func _screen_to_local(position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * position

func _update_touch(position: Vector2) -> void:
	var offset := (position - size * 0.5) / radius
	if offset.length() > 1.0:
		offset = offset.normalized()
	value = Vector2(offset.x, offset.y)
	if value.length() < deadzone:
		value = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, Color(0.025, 0.035, 0.05, 0.34))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.82, 0.84, 0.87, 0.45), 2.0, true)
	draw_circle(center + Vector2(value.x, -value.y) * radius * 0.62, radius * 0.34, Color(0.74, 0.80, 0.86, 0.50))
