extends Node
class_name FlashlightVisibilityManager
## One shared screen mask and one cached classifier for all enemies.
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
const BEAM_VOLUME_SHADER := preload("res://shaders/flashlight_beam_volume.gdshader")
const BEAM_SECTIONS_SHADER := preload("res://shaders/flashlight_beam_sections.gdshader")
const DISTANT_TEETH_OVERLAY := preload("res://scripts/distant_zombie_teeth.gd")
const MAX_RADIUS := 30.0
const BRIGHT_RADIUS := 22.0
const CLOSE_COMBAT_RADIUS := FoundationEnemy.DETAILED_RADIUS
const SECTOR_HYSTERESIS_METERS := 0.65
const CLASSIFICATION_INTERVAL := 0.12
const TEETH_REFRESH_INTERVAL := 0.033
const TEETH_EXTRA_FORWARD_METERS := 5.0
const TEETH_EXTRA_SIDE_METERS := 3.0
const TEETH_EDGE_FADE_METERS := 1.0
const TEETH_FRONT_FACING_DOT := 0.24
# Camera-space footprint of the supplied 1536x707 gameplay reference.
const OVAL_CENTER_UV := Vector2(0.44, 0.60)
const OVAL_RADIUS_UV := Vector2(0.29, 0.22)
const OVAL_FEATHER := 0.055
const BEAM_HEIGHT := 1.55
const BEAM_HALF_ANGLE_DEGREES := 25.0
const BEAM_TANGENT := 0.46630766 # tan(25 degrees), shared with the screen shader.

var player: Node3D
var camera: Camera3D
var enabled := true
var rooftop_sky_visible := false
var aim_direction := Vector3.FORWARD
var beam_origin := Vector3.ZERO
var beam_direction := Vector3.FORWARD
var spotlight: SpotLight3D
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
	_build_beam_light()
	_upload_shader_parameters()
	_classify_enemies()

func set_aim_yaw(yaw: float) -> void:
	# Godot's positive Y rotation turns local -Z toward -X. Match the
	# camera's actual forward vector so the lit half always fills the view.
	aim_direction = Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	_upload_shader_parameters()

func get_beam_density(world_position: Vector3) -> float:
	# A true 3D cone, including height. The air pass and the SpotLight use
	# this same origin, direction, angle, and range.
	var offset := world_position - beam_origin
	var axial := offset.dot(beam_direction)
	if axial <= 0.0 or axial >= MAX_RADIUS:
		return 0.0
	var radius := maxf(0.4, axial * BEAM_TANGENT)
	var lateral := (offset - beam_direction * axial).length()
	return (1.0 - smoothstep(0.45, 1.0, lateral / radius)) \
		* smoothstep(0.0, 2.0, axial) * (1.0 - smoothstep(BRIGHT_RADIUS, MAX_RADIUS, axial))

func set_rooftop_sky_visible(is_visible: bool) -> void:
	rooftop_sky_visible = is_visible
	if _material != null:
		_material.set_shader_parameter("rooftop_sky_visible", is_visible)

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

func get_teeth_reach_weight(world_position: Vector3) -> float:
	# Extend ONLY the reflective-tooth overlay: 5 m in front and 3 m
	# on either side of the unchanged 30 m forward flashlight half-disc.
	if not is_instance_valid(player):
		return 0.0
	var offset := world_position - player.global_position
	offset.y = 0.0
	var forward_meters := offset.dot(aim_direction)
	if forward_meters < 0.0:
		return 0.0
	var side_axis := Vector3(-aim_direction.z, 0.0, aim_direction.x)
	var sideways_meters := absf(offset.dot(side_axis))
	# Shortest reach back to the normal semicircular beam after its
	# independent forward and side extensions (not extra scene lighting).
	var core_forward := maxf(0.0, forward_meters - TEETH_EXTRA_FORWARD_METERS)
	var core_side := maxf(0.0, sideways_meters - TEETH_EXTRA_SIDE_METERS)
	var core_radius := Vector2(core_forward, core_side).length()
	return 1.0 - smoothstep(MAX_RADIUS - TEETH_EDGE_FADE_METERS, MAX_RADIUS, core_radius)


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
	# Leave the last transparent priority for depth-tested, whole enemy bodies.
	_material.render_priority = 126
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

func _build_beam_light() -> void:
	if not enabled or not is_instance_valid(player):
		return
	spotlight = SpotLight3D.new()
	spotlight.name = "PlayerFlashlightSpot"
	spotlight.add_to_group("flashlight_beam")
	spotlight.light_color = Color(0.84, 0.90, 1.0)
	spotlight.light_energy = 1.6
	spotlight.spot_range = MAX_RADIUS
	spotlight.spot_angle = BEAM_HALF_ANGLE_DEGREES
	spotlight.spot_attenuation = 1.4
	# One unshadowed local light lights surfaces. The translucent, depth-tested
	# sheets below make its shaft visible in the air on Compatibility/mobile.
	spotlight.shadow_enabled = false
	player.add_child(spotlight)
	_build_visible_beam_volume()
	_build_visible_beam_sections()

func _build_visible_beam_volume() -> void:
	var material := ShaderMaterial.new()
	material.shader = BEAM_VOLUME_SHADER
	# Draw after the fullscreen darkness mask. Depth testing stays on, so
	# opaque walls and buildings still hide the beam behind them.
	material.render_priority = 127
	material.set_shader_parameter("beam_range", MAX_RADIUS)
	material.set_shader_parameter("beam_tangent", BEAM_TANGENT)
	material.set_shader_parameter("beam_color", Color(0.61, 0.80, 1.0))
	material.set_shader_parameter("beam_opacity", 0.12)
	material.set_shader_parameter("core_opacity", 0.11)

	var maximum_width := maxf(0.32, MAX_RADIUS * BEAM_TANGENT)
	for index in range(3):
		var sheet := MeshInstance3D.new()
		sheet.name = "PlayerFlashlightBeamSheet%d" % index
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, MAX_RADIUS)
		sheet.mesh = quad
		sheet.material_override = material
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The vertex shader widens the quad to the full cone radius. Tell CPU
		# culling about that expanded bound instead of the original 2 m quad.
		sheet.custom_aabb = AABB(
			Vector3(-maximum_width, -MAX_RADIUS * 0.5, -0.05),
			Vector3(maximum_width * 2.0, MAX_RADIUS, 0.1)
		)
		var azimuth := TAU * float(index) / 3.0
		var sheet_basis := Basis(Vector3.BACK, azimuth) * Basis(Vector3.RIGHT, PI * 0.5)
		sheet.transform = Transform3D(sheet_basis, Vector3(0.0, 0.0, -MAX_RADIUS * 0.5))
		spotlight.add_child(sheet)


func _build_visible_beam_sections() -> void:
	var material := ShaderMaterial.new()
	material.shader = BEAM_SECTIONS_SHADER
	material.render_priority = 127
	material.set_shader_parameter("beam_color", Color(0.61, 0.80, 1.0))
	material.set_shader_parameter("section_opacity", 0.16)
	material.set_shader_parameter("beam_range", MAX_RADIUS)
	material.set_shader_parameter("fade_end_start", 24.0)

	# Camera-facing sections expose scattering from the third-person view,
	# which follows the beam and sees longitudinal sheets nearly edge-on.
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Spend the same seven depth-tested sections closer to the player, where
	# the rooftop view previously showed only the distant part past the rail.
	for distance in [2.0, 3.5, 5.5, 8.5, 13.0, 20.0, 27.0]:
		var radius: float = float(distance) * BEAM_TANGENT
		var base := vertices.size()
		vertices.append_array(PackedVector3Array([
			Vector3(-radius, -radius, -distance),
			Vector3(radius, -radius, -distance),
			Vector3(radius, radius, -distance),
			Vector3(-radius, radius, -distance),
		]))
		uvs.append_array(PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(1.0, 0.0),
			Vector2(1.0, 1.0), Vector2(0.0, 1.0),
		]))
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2,
			base, base + 2, base + 3,
		]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var sections := MeshInstance3D.new()
	sections.name = "PlayerFlashlightBeamSections"
	sections.mesh = mesh
	sections.material_override = material
	sections.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var maximum_width := MAX_RADIUS * BEAM_TANGENT
	sections.custom_aabb = AABB(
		Vector3(-maximum_width, -maximum_width, -MAX_RADIUS + 1.9),
		Vector3(maximum_width * 2.0, maximum_width * 2.0, MAX_RADIUS - 3.9)
	)
	spotlight.add_child(sections)


func _upload_shader_parameters() -> void:
	if not is_instance_valid(player):
		return
	beam_origin = player.global_position + Vector3.UP * BEAM_HEIGHT
	# The camera supplies pitch while yaw follows the exact same direction as
	# combat and the ground mask, including touch and gamepad turning.
	var camera_forward := -camera.global_basis.z if is_instance_valid(camera) else aim_direction
	var horizontal_length := maxf(Vector2(camera_forward.x, camera_forward.z).length(), 0.001)
	beam_direction = (aim_direction + Vector3.UP * camera_forward.y / horizontal_length).normalized()
	if is_instance_valid(spotlight):
		spotlight.global_position = beam_origin
		spotlight.global_basis = Basis.looking_at(beam_direction, Vector3.UP)
		spotlight.visible = enabled
	if _material == null:
		return
	_material.set_shader_parameter("flashlight_origin", player.global_position)
	_material.set_shader_parameter("flashlight_forward", aim_direction)
	_material.set_shader_parameter("flashlight_enabled", enabled)
	_material.set_shader_parameter("rooftop_sky_visible", rooftop_sky_visible)

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
			var on_screen := not enabled or _body_intersects_beam(enemy)
			var is_visible := not enabled or (in_sector and on_screen)
			if is_visible:
				band = Band.VISIBLE_CLOSE if distance_squared <= CLOSE_COMBAT_RADIUS * CLOSE_COMBAT_RADIUS else Band.VISIBLE_DISTANT
			else:
				band = Band.DARK_CLOSE_COMBAT if distance_squared <= CLOSE_COMBAT_RADIUS * CLOSE_COMBAT_RADIUS else Band.DARK_DISTANT
		_bands[id] = band
		if enemy.has_method("set_flashlight_render_visible"):
			enemy.call("set_flashlight_render_visible", band == Band.VISIBLE_CLOSE or band == Band.VISIBLE_DISTANT)
		if enemy.has_method("set_flashlight_full_body_visible"):
			enemy.call("set_flashlight_full_body_visible", enabled and (band == Band.VISIBLE_CLOSE or band == Band.VISIBLE_DISTANT))
		match band:
			Band.VISIBLE_CLOSE: _counts.visible_close += 1
			Band.VISIBLE_DISTANT: _counts.visible_distant += 1
			Band.DARK_CLOSE_COMBAT: _counts.dark_close_combat += 1
			Band.DARK_DISTANT: _counts.dark_distant += 1
			Band.BEYOND_RENDER: _counts.beyond_render += 1

func _body_intersects_beam(enemy: Node3D) -> bool:
	if not is_instance_valid(camera) or not camera.is_current():
		return true
	var viewport_size := camera.get_viewport().get_visible_rect().size
	if viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return false
	var boss := enemy is FoundationEnemy and (enemy as FoundationEnemy).is_boss
	var height := 2.85 if boss else 2.1
	var half_width := 0.80 if boss else 0.55
	var side := camera.global_basis.x * half_width
	# A wall or railing may block rays to these approximate points even when
	# actual triangles are visibly lit. The enemy's depth-tested material keeps
	# every covered fragment behind the wall after the blackout pass.
	# Head, torso, feet and both sides allow a partially lit body to qualify.
	for level in [0.52, 0.92, 0.08]:
		for lateral in [0.0, -1.0, 1.0]:
			var point: Vector3 = enemy.global_position + Vector3.UP * height * level + side * lateral
			if camera.is_position_behind(point):
				continue
			var uv := camera.unproject_position(point) / viewport_size
			if get_oval_weight(uv) > 0.01:
				return true
	return false


func _update_distant_teeth() -> void:
	# Mouth-only screen-space reflections cover the beam plus 5 m forward
	# and 3 m sideways. The scene mask and zombie meshes remain unchanged.
	# Only five registered ordinary zombies are considered, not the boss.
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
		if distance < 0.1:
			continue
		var reach_strength := get_teeth_reach_weight(enemy.global_position)
		if reach_strength <= 0.01:
			continue
		var forward_meters := offset.dot(aim_direction)
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
		if not Rect2(Vector2.ZERO, viewport_size).has_point(screen_position):
			continue
		# Teeth may glint in the added fringe outside the oval, but never
		# expose the face, enemy body or darkened environment.
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
		var aim_strength := smoothstep(0.0, 1.25, forward_meters)
		var front_strength := smoothstep(TEETH_FRONT_FACING_DOT, 0.78, front_dot)
		var strength := reach_strength * aim_strength * front_strength
		if strength < 0.02:
			continue
		var size_scale := clampf((viewport_size.y / 720.0) * 35.0 / distance, 0.7, 1.6)
		points.append({"center": screen_position, "strength": strength, "scale": size_scale})
		if points.size() >= 5:
			break
	_teeth_overlay.call("set_glints", points)
