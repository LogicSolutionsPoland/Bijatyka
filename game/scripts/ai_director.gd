extends Node
class_name BijatykaAIDirector

## Offline encounter pacing and local formation. ConcealedForwardSpawns remains
## the sole owner of ordinary population, birth reservations and attack locks.
signal local_reinforcement_requested(missing: int)

enum State { PRESSURE, SURGE, PEAK, FRENZY }

const EVALUATION_SECONDS := 1.0
const NEARBY_DISTANCE_SQUARED := 18.0 * 18.0
const KILL_WINDOW_SECONDS := 6
const LOCAL_RADIUS := 4.0
const LOCAL_LIVING_LIMIT := 14
const ATTACKER_COUNT := 4
const RESERVE_COUNT := 7
const FORMATION_INTERVAL := 0.25
const ADMISSION_RADIUS_SQUARED := 6.0 * 6.0
const ATTACKER_RING_RADIUS := 1.55
const RESERVE_RING_RADIUS := 3.1
const PERIMETER_RING_RADIUS := 3.7
const ROTATION_COOLDOWN := 1.25

var player: FoundationPlayer
var spawns
var boss: FoundationEnemy
var state := State.PRESSURE
var intensity := 0.0
var active := false
var nearby_count := 0
var evaluation_count := 0
var local_living_count := 0
var attacker_role_count := 0
var reserve_role_count := 0

var _timer: Timer
var _formation_timer: Timer
var _rotation_cooldowns: Dictionary = {}
var _last_requested_deficit := -1
var _last_formation_time := -INF
var _last_player_at := Vector3.INF
var _last_forward := Vector3.ZERO
var _last_roster: Array[int] = []
var _formation_dirty := true
var _random := RandomNumberGenerator.new()
var _state_remaining := 0.0
var _damage_frenzy_seconds := 0.0
var _quiet_seconds := 0.0
var _recent_damage := 0.0
var _last_health := 0
var _kills: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0])
var _kill_bucket := 0

func configure(game_player: FoundationPlayer, spawn_manager) -> void:
	player = game_player
	spawns = spawn_manager
	_last_health = player.health
	player.health_changed.connect(_on_health_changed)
	player.attack_connected.connect(_on_player_hit)
	player.respawned.connect(deactivate)
	spawns.attacker_slot_released.connect(_on_attacker_slot_released)
	_random.seed = 0xB1A7A # Local reproducible variation; no network or inference.

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = EVALUATION_SECONDS
	_timer.timeout.connect(_evaluate)
	add_child(_timer)
	_formation_timer = Timer.new()
	_formation_timer.wait_time = FORMATION_INTERVAL
	_formation_timer.timeout.connect(_refresh_formation)
	add_child(_formation_timer)

func activate() -> void:
	if active or not is_instance_valid(spawns) or not spawns._ground_active:
		return
	active = true
	state = State.PRESSURE
	intensity = 0.0
	_nearby_reset()
	_last_health = player.health
	_apply_policy()
	_formation_dirty = true
	_refresh_formation()
	_timer.start()
	_formation_timer.start()

func deactivate() -> void:
	active = false
	if is_instance_valid(_timer):
		_timer.stop()
	if is_instance_valid(_formation_timer):
		_formation_timer.stop()
	_rotation_cooldowns.clear()
	_last_roster.clear()
	_last_player_at = Vector3.INF
	_last_formation_time = -INF
	_formation_dirty = true
	_last_requested_deficit = -1
	local_living_count = 0
	attacker_role_count = 0
	reserve_role_count = 0
	_nearby_reset()
	state = State.PRESSURE
	intensity = 0.0
	if is_instance_valid(spawns):
		spawns.clear_local_formation()
		spawns.reset_director_policy()

func _nearby_reset() -> void:
	_nearby_reset_counters()
	_state_remaining = 0.0
	_damage_frenzy_seconds = 0.0
	_quiet_seconds = 0.0
	_recent_damage = 0.0
	_kill_bucket = 0
	for index in KILL_WINDOW_SECONDS:
		_kills[index] = 0

func _nearby_reset_counters() -> void:
	nearby_count = 0
	evaluation_count = 0

func _on_health_changed(current: int, _maximum: int) -> void:
	if active and current < _last_health:
		_recent_damage = minf(100.0, _recent_damage + float(_last_health - current))
		_damage_frenzy_seconds = maxf(_damage_frenzy_seconds, 4.0)
		_quiet_seconds = 0.0
		_evaluate(false)
	_last_health = current

func _on_player_hit(_kind: String, _target: Node) -> void:
	if active:
		_quiet_seconds = 0.0

func on_ordinary_defeated() -> void:
	if not active:
		return
	_formation_dirty = true
	_kills[_kill_bucket] += 1
	_quiet_seconds = 0.0
	_refresh_formation()
	_evaluate(false)

func _evaluate(advance_clock: bool = true) -> void:
	if not active or not is_instance_valid(player) or not is_instance_valid(spawns) or not spawns._ground_active:
		return
	if advance_clock:
		_quiet_seconds = minf(60.0, _quiet_seconds + EVALUATION_SECONDS)
		_state_remaining = maxf(0.0, _state_remaining - EVALUATION_SECONDS)
		_recent_damage *= 0.72
		_damage_frenzy_seconds = maxf(0.0, _damage_frenzy_seconds - EVALUATION_SECONDS)
		_kill_bucket = (_kill_bucket + 1) % KILL_WINDOW_SECONDS
		_kills[_kill_bucket] = 0
	var kills := 0
	for count in _kills:
		kills += count
	var left := 0
	var right := 0
	var forward: Vector3 = spawns.forward_direction()
	var right_axis := forward.cross(Vector3.UP)
	nearby_count = 0
	for id in spawns._live:
		var enemy: FoundationEnemy = spawns._live[id]
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			continue
		var offset := enemy.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= NEARBY_DISTANCE_SQUARED:
			nearby_count += 1
			if offset.dot(right_axis) < 0.0:
				left += 1
			else:
				right += 1
	var attackers: int = spawns._attackers.size()
	var health_fraction := float(player.health) / maxf(1.0, float(player.MAX_HEALTH))
	var movement := Vector2(player.velocity.x, player.velocity.z).length()
	intensity = clampf(
		0.23 * minf(1.0, float(nearby_count) / 5.0)
		+ 0.21 * minf(1.0, float(attackers) / 4.0)
		+ 0.23 * minf(1.0, _recent_damage / 40.0)
		+ 0.18 * minf(1.0, float(kills) / 4.0)
		+ 0.08 * minf(1.0, movement / 5.0)
		+ 0.07 * (1.0 - health_fraction), 0.0, 1.0)
	evaluation_count += 1
	# Taking damage makes the pack more dangerous for several seconds instead
	# of granting a respite. Quiet combat creates a surge; quick kills trigger PEAK.
	if _damage_frenzy_seconds > 0.0:
		if state != State.FRENZY:
			_set_state(State.FRENZY, 3.0, 4.0)
	elif state == State.FRENZY or _state_remaining <= 0.0 or (kills >= 3 and intensity >= 0.36 and state != State.PEAK):
		if kills >= 3 and intensity >= 0.36:
			_set_state(State.PEAK, 3.0, 5.0)
		elif (_quiet_seconds >= 6.0 and nearby_count <= 2) or (intensity < 0.22 and _quiet_seconds >= 4.0):
			_set_state(State.SURGE, 3.0, 5.0)
		else:
			_set_state(State.PRESSURE, 2.0, 3.5)
	# Never alter boss attack logic or its damage. Direct only ordinary slots.
	spawns.director_flank_bias = 0.42 if left < right else (-0.42 if right < left else 0.0)
	_apply_policy()
	# Stage 4 may subscribe to local_reinforcement_requested. Formation never
	# queues a birth or instantiates an actor.

func _set_state(next_state: int, shortest: float, longest: float) -> void:
	state = next_state
	_state_remaining = _random.randf_range(shortest, longest)

func _apply_policy() -> void:
	if not active or not is_instance_valid(spawns):
		return
	match state:
		State.PRESSURE:
			spawns.director_attacker_target = 4
			spawns.director_replacement_delay = 1.0
		State.SURGE:
			spawns.director_attacker_target = 4
			spawns.director_replacement_delay = 0.8
		State.PEAK:
			spawns.director_attacker_target = 4
			spawns.director_replacement_delay = 0.65
		State.FRENZY:
			spawns.director_attacker_target = 4
			spawns.director_replacement_delay = 0.55

func _on_attacker_slot_released(enemy: FoundationEnemy) -> void:
	if not active or not is_instance_valid(enemy):
		return
	_rotation_cooldowns[enemy.get_instance_id()] = Time.get_ticks_msec() * 0.001 + ROTATION_COOLDOWN
	_formation_dirty = true
	# The release may happen during an attack or hit callback; read the final
	# enemy state after that callback completes.
	call_deferred("_refresh_formation")

func _closer(a: Dictionary, b: Dictionary) -> bool:
	if is_equal_approx(float(a.distance), float(b.distance)):
		return int(a.id) < int(b.id)
	return float(a.distance) < float(b.distance)

func _attacker_rank(entry: Dictionary, now: float) -> int:
	var id: int = entry.id
	if spawns._attackers.has(id):
		return 0
	var old_role: String = spawns.formation_role_for(entry.enemy)
	if old_role == "attacker":
		return 4 if float(_rotation_cooldowns.get(id, 0.0)) > now else 1
	if old_role == "reserve":
		return 2
	return 3

func _refresh_formation() -> void:
	if not active or not is_instance_valid(player) or not is_instance_valid(spawns) or not spawns._ground_active:
		return
	var entries: Array[Dictionary] = []
	var player_at := player.global_position
	# The manager's bounded live map is already maintained by births, wake,
	# sleep and defeat. No scene group scan or per-enemy per-frame search.
	for id in spawns._live:
		var enemy: FoundationEnemy = spawns._live[id]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.hp <= 0:
			continue
		var offset := enemy.global_position - player_at
		offset.y = 0.0
		if offset.length_squared() <= ADMISSION_RADIUS_SQUARED:
			entries.append({"id": id, "enemy": enemy, "distance": offset.length_squared()})
	entries.sort_custom(_closer)
	var admitted: Array[Dictionary] = []
	for entry in entries:
		if admitted.size() >= LOCAL_LIVING_LIMIT:
			break
		admitted.append(entry)
	var now := Time.get_ticks_msec() * 0.001
	var roster: Array[int] = []
	for entry in admitted:
		roster.append(int(entry.id))
	var forward: Vector3 = spawns.forward_direction()
	var movement := player_at - _last_player_at
	movement.y = 0.0
	if not _formation_dirty and roster == _last_roster and movement.length_squared() < 0.25 * 0.25 and forward.dot(_last_forward) > 0.96 and now - _last_formation_time < 1.0:
		return
	_last_roster = roster
	_last_player_at = player_at
	_last_forward = forward
	_last_formation_time = now
	_formation_dirty = false
	for id in _rotation_cooldowns.keys():
		if float(_rotation_cooldowns[id]) <= now or not spawns._live.has(id):
			_rotation_cooldowns.erase(id)
	var ranked := admitted.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_rank := _attacker_rank(a, now)
		var b_rank := _attacker_rank(b, now)
		return _closer(a, b) if a_rank == b_rank else a_rank < b_rank
	)
	var attackers: Array[FoundationEnemy] = []
	for entry in ranked:
		if attackers.size() >= ATTACKER_COUNT:
			break
		attackers.append(entry.enemy)
	var reserves: Array[FoundationEnemy] = []
	var perimeter: Array[FoundationEnemy] = []
	for entry in admitted:
		var enemy: FoundationEnemy = entry.enemy
		if attackers.has(enemy):
			continue
		if reserves.size() < RESERVE_COUNT:
			reserves.append(enemy)
		else:
			perimeter.append(enemy)
	var roles: Dictionary = {}
	var targets: Dictionary = {}
	var occupied: Array[Vector3] = []
	_assign_ring(attackers, "attacker", ATTACKER_COUNT, ATTACKER_RING_RADIUS, forward, roles, targets, occupied)
	_assign_ring(reserves, "reserve", RESERVE_COUNT, RESERVE_RING_RADIUS, forward, roles, targets, occupied)
	_assign_ring(perimeter, "perimeter", 3, PERIMETER_RING_RADIUS, forward, roles, targets, occupied)
	var promoted_reserve := false
	for enemy in attackers:
		if spawns.formation_role_for(enemy) == "reserve":
			promoted_reserve = true
			break
	spawns.set_local_formation(roles, targets)
	local_living_count = roles.size()
	attacker_role_count = 0
	reserve_role_count = 0
	for role in roles.values():
		if role == "attacker":
			attacker_role_count += 1
		elif role == "reserve":
			reserve_role_count += 1
	var deficit := maxi(0, ATTACKER_COUNT + RESERVE_COUNT - attacker_role_count - reserve_role_count)
	if deficit != _last_requested_deficit:
		_last_requested_deficit = deficit
		if deficit > 0:
			local_reinforcement_requested.emit(deficit)
	elif promoted_reserve and local_living_count < LOCAL_LIVING_LIMIT:
		# A reserve taking an attack slot asks for one new back-line member.
		# The spawn owner coalesces requests while one is already pending.
		local_reinforcement_requested.emit(1)

func _assign_ring(members: Array[FoundationEnemy], role: String, slot_count: int,
		radius: float, forward: Vector3, roles: Dictionary, targets: Dictionary,
		occupied: Array[Vector3]) -> void:
	if members.is_empty():
		return
	var available: Array[FoundationEnemy] = members.duplicate()
	for slot in range(slot_count):
		if available.is_empty():
			break
		# The three optional perimeter positions sit between reserve slots.
		var angle := TAU * (float(slot * 2) + 0.5) / float(RESERVE_COUNT) if role == "perimeter" else TAU * float(slot) / float(slot_count)
		var raw := player.global_position + forward.rotated(Vector3.UP, angle) * radius
		var best_index := -1
		var best_distance := INF
		for index in range(available.size()):
			var distance := available[index].global_position.distance_squared_to(raw)
			if distance < best_distance:
				best_index = index
				best_distance = distance
		if best_index < 0:
			continue
		var enemy := available[best_index]
		var safe := Vector3.INF
		# Bounded alternatives accommodate a nearby wall without pathfinding
		# every physics frame or moving a living actor to a new position.
		for angle_offset in [0.0, -0.16, 0.16]:
			var candidate := player.global_position + forward.rotated(Vector3.UP, angle + angle_offset) * radius
			safe = spawns.safe_formation_position(candidate, enemy, occupied, LOCAL_RADIUS)
			if safe.is_finite():
				break
		if not safe.is_finite():
			continue
		var id := enemy.get_instance_id()
		roles[id] = role
		targets[id] = safe
		occupied.append(safe)
		available.remove_at(best_index)
