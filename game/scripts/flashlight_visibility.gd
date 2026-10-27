extends Node
class_name FlashlightVisibilityManager
## One shared screen mask and one cached classifier for the ordinary horde.
## The shader handles the exact projected footprint; this manager prevents
## hidden actors from entering the detailed-rig and MultiMesh render queues.

enum Band {
	VISIBLE_CLOSE,
	VISIBLE_DISTANT,
	DARK_CLOSE_COMBAT,
	DARK_DISTANT,
	BEYOND_RENDER,
}

const VISIBILITY_SHADER := preload("res://shaders/flashlight_visibility.gdshader")
const DISTANT_TEETH_OVERLAY := preload("res://scripts/distant_zombie_teeth.gd")
const MAX_RADIUS := 30.0
const BRIGHT_RADIUS := 22.0
const CLOSE_COMBAT_RADIUS := FoundationEnemy.DETAILED_RADIUS
const SECTOR_HYSTERESIS_METERS := 0.65
const CLASSIFICATION_INTERVAL := 0.12
const TEETH_REFRESH_INTERVAL := 0.033
const TEETH_GLOW_EXTRA_METERS := 10.0
const TEETH_FRONT_FACING_DOT := 0.24
# Camera-space footprint of the supplied 1536x707 gameplay reference.
const OVAL_CENTER_UV := Vector2(0.44, 0.60)
const OVAL_RADIUS_UV := Vector2(0.29, 0.22)
const OVAL_FEATHER := 0.055

var player: Node3D
var camera: Camera3D
var enabled := true
var aim_direction := Vector3.FORWARD
var _tracked: Dictionary = {}
var _bands: Dictionary = {}
var _sector_visible: Dictionary = {}
var _material: ShaderMaterial
var _composite: MeshInstance3D
var _classification_timer := 0.0
var _teeth_timer := 0.0
var _teeth_canvas: CanvasLayer
var _teeth_overlay: Control
var _counts := {}

func configure(player_node: Node3D, camera_node: Camera3D, is_enabled: bool) -> void:
	player = player_node
	camera = camera_node
	enabled = is_enabled
	_build_composite()
	_upload_shader_parameters()
	_classify_enemies()

func set_aim_yaw(yaw: float) -> void:
	# Godot's positive Y rotation turns local -Z toward -X. Match the
	# camera's actual forward vector so the lit half always fills the view.
	aim_direction = Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	_upload_shader_parameters()

func track_enemy(enemy: Node3D) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	_tracked[id] = enemy
	_sector_visible[id] = false

func untrack_enemy(enemy_id: int) -> void:
	_tracked.erase(enemy_id)
	_bands.erase(enemy_id)
	_sector_visible.erase(enemy_id)

func is_visible_to_flashlight(enemy: Node3D) -> bool:
	if not enabled:
		return is_instance_valid(enemy) and enemy.global_position.distance_squared_to(player.global_position) <= MAX_RADIUS * MAX_RADIUS
	var band := int(_bands.get(enemy.get_instance_id(), Band.BEYOND_RENDER))
	return band == Band.VISIBLE_CLOSE or band == Band.VISIBLE_DISTANT

func get_band(enemy: Node3D) -> int:
	return int(_bands.get(enemy.get_instance_id(), Band.BEYOND_RENDER)) if is_instance_valid(enemy) else Band.BEYOND_RENDER

func is_point_in_sector(world_position: Vector3, edge_tolerance: float = 0.0) -> bool:
	if not is_instance_valid(player):
		return false
	var offset := world_position - player.global_position
	offset.y = 0.0
	return offset.dot(aim_direction) >= -edge_tolerance

func get_radial_weight(distance: float) -> float:
	if distance <= BRIGHT_RADIUS:
		return 1.0
	if distance >= MAX_RADIUS:
		return 0.0
	var t := clampf((distance - BRIGHT_RADIUS) / (MAX_RADIUS - BRIGHT_RADIUS), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)

func get_oval_weight(screen_uv: Vector2) -> float:
	var offset := (screen_uv - OVAL_CENTER_UV) / OVAL_RADIUS_UV
	return 1.0 - smoothstep(1.0 - OVAL_FEATHER, 1.0, offset.length())

func get_classification_counts() -> Dictionary:
	return _counts.duplicate()

func set_composite_visible_for_comparison(is_visible: bool) -> void:
	# Debug-only A/B probe: stop drawing the full-screen pass while keeping
	# exactly the same AI, horde classification, and scene geometry.
	if OS.is_debug_build() and is_instance_valid(_composite):
		_composite.visible = is_visible

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	# Uniforms update each frame for immediate aiming response. Actor classes are
	# refreshed at 8.3 Hz, shared across both render queues.
	_upload_shader_parameters()
	_classification_timer += delta
	if _classification_timer >= CLASSIFICATION_INTERVAL:
		_classification_timer = 0.0
		_classify_enemies()
	if enabled and is_instance_valid(_teeth_overlay):
		_teeth_timer += delta
		if _teeth_timer >= TEETH_REFRESH_INTERVAL:
			_teeth_timer = 0.0
			_update_distant_teeth()

func _build_composite() -> void:
	if not enabled or not is_instance_valid(camera):
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_material = ShaderMaterial.new()
	_material.shader = VISIBILITY_SHADER
	_material.render_priority = 127
	_material.set_shader_parameter("oval_center_uv", OVAL_CENTER_UV)
	_material.set_shader_parameter("oval_radius_uv", OVAL_RADIUS_UV)
	_material.set_shader_parameter("oval_feather", OVAL_FEATHER)
	_composite = MeshInstance3D.new()
	_composite.name = "FlashlightVisibilityComposite"
	_composite.mesh = quad
	_composite.material_override = _material
	_composite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_composite.custom_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0))
	camera.add_child(_composite)
	# Canvas layer 0 draws after the 3D blackout pass but beneath the HUD.
	# Far teeth can catch a tiny glint without revealing the rest of a zombie.
	_teeth_canvas = CanvasLayer.new()
	_teeth_canvas.name = "DistantTeethGlintsLayer"
	_teeth_canvas.layer = 0
	add_child(_teeth_canvas)
	_teeth_overlay = DISTANT_TEETH_OVERLAY.new()
	_teeth_overlay.name = "DistantTeethGlints"
	_teeth_canvas.add_child(_teeth_overlay)

func _upload_shader_parameters() -> void:
	if _material == null or not is_instance_valid(player):
		return
	_material.set_shader_parameter("flashlight_origin", player.global_position)
	_material.set_shader_parameter("flashlight_forward", aim_direction)
	_material.set_shader_parameter("flashlight_enabled", enabled)

func _classify_enemies() -> void:
	_counts = {
		"visible_close": 0,
		"visible_distant": 0,
		"dark_close_combat": 0,
		"dark_distant": 0,
		"beyond_render": 0,
	}
	if not is_instance_valid(player):
		return
	for id_variant in _tracked.keys():
		var id := int(id_variant)
		var enemy := _tracked[id] as Node3D
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		var band := Band.BEYOND_RENDER
		if distance_squared <= MAX_RADIUS * MAX_RADIUS:
			var in_sector := true
			if enabled:
				var was_in_sector := bool(_sector_visible.get(id, false))
				var threshold := -SECTOR_HYSTERESIS_METERS if was_in_sector else SECTOR_HYSTERESIS_METERS
				in_sector = offset.dot(aim_direction) >= threshold
				_sector_visible[id] = in_sector
			var on_screen := not enabled or _inside_camera_frustum(enemy)
			var is_visible := not enabled or (in_sector and on_screen)
			if is_visible:
				band = Band.VISIBLE_CLOSE if distance_squared <= CLOSE_COMBAT_RADIUS * CLOSE_COMBAT_RADIUS else Band.VISIBLE_DISTANT
			else:
				band = Band.DARK_CLOSE_COMBAT if distance_squared <= CLOSE_COMBAT_RADIUS * CLOSE_COMBAT_RADIUS else Band.DARK_DISTANT
		_bands[id] = band
		if enemy.has_method("set_flashlight_render_visible"):
			enemy.call("set_flashlight_render_visible", band == Band.VISIBLE_CLOSE or band == Band.VISIBLE_DISTANT)
		match band:
			Band.VISIBLE_CLOSE: _counts.visible_close += 1
			Band.VISIBLE_DISTANT: _counts.visible_distant += 1
			Band.DARK_CLOSE_COMBAT: _counts.dark_close_combat += 1
			Band.DARK_DISTANT: _counts.dark_distant += 1
			Band.BEYOND_RENDER: _counts.beyond_render += 1

func _inside_camera_frustum(enemy: Node3D) -> bool:
	if not is_instance_valid(camera) or not camera.is_current():
		return true
	var point := enemy.global_position + Vector3.UP * 1.0
	if camera.is_position_behind(point):
		return false
	var screen_position := camera.unproject_position(point)
	return camera.get_viewport().get_visible_rect().grow(24.0).has_point(screen_position)


func _update_distant_teeth() -> void:
	# Screen-space glints are much cheaper than extending animated characters
	# or adding five realtime lights. Only the five registered ordinary zombies
	# are considered; neither the boss nor distant silhouettes are unmasked.
	var points: Array[Dictionary] = []
	if not is_instance_valid(camera) or not is_instance_valid(player) or not camera.is_current():
		_teeth_overlay.call("set_glints", points)
		return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		_teeth_overlay.call("set_glints", points)
		return
	for enemy_variant in _tracked.values():
		var enemy := enemy_variant as FoundationEnemy
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0 or enemy.is_boss:
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		var distance := offset.length()
		# Strictly ten additional metres BEYOND the existing 30 m beam.
		if distance <= MAX_RADIUS or distance >= MAX_RADIUS + TEETH_GLOW_EXTRA_METERS:
			continue
		var aim_dot := offset.normalized().dot(aim_direction)
		if aim_dot <= 0.0:
			continue
		# The glint appears on the mouth, never on the back of the head.
		var enemy_forward := Vector3(-sin(enemy.rotation.y), 0.0, -cos(enemy.rotation.y))
		var to_player := -offset.normalized()
		var front_dot := enemy_forward.dot(to_player)
		if front_dot <= TEETH_FRONT_FACING_DOT:
			continue
		var mouth_world := enemy.global_position + Vector3.UP * 1.60 + enemy_forward * 0.22
		if camera.is_position_behind(mouth_world):
			continue
		var screen_position := camera.unproject_position(mouth_world)
		if not Rect2(Vector2.ZERO, viewport_size).grow(6.0).has_point(screen_position):
			continue
		# Do not draw glints through buildings, terrain or the base boundary.
		# Enemy bodies use layer 2; only static occluders (1 and 4) are queried.
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, mouth_world)
		ray.collision_mask = 1 | 4
		# The third-person camera sits behind the player capsule (layer 1).
		# Ignoring it avoids permanently hiding every distant glint.
		if player is CollisionObject3D:
			ray.exclude = [(player as CollisionObject3D).get_rid()]
		if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var fade := 1.0 - smoothstep(MAX_RADIUS + 5.0, MAX_RADIUS + TEETH_GLOW_EXTRA_METERS, distance)
		var aim_strength := smoothstep(0.0, 0.45, aim_dot)
		var front_strength := smoothstep(TEETH_FRONT_FACING_DOT, 0.78, front_dot)
		var strength := fade * aim_strength * front_strength
		if strength < 0.02:
			continue
		var size_scale := clampf((viewport_size.y / 720.0) * 35.0 / distance, 0.7, 1.6)
		points.append({"center": screen_position, "strength": strength, "scale": size_scale})
		if points.size() >= 5:
			break
	_teeth_overlay.call("set_glints", points)
