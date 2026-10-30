extends Node3D
## Only new zombies enter this director. Living zombies are never repositioned.

signal spawn_requested(at: Vector3)

const MAX_CANDIDATES_PER_TICK := 8
const MAX_SPAWNS_PER_TICK := 2
# Phones spread collision queries and enemy setup across frames instead of
# doing two synchronous births plus a large placement-search burst at once.
const MOBILE_MAX_CANDIDATES_PER_TICK := 2
const MOBILE_MAX_SPAWNS_PER_TICK := 1
const MOBILE_SPAWN_INTERVAL := 0.12
const RETRY_SECONDS := 0.25
const REPLACEMENT_SECONDS := 1.0
const MAX_PLAYER_ATTACKERS := 4
const FORWARD_HALF_ANGLE := deg_to_rad(80.0)
const RADIAL_SPREAD := 4.0
const WORLD_LIMIT := 94.0
const MIN_PLAYER_DISTANCE := 12.0
const BASE_EXCLUSION_RADIUS := 7.5
const INITIAL_SPAWN_MIN_DISTANCE := 36.0
const INITIAL_SPAWN_MAX_DISTANCE := 64.0
const RECENT_SPACING := 2.0
const RECENT_SECONDS := 8.0
# Includes outstretched arms and the health display, not just the physics capsule.
const VISUAL_EXTENTS := Vector3(1.5, 1.6, 1.5)

var player: FoundationPlayer
var camera: Camera3D
var population_limit := 4
var spawn_distance := 50.0
var initial_spawn_min_distance := INITIAL_SPAWN_MIN_DISTANCE
var initial_spawn_max_distance := INITIAL_SPAWN_MAX_DISTANCE
var visibility_radius := 30.0
var blocked_boxes: Array[AABB] = []
var last_candidate_count := 0
var last_spawn_count := 0
var _live: Dictionary = {}
var _stored_population: Array[Dictionary] = []
var _ground_active := true
var _attackers: Dictionary = {}
var _pending: Array[float] = []
var _initial_population_pending := 0
var _initial_sample_index := 0
var _recent: Array[Dictionary] = []
var _clock := 0.0
var _retry_time := 0.0
var _sample_index := 0
var _capsule := CapsuleShape3D.new()
var _mobile_spawn_cooldown := 0.0

func _init() -> void:
	_capsule.radius = 0.55
	_capsule.height = 1.95

func store_upstairs_population(count: int) -> void:
	# Only data remains upstairs. The arena removes the actors before this reset.
	_ground_active = false
	set_physics_process(false)
	_live.clear()
	_attackers.clear()
	_pending.clear()
	_initial_population_pending = 0
	_recent.clear()
	_retry_time = 0.0
	_mobile_spawn_cooldown = 0.0
	_stored_population.clear()
	population_limit = count
	for index in range(count):
		_stored_population.append({"kind": "shambler"})

func activate_ground_population(cap: int) -> void:
	if _ground_active:
		return
	# Consume the four stored entries, not the full thirteen-slot capacity.
	var opening_count := mini(_stored_population.size(), cap)
	_stored_population.clear()
	population_limit = cap
	_initial_population_pending = opening_count
	_ground_active = true
	set_physics_process(true)

func activate_profiling_population(cap: int) -> void:
	_stored_population.clear()
	population_limit = cap
	_ground_active = true
	set_physics_process(true)

func ordinary_population_count() -> int:
	if not _ground_active:
		return _stored_population.size()
	var living := 0
	for enemy in _live.values():
		if is_instance_valid(enemy) and enemy.hp > 0:
			living += 1
	return living

func request_initial_population() -> void:
	if not _ground_active:
		return
	while _live.size() + _pending.size() + _initial_population_pending < population_limit:
		_initial_population_pending += 1

func request_population() -> void:
	if not _ground_active:
		return
	while _live.size() + _pending.size() + _initial_population_pending < population_limit:
		_pending.append(_clock)

func register_enemy(enemy: FoundationEnemy) -> void:
	if not _ground_active or enemy.is_boss or _live.has(enemy.get_instance_id()) or _live.size() >= population_limit:
		return
	var id := enemy.get_instance_id()
	_live[id] = enemy
	enemy.attack_director = self
	enemy.tree_exiting.connect(_on_removed.bind(id))

func replace_enemy(enemy: FoundationEnemy) -> void:
	if not enemy.is_boss:
		_on_removed(enemy.get_instance_id(), 2)

func _on_removed(id: int, replacements: int = 1) -> void:
	if not _live.has(id):
		return
	var enemy := _live[id] as FoundationEnemy
	if is_instance_valid(enemy):
		enemy.attack_director = null
	_attackers.erase(id)
	_live.erase(id)
	if _ground_active:
		# Pending births reserve slots. A death at thirteen therefore adds one;
		# a death in the opening group can add both requested replacements.
		var available := maxi(0, population_limit - _live.size() - _pending.size() - _initial_population_pending)
		for index in range(mini(replacements, available)):
			_pending.append(_clock + REPLACEMENT_SECONDS)

func try_acquire_attacker(enemy: FoundationEnemy) -> bool:
	var id := enemy.get_instance_id()
	if not _ground_active or enemy.hp <= 0 or not _live.has(id):
		return false
	if _attackers.has(id):
		return true
	if _attackers.size() >= MAX_PLAYER_ATTACKERS:
		return false
	_attackers[id] = true
	return true

func release_attacker(enemy: FoundationEnemy) -> void:
	_attackers.erase(enemy.get_instance_id())

func _physics_process(delta: float) -> void:
	if not _ground_active:
		return
	_clock += delta
	_retry_time = maxf(0.0, _retry_time - delta)
	last_candidate_count = 0
	last_spawn_count = 0
	var mobile_budget_enabled := OS.has_feature("mobile")
	if mobile_budget_enabled:
		_mobile_spawn_cooldown = maxf(0.0, _mobile_spawn_cooldown - delta)
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	if _retry_time > 0.0 or (_pending.is_empty() and _initial_population_pending <= 0) or _live.size() >= population_limit:
		return
	if mobile_budget_enabled and _mobile_spawn_cooldown > 0.0:
		return
	while not _recent.is_empty() and float(_recent.front().time) < _clock - RECENT_SECONDS:
		_recent.pop_front()
	# One shared budget, even when many enemies die in the same frame.
	var candidate_budget: int = MOBILE_MAX_CANDIDATES_PER_TICK if mobile_budget_enabled else MAX_CANDIDATES_PER_TICK
	var spawn_budget: int = MOBILE_MAX_SPAWNS_PER_TICK if mobile_budget_enabled else MAX_SPAWNS_PER_TICK
	while last_candidate_count < candidate_budget and last_spawn_count < spawn_budget:
		var initial_spawn := _initial_population_pending > 0
		if not initial_spawn and (_pending.is_empty() or _pending.front() > _clock):
			break
		if _live.size() >= population_limit:
			break
		last_candidate_count += 1
		var candidate := _sample_initial_candidate() if initial_spawn else _sample_candidate()
		var at := _grounded_candidate(candidate)
		if not at.is_finite() or not is_valid_spawn(at, not initial_spawn):
			continue
		if initial_spawn:
			_initial_population_pending -= 1
		else:
			_pending.pop_front()
		_recent.append({"position": at, "time": _clock})
		if _recent.size() > 64:
			_recent.pop_front()
		last_spawn_count += 1
		# Synchronous: the receiver registers and activates the zombie before rendering.
		spawn_requested.emit(at)
	if mobile_budget_enabled and last_spawn_count > 0:
		_mobile_spawn_cooldown = MOBILE_SPAWN_INTERVAL
	if last_spawn_count == 0 and last_candidate_count > 0:
		_retry_time = RETRY_SECONDS

func forward_direction() -> Vector3:
	var forward := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if forward.length_squared() < 0.16:
		forward = -player.global_basis.z
		forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD

func _sample_candidate() -> Vector3:
	# Low discrepancy sampling spreads replacement waves across the forward arc.
	_sample_index += 1
	var angle := lerpf(-FORWARD_HALF_ANGLE, FORWARD_HALF_ANGLE, fmod(float(_sample_index) * 0.61803398875, 1.0))
	var radius := spawn_distance + lerpf(-RADIAL_SPREAD, RADIAL_SPREAD, fmod(float(_sample_index) * 0.41421356237, 1.0))
	return player.global_position + forward_direction().rotated(Vector3.UP, angle) * radius

func _sample_initial_candidate() -> Vector3:
	# Start with a full 360-degree annulus so the opening invasion is already
	# distributed around the arena. The default 36–64 m band stays concealed
	# and within the zombie AI's 70 m active radius.
	_initial_sample_index += 1
	var index := float(_initial_sample_index)
	var angle := TAU * fmod(index * 0.61803398875, 1.0)
	var radial_fraction := fmod(index * 0.7548776662466927, 1.0)
	var radius_squared := lerpf(
		initial_spawn_min_distance * initial_spawn_min_distance,
		initial_spawn_max_distance * initial_spawn_max_distance,
		radial_fraction
	)
	var radius := sqrt(radius_squared)
	return player.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _grounded_candidate(at: Vector3) -> Vector3:
	if absf(at.x) > WORLD_LIMIT or absf(at.z) > WORLD_LIMIT:
		return Vector3.INF
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, player.global_position.y + 6.0, at.z), Vector3(at.x, -8.0, at.z), 1)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85 or absf(hit.position.y) > 0.5:
		return Vector3.INF
	return hit.position + Vector3.UP * 0.05

func is_valid_spawn(at: Vector3, require_forward: bool = true) -> bool:
	if not at.is_finite() or absf(at.x) > WORLD_LIMIT or absf(at.z) > WORLD_LIMIT:
		return false
	var offset := at - player.global_position
	offset.y = 0.0
	if offset.length() < MIN_PLAYER_DISTANCE:
		return false
	if require_forward and offset.normalized().dot(forward_direction()) < cos(FORWARD_HALF_ANGLE):
		return false
	var base_offset := at - player.safe_base_position
	base_offset.y = 0.0
	if base_offset.length() < BASE_EXCLUSION_RADIUS:
		return false
	for entry in _recent:
		if at.distance_squared_to(entry.position) < RECENT_SPACING * RECENT_SPACING:
			return false
	var envelope := AABB(at + Vector3.UP * VISUAL_EXTENTS.y - VISUAL_EXTENTS, VISUAL_EXTENTS * 2.0)
	for box in blocked_boxes:
		if box.intersects(envelope):
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.05)
	# Areas with a collision layer reserve protected space; they never occlude sight.
	query.collision_mask = 0xFFFFFFFF
	query.collide_with_areas = true
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	# This arena currently uses flat collision-ground movement. If navigation
	# regions are added, also require the candidate to lie on a reachable mesh.
	var nav_map := get_world_3d().navigation_map
	if not NavigationServer3D.map_get_regions(nav_map).is_empty():
		if NavigationServer3D.map_get_closest_point(nav_map, at).distance_to(at) > 0.75:
			return false
		var route := NavigationServer3D.map_get_path(nav_map, at, player.global_position, true)
		if route.size() < 2 or route[0].distance_to(at) > 0.75 or route[route.size() - 1].distance_to(player.global_position) > 2.0:
			return false
	if not is_concealed(at):
		return false
	# Leave room for the first part of the dash instead of spawning against a wall.
	query.collision_mask = 1
	query.collide_with_areas = false
	query.motion = -offset.normalized() * 4.0
	var travel := get_world_3d().direct_space_state.cast_motion(query)
	return travel[0] >= 0.99

func is_concealed(at: Vector3) -> bool:
	if not is_instance_valid(camera) or not camera.is_current():
		return false
	var center := at + Vector3.UP * VISUAL_EXTENTS.y
	var radius := VISUAL_EXTENTS.length()
	# The existing 30 m cull hides this whole envelope, regardless of camera yaw.
	if center.distance_to(player.global_position) - radius > visibility_radius:
		return true
	for plane in camera.get_frustum():
		if plane.distance_to(center) > radius:
			return true
	# Require every corner to be hidden by the SAME opaque convex box. A center-only
	# ray can hide the torso while letting the head/arms appear beside a pillar.
	var occluder: StaticBody3D
	var shape_index := -1
	for x in [-VISUAL_EXTENTS.x, VISUAL_EXTENTS.x]:
		for y in [-VISUAL_EXTENTS.y, VISUAL_EXTENTS.y]:
			for z in [-VISUAL_EXTENTS.z, VISUAL_EXTENTS.z]:
				var query := PhysicsRayQueryParameters3D.create(camera.global_position, center + Vector3(x, y, z), 1)
				query.exclude = [player.get_rid()]
				var hit := get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty() or not hit.collider is StaticBody3D:
					return false
				if occluder == null:
					occluder = hit.collider
					shape_index = hit.shape
					if not _opaque_box(occluder, shape_index):
						return false
				elif hit.collider != occluder or hit.shape != shape_index:
					return false
	return true

func _opaque_box(body: StaticBody3D, shape_index: int) -> bool:
	if not body.is_in_group("zombie_spawn_occluder"):
		return false
	var owner_id := body.shape_find_owner(shape_index)
	if not body.shape_owner_get_shape(owner_id, 0) is BoxShape3D:
		return false
	var collision := body.shape_owner_get_owner(owner_id) as CollisionShape3D
	if collision == null:
		return false
	for child in body.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.is_visible_in_tree() and child.global_position.distance_to(player.global_position) <= visibility_radius:
			if not child.transform.is_equal_approx(collision.transform) or not child.mesh.size.is_equal_approx(collision.shape.size):
				continue
			var material: Material = child.get_active_material(0)
			if material is BaseMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				return true
			# The global Pencil style converts opaque standard materials to shader
			# materials before the first physics tick. Tower ruins use an opaque
			# shader as well. Do not accept arbitrary shaders as visual cover.
			if material is ShaderMaterial and material.shader != null and (
					material.get_meta(&"_pencil_sketch_opaque_material", false)
					or Pencil.is_pencil(material)
					or material.shader.resource_path == "res://shaders/ruined_surface.gdshader"
			):
				return true
	return false
