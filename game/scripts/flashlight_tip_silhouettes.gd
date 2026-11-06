extends Node
## Screen-space artwork anchored to the live end cross-section of the 3D flashlight.
## It is decorative only: this node never creates or queries gameplay actors.

const TIP_SHADER := preload("res://shaders/flashlight_tip_silhouettes.gdshader")
const SILHOUETTE_OPACITY := 0.40
const CLUSTER_FOOTPRINT_SCALE := 0.34

var camera: Camera3D
var canvas_layer: CanvasLayer
var overlay: ColorRect
var material: ShaderMaterial
var beam_tip := Vector3.ZERO
var projected_center := Vector2.ZERO
var projected_size := Vector2.ZERO
var effect_active := false
var _last_projection_state: Array = []

func configure(camera_node: Camera3D) -> void:
	camera = camera_node
	if not is_instance_valid(camera):
		return
	canvas_layer = CanvasLayer.new()
	canvas_layer.name = "FlashlightTipSilhouettesLayer"
	# Layer 0 renders after the 3D blackout and beam passes, but below the HUD.
	canvas_layer.layer = 0
	add_child(canvas_layer)

	overlay = ColorRect.new()
	overlay.name = "MovingZombieSilhouettes"
	overlay.color = Color.WHITE
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.visible = false
	material = ShaderMaterial.new()
	material.shader = TIP_SHADER
	material.set_shader_parameter("silhouette_opacity", SILHOUETTE_OPACITY)
	overlay.material = material
	canvas_layer.add_child(overlay)

func set_effect_visible(is_visible: bool) -> void:
	if not is_instance_valid(overlay):
		return
	if not is_visible:
		effect_active = false
		if overlay.visible:
			overlay.visible = false
		_last_projection_state.clear()
	elif effect_active and not overlay.visible:
		overlay.visible = true

func update_beam(
	origin: Vector3,
	direction: Vector3,
	beam_range: float,
	beam_tangent: float,
	should_draw: bool
) -> void:
	if not should_draw or not is_instance_valid(camera) or not is_instance_valid(overlay):
		set_effect_visible(false)
		return
	if beam_range <= 0.0 or beam_tangent <= 0.0 or direction.length_squared() < 0.99:
		set_effect_visible(false)
		return

	var normalized_direction := direction.normalized()
	beam_tip = origin + normalized_direction * beam_range
	var viewport := camera.get_viewport()
	if not is_instance_valid(viewport):
		set_effect_visible(false)
		return
	var visible_rect := viewport.get_visible_rect()
	if visible_rect.size.x <= 1.0 or visible_rect.size.y <= 1.0 or camera.is_position_behind(beam_tip):
		set_effect_visible(false)
		return

	var state: Array = [origin, normalized_direction, beam_range, beam_tangent,
		camera.global_transform, camera.projection, camera.fov, visible_rect]
	if state == _last_projection_state:
		return
	_last_projection_state = state

	# Project the actual circular beam cross-section at its range limit. The
	# displayed cluster stays a small fixed fraction of that live screen footprint.
	var right := normalized_direction.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = camera.global_basis.x
	right = right.normalized()
	var up := right.cross(normalized_direction).normalized()
	var beam_radius := beam_range * beam_tangent
	var edge_points: Array[Vector3] = [
		beam_tip + right * beam_radius,
		beam_tip - right * beam_radius,
		beam_tip + up * beam_radius,
		beam_tip - up * beam_radius,
	]
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for point in edge_points:
		if camera.is_position_behind(point):
			set_effect_visible(false)
			return
		var screen_point := camera.unproject_position(point)
		minimum.x = minf(minimum.x, screen_point.x)
		minimum.y = minf(minimum.y, screen_point.y)
		maximum.x = maxf(maximum.x, screen_point.x)
		maximum.y = maxf(maximum.y, screen_point.y)

	projected_center = camera.unproject_position(beam_tip)
	projected_size = (maximum - minimum) * CLUSTER_FOOTPRINT_SCALE
	if projected_size.x < 2.0 or projected_size.y < 2.0:
		set_effect_visible(false)
		return
	overlay.position = projected_center - projected_size * 0.5
	overlay.size = projected_size
	var effect_rect := Rect2(overlay.position, overlay.size)
	effect_active = visible_rect.intersects(effect_rect)
	if overlay.visible != effect_active:
		overlay.visible = effect_active
