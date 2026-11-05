extends Node3D
## Only new zombies enter this director. Living zombies are never repositioned.

signal spawn_requested(at: Vector3)
signal dormant_enemy_wake_requested(at: Vector3, health: int, kind: String)
signal attacker_slot_released(enemy: FoundationEnemy)
signal prepared_local_actor_requested
signal prepared_local_actor_activated(enemy: FoundationEnemy, at: Vector3)
signal local_group_activated

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
const MAX_ORDINARY_POPULATION := 20
const LOCAL_ATTACK_RADIUS_SQUARED := 4.0 * 4.0
const FORMATION_SPACING_SQUARED := 1.15 * 1.15
const LOCAL_GROUP_SIZE := 11
const LOCAL_POOL_SIZE := 14
const LOCAL_RADIUS := 4.0
const LOCAL_PLACEMENT_BUDGET := 8
const LOCAL_LANDING_TOLERANCE_SQUARED := 0.45 * 0.45
# Only unalerted, invisible actors can be stored as data (boss excluded).
const DORMANT_SLEEP_DISTANCE_SQUARED := 10.0 * 10.0
const DORMANT_WAKE_DISTANCE_SQUARED := 5.0 * 5.0
const DORMANT_SCAN_INTERVAL := 0.20
const MAX_DORMANT_CHANGES_PER_SCAN := 2
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
var population_limit := 4:
	set(value):
		population_limit = clampi(value, 0, MAX_ORDINARY_POPULATION)
var spawn_distance := 50.0
var initial_spawn_min_distance := INITIAL_SPAWN_MIN_DISTANCE
var initial_spawn_max_distance := INITIAL_SPAWN_MAX_DISTANCE
var visibility_radius := 30.0
var blocked_boxes: Array[AABB] = []
var last_candidate_count := 0
var last_spawn_count := 0
var _live: Dictionary = {}
var _stored_population: Array[Dictionary] = []
var _dormant_population: Array[Dictionary] = []
var dormancy_enabled := true
var _dormant_scan_time := 0.0
var _ground_active := true
var _attackers: Dictionary = {}
var _formation_active := false
var _formation_roles: Dictionary = {}
var _formation_targets: Dictionary = {}
var _pending: Array[float] = []
var _initial_population_pending := 0
var _initial_sample_index := 0
var _recent: Array[Dictionary] = []
var _clock := 0.0
var _retry_time := 0.0
var _sample_index := 0
var _capsule := CapsuleShape3D.new()
var _formation_capsule := CapsuleShape3D.new()
var _mobile_spawn_cooldown := 0.0
var _prepared_local: Array[FoundationEnemy] = []
var _local_pool_reservations := 0
var _skip_preparation_through_frame := -1
var _local_members: Dictionary = {}
var _initial_horde_activated := false
var _local_reinforcement_pending := false
var _local_reinforcement_delay := 0.0
var _jump_preparing := false
var _jump_blocked := false
var _jump_origin := Vector3.ZERO
var _jump_direction := Vector3.ZERO
var _jump_predicted_at := Vector3.ZERO
var _jump_desired: Array[Vector3] = []
var _jump_candidates: Array[Vector3] = []
var _jump_ordered: Array[Vector3] = []
var _jump_slots: Array[Vector3] = []
var _jump_slot_index := 0
var _jump_candidate_index := 0
# Tunable ordinary-zombie policy; the population and placement checks below
# remain authoritative even when an encounter Director requests more pressure.
var director_attacker_target := MAX_PLAYER_ATTACKERS
var director_replacement_delay := REPLACEMENT_SECONDS
var director_flank_bias := 0.0

func _ready() -> void:
	set_process(false)

func _init() -> void:
	_capsule.radius = 0.55
	_capsule.height = 1.95
	_formation_capsule.radius = 0.5
	_formation_capsule.height = 1.9

func store_upstairs_population(count: int) -> void:
	# Only data remains upstairs. The arena removes the actors before this reset.
	_ground_active = false
	set_physics_process(false)
	reset_local_horde()
	_live.clear()
	_attackers.clear()
	clear_local_formation()
	_pending.clear()
	_initial_population_pending = 0
	_recent.clear()
	_retry_time = 0.0
	_mobile_spawn_cooldown = 0.0
	_stored_population.clear()
	_dormant_population.clear()
	_dormant_scan_time = 0.0
	dormancy_enabled = true
	reset_director_policy()
	population_limit = count
	for index in range(population_limit):
		_stored_population.append({"kind": "shambler"})

func activate_ground_population(cap: int) -> void:
	if _ground_active:
		return
	# Consume the four stored entries, preserving the full ground capacity.
	var opening_count := mini(_stored_population.size(), cap)
	_stored_population.clear()
	population_limit = cap
	_initial_population_pending = opening_count
	dormancy_enabled = true
	_ground_active = true
	set_physics_process(true)

func activate_profiling_population(cap: int) -> void:
	reset_local_horde()
	_stored_population.clear()
	_dormant_population.clear()
	dormancy_enabled = false # Profiling still measures the full active load.
	reset_director_policy()
	population_limit = cap
	_ground_active = true
	set_physics_process(true)

func ordinary_population_count() -> int:
	if not _ground_active:
		return _stored_population.size() + _prepared_local.size() + _local_pool_reservations
	var living := 0
	for enemy in _live.values():
		if is_instance_valid(enemy) and enemy.hp > 0:
			living += 1
	return living + _dormant_population.size() + _prepared_local.size() + _local_pool_reservations

func dormant_population_count() -> int:
	return _dormant_population.size() if _ground_active else 0

func get_dormant_visual_records() -> Array[Dictionary]:
	# Read-only reference for the existing MultiMesh render queue. No zombie
	# actor, AI, animation player or collision is created for these records.
	return _dormant_population if _ground_active and dormancy_enabled else []

func request_initial_population() -> void:
	if not _ground_active:
		return
	while _population_claims() < population_limit:
		_initial_population_pending += 1

func request_population() -> void:
	if not _ground_active:
		return
	while _population_claims() < population_limit:
		_queue_birth(_clock)

func request_reinforcements(count: int) -> void:
	if not _ground_active:
		return
	var available := maxi(0, population_limit - _population_claims())
	for index in mini(maxi(0, count), available):
		_queue_birth(_clock + director_replacement_delay)

func reset_director_policy() -> void:
	director_attacker_target = MAX_PLAYER_ATTACKERS
	director_replacement_delay = REPLACEMENT_SECONDS
	director_flank_bias = 0.0

func _queue_birth(when: float) -> void:
	# Changed pacing can place a new reservation before an older one. Keep the
	# queue ordered so a later deadline never blocks a ready reinforcement.
	var index := _pending.size()
	while index > 0 and _pending[index - 1] > when:
		index -= 1
	_pending.insert(index, when)


# Every reserved birth, sleeping record and pooled actor consumes one global slot.
func _population_claims() -> int:
	return _occupied_population_count() + _pending.size() + _initial_population_pending

func _occupied_population_count() -> int:
	return _live.size() + _dormant_population.size() + _prepared_local.size() + _local_pool_reservations

func register_enemy(enemy: FoundationEnemy) -> void:
	if not _ground_active or enemy.is_boss or _live.has(enemy.get_instance_id()) or _population_claims() >= population_limit:
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
		if enemy.state == "limb_hold":
			enemy.release_limb_grab(player)
		elif enemy.state == "limb_grab_windup":
			enemy.cancel_limb_grab_windup(player)
		enemy.attack_director = null
	_attackers.erase(id)
	_formation_roles.erase(id)
	_formation_targets.erase(id)
	_live.erase(id)
	var was_local := _local_members.erase(id)
	if _ground_active and _local_reinforcement_pending and _prepared_local.is_empty() and _local_pool_reservations == 0 and _population_claims() < population_limit:
		_local_pool_reservations = 1
		set_process(true)
	if _ground_active and not was_local:
		# Pending births reserve slots. A death at the cap therefore adds one;
		# a death in the opening group can add both requested replacements.
		var available := maxi(0, population_limit - _population_claims())
		for index in range(mini(replacements, available)):
			_queue_birth(_clock + director_replacement_delay)

# No scene node, animator, AI or physics is retained for a dormant entry.
# A living zombie returns to the SAME previously occupied offscreen position.
func _update_dormant_population(delta: float) -> void:
	_dormant_scan_time += delta
	if _dormant_scan_time < DORMANT_SCAN_INTERVAL:
		return
	_dormant_scan_time = 0.0
	if not _ground_active or not dormancy_enabled or not is_instance_valid(player):
		return
	var changes := 0
	for index in range(_dormant_population.size() - 1, -1, -1):
		var entry := _dormant_population[index]
		var previous_position: Vector3 = entry["position"]
		if previous_position.distance_squared_to(player.global_position) > DORMANT_WAKE_DISTANCE_SQUARED:
			continue
		_dormant_population.remove_at(index)
		# The gameplay callback must register the restored node synchronously.
		dormant_enemy_wake_requested.emit(previous_position, int(entry["hp"]), String(entry["kind"]))
		changes += 1
		if changes >= MAX_DORMANT_CHANGES_PER_SCAN:
			return
	for item in _live.values():
		var enemy := item as FoundationEnemy
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0 or enemy.is_boss:
			continue
		if enemy._spawn_assault_time > 0.0 or enemy._player_grapple_time > 0.0:
			continue
		if enemy._valid_target() or enemy.state in ["windup", "hit", "recovery"]:
			continue
		if enemy.global_position.distance_squared_to(player.global_position) <= DORMANT_SLEEP_DISTANCE_SQUARED:
			continue
		# Return unused animation rigs to the shared pool before sleep.
		# Pursuers, active attacks and enemies with valid targets are exempt.
		if enemy._model != null or enemy._full_animation_selected:
			enemy._set_full_animation_selected(false)
		var id := enemy.get_instance_id()
		_dormant_population.append({
			"position": enemy.global_position,
			"hp": enemy.hp,
			"kind": enemy.enemy_variant,
			"facing_y": enemy.rotation.y,
			"visual_id": enemy.get_instance_id(),
		})
		_live.erase(id)
		_local_members.erase(id)
		_attackers.erase(id)
		_formation_roles.erase(id)
		_formation_targets.erase(id)
		enemy.attack_director = null
		enemy.visible = false
		enemy.set_physics_process(false)
		enemy.collision_layer = 0
		enemy.collision_mask = 0
		# Queue-free is not a death; exiting cannot request replacements.
		enemy.queue_free()
		changes += 1
		if changes >= MAX_DORMANT_CHANGES_PER_SCAN:
			break



# Reserve all fourteen slots before preparing actors. Three stay pooled after
# the first eleven join the fight, so the first promotions have ready replacements.
func begin_local_pool_preparation() -> void:
	if _initial_horde_activated or _local_pool_reservations > 0 or not _prepared_local.is_empty():
		return
	var capacity := MAX_ORDINARY_POPULATION if not _ground_active else population_limit
	var claimed := _population_claims() + (_stored_population.size() if not _ground_active else 0)
	_local_pool_reservations = mini(LOCAL_POOL_SIZE, maxi(0, capacity - claimed))
	if _local_pool_reservations > 0:
		set_process(true)

func register_prepared_local_enemy(enemy: FoundationEnemy) -> void:
	if _local_pool_reservations <= 0 or not is_instance_valid(enemy) or enemy.is_boss:
		return
	_local_pool_reservations -= 1
	_prepared_local.append(enemy)
	if _local_pool_reservations == 0:
		set_process(false)

func reset_local_horde() -> void:
	set_process(false)
	for enemy in _prepared_local:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_prepared_local.clear()
	_local_pool_reservations = 0
	_local_members.clear()
	_initial_horde_activated = false
	_local_reinforcement_pending = false
	_local_reinforcement_delay = 0.0
	_discard_jump_plan()

func _process(_delta: float) -> void:
	if Engine.get_physics_frames() <= _skip_preparation_through_frame:
		return
	if _local_pool_reservations > 0:
		# The arena constructs one lightweight, disabled actor per render frame.
		# No GLB rig is attached to a prepared actor.
		prepared_local_actor_requested.emit()

func on_parabolic_jump_started(takeoff: Vector3, direction: Vector3) -> void:
	if not _ground_active or not dormancy_enabled or _initial_horde_activated:
		return
	_discard_jump_plan()
	_jump_preparing = true
	_jump_origin = takeoff
	_jump_direction = direction.normalized()
	_jump_predicted_at = takeoff + _jump_direction * player.forward_jump_distance_m
	var landing_ray := PhysicsRayQueryParameters3D.create(
		_jump_predicted_at + Vector3.UP * 6.0,
		_jump_predicted_at - Vector3.UP * 8.0, 1
	)
	landing_ray.exclude = [player.get_rid()]
	var landing_ground := get_world_3d().direct_space_state.intersect_ray(landing_ray)
	if not landing_ground.is_empty() and landing_ground.normal.dot(Vector3.UP) >= 0.85:
		_jump_predicted_at.y = landing_ground.position.y + 0.05
	var rear := -_jump_direction
	for angle in [-75.0, -25.0, 25.0, 75.0]:
		_jump_desired.append(rear.rotated(Vector3.UP, deg_to_rad(angle)) * 2.15)
	for angle in [-80.0, -53.0, -27.0, 0.0, 27.0, 53.0, 80.0]:
		_jump_desired.append(rear.rotated(Vector3.UP, deg_to_rad(angle)) * 3.6)
	_jump_candidates.append_array(_jump_desired)
	for radius in [2.15, 3.1, 3.8]:
		for index in range(13):
			_jump_candidates.append(rear.rotated(Vector3.UP, deg_to_rad(-84.0 + 14.0 * float(index))) * radius)
	_order_jump_candidates()

func _discard_jump_plan() -> void:
	_jump_preparing = false
	_jump_blocked = false
	_jump_desired.clear()
	_jump_candidates.clear()
	_jump_ordered.clear()
	_jump_slots.clear()
	_jump_slot_index = 0
	_jump_candidate_index = 0

func _order_jump_candidates() -> void:
	if _jump_slot_index >= LOCAL_GROUP_SIZE:
		return
	var desired := _jump_desired[_jump_slot_index]
	_jump_ordered = _jump_candidates.duplicate()
	_jump_ordered.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return a.distance_squared_to(desired) < b.distance_squared_to(desired)
	)
	_jump_candidate_index = 0

func _prepare_jump_positions() -> void:
	if not _jump_preparing or _jump_blocked or _jump_slot_index >= LOCAL_GROUP_SIZE:
		return
	# Spread expensive ground, obstacle and optional navigation checks over
	# the airborne physics ticks. A blocked slot never causes a landing burst.
	for unused in range(LOCAL_PLACEMENT_BUDGET):
		if _jump_candidate_index >= _jump_ordered.size():
			return
		var raw := _jump_predicted_at + _jump_ordered[_jump_candidate_index]
		_jump_candidate_index += 1
		var at := _safe_local_birth_position(raw, _jump_predicted_at, _jump_slots)
		if at.is_finite():
			_jump_slots.append(at)
			_jump_slot_index += 1
			_order_jump_candidates()
			if _jump_slot_index >= LOCAL_GROUP_SIZE:
				return

func _safe_local_birth_position(raw: Vector3, center: Vector3, occupied: Array[Vector3]) -> Vector3:
	if absf(raw.x) > WORLD_LIMIT or absf(raw.z) > WORLD_LIMIT:
		return Vector3.INF
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(raw.x, center.y + 6.0, raw.z),
		Vector3(raw.x, minf(-8.0, center.y - 8.0), raw.z), 1
	)
	ray.exclude = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85:
		return Vector3.INF
	var at: Vector3 = hit.position + Vector3.UP * 0.05
	if absf(at.y - center.y) > 1.0 or not _local_spacing_clear(at, center, occupied):
		return Vector3.INF
	var envelope := AABB(at + Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.95, 1.0))
	for box in blocked_boxes:
		if box.intersects(envelope):
			return Vector3.INF
	if not _local_body_clear(at, true):
		return Vector3.INF
	var nav_map := get_world_3d().navigation_map
	if not NavigationServer3D.map_get_regions(nav_map).is_empty():
		if NavigationServer3D.map_get_closest_point(nav_map, at).distance_to(at) > 0.75:
			return Vector3.INF
		var route := NavigationServer3D.map_get_path(nav_map, at, center, true)
		if route.size() < 2 or route[0].distance_to(at) > 0.75 or route[route.size() - 1].distance_to(center) > 1.0:
			return Vector3.INF
	else:
		var travel := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.85, center + Vector3.UP * 0.85, 1 | 4)
		travel.exclude = [player.get_rid()]
		if not space.intersect_ray(travel).is_empty():
			return Vector3.INF
	return at

func _local_spacing_clear(at: Vector3, center: Vector3, occupied: Array[Vector3]) -> bool:
	var offset := at - center
	offset.y = 0.0
	if offset.length_squared() > LOCAL_RADIUS * LOCAL_RADIUS or offset.length_squared() < 1.35 * 1.35:
		return false
	for other in occupied:
		var spacing := at - other
		spacing.y = 0.0
		if spacing.length_squared() < FORMATION_SPACING_SQUARED:
			return false
	return true

func _local_body_clear(at: Vector3, exclude_player: bool) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _formation_capsule
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
	query.collision_mask = 1 | 2 | 4
	query.collide_with_areas = true
	if exclude_player:
		query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func on_parabolic_jump_landed(at: Vector3, direction: Vector3) -> void:
	_skip_preparation_through_frame = Engine.get_physics_frames()
	if not _jump_preparing:
		return
	var displacement := at - _jump_origin
	displacement.y = 0.0
	var predicted_error := at - _jump_predicted_at
	predicted_error.y = 0.0
	var valid := not _jump_blocked and not player.is_on_wall() and displacement.dot(_jump_direction) > 0.5 * player.forward_jump_distance_m
	valid = valid and direction.dot(_jump_direction) > 0.99 and predicted_error.length_squared() <= LOCAL_LANDING_TOLERANCE_SQUARED
	valid = valid and absf(at.y - _jump_predicted_at.y) <= 0.7
	# Existing ordinary zombies are already moving through the encounter. Use
	# them as local members and fill only the missing positions to eleven.
	var existing := _nearby_living_count(at, 6.0)
	var needed := maxi(0, LOCAL_GROUP_SIZE - existing)
	valid = valid and existing <= BijatykaAIDirector.LOCAL_LIVING_LIMIT
	valid = valid and _jump_slots.size() >= needed and _prepared_local.size() >= needed
	if not valid:
		_discard_jump_plan()
		return
	# Static floor/path checks were spread across the flight. Recheck only the
	# dynamic capsules against the actual landed player and moving enemies.
	var no_occupied: Array[Vector3] = []
	for index in range(needed):
		var point := _jump_slots[index]
		var behind := point - at
		behind.y = 0.0
		if behind.dot(_jump_direction) >= 0.0 or not _local_spacing_clear(point, at, no_occupied) or not _local_body_clear(point, false):
			_discard_jump_plan()
			return
	for index in range(needed):
		if not is_instance_valid(_prepared_local[index]) or _prepared_local[index].is_queued_for_deletion():
			_discard_jump_plan()
			return
	# Arm the one-shot guard before the synchronous activation callbacks.
	_initial_horde_activated = true
	_jump_preparing = false
	for index in range(needed):
		_activate_prepared_local(_jump_slots[index])
	_discard_jump_plan()
	local_group_activated.emit()

func _nearby_living_count(at: Vector3, radius: float = LOCAL_RADIUS) -> int:
	var total := 0
	for item in _live.values():
		var enemy := item as FoundationEnemy
		if is_instance_valid(enemy) and enemy.hp > 0:
			var offset := enemy.global_position - at
			offset.y = 0.0
			if offset.length_squared() <= radius * radius:
				total += 1
	return total

func _activate_prepared_local(at: Vector3) -> void:
	if _prepared_local.is_empty():
		return
	var enemy: FoundationEnemy = _prepared_local.pop_front()
	prepared_local_actor_activated.emit(enemy, at)
	if _live.has(enemy.get_instance_id()):
		_local_members[enemy.get_instance_id()] = true
	else:
		_prepared_local.push_front(enemy)

func request_local_reinforcement(_missing: int, current_local_count: int) -> void:
	if not _initial_horde_activated or _local_reinforcement_pending or current_local_count >= BijatykaAIDirector.LOCAL_LIVING_LIMIT:
		return
	if _local_members.size() >= BijatykaAIDirector.LOCAL_LIVING_LIMIT or _nearby_living_count(player.global_position) >= BijatykaAIDirector.LOCAL_LIVING_LIMIT:
		return
	_local_reinforcement_pending = true
	_local_reinforcement_delay = director_replacement_delay
	if _prepared_local.is_empty() and _population_claims() < population_limit:
		_local_pool_reservations = 1
		set_process(true)

func _update_local_reinforcement(delta: float) -> void:
	if not _local_reinforcement_pending:
		return
	_local_reinforcement_delay = maxf(0.0, _local_reinforcement_delay - delta)
	if _local_members.size() >= BijatykaAIDirector.LOCAL_LIVING_LIMIT or _nearby_living_count(player.global_position) >= BijatykaAIDirector.LOCAL_LIVING_LIMIT:
		_local_reinforcement_pending = false
		return
	if _prepared_local.is_empty() and _local_pool_reservations == 0 and _population_claims() < population_limit:
		_local_pool_reservations = 1
		set_process(true)
	if _local_reinforcement_delay > 0.0 or _prepared_local.is_empty():
		return
	var rear := -forward_direction()
	var candidates: Array[Vector3] = [
		rear * 3.65, rear.rotated(Vector3.UP, 0.4) * 3.65,
		rear.rotated(Vector3.UP, -0.4) * 3.65,
		rear.rotated(Vector3.UP, 0.8) * 3.65,
		rear.rotated(Vector3.UP, -0.8) * 3.65,
	]
	var no_occupied: Array[Vector3] = []
	for offset in candidates:
		var point := _safe_local_birth_position(player.global_position + offset, player.global_position, no_occupied)
		if point.is_finite():
			_local_reinforcement_pending = false
			_activate_prepared_local(point)
			local_group_activated.emit()
			return
	_local_reinforcement_delay = RETRY_SECONDS

func set_local_formation(roles: Dictionary, targets: Dictionary) -> void:
	# The local Director supplies admission and goals; this existing manager
	# remains the only owner of attack locks and global population.
	_formation_roles = roles
	_formation_targets = targets
	_formation_active = true
	_release_unadmitted_grabs()
	# Only admitted local actors collide with other zombie bodies. This keeps
	# moving reserves from passing through an occupied attack position.
	for id in _live:
		var enemy := _live[id] as FoundationEnemy
		if is_instance_valid(enemy) and enemy.hp > 0:
			var mask := enemy.collision_mask | 2 if roles.has(id) else enemy.collision_mask & ~2
			if enemy.collision_mask != mask:
				enemy.collision_mask = mask

func clear_local_formation() -> void:
	_formation_active = false
	_release_unadmitted_grabs()
	_formation_roles.clear()
	_formation_targets.clear()
	for item in _live.values():
		var enemy := item as FoundationEnemy
		if is_instance_valid(enemy) and enemy.hp > 0:
			enemy.collision_mask &= ~2

func _release_unadmitted_grabs() -> void:
	# Four locked attackers at most; release as soon as a role or encounter ends.
	for id in _attackers.keys():
		var enemy := _live.get(id) as FoundationEnemy
		if not is_instance_valid(enemy) or can_maintain_limb_grab(enemy):
			continue
		if enemy.state == "limb_hold":
			enemy.release_limb_grab(player)
		elif enemy.state == "limb_grab_windup":
			enemy.cancel_limb_grab_windup(player)

func is_local_formation_active() -> bool:
	return _formation_active

func formation_role_for(enemy: FoundationEnemy) -> String:
	return String(_formation_roles.get(enemy.get_instance_id(), "")) if _formation_active else ""

func formation_target_for(enemy: FoundationEnemy) -> Vector3:
	return _formation_targets.get(enemy.get_instance_id(), Vector3.INF) if _formation_active else Vector3.INF

func safe_formation_position(raw: Vector3, enemy: FoundationEnemy,
		occupied: Array[Vector3], zone_radius: float) -> Vector3:
	# Formation is close and visible, so the concealed-birth tests are not used.
	# Reuse their ground, static-collision, blockers and optional navigation rules.
	if not is_instance_valid(player) or not is_instance_valid(enemy):
		return Vector3.INF
	if absf(raw.x) > WORLD_LIMIT or absf(raw.z) > WORLD_LIMIT:
		return Vector3.INF
	var ray := PhysicsRayQueryParameters3D.create(
		Vector3(raw.x, player.global_position.y + 6.0, raw.z),
		Vector3(raw.x, minf(-8.0, player.global_position.y - 8.0), raw.z), 1
	)
	ray.exclude = [player.get_rid(), enemy.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < 0.85:
		return Vector3.INF
	var at: Vector3 = hit.position + Vector3.UP * 0.05
	var offset := at - player.global_position
	offset.y = 0.0
	if offset.length_squared() > zone_radius * zone_radius or offset.length_squared() < 1.15 * 1.15:
		return Vector3.INF
	for goal in occupied:
		var spacing := at - goal
		spacing.y = 0.0
		if spacing.length_squared() < FORMATION_SPACING_SQUARED:
			return Vector3.INF
	var envelope := AABB(at + Vector3(-0.5, 0.0, -0.5), Vector3(1.0, 1.95, 1.0))
	for box in blocked_boxes:
		if box.intersects(envelope):
			return Vector3.INF
	# A slot may be occupied while its previous attacker walks to reserve.
	# Planned goals are separated above; local body collisions keep the actual
	# handoff from overlapping as both actors move.
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = _formation_capsule
	shape_query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * 1.0)
	shape_query.collision_mask = 1 | 4
	shape_query.collide_with_areas = true
	shape_query.exclude = [player.get_rid(), enemy.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(shape_query, 1).is_empty():
		return Vector3.INF
	var nav_map := get_world_3d().navigation_map
	if not NavigationServer3D.map_get_regions(nav_map).is_empty():
		if NavigationServer3D.map_get_closest_point(nav_map, at).distance_to(at) > 0.75:
			return Vector3.INF
		var route := NavigationServer3D.map_get_path(nav_map, enemy.global_position, at, true)
		if route.size() < 2 or route[0].distance_to(enemy.global_position) > 0.75 or route[route.size() - 1].distance_to(at) > 0.75:
			return Vector3.INF
	else:
		var travel := PhysicsRayQueryParameters3D.create(
			enemy.global_position + Vector3.UP * 0.85, at + Vector3.UP * 0.85, 1 | 4
		)
		travel.exclude = [enemy.get_rid(), player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(travel).is_empty():
			return Vector3.INF
	return at

func try_acquire_attacker(enemy: FoundationEnemy) -> bool:
	var id := enemy.get_instance_id()
	if not _ground_active or enemy.hp <= 0 or not _live.has(id):
		return false
	if _formation_active:
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		if formation_role_for(enemy) != "attacker" or offset.length_squared() > LOCAL_ATTACK_RADIUS_SQUARED:
			return false
	if _attackers.has(id):
		return true
	if _attackers.size() >= mini(MAX_PLAYER_ATTACKERS, director_attacker_target):
		return false
	_attackers[id] = true
	return true

func can_resolve_player_attack(enemy: FoundationEnemy) -> bool:
	if not _formation_active:
		return true
	if not _attackers.has(enemy.get_instance_id()) or formation_role_for(enemy) != "attacker":
		return false
	var offset := enemy.global_position - player.global_position
	offset.y = 0.0
	return offset.length_squared() <= LOCAL_ATTACK_RADIUS_SQUARED

# A hold keeps its original attack lock and remains inside the local ring.
func can_maintain_limb_grab(enemy: FoundationEnemy) -> bool:
	if not _ground_active or not _formation_active or not is_instance_valid(player) or not is_instance_valid(enemy):
		return false
	var id := enemy.get_instance_id()
	if enemy.hp <= 0 or not _live.has(id) or not _attackers.has(id) or formation_role_for(enemy) != "attacker":
		return false
	var offset := enemy.global_position - player.global_position
	offset.y = 0.0
	return offset.length_squared() <= LOCAL_ATTACK_RADIUS_SQUARED

func release_attacker(enemy: FoundationEnemy) -> void:
	if _attackers.erase(enemy.get_instance_id()):
		attacker_slot_released.emit(enemy)

func _physics_process(delta: float) -> void:
	if not _ground_active:
		return
	_clock += delta
	if _jump_preparing:
		_jump_blocked = _jump_blocked or player.is_on_wall()
		_prepare_jump_positions()
	_update_local_reinforcement(delta)
	_update_dormant_population(delta)
	_retry_time = maxf(0.0, _retry_time - delta)
	last_candidate_count = 0
	last_spawn_count = 0
	var mobile_budget_enabled := OS.has_feature("mobile")
	if mobile_budget_enabled:
		_mobile_spawn_cooldown = maxf(0.0, _mobile_spawn_cooldown - delta)
	if not is_instance_valid(player) or not is_instance_valid(camera):
		return
	if _retry_time > 0.0 or (_pending.is_empty() and _initial_population_pending <= 0) or _occupied_population_count() >= population_limit:
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
		if _occupied_population_count() >= population_limit:
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
	var angle := clampf(lerpf(-FORWARD_HALF_ANGLE, FORWARD_HALF_ANGLE, fmod(float(_sample_index) * 0.61803398875, 1.0)) + director_flank_bias, -FORWARD_HALF_ANGLE, FORWARD_HALF_ANGLE)
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
