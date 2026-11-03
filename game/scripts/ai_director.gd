extends Node
class_name BijatykaAIDirector

## Offline encounter pacing. ConcealedForwardSpawns remains the sole owner of
## ordinary population, placement, replacement reservations and attacker slots.
enum State { PRESSURE, SURGE, PEAK, RECOVERY }

const EVALUATION_SECONDS := 1.0
const NEARBY_DISTANCE_SQUARED := 18.0 * 18.0
const KILL_WINDOW_SECONDS := 6

var player: FoundationPlayer
var spawns
var boss: FoundationEnemy
var state := State.PRESSURE
var intensity := 0.0
var active := false
var nearby_count := 0
var evaluation_count := 0

var _timer: Timer
var _random := RandomNumberGenerator.new()
var _state_remaining := 0.0
var _recovery_cooldown := 0.0
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
	_random.seed = 0xB1A7A # Local reproducible variation; no network or inference.

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = EVALUATION_SECONDS
	_timer.timeout.connect(_evaluate)
	add_child(_timer)

func activate() -> void:
	if active or not is_instance_valid(spawns) or not spawns._ground_active:
		return
	active = true
	state = State.PRESSURE
	intensity = 0.0
	_nearby_reset()
	_last_health = player.health
	_apply_policy()
	_timer.start()

func deactivate() -> void:
	active = false
	if is_instance_valid(_timer):
		_timer.stop()
	_nearby_reset()
	state = State.PRESSURE
	intensity = 0.0
	if is_instance_valid(spawns):
		spawns.reset_director_policy()

func _nearby_reset() -> void:
	_nearby_reset_counters()
	_state_remaining = 0.0
	_recovery_cooldown = 0.0
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
		_quiet_seconds = 0.0
		_evaluate(false)
	_last_health = current

func _on_player_hit(_kind: String, _target: Node) -> void:
	if active:
		_quiet_seconds = 0.0

func on_ordinary_defeated() -> void:
	if not active:
		return
	_kills[_kill_bucket] += 1
	_quiet_seconds = 0.0
	_evaluate(false)

func _evaluate(advance_clock: bool = true) -> void:
	if not active or not is_instance_valid(player) or not is_instance_valid(spawns) or not spawns._ground_active:
		return
	if advance_clock:
		_quiet_seconds = minf(60.0, _quiet_seconds + EVALUATION_SECONDS)
		_state_remaining = maxf(0.0, _state_remaining - EVALUATION_SECONDS)
		_recovery_cooldown = maxf(0.0, _recovery_cooldown - EVALUATION_SECONDS)
		_recent_damage *= 0.72
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
	var boss_engaged := is_instance_valid(boss) and boss.hp > 0 and boss.global_position.distance_squared_to(player.global_position) < 25.0 * 25.0
	intensity = clampf(
		0.23 * minf(1.0, float(nearby_count) / 5.0)
		+ 0.21 * minf(1.0, float(attackers) / 4.0)
		+ 0.23 * minf(1.0, _recent_damage / 40.0)
		+ 0.18 * minf(1.0, float(kills) / 4.0)
		+ 0.08 * minf(1.0, movement / 5.0)
		+ 0.07 * (1.0 - health_fraction), 0.0, 1.0)
	evaluation_count += 1
	# A short respite follows a damage spike. A quiet patch quickly promotes a
	# new surge; random ranges prevent a fixed-duration encounter loop.
	if _state_remaining <= 0.0 or (_recovery_cooldown <= 0.0 and _recent_damage >= 28.0 and state != State.RECOVERY) or (kills >= 3 and intensity >= 0.36 and state != State.PEAK):
		if _recovery_cooldown <= 0.0 and (_recent_damage >= 28.0 or health_fraction < 0.30 and intensity > 0.38):
			_set_state(State.RECOVERY, 2.0, 4.0)
			_recovery_cooldown = _random.randf_range(9.0, 14.0)
		elif kills >= 3 and intensity >= 0.36 and health_fraction >= 0.30:
			_set_state(State.PEAK, 3.0, 5.0)
		elif (_quiet_seconds >= 6.0 and nearby_count <= 2) or (intensity < 0.22 and _quiet_seconds >= 4.0):
			_set_state(State.SURGE, 3.0, 5.0)
		else:
			_set_state(State.PRESSURE, 2.0, 3.5)
	# Never alter boss attack logic or its damage. Direct only ordinary slots.
	spawns.director_flank_bias = 0.42 if left < right else (-0.42 if right < left else 0.0)
	_apply_policy()
	if advance_clock and _quiet_seconds >= 7.0 and nearby_count <= 2:
		var target := 4 if state == State.RECOVERY else (12 if state == State.PEAK else (10 if state == State.SURGE else 7))
		if boss_engaged:
			target = mini(target, 7)
		spawns.request_reinforcements(mini(2, maxi(0, target - spawns.ordinary_population_count())))

func _set_state(next_state: int, shortest: float, longest: float) -> void:
	state = next_state
	_state_remaining = _random.randf_range(shortest, longest)

func _apply_policy() -> void:
	if not active or not is_instance_valid(spawns):
		return
	match state:
		State.RECOVERY:
			spawns.director_attacker_target = 2
			spawns.director_replacement_delay = 1.4
		State.PRESSURE:
			spawns.director_attacker_target = 3
			spawns.director_replacement_delay = 1.0
		State.SURGE:
			spawns.director_attacker_target = 4
			spawns.director_replacement_delay = 0.8
		State.PEAK:
			spawns.director_attacker_target = 4
			spawns.director_replacement_delay = 0.65
