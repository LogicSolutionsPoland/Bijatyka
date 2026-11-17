extends CharacterBody3D
class_name FoundationEnemy

signal telegraph_started(enemy: Node, is_boss: bool)
signal attack_resolved(enemy: Node, hit: bool)
signal defeated(enemy: Node)

const INFECTED_ALBEDO := preload("res://assets/characters/infected/Ashen_Worker.jpg")
const ENEMY_MODEL_PATH := "res://assets/characters/universal_base/Universal_Base_Characters_Male.glb"
const BOSS_MODEL_PATH := "res://assets/characters/universal_base/Universal_Base_Characters_Female.glb"
const HEALTH_BAR := preload("res://scenes/enemy_health_bar.tscn")
const UNIVERSAL_BASE_MOTION := preload("res://scripts/universal_base_motion.gd")
const ENEMY_MODEL_YAW_OFFSET := PI
const FIGHT_ANIMATION_BUILDER := preload("res://scripts/universal_base_enemy_combat.gd")
const RIG_ANIMATION_CACHE := preload("res://scripts/enemy_rig_animation_cache.gd")
const ENEMY_FIGHT_LIBRARY := &"enemy_combat"
const SHADOW_POLICY := preload("res://scripts/shadow_policy.gd")
const FLASHLIGHT_REVEAL := preload("res://scripts/flashlight_enemy_reveal.gd")
const GRAVITY := 24.0
const RENDER_RADIUS := 30.0
const DETAILED_RADIUS := 18.0
const FAR_PHYSICS_INTERVAL := 0.10
const FAR_PHYSICS_DISTANCE := 7.0
const SPATIAL_GRID_REFRESH_HZ := 10
const FULL_ANIMATION_BUDGET := 7
const SPAWN_ASSAULT_DURATION := 4.5
const SPAWN_ASSAULT_SPEED_MULTIPLIER := 3.2
const SPAWN_ASSAULT_HANDOFF_DISTANCE := 6.0
const PURSUIT_PROBE_DISTANCE := 2.4
const PURSUIT_AVOID_SECONDS := 0.45
const CROWD_SEPARATION_RADIUS := 1.55
const CROWD_SEPARATION_STRENGTH := 1.25
const CROWD_WAIT_SPEED := 0.70
const PURSUIT_DETOUR_ANGLES := [35.0, -35.0, 60.0, -60.0, 90.0, -90.0, 125.0, -125.0]

@export_enum("shambler", "brute", "stalker", "boss") var enemy_variant := "shambler"
@export var is_boss := false
@export var starting_health := 90
@export_range(0.45, 1.25, 0.05) var limb_grab_windup_seconds := 0.75

var hp := 90
var move_speed := 2.5
var attack_range := 1.8
var telegraph_duration := 1.0
var recovery_duration := 1.15
var state := "idle"
var state_time := 0.0
var stun_time := 0.0
var slow_time := 0.0
var slow_factor := 1.0
var knockback := Vector3.ZERO
var _ai_accumulator := 0.0
var _ai_interval := 0.0
var _far_physics_time := 0.0
var _far_physics_active := false
var _player: FoundationPlayer
var combat_fx_pool: Node
var _model: Node3D
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _fight_animations_ready := false
var _attack_sequence := 0
var _death_animation := ""
var _death_started := false
var _death_completed := false
var _attack_animation := ""
var _attack_contact_time := 0.0
var _visual_root: Node3D
var _collision_shape: CollisionShape3D
var _status_label: Label3D
var _health_bar_root: Node3D
var _health_bar_fill: MeshInstance3D
var _attack_latched := false
var _lod_band := -1
var _full_animation_selected := false
var _flashlight_render_visible := true
var _flashlight_full_body_visible := false
var combat_target: Node3D
var attack_director: Node
var _decision_time := 0.0
var _wander_time := 0.0
var _wander_direction := Vector3.ZERO
var _spawn_assault_time := 0.0
var _base_visual_meshes: Array[MeshInstance3D] = []
var _quality_shadows_enabled := false
# Rebuilt once per decision frame, shared by the whole population.
static var _grid_frame := -1
static var _grid: Dictionary = {}
static var _infected_body_material: StandardMaterial3D
static var _enemy_model_scene: PackedScene
static var _boss_model_scene: PackedScene
var _rig_budget_owner: Node
var _low_poly_death_scale := 1.0
var _player_grapple_owner: FoundationPlayer
var _player_grapple_time := 0.0
var _limb_grab_limb := ""
var _limb_grab_hand := ""
var _pursuit_avoid_direction := Vector3.ZERO
var _pursuit_avoid_remaining := 0.0
var _player_alert_shared := false

# Sharing this ten-Hz broad-phase cache across all enemies prevents a full
# scene-group scan for every physics frame. The 10 m cells and 3x3 query remain
# unchanged; target acquisition is already staggered separately.
static func _spatial_bucket(physics_frame: int, physics_hz: int) -> int:
	var stride := maxi(1, ceili(float(physics_hz) / float(SPATIAL_GRID_REFRESH_HZ)))
	return floori(float(physics_frame) / float(stride))

func _nearby() -> Array[FoundationEnemy]:
	var bucket := _spatial_bucket(Engine.get_physics_frames(), Engine.physics_ticks_per_second)
	if _grid_frame != bucket:
		_grid_frame = bucket
		_grid.clear()
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is FoundationEnemy and node.hp > 0:
				var key := Vector2i(floori(node.global_position.x / 10.0), floori(node.global_position.z / 10.0))
				if not _grid.has(key):
					_grid[key] = []
				_grid[key].append(node)
	var result: Array[FoundationEnemy] = []
	var cell := Vector2i(floori(global_position.x / 10.0), floori(global_position.z / 10.0))
	for x in range(-1, 2):
		for z in range(-1, 2):
			for node in _grid.get(cell + Vector2i(x, z), []):
				if is_instance_valid(node) and not node.is_queued_for_deletion() and node != self and node.hp > 0:
					result.append(node)
	return result

func _clear_sight(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target.global_position + Vector3.UP, 1)
	query.exclude = [get_rid(), target.get_rid()] if target is CollisionObject3D else [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _pursuit_ray_clear(direction: Vector3, ray_distance: float) -> bool:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.001:
		return false
	var origin := global_position + Vector3.UP * 0.85
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + flat.normalized() * ray_distance,
		collision_mask
	)
	query.exclude = [get_rid()]
	if is_instance_valid(_player):
		query.exclude.append(_player.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _pursuit_direction(desired: Vector3, delta: float, target_distance: float) -> Vector3:
	desired.y = 0.0
	if desired.length_squared() < 0.001:
		return Vector3.ZERO
	desired = desired.normalized()
	var probe_distance := minf(PURSUIT_PROBE_DISTANCE, maxf(1.0, target_distance))
	_pursuit_avoid_remaining = maxf(0.0, _pursuit_avoid_remaining - delta)
	if _pursuit_ray_clear(desired, probe_distance):
		_pursuit_avoid_direction = Vector3.ZERO
		_pursuit_avoid_remaining = 0.0
		return desired
	if _pursuit_avoid_remaining > 0.0 and _pursuit_avoid_direction.length_squared() > 0.001:
		if _pursuit_ray_clear(_pursuit_avoid_direction, probe_distance * 0.8):
			return _pursuit_avoid_direction
	var preferred_side := -1.0 if get_instance_id() % 2 == 0 else 1.0
	var lateral_axis := Vector3.UP.cross(desired)
	var best_direction := Vector3.ZERO
	var best_score := -INF
	for angle_degrees in PURSUIT_DETOUR_ANGLES:
		var candidate := desired.rotated(Vector3.UP, deg_to_rad(angle_degrees)).normalized()
		if not _pursuit_ray_clear(candidate, probe_distance):
			continue
		var score := candidate.dot(desired) + preferred_side * candidate.dot(lateral_axis) * 0.025
		if score > best_score:
			best_score = score
			best_direction = candidate
	if best_direction.length_squared() < 0.001:
		best_direction = desired.rotated(Vector3.UP, PI * 0.5 * preferred_side).normalized()
	_pursuit_avoid_direction = best_direction
	_pursuit_avoid_remaining = PURSUIT_AVOID_SECONDS
	return _pursuit_avoid_direction

func _crowd_separation_direction() -> Vector3:
	# Zombie bodies intentionally do not collide with one another. Use the
	# shared 10 Hz neighbor grid to stop live actors and their low-detail
	# silhouettes from occupying the same spot in the horde.
	var total := Vector3.ZERO
	var neighbor_count := 0
	var strongest_weight := 0.0
	var radius_squared := CROWD_SEPARATION_RADIUS * CROWD_SEPARATION_RADIUS
	for ally in _nearby():
		if ally.is_boss or ally.hp <= 0:
			continue
		var offset := global_position - ally.global_position
		offset.y = 0.0
		var distance_squared := offset.length_squared()
		if distance_squared >= radius_squared:
			continue
		neighbor_count += 1
		var distance := sqrt(distance_squared)
		var away := Vector3.ZERO
		if distance_squared <= 0.0001:
			# Give exact overlaps a stable, opposite escape direction per pair.
			var self_id: int = get_instance_id()
			var ally_id: int = ally.get_instance_id()
			var low_id: int = mini(self_id, ally_id)
			var high_id: int = maxi(self_id, ally_id)
			var overlap_angle := deg_to_rad(float(((low_id % 360) * 31 + (high_id % 360) * 17) % 360))
			away = Vector3(cos(overlap_angle), 0.0, sin(overlap_angle))
			if self_id > ally_id:
				away = -away
		else:
			away = offset / distance
		var weight := 1.0 - distance / CROWD_SEPARATION_RADIUS
		strongest_weight = maxf(strongest_weight, weight)
		total += away * weight
	if neighbor_count == 0:
		return Vector3.ZERO
	if total.length_squared() <= 0.001:
		# A perfectly symmetric pile must still have a repeatable way to spread.
		var fallback_angle := deg_to_rad(float(get_instance_id() % 360))
		total = Vector3(cos(fallback_angle), 0.0, sin(fallback_angle)) * strongest_weight
	return total.limit_length(1.0)

func _crowd_wait_direction(toward_target: Vector3) -> Vector3:
	var away := _crowd_separation_direction()
	if away.length_squared() < 0.04:
		return Vector3.ZERO
	var toward := toward_target
	toward.y = 0.0
	if toward.length_squared() <= 0.001:
		return away
	toward = toward.normalized()
	var tangent := away - toward * away.dot(toward)
	if tangent.length_squared() <= 0.001:
		tangent = Vector3.UP.cross(toward)
		if get_instance_id() % 2 == 0:
			tangent = -tangent
	return tangent.normalized()

func _valid_target() -> bool:
	return is_instance_valid(combat_target) and not combat_target.is_queued_for_deletion() and (not combat_target is FoundationEnemy or combat_target.hp > 0)

func _choose_target() -> void:
	if is_boss:
		combat_target = _player
		return
	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		combat_target = null
		_player_alert_shared = false
		return
	# Spawn-rushing and alerted zombies stay committed through distance and cover.
	# They pursue the player instead of switching to other zombies.
	if combat_target == _player or _spawn_assault_time > 0.0 or global_position.distance_to(_player.global_position) <= 14.0:
		combat_target = _player
		if not _player_alert_shared:
			_alert_nearby_allies()
			_player_alert_shared = true
		return
	# Unalerted zombies remain still and concealed until the player enters their
	# awareness radius. The spawn manager can then store them as data records.
	combat_target = null

func _alert_nearby_allies() -> void:
	for ally in _nearby():
		if ally.is_boss or ally.state == "windup":
			continue
		if ally.global_position.distance_squared_to(global_position) <= 100.0:
			ally.combat_target = _player

func _wander(delta: float) -> void:
	_wander_time -= delta
	if _wander_time <= 0.0:
		if state == "wander":
			state = "idle"
			_wander_time = randf_range(0.6, 2.5)
			_wander_direction = Vector3.ZERO
		else:
			state = "wander"
			_wander_time = randf_range(3.0, 8.0)
			var angle := randf() * TAU
			_wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	if is_on_wall():
		_wander_direction = _wander_direction.rotated(Vector3.UP, 1.2)
	if absf(global_position.x) > 92.0 or absf(global_position.z) > 92.0:
		_wander_direction = -Vector3(global_position.x, 0.0, global_position.z).normalized()
	velocity.x = _wander_direction.x * 1.5 * slow_factor
	velocity.z = _wander_direction.z * 1.5 * slow_factor
	if _wander_direction.length_squared() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-_wander_direction.x, -_wander_direction.z), minf(1.0, delta * 5.0))
	_play_animation("Walk" if state == "wander" else "Idle")

func configure(kind: String, boss_target: bool = false, _legacy_visual_sample: bool = false) -> void:
	enemy_variant = kind
	is_boss = boss_target or kind == "boss"

func begin_spawn_assault(target: FoundationPlayer) -> bool:
	if is_boss or hp <= 0 or not is_instance_valid(target):
		return false
	_player = target
	combat_target = target
	_player_alert_shared = false
	state = "assault"
	_spawn_assault_time = SPAWN_ASSAULT_DURATION
	var direction := target.global_position - global_position
	direction.y = 0.0
	direction = direction.normalized()
	# Set heading and speed before the first rendered frame: no visible turn on birth.
	rotation.y = atan2(-direction.x, -direction.z)
	velocity.x = direction.x * move_speed * SPAWN_ASSAULT_SPEED_MULTIPLIER
	velocity.z = direction.z * move_speed * SPAWN_ASSAULT_SPEED_MULTIPLIER
	_set_distance_detail(global_position.distance_to(target.global_position))
	if _visual_root.visible:
		_play_animation("Sprint")
	return true

func _finish_spawn_assault() -> void:
	if _spawn_assault_time <= 0.0 and state != "assault":
		return
	_spawn_assault_time = 0.0
	if state == "assault":
		state = "approach"
		velocity.x = 0.0
		velocity.z = 0.0
	_decision_time = 0.0

func _update_spawn_assault(delta: float) -> bool:
	_spawn_assault_time = maxf(0.0, _spawn_assault_time - delta)
	var offset := _player.global_position - global_position if is_instance_valid(_player) else Vector3.ZERO
	offset.y = 0.0
	if _spawn_assault_time <= 0.0 or offset.length() <= SPAWN_ASSAULT_HANDOFF_DISTANCE or is_on_wall():
		_finish_spawn_assault()
		return false
	var direction := offset.normalized()
	var crowd_separation := _crowd_separation_direction()
	if crowd_separation.length_squared() > 0.001:
		direction = (direction + crowd_separation * CROWD_SEPARATION_STRENGTH).normalized()
	rotation.y = atan2(-direction.x, -direction.z)
	velocity.x = direction.x * move_speed * SPAWN_ASSAULT_SPEED_MULTIPLIER * slow_factor
	velocity.z = direction.z * move_speed * SPAWN_ASSAULT_SPEED_MULTIPLIER * slow_factor
	if _visual_root.visible:
		_play_animation("Sprint")
	return true

func _ready() -> void:
	add_to_group("enemies")
	# A freshly spawned actor must enter the shared broad-phase immediately.
	_grid_frame = -1
	collision_layer = 2
	# Also collide with the player-base boundary (physics layer 3 / bit 4).
	collision_mask = 1 | 4
	name = enemy_variant.capitalize()
	_apply_variant()
	hp = starting_health
	_decision_time = randf_range(0.0, 0.45)
	_wander_time = randf_range(0.1, 2.5)
	_ai_accumulator = randf_range(0.0, 0.10)
	_build_collision()
	_build_visual()

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42 if not is_boss else 0.64
	capsule.height = 1.85 if not is_boss else 2.55
	collision.shape = capsule
	collision.position.y = capsule.height * 0.5
	_collision_shape = collision
	add_child(collision)

func _apply_variant() -> void:
	match enemy_variant:
		"brute":
			starting_health = 150
			move_speed = 1.9
			attack_range = 2.1
			telegraph_duration = 1.25
			recovery_duration = 1.35
		"stalker":
			starting_health = 75
			move_speed = 3.6
			attack_range = 1.7
			telegraph_duration = 0.95
			recovery_duration = 0.95
		"boss":
			is_boss = true
			starting_health = 360
			move_speed = 2.2
			attack_range = 2.8
			telegraph_duration = 1.45
			recovery_duration = 1.55
		_:
			starting_health = 90
			move_speed = 2.5
			attack_range = 1.8
			telegraph_duration = 1.1
			recovery_duration = 1.1

func _fight_attack_profiles() -> Dictionary:
	var windup := telegraph_duration if is_boss else telegraph_duration * 0.55
	var recovery := recovery_duration if is_boss else recovery_duration * 0.65
	var profile := {"windup": windup, "active": 0.04, "recovery": recovery}
	return {"punch": profile.duplicate(), "kick": profile.duplicate()}

func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	# Most births occur at 50 m. Load the character rig near the combat ring;
	# distant enemies use one shared silhouette batch.
	if is_boss:
		_full_animation_selected = true
		_ensure_detailed_model()
	if is_boss:
		_add_boss_ring()
	_build_health_display()
	SHADOW_POLICY.disable_in_tree(_visual_root)

func _ensure_detailed_model() -> void:
	if _model != null:
		return
	if not is_boss and is_instance_valid(_rig_budget_owner):
		_rig_budget_owner.call("_acquire_rig", self)
	else:
		_adopt_detailed_model(_instantiate_detailed_model())
	if _model == null:
		if is_boss:
			_build_debug_variant()
		return
	SHADOW_POLICY.disable_in_tree(_visual_root)
	set_quality_shadow_enabled(_quality_shadows_enabled)

func _instantiate_detailed_model() -> Node3D:
	if is_boss:
		if _boss_model_scene == null and ResourceLoader.exists(BOSS_MODEL_PATH):
			_boss_model_scene = load(BOSS_MODEL_PATH) as PackedScene
		return _boss_model_scene.instantiate() as Node3D if _boss_model_scene != null else null
	if _enemy_model_scene == null and ResourceLoader.exists(ENEMY_MODEL_PATH):
		_enemy_model_scene = load(ENEMY_MODEL_PATH) as PackedScene
	if _enemy_model_scene == null:
		return null
	var rig := _enemy_model_scene.instantiate() as Node3D
	# Style the body once at rig creation, before Pencil and flashlight
	# variants are made. Eyes, eyebrows and the player's source rig stay independent.
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null or source.resource_name != "MI_Superhero_Male":
				continue
			if _infected_body_material == null:
				_infected_body_material = source.duplicate() as StandardMaterial3D
				_infected_body_material.albedo_texture = INFECTED_ALBEDO
				_infected_body_material.vertex_color_use_as_albedo = false
			mesh.set_surface_override_material(surface, _infected_body_material)
	return rig

func _adopt_detailed_model(model: Node3D) -> void:
	if model == null or _model != null:
		return
	_model = model
	_visual_root.add_child(model)
	model.visible = true
	model.position = Vector3.ZERO
	# The imported rig faces +Z; enemy movement and targeting use -Z as forward.
	model.rotation = Vector3(0.0, ENEMY_MODEL_YAW_OFFSET, 0.0)
	model.scale = Vector3.ONE * 1.38 if is_boss else (Vector3(1.16, 1.0, 1.15) if enemy_variant == "brute" else (Vector3(0.91, 1.03, 0.91) if enemy_variant == "stalker" else Vector3.ONE))
	_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if is_boss and _animation_player == null:
		_animation_player = AnimationPlayer.new()
		_animation_player.name = "UniversalBaseAnimationPlayer"
		model.add_child(_animation_player)
	if _animation_player != null:
		_animation_player.root_node = _animation_player.get_path_to(model)
	_skeleton = null
	var skeleton_nodes := model.find_children("*", "Skeleton3D", true, false)
	if not skeleton_nodes.is_empty():
		_skeleton = skeleton_nodes[0] as Skeleton3D
	_base_visual_meshes.clear()
	for mesh_node in model.find_children("*", "MeshInstance3D", true, false):
		_base_visual_meshes.append(mesh_node as MeshInstance3D)
	if _animation_player != null and _skeleton != null:
		_fight_animations_ready = RIG_ANIMATION_CACHE.install(model, _animation_player, _skeleton, _fight_attack_profiles())
		_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	if _animation_player != null:
		for loop_name in ["Idle", "Walk", "Sprint"]:
			if _animation_player.has_animation(loop_name):
				_animation_player.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		_animation_player.speed_scale = 1.0
		# Apply a real imported pose before the model can be rendered. The GLB's
		# bind pose has horizontal arms, and the boss is visible immediately.
		if _animation_player.has_animation(&"Idle"):
			_animation_player.play(&"Idle", 0.0)
			_animation_player.seek(0.05, true)
		if not _animation_player.animation_finished.is_connected(_on_animation_finished):
			_animation_player.animation_finished.connect(_on_animation_finished)
	if is_boss:
		_apply_variant_overlay()
	# Style newly acquired and reused rigs before selecting their reveal material.
	Pencil.convert(model)
	_update_flashlight_body_materials()
	SHADOW_POLICY.disable_in_tree(model)
	set_quality_shadow_enabled(_quality_shadows_enabled)

func _release_detailed_model() -> void:
	if state == "limb_hold":
		release_limb_grab(_player, "model_released")
	elif state == "limb_grab_windup":
		cancel_limb_grab_windup(_player, "model_released")
	if _model == null:
		return
	var model := _model
	for mesh in _base_visual_meshes:
		FLASHLIGHT_REVEAL.set_mesh_revealed(mesh, false)
	if _animation_player != null:
		_animation_player.stop()
		_animation_player.speed_scale = 1.0
		if _animation_player.animation_finished.is_connected(_on_animation_finished):
			_animation_player.animation_finished.disconnect(_on_animation_finished)
	_animation_player = null
	_skeleton = null
	_fight_animations_ready = false
	_model = null
	_full_animation_selected = false
	_base_visual_meshes.clear()
	_update_visual_visibility()
	_visual_root.remove_child(model)
	if not is_boss and is_instance_valid(_rig_budget_owner):
		_rig_budget_owner.call("_release_rig", model)
	else:
		model.free()

func attach_status_label(label: Label3D) -> void:
	_status_label = label
	if _visual_root != null:
		_visual_root.add_child(label)
	else:
		add_child(label)
	_update_health_display()

func _build_health_display() -> void:
	_health_bar_root = HEALTH_BAR.instantiate() as Node3D
	_health_bar_fill = _health_bar_root.get_node("Fill") as MeshInstance3D
	_health_bar_root.position.y = 3.05 if is_boss else 2.58
	_health_bar_root.visible = is_boss
	_visual_root.add_child(_health_bar_root)
	_update_health_display()

func _update_health_display() -> void:
	var ratio := clampf(float(hp) / maxf(1.0, float(starting_health)), 0.0, 1.0)
	if _status_label != null:
		_status_label.text = "%s  %d%%" % [enemy_variant.to_upper(), roundi(ratio * 100.0)]
	if _health_bar_fill != null:
		_health_bar_fill.scale.x = ratio
		_health_bar_fill.position.x = -0.41 * (1.0 - ratio)
	if _health_bar_root != null:
		_health_bar_root.visible = is_boss or hp < starting_health

func _show_impact_flash(is_jump_hit: bool) -> void:
	if _visual_root == null:
		return
	if is_instance_valid(combat_fx_pool) and combat_fx_pool.has_method("play_zombie_hit_flash"):
		combat_fx_pool.call("play_zombie_hit_flash", global_position + Vector3(0.0, 1.0, 0.0), is_jump_hit)
		return
	var flash := MeshInstance3D.new()
	flash.name = "ImpactFlash"
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	sphere.radial_segments = 8
	sphere.rings = 4
	flash.mesh = sphere
	flash.position = Vector3(0.0, 1.0, 0.0)
	var tint := Color(1.0, 0.72, 0.24) if is_jump_hit else Color(1.0, 0.86, 0.68)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(tint.r, tint.g, tint.b, 0.92)
	material.emission_enabled = true
	material.emission = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = material
	_visual_root.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.18)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.18)
	tween.parallel().tween_property(material, "emission:a", 0.0, 0.18)
	tween.tween_callback(flash.queue_free)

func _apply_variant_overlay() -> void:
	var tint := Color(0.43, 0.82, 0.47, 0.15)
	if enemy_variant == "brute":
		tint = Color(0.86, 0.44, 0.20, 0.20)
	elif enemy_variant == "stalker":
		tint = Color(0.20, 0.72, 0.76, 0.16)
	elif is_boss:
		tint = Color(0.82, 0.10, 0.16, 0.22)
	var overlay := StandardMaterial3D.new()
	overlay.albedo_color = tint
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for node in _descendants(_model):
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).material_overlay = overlay

func _add_boss_ring() -> void:
	var halo := MeshInstance3D.new()
	halo.name = "BossRing"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.65
	ring.outer_radius = 0.82
	ring.rings = 18
	ring.ring_segments = 8
	halo.mesh = ring
	halo.position.y = 0.12
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.85, 0.08, 0.12)
	glow.emission_enabled = true
	glow.emission = Color(0.85, 0.08, 0.12)
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.material_override = glow
	_visual_root.add_child(halo)

func _build_debug_variant() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.5 if not is_boss else 0.75
	mesh.height = 1.8 if not is_boss else 2.5
	body.mesh = mesh
	body.position.y = mesh.height * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = _variant_color()
	body.material_override = material
	_visual_root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.28 if not is_boss else 0.4
	head_mesh.height = head_mesh.radius * 2.0
	head.mesh = head_mesh
	head.position.y = mesh.height - 0.06
	head.material_override = material
	_visual_root.add_child(head)

func _variant_color() -> Color:
	match enemy_variant:
		"brute": return Color(0.53, 0.31, 0.25)
		"stalker": return Color(0.22, 0.46, 0.44)
		"boss": return Color(0.35, 0.08, 0.11)
		_: return Color(0.38, 0.48, 0.34)

func _descendants(root: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		result.append(current)
		for child in current.get_children():
			pending.append(child)
	return result

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	if _player_grapple_time > 0.0:
		_player_grapple_time = maxf(0.0, _player_grapple_time - delta)
		if not is_instance_valid(_player_grapple_owner):
			_player_grapple_time = 0.0
		else:
			var facing := _player_grapple_owner.global_position - global_position
			facing.y = 0.0
			if facing.length_squared() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 16.0))
			velocity.x = 0.0
			velocity.z = 0.0
			knockback = Vector3.ZERO
			if not is_on_floor():
				velocity.y -= GRAVITY * delta
			else:
				velocity.y = 0.0
			move_and_slide()
			return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as FoundationPlayer
	if _player == null:
		return
	var distance := global_position.distance_to(_player.global_position)
	_set_distance_detail(distance)
	# Beyond 7 m, ordinary collision/AI runs at 10 Hz, including
	# opening assaults. Near-player contact remains full-rate.
	if not is_boss and distance > FAR_PHYSICS_DISTANCE:
		if not _far_physics_active:
			# Offset the first distant tick by a stable per-actor phase so a
			# crowd crossing the 7 m boundary does not collide on one frame.
			_far_physics_time = float(get_instance_id() % 10) * (FAR_PHYSICS_INTERVAL / 10.0)
			_far_physics_active = true
		_far_physics_time += delta
		if _far_physics_time < FAR_PHYSICS_INTERVAL:
			return
		delta = _far_physics_time
		_far_physics_time = 0.0
	else:
		_far_physics_time = 0.0
		_far_physics_active = false
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	if distance > 70.0:
		if _spawn_assault_time > 0.0:
			_finish_spawn_assault()
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = 0.0
		return
	# Cheap distance guard between staggered decisions prevents a fast burst from
	# carrying through the player. Contact still requires the normal attack windup.
	if _spawn_assault_time > 0.0 and Vector2(global_position.x - _player.global_position.x, global_position.z - _player.global_position.z).length() <= SPAWN_ASSAULT_HANDOFF_DISTANCE:
		_finish_spawn_assault()
	_ai_accumulator += delta
	if is_boss:
		_ai_interval = 0.0
	elif distance > RENDER_RADIUS:
		_ai_interval = 0.45
	elif distance > 18.0:
		_ai_interval = 0.18
	else:
		_ai_interval = 0.10
	if _ai_accumulator < _ai_interval:
		# A stale chase velocity must not carry an unadmitted zombie into the
		# local ring between staggered decisions.
		if not is_boss and is_instance_valid(attack_director) and attack_director.has_method("is_local_formation_active") and bool(attack_director.call("is_local_formation_active")) and combat_target == _player and distance <= 4.2 and String(attack_director.call("formation_role_for", self)).is_empty() and state not in ["windup", "limb_grab_windup", "limb_hold", "hit", "recovery"]:
			velocity.x = 0.0
			velocity.z = 0.0
		_move_and_check_assault(delta)
		return
	var step := _ai_accumulator
	_ai_accumulator = 0.0
	_update_ai(step, distance)
	_move_and_check_assault(delta)

func _move_and_check_assault(step: float) -> void:
	# CharacterBody3D moves for one engine tick per call. Scale velocity for
	# a skipped far tick, then restore the collision-adjusted speed so an enemy
	# covers the same ground in real time at 10 Hz as it did at 60 Hz.
	var factor := maxf(1.0, step / get_physics_process_delta_time())
	velocity *= factor
	move_and_slide()
	velocity /= factor
	# Collision flags can clear on the next zero-velocity tick. Inspect them here,
	# rather than waiting up to 0.45 seconds for a distant AI decision.
	if _spawn_assault_time > 0.0 and is_on_wall():
		_finish_spawn_assault()

func _set_distance_detail(distance: float) -> void:
	if _visual_root == null:
		return
	var band := 2 if distance > RENDER_RADIUS else (0 if distance <= DETAILED_RADIUS else 1)
	if band == _lod_band:
		# Rendering state is already synchronized by rig/flashlight changes.
		return
	_lod_band = band
	_update_visual_visibility()

func _update_visual_visibility() -> void:
	if _visual_root == null:
		return
	_visual_root.visible = is_boss or (_flashlight_render_visible and _full_animation_selected and _lod_band <= 1)

func set_flashlight_render_visible(is_visible: bool) -> void:
	if is_boss or _flashlight_render_visible == is_visible:
		return
	_flashlight_render_visible = is_visible
	_update_visual_visibility()

func set_flashlight_full_body_visible(is_visible: bool) -> void:
	if _flashlight_full_body_visible == is_visible:
		return
	_flashlight_full_body_visible = is_visible
	_update_flashlight_body_materials()

func _update_flashlight_body_materials() -> void:
	for mesh in _base_visual_meshes:
		FLASHLIGHT_REVEAL.set_mesh_revealed(mesh, _flashlight_full_body_visible)

func _set_full_animation_selected(selected: bool) -> void:
	if is_boss:
		selected = true
	if _death_started and not is_boss:
		return
	if _full_animation_selected == selected:
		_update_visual_visibility()
		return
	if selected:
		_ensure_detailed_model()
		_full_animation_selected = _model != null
		_update_visual_visibility()
		if _full_animation_selected:
			_resume_animation_for_state()
	else:
		_release_detailed_model()
		_update_visual_visibility()

func set_quality_shadow_enabled(enabled: bool) -> void:
	_quality_shadows_enabled = enabled
	_apply_quality_shadow_state()

func _apply_quality_shadow_state() -> void:
	for mesh in _base_visual_meshes:
		if is_instance_valid(mesh):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _quality_shadows_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _distance_to_player() -> float:
	if is_instance_valid(_player):
		return global_position.distance_to(_player.global_position)
	return INF



func _resume_animation_for_state() -> void:
	if _animation_player == null or not _full_animation_selected:
		return
	match state:
		"windup":
			var target := combat_target if _valid_target() else _player
			if is_instance_valid(target):
				_begin_attack_animation(target, global_position.distance_to(target.global_position), maxf(state_time, 0.01))
			else:
				_play_animation("Idle")
		"limb_grab_windup", "limb_hold":
			if not _limb_grab_hand.is_empty():
				var clip := String(FIGHT_ANIMATION_BUILDER.clip_path("punch", _limb_grab_hand, ENEMY_FIGHT_LIBRARY))
				if _animation_player.has_animation(clip):
					_play_animation(clip, 1.0, 0.04, true)
					if state == "limb_hold":
						_animation_player.seek(_attack_contact_time, true)
						_animation_player.pause()
		"hit": _play_animation("Hit_React", 1.0, 0.04, true)
		"assault": _play_animation("Sprint")
		"wander": _play_animation("Walk")
		"approach": _play_animation("Sprint" if _is_high_speed_chase() else "Walk")
		_: _play_animation("Idle")

func _update_ai(delta: float, distance: float) -> void:
	if state == "limb_hold":
		velocity.x = 0.0
		velocity.z = 0.0
		# The player's session timer is authoritative, not this AI clock.
		if not _can_keep_limb_grab():
			release_limb_grab(_player, "reservation_lost")
		elif _player.get_active_grab_enemy() != self:
			release_limb_grab(_player, "session_lost")
		return
	if stun_time > 0.0:
		stun_time = maxf(0.0, stun_time - delta)
		velocity.x = move_toward(velocity.x, 0.0, delta * 9.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 9.0)
		return
	if slow_time > 0.0:
		slow_time = maxf(0.0, slow_time - delta)
		if slow_time == 0.0:
			slow_factor = 1.0
	if knockback.length_squared() > 0.01:
		velocity.x = knockback.x
		velocity.z = knockback.z
		knockback = knockback.move_toward(Vector3.ZERO, delta * 14.0)
		return
	if _spawn_assault_time > 0.0 and _update_spawn_assault(delta):
		return
	_decision_time -= delta
	if _decision_time <= 0.0 and state not in ["windup", "limb_grab_windup"]:
		_decision_time = randf_range(0.35, 0.55)
		_choose_target()
	if not _valid_target():
		combat_target = null
		if state == "limb_grab_windup":
			cancel_limb_grab_windup(_player)
		if state == "windup":
			_release_player_attack_slot()
			state = "recovery"
			state_time = recovery_duration
			_attack_animation = ""
			_play_animation("Idle")
		if state == "hit" or state == "recovery":
			state_time = maxf(0.0, state_time - delta)
			velocity.x = 0.0
			velocity.z = 0.0
			if state_time > 0.0:
				return
		if not is_boss:
			# Ordinary ground zombies wait for the player and never pick another
			# zombie as prey or wander away from the encounter.
			state = "idle"
			_wander_time = 0.0
			_wander_direction = Vector3.ZERO
			velocity.x = move_toward(velocity.x, 0.0, delta * 9.0)
			velocity.z = move_toward(velocity.z, 0.0, delta * 9.0)
			_play_animation("Idle")
		else:
			_wander(delta)
		return
	distance = global_position.distance_to(combat_target.global_position)
	var to_player := combat_target.global_position - global_position
	to_player.y = 0.0
	var direction := to_player.normalized()
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))
	state_time = maxf(0.0, state_time - delta)
	if state == "hit":
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
		_play_animation("Hit_React")
		if state_time <= 0.0:
			state = "approach"
	elif state == "limb_grab_windup":
		velocity.x = 0.0
		velocity.z = 0.0
		if not _can_keep_limb_grab() or not _player.is_limb_grab_candidate(self):
			cancel_limb_grab_windup(_player)
		elif state_time <= 0.0:
			_resolve_limb_grab(distance)
	elif state == "windup":
		velocity.x = 0.0
		velocity.z = 0.0
		if _attack_animation.is_empty():
			_begin_attack_animation(combat_target, distance, maxf(state_time, 0.01))
		if state_time <= 0.0:
			_resolve_enemy_attack(distance)
	elif state == "recovery":
		velocity.x = 0.0
		velocity.z = 0.0
		if state_time <= 0.0:
			state = "approach"
	else:
		if _follow_local_formation(delta, distance):
			return
		if distance <= attack_range and _clear_sight(combat_target):
			if combat_target == _player and not is_boss and is_instance_valid(attack_director) and not attack_director.call("try_acquire_attacker", self):
				# Waiters make room around the player instead of stacking inside
				# the same capsule while one of the four attack slots is occupied.
				var queue_direction := _crowd_wait_direction(direction)
				velocity.x = queue_direction.x * CROWD_WAIT_SPEED
				velocity.z = queue_direction.z * CROWD_WAIT_SPEED
				return
			_attack_sequence += 1
			if _attack_sequence % 3 == 1 and _try_begin_limb_grab():
				return
			state = "windup"
			state_time = telegraph_duration if is_boss else telegraph_duration * 0.55
			_attack_latched = true
			velocity.x = 0.0
			velocity.z = 0.0
			_begin_attack_animation(combat_target, distance, state_time)
			telegraph_started.emit(self, is_boss)
		else:
			# Ray probes steer around the next solid obstacle without changing
			# CharacterBody collision handling or teleporting the zombie.
			var crowd_separation := _crowd_separation_direction()
			var desired_direction := direction
			if not is_boss and is_instance_valid(attack_director) and attack_director.has_method("is_local_formation_active") and bool(attack_director.call("is_local_formation_active")) and combat_target == _player and String(attack_director.call("formation_role_for", self)) == "attacker":
				var goal: Vector3 = attack_director.call("formation_target_for", self)
				if goal.is_finite():
					desired_direction = goal - global_position
					desired_direction.y = 0.0
					if desired_direction.length_squared() > 0.04:
						desired_direction = desired_direction.normalized()
					else:
						desired_direction = direction
			if crowd_separation.length_squared() > 0.001:
				desired_direction = (desired_direction + crowd_separation * CROWD_SEPARATION_STRENGTH).normalized()
			var chase_direction := _pursuit_direction(desired_direction, delta, distance)
			velocity.x = chase_direction.x * move_speed * slow_factor * (1.0 if is_boss else 1.45)
			velocity.z = chase_direction.z * move_speed * slow_factor * (1.0 if is_boss else 1.45)
			_play_animation("Sprint" if _is_high_speed_chase() else "Walk")

func _follow_local_formation(delta: float, distance: float) -> bool:
	if is_boss or combat_target != _player or not is_instance_valid(attack_director) or not attack_director.has_method("is_local_formation_active") or not bool(attack_director.call("is_local_formation_active")):
		return false
	var role: String = String(attack_director.call("formation_role_for", self))
	if role == "attacker":
		return false
	if role.is_empty() and distance > 4.9:
		return false
	var goal := Vector3.INF
	if role.is_empty():
		# Unadmitted actors hold outside the ring; if the player crosses them,
		# they walk back out through ordinary CharacterBody collision.
		var away := global_position - _player.global_position
		away.y = 0.0
		if away.length_squared() < 0.01:
			away = -_player.global_basis.z
			away.y = 0.0
		goal = _player.global_position + away.normalized() * 4.55
	else:
		goal = attack_director.call("formation_target_for", self)
	state = "approach"
	var to_goal := goal - global_position if goal.is_finite() else Vector3.ZERO
	to_goal.y = 0.0
	if to_goal.length_squared() < 0.12:
		var separation := _crowd_separation_direction()
		if separation.length_squared() > 0.04:
			velocity.x = separation.x * CROWD_WAIT_SPEED
			velocity.z = separation.z * CROWD_WAIT_SPEED
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		_play_animation("Walk" if separation.length_squared() > 0.04 else "Idle")
		return true
	var desired := to_goal.normalized()
	var crowd := _crowd_separation_direction()
	if crowd.length_squared() > 0.001:
		desired = (desired + crowd * CROWD_SEPARATION_STRENGTH).normalized()
	var steering := _pursuit_direction(desired, delta, to_goal.length())
	velocity.x = steering.x * move_speed * slow_factor
	velocity.z = steering.z * move_speed * slow_factor
	rotation.y = lerp_angle(rotation.y, atan2(-steering.x, -steering.z), minf(1.0, delta * 8.0))
	_play_animation("Walk")
	return true

# Only detailed local attackers can start a visible, side-specific reach.
# Both rigs expose hand_l/hand_r; use live bone positions instead of assuming
# that model yaw or imported rest axes correspond to world left/right.
func _try_begin_limb_grab() -> bool:
	if is_boss or combat_target != _player or not is_instance_valid(_player):
		return false
	if not _full_animation_selected or not _visual_root.visible or _animation_player == null or _skeleton == null or _player._skeleton == null:
		return false
	if not _can_keep_limb_grab():
		return false
	var nearest := _nearest_arm_and_hand()
	if nearest.is_empty():
		return false
	var hand: String = nearest["hand"]
	var clip := String(FIGHT_ANIMATION_BUILDER.clip_path("punch", hand, ENEMY_FIGHT_LIBRARY))
	if not _animation_player.has_animation(clip):
		# No compatible side-specific reach: continue with the ordinary strike.
		return false
	var limb: String = nearest["limb"]
	if not _player.try_reserve_limb_grab(self, limb):
		return false
	_limb_grab_hand = hand
	_limb_grab_limb = limb
	_attack_animation = clip
	_attack_contact_time = _attack_clip_contact_time(clip)
	state = "limb_grab_windup"
	state_time = clampf(limb_grab_windup_seconds, 0.45, 1.25)
	_attack_latched = true
	velocity.x = 0.0
	velocity.z = 0.0
	var speed := _attack_contact_time / state_time if _attack_contact_time > 0.0 else 1.0
	if not _play_animation(clip, speed, 0.08, true):
		cancel_limb_grab_windup(_player)
		return false
	return true

func _nearest_arm_and_hand() -> Dictionary:
	var nearest := {}
	var best := INF
	for arm in ["left", "right"]:
		var player_bone := _player._skeleton.find_bone("hand_l" if arm == "left" else "hand_r")
		if player_bone < 0:
			continue
		var arm_at := _player._skeleton.to_global(_player._skeleton.get_bone_global_pose(player_bone).origin)
		for hand in ["left", "right"]:
			var enemy_bone := _skeleton.find_bone("hand_l" if hand == "left" else "hand_r")
			if enemy_bone < 0:
				continue
			var hand_at := _skeleton.to_global(_skeleton.get_bone_global_pose(enemy_bone).origin)
			var distance_squared := arm_at.distance_squared_to(hand_at)
			if distance_squared < best:
				best = distance_squared
				nearest = {"limb": "LEFT ARM" if arm == "left" else "RIGHT ARM", "hand": hand}
	return nearest

func _can_keep_limb_grab() -> bool:
	return is_instance_valid(_player) and _player.health > 0 and is_instance_valid(attack_director) and attack_director.has_method("can_maintain_limb_grab") and bool(attack_director.call("can_maintain_limb_grab", self))

func _resolve_limb_grab(distance: float) -> void:
	var hit := false
	if _can_keep_limb_grab() and is_instance_valid(_player):
		distance = global_position.distance_to(_player.global_position)
		if distance <= minf(attack_range + 0.18, 1.65) and _clear_sight(_player):
			# A synchronous escape callback can now release the tactical hold.
			state = "limb_hold"
			state_time = clampf(_player.limb_grab_hold_seconds, 0.5, 3.0)
			hit = _player.begin_limb_grab(self, _limb_grab_limb)
			if not hit and state == "limb_hold":
				state = "limb_grab_windup"
	if hit:
		if state == "limb_hold" and _animation_player != null and _animation_player.current_animation == _attack_animation:
			_animation_player.seek(_attack_contact_time, true)
			_animation_player.pause()
		_attack_latched = false
		attack_resolved.emit(self, true)
		return
	attack_resolved.emit(self, false)
	cancel_limb_grab_windup(_player, "contact_failed")

func cancel_limb_grab_windup(owner: FoundationPlayer, reason: String = "windup_cancelled") -> void:
	if state != "limb_grab_windup" or owner != _player:
		return
	state = "recovery"
	state_time = recovery_duration * 0.65
	_limb_grab_limb = ""
	_limb_grab_hand = ""
	_attack_animation = ""
	_attack_latched = false
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(_player):
		_player.cancel_pending_limb_grab(self, reason)
	_play_animation("Idle", 1.0, 0.08, true)
	_release_player_attack_slot()

func release_limb_grab(owner: FoundationPlayer, reason: String = "enemy_released") -> void:
	if state != "limb_hold" or owner != _player:
		return
	state = "recovery"
	state_time = recovery_duration * 0.65
	_limb_grab_limb = ""
	_limb_grab_hand = ""
	_attack_animation = ""
	_attack_latched = false
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(_player):
		_player.end_limb_grab(self, reason)
	_play_animation("Idle", 1.0, 0.08, true)
	_release_player_attack_slot()

func _exit_tree() -> void:
	if state == "limb_hold":
		release_limb_grab(_player, "enemy_despawned")
	elif state == "limb_grab_windup":
		cancel_limb_grab_windup(_player, "enemy_despawned")

func _resolve_enemy_attack(distance: float) -> void:
	var hit := false
	# Legacy direct callers resolve against the player; active AI locks its target during windup.
	var target: Node3D = combat_target if _valid_target() else _player
	if is_instance_valid(target):
		distance = global_position.distance_to(target.global_position)
		var local_attack_allowed := is_boss or target != _player or not is_instance_valid(attack_director) or not attack_director.has_method("can_resolve_player_attack") or bool(attack_director.call("can_resolve_player_attack", self))
		if local_attack_allowed and distance <= attack_range + 0.18 and _clear_sight(target):
			if target is FoundationEnemy:
				target.receive_hit(12, (target.global_position - global_position).normalized())
				if target.hp > 0 and target.combat_target != _player:
					target.combat_target = self
			elif is_boss:
				_player.take_boss_damage(22)
			else:
				_player.interrupt_by_zombie(0.75, 0.60)
			hit = true
	attack_resolved.emit(self, hit)
	_release_player_attack_slot()
	if not _attack_animation.is_empty() and _animation_player != null and _animation_player.current_animation == _attack_animation:
		var clip := _animation_player.get_animation(_attack_animation)
		var remaining := maxf(0.01, clip.length - _attack_contact_time)
		var recovery := recovery_duration if is_boss else recovery_duration * 0.65
		# The AI clock decides damage; play the remaining visual recovery over
		# that same interval, even when a decision tick resolves contact late.
		_animation_player.play(_attack_animation, -1.0, remaining / maxf(recovery, 0.01))
		_animation_player.seek(_attack_contact_time, true)
	_attack_animation = ""
	state = "recovery"
	state_time = recovery_duration if is_boss else recovery_duration * 0.65
	_attack_latched = false

func _is_player_visible_to_player() -> bool:
	var camera := get_tree().get_first_node_in_group("foundation_camera") as Camera3D
	if camera == null:
		return true
	var point := camera.unproject_position(global_position + Vector3(0.0, 1.0, 0.0))
	var rect := get_viewport().get_visible_rect()
	return not camera.is_position_behind(global_position) and rect.grow(-28.0).has_point(point)

func begin_player_grapple(owner: FoundationPlayer, duration: float) -> bool:
	# Existing reaction clip is shared; enemy/boss animation libraries stay untouched.
	if hp <= 0 or is_boss or not is_instance_valid(owner) or duration <= 0.0:
		return false
	_finish_spawn_assault()
	if state == "limb_hold":
		release_limb_grab(_player)
	elif state == "limb_grab_windup":
		cancel_limb_grab_windup(_player)
	_release_player_attack_slot()
	_player_grapple_owner = owner
	_player_grapple_time = duration
	state = "hit"
	state_time = duration
	_attack_animation = ""
	velocity.x = 0.0
	velocity.z = 0.0
	knockback = Vector3.ZERO
	_play_animation("Hit_React", 1.0, 0.08, true)
	return true

func end_player_grapple(owner: FoundationPlayer) -> void:
	if _player_grapple_owner != owner:
		return
	_player_grapple_owner = null
	_player_grapple_time = 0.0

func receive_hit(damage: int, hit_direction: Vector3 = Vector3.ZERO, is_jump_hit: bool = false) -> int:
	if hp <= 0 or damage <= 0 or _death_started:
		return 0
	var interrupt_reason := "enemy_died" if damage >= hp else "enemy_hit"
	if state == "limb_hold":
		release_limb_grab(_player, interrupt_reason)
	elif state == "limb_grab_windup":
		cancel_limb_grab_windup(_player, interrupt_reason)
	_finish_spawn_assault()
	_release_player_attack_slot()
	var dealt := mini(hp, damage)
	hp -= dealt
	_update_health_display()
	_show_impact_flash(is_jump_hit)
	state = "hit"
	state_time = 0.30 if not is_jump_hit else 0.42
	_attack_animation = ""
	if hit_direction.length_squared() > 0.01:
		knockback = hit_direction.normalized() * (4.5 if not is_jump_hit else 6.5)
	if hp <= 0:
		_player_grapple_time = 0.0
		_player_grapple_owner = null
		state = "dead"
		_death_started = true
		velocity = Vector3.ZERO
		set_physics_process(false)
		collision_layer = 0
		collision_mask = 0
		if is_instance_valid(_collision_shape):
			_collision_shape.set_deferred("disabled", true)
		_death_animation = _death_animation_for_hit(hit_direction)
		if _full_animation_selected and _play_animation(_death_animation, 1.0, 0.06, true):
			return dealt
		# A dying reduced-tier enemy remains in the shared silhouette batch.
		# No new rig is allocated just to play a death animation.
		var tween := create_tween()
		tween.tween_property(self, "_low_poly_death_scale", 0.08, 0.45)
		tween.tween_callback(_complete_death)
	else:
		_play_animation("Hit_React", 1.0, 0.08, true)
	return dealt

func apply_stun(duration: float) -> void:
	if state == "limb_hold":
		release_limb_grab(_player)
	elif state == "limb_grab_windup":
		cancel_limb_grab_windup(_player)
	_finish_spawn_assault()
	if state == "windup":
		state = "approach"
		_attack_animation = ""
	_release_player_attack_slot()
	stun_time = maxf(stun_time, duration)

func _release_player_attack_slot() -> void:
	if is_instance_valid(attack_director):
		attack_director.call("release_attacker", self)

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(factor, 0.1, 1.0))
	slow_time = maxf(slow_time, duration)

func _play_animation(animation_name: String, playback_speed: float = 1.0, blend: float = 0.12, force_restart: bool = false) -> bool:
	if animation_name.is_empty() or not _full_animation_selected or _animation_player == null or not _animation_player.has_animation(animation_name):
		return false
	if force_restart or _animation_player.current_animation != animation_name or not _animation_player.is_playing():
		_animation_player.play(animation_name, blend, maxf(0.01, playback_speed))
		if force_restart:
			_animation_player.seek(0.0, true)
	return true

func _is_high_speed_chase() -> bool:
	return _spawn_assault_time > 0.0 or (not is_boss and move_speed * 1.45 >= 4.5)

func _attack_clip_contact_time(animation_name: String) -> float:
	if _animation_player != null and _animation_player.has_animation(animation_name):
		var clip := _animation_player.get_animation(animation_name)
		var marker_time := clip.get_marker_time(&"contact")
		if marker_time > 0.0:
			return marker_time
	match animation_name:
		"Attack_Swipe_L", "Attack_Swipe_R": return 0.36666667
		"Attack_Bite": return 0.53333336
	return 0.0

func _select_attack_animation(target: Node3D, distance: float, available: Array[String] = []) -> String:
	if _fight_animations_ready:
		var side_name := "right"
		if is_instance_valid(target):
			var offset := target.global_position - global_position
			side_name = "left" if global_basis.x.dot(offset) < 0.0 else "right"
		var kind := _fight_attack_kind(distance)
		var player_clip := String(FIGHT_ANIMATION_BUILDER.clip_path(kind, side_name, ENEMY_FIGHT_LIBRARY))
		if available.is_empty() or available.has(player_clip):
			return player_clip

	var desired := "Attack_Swipe_L"
	if distance <= attack_range * 0.68:
		desired = "Attack_Bite"
	elif is_instance_valid(target):
		var legacy_offset := target.global_position - global_position
		var side := global_basis.x.dot(legacy_offset)
		desired = "Attack_Swipe_L" if side < 0.0 else "Attack_Swipe_R"
	var candidates: Array[String] = [desired, "Attack_Swipe_L", "Attack_Swipe_R", "Attack_Bite"]
	if available.is_empty():
		return desired
	for candidate in candidates:
		if available.has(candidate):
			return candidate
	return ""

func _fight_attack_kind(distance: float) -> String:
	if distance <= attack_range * 0.68:
		return "punch"
	if enemy_variant == "stalker":
		return "kick"
	if enemy_variant == "brute" or is_boss:
		return "kick" if _attack_sequence % 2 == 1 else "punch"
	return "kick" if _attack_sequence % 3 == 2 else "punch"

func _begin_attack_animation(target: Node3D, distance: float, windup_time: float) -> void:
	var available: Array[String] = []
	if _animation_player != null:
		if _fight_animations_ready:
			for kind in ["punch", "kick"]:
				for side in ["left", "right"]:
					var candidate := String(FIGHT_ANIMATION_BUILDER.clip_path(kind, side, ENEMY_FIGHT_LIBRARY))
					if _animation_player.has_animation(candidate):
						available.append(candidate)
		else:
			for candidate in ["Attack_Swipe_L", "Attack_Swipe_R", "Attack_Bite"]:
				if _animation_player.has_animation(candidate):
					available.append(candidate)
	_attack_animation = _select_attack_animation(target, distance, available)
	_attack_contact_time = _attack_clip_contact_time(_attack_animation)
	var speed := _attack_contact_time / maxf(0.01, windup_time) if _attack_contact_time > 0.0 else 1.0
	if not _play_animation(_attack_animation, speed, 0.08, true):
		_attack_animation = ""

func _death_animation_for_hit(hit_direction: Vector3) -> String:
	if hit_direction.length_squared() < 0.01:
		return "Death_Forward"
	var forward := -global_basis.z
	return "Death_Backward" if forward.dot(hit_direction.normalized()) >= 0.0 else "Death_Forward"

func _on_animation_finished(animation_name: StringName) -> void:
	if _death_started and not _death_completed and String(animation_name) == _death_animation:
		_complete_death()

func _complete_death() -> void:
	if not _death_started or _death_completed:
		return
	_death_completed = true
	_release_detailed_model()
	defeated.emit(self)
	queue_free()
