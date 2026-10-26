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
const MAX_RADIUS := 30.0
const BRIGHT_RADIUS := 22.0
const CLOSE_COMBAT_RADIUS := FoundationEnemy.DETAILED_RADIUS
const SECTOR_HYSTERESIS_METERS := 0.65
const CLASSIFICATION_INTERVAL := 0.12
# Target from the user's red oval on the 1536x707 gameplay screenshot.
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

## CPU reference for the screen-space beam; used by the visibility QA checks.
func get_oval_weight(screen_uv: Vector2) -> float:
	var normalized_offset := (screen_uv - OVAL_CENTER_UV) / OVAL_RADIUS_UV
	return 1.0 - smoothstep(1.0 - OVAL_FEATHER, 1.0, normalized_offset.length())

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
