extends Node3D
## Fog silhouettes use a foreground layer anchored to the live flashlight tip.

const TIP_SHADER := preload("res://shaders/flashlight_tip_silhouettes.gdshader")
const TIP_ARTWORK := preload("res://assets/effects/flashlight_tip_zombie_fog.webp")
const SILHOUETTE_OPACITY := 0.40
const FOG_OPACITY := 0.72
const CLUSTER_FOOTPRINT_SCALE := 0.62
const RENDER_PRIORITY := 127 # After the flashlight blackout composite.

var camera: Camera3D
var overlay: MeshInstance3D
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
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	overlay = MeshInstance3D.new()
	overlay.name = "MovingZombieSilhouettes"
	overlay.mesh = quad
	# This independently toggled effect must never be re-enabled by Foundation's distance cache.
	overlay.add_to_group("flashlight_beam")
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.visible = false
	material = ShaderMaterial.new()
	material.shader = TIP_SHADER
	material.render_priority = RENDER_PRIORITY
	material.set_shader_parameter("silhouette_opacity", SILHOUETTE_OPACITY)
	material.set_shader_parameter("fog_opacity", FOG_OPACITY)
	material.set_shader_parameter("tip_artwork", TIP_ARTWORK)
	overlay.material_override = material
	add_child(overlay)

func set_effect_visible(is_visible: bool) -> void:
	if not is_instance_valid(overlay):
		return
	effect_active = is_visible
	if overlay.visible != is_visible:
		overlay.visible = is_visible
	if not is_visible:
		_last_projection_state.clear()

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
	var visible_tip := beam_tip
	var visible_range := beam_range
	# If the beam reaches the arena floor before its nominal range, place the
	# fog cluster just above that visible surface instead of behind the floor.
	if normalized_direction.y < -0.01:
		var floor_distance := -origin.y / normalized_direction.y
		if floor_distance > 0.0 and floor_distance < beam_range:
			visible_range = maxf(1.0, floor_distance - 0.15)
			visible_tip = origin + normalized_direction * visible_range + Vector3.UP * 1.6
	var viewport := camera.get_viewport()
	if not is_instance_valid(viewport):
		set_effect_visible(false)
		return
	var visible_rect := viewport.get_visible_rect()
	if visible_rect.size.x <= 1.0 or visible_rect.size.y <= 1.0 or camera.is_position_behind(visible_tip):
		set_effect_visible(false)
		return

	var state: Array = [origin, normalized_direction, beam_range, beam_tangent,
		camera.global_transform, camera.projection, camera.fov, visible_rect]
	if state == _last_projection_state:
		return
	_last_projection_state = state

	# Project the live circular beam cross-section. Keep the cluster footprint
	# proportional to the cone while placing it on a camera-facing 3D quad.
	var right := normalized_direction.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = camera.global_basis.x
	right = right.normalized()
	var up := right.cross(normalized_direction).normalized()
	var beam_radius := visible_range * beam_tangent
	var edge_points: Array[Vector3] = [
		visible_tip + right * beam_radius,
		visible_tip - right * beam_radius,
		visible_tip + up * beam_radius,
		visible_tip - up * beam_radius,
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

	projected_center = camera.unproject_position(visible_tip)
	projected_size = (maximum - minimum) * CLUSTER_FOOTPRINT_SCALE
	if projected_size.x < 2.0 or projected_size.y < 2.0:
		set_effect_visible(false)
		return
	var effect_rect := Rect2(projected_center - projected_size * 0.5, projected_size)
	effect_active = visible_rect.intersects(effect_rect)
	if not effect_active:
		set_effect_visible(false)
		return

	# Size the camera-facing quad to the same projected footprint, but keep the fog silhouettes visible over distant enemy models.
	var camera_right := camera.global_basis.x.normalized()
	var camera_up := camera.global_basis.y.normalized()
	var right_scale := camera.unproject_position(visible_tip + camera_right).distance_to(projected_center)
	var up_scale := camera.unproject_position(visible_tip + camera_up).distance_to(projected_center)
	var world_width := projected_size.x / maxf(right_scale, 0.001)
	var world_height := projected_size.y / maxf(up_scale, 0.001)
	var billboard_basis := Basis(camera_right, camera_up, camera.global_basis.z.normalized())
	overlay.global_transform = Transform3D(billboard_basis, visible_tip)
	overlay.scale = Vector3(world_width, world_height, 1.0)
	if not overlay.visible:
		overlay.visible = true
