extends CharacterBody3D
class_name FoundationPlayer

signal attack_started(kind: String)
signal attack_connected(kind: String, target: Node)
signal attack_finished(kind: String)
signal health_changed(current: int, maximum: int)
signal magic_changed(current: float, maximum: float, school: String)
signal interrupted(duration: float)
signal jump_impact(target: Node)

const RAGE_SCRIPT := preload("res://scripts/rage_progression.gd")
const FIGHT_ANIMATION_BUILDER := preload("res://scripts/universal_base_combat.gd")
const CHARACTER_MOTION := preload("res://scripts/universal_base_motion.gd")
const PLAYER_MODEL_PATH := "res://assets/characters/universal_base/Universal_Base_Characters_Male.glb"
const GRAVITY := 24.0
const MAX_HEALTH := 100
const MAX_MAGIC := 100.0
const DASH_DISTANCE := 15.0
const DASH_DURATION := 0.30
const TARGET_MELEE_HITS_PER_SECOND := 5.0
const TARGET_MELEE_CYCLE_SECONDS := 1.0 / TARGET_MELEE_HITS_PER_SECOND
const MELEE_TIMER_EPSILON := 0.0001
const ATTACK_ANIMATION_BLEND_SECONDS := 0.08
const LOCOMOTION_ANIMATION_BLEND_SECONDS := 0.12
const ATTACKS := {
	"punch": {"windup": 0.10, "active": TARGET_MELEE_CYCLE_SECONDS - 0.10, "recovery": 0.34, "range": 1.55, "damage": 18, "cone": 0.42},
	"kick": {"windup": 0.12, "active": TARGET_MELEE_CYCLE_SECONDS - 0.12, "recovery": 0.48, "range": 2.15, "damage": 28, "cone": 0.30}
}
const SPELLS := {
	"light": {"cost": 20.0, "range": 8.0, "color": Color(1.0, 0.84, 0.32)},
	"judgment": {"cost": 20.0, "range": 18.0, "color": Color(0.40, 0.78, 1.0)},
	"fire": {"cost": 15.0, "range": 18.0, "color": Color(1.0, 0.24, 0.06)},
	"shadow": {"cost": 20.0, "range": 18.0, "color": Color(0.68, 0.30, 1.0)}
}

var rage: RageProgression = RAGE_SCRIPT.new()
var health := MAX_HEALTH
var magic_energy := MAX_MAGIC
var current_spell := ""
var attack_phase := "ready"
var attack_kind := ""
var attack_side := "right"
var attack_phase_time := 0.0
var attack_count := 0
var _queued_attack_kind := ""
var _queued_attack_side := ""
var _attack_recovery_locked := false
var movement_slow_time := 0.0
var movement_slow_factor := 1.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var jump_impact_armed := false
var _was_airborne := false
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _fight_animations_ready := false
var _character_motion_ready := false
var _character_action_time := 0.0
var _camera_yaw := 0.0
var _burns: Array[Dictionary] = []
var _magic_hud_timer := 0.0
var _desktop_attack_repeat_timers: Dictionary = {}
var safe_base_position := Vector3.ZERO
var combat_fx_pool: Node

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")

const SHADOW_POLICY := preload("res://scripts/shadow_policy.gd")

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 3
	if get_node_or_null("CollisionShape3D") == null:
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.38
		capsule.height = 1.85
		collision.shape = capsule
		collision.position.y = 0.92
		add_child(collision)
	if visual_root == null:
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	_load_player_visual()
	SHADOW_POLICY.disable_in_tree(visual_root)
	rage.condemned.connect(_on_condemned)
	rage.selection_resolved.connect(_on_selection_resolved)

func _load_player_visual() -> void:
	if visual_root.get_child_count() > 0:
		return
	if ResourceLoader.exists(PLAYER_MODEL_PATH):
		var packed := load(PLAYER_MODEL_PATH) as PackedScene
		if packed != null:
			var model := packed.instantiate() as Node3D
			if model != null:
				visual_root.add_child(model)
				model.rotation.y = PI
				_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if _animation_player == null:
					_animation_player = AnimationPlayer.new()
					_animation_player.name = "UniversalBaseAnimationPlayer"
					model.add_child(_animation_player)
				_animation_player.root_node = _animation_player.get_path_to(model)
				_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
				if _skeleton != null:
					_character_motion_ready = CHARACTER_MOTION.install(_animation_player, _skeleton)
					_fight_animations_ready = FIGHT_ANIMATION_BUILDER.install(_animation_player, _skeleton, ATTACKS)
				_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
				_set_locomotion_animation("Idle")
				# Avoid displaying the imported T-pose on the first gameplay frame.
				if _animation_player.current_animation == "Idle":
					_animation_player.seek(0.05, true)
				return
	_add_debug_visual()

func _add_debug_visual() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.28, 0.34)
	body.material_override = material
	visual_root.add_child(body)

func _physics_process(delta: float) -> void:
	if rage.current_soul_condemned:
		return
	_character_action_time = maxf(0.0, _character_action_time - delta)
	_read_desktop_input(delta)
	_update_attack(delta)
	_update_burns(delta)
	magic_energy = minf(MAX_MAGIC, magic_energy + 5.0 * delta)
	if movement_slow_time > 0.0:
		movement_slow_time = maxf(0.0, movement_slow_time - delta)
		if movement_slow_time == 0.0:
			movement_slow_factor = 1.0
	if dash_time > 0.0:
		dash_time = maxf(0.0, dash_time - delta)
		# Explicit directed dashes may rise; the default camera dash stays level.
		var vertical_velocity := velocity.y
		velocity = dash_direction * (DASH_DISTANCE / DASH_DURATION)
		if is_zero_approx(dash_direction.y) and (not is_on_floor() or vertical_velocity > 0.1):
			# A level air dash must not cancel an upward jump or force a fall.
			velocity.y = vertical_velocity
	else:
		_update_movement(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	var started_airborne := not is_on_floor() or velocity.y > 0.1
	move_and_slide()
	if started_airborne:
		_was_airborne = true
	if _was_airborne and is_on_floor():
		_was_airborne = false
		_play_character_action("Landing", float(CHARACTER_MOTION.ACTIONS.get("Landing", 0.38)))
		if jump_impact_armed:
			jump_impact_armed = false
			_resolve_jump_impact()
	_update_locomotion_animation()
	_update_attack_pose()
	rage.advance(delta, true)
	_magic_hud_timer += delta
	if _magic_hud_timer >= 0.18:
		_magic_hud_timer = 0.0
		magic_changed.emit(magic_energy, MAX_MAGIC, current_spell)

func _read_desktop_input(delta: float) -> void:
	for input_action in [&"attack_punch", &"attack_kick"]:
		var kind := "punch" if input_action == &"attack_punch" else "kick"
		if Input.is_action_just_pressed(input_action):
			request_attack(kind)
			_desktop_attack_repeat_timers[input_action] = TARGET_MELEE_CYCLE_SECONDS
		elif Input.is_action_pressed(input_action):
			var repeat_time := float(_desktop_attack_repeat_timers.get(input_action, TARGET_MELEE_CYCLE_SECONDS)) - delta
			if repeat_time <= MELEE_TIMER_EPSILON:
				request_attack(kind)
				repeat_time += TARGET_MELEE_CYCLE_SECONDS
			_desktop_attack_repeat_timers[input_action] = repeat_time
		else:
			_desktop_attack_repeat_timers.erase(input_action)
	if Input.is_action_just_pressed("jump"):
		try_jump()
	if Input.is_action_just_pressed("dash"):
		try_dash()
	if Input.is_action_just_pressed("cast_spell"):
		cast_spell()
	if Input.is_action_just_pressed("cycle_spell"):
		cycle_spell()

func set_camera_yaw(yaw: float) -> void:
	_camera_yaw = yaw

func move_input() -> Vector2:
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var touch := Vector2.ZERO
	var controls := get_tree().get_first_node_in_group("mobile_controls")
	if controls != null and controls.has_method("get_move_vector"):
		touch = controls.get_move_vector()
	if touch.length() > keyboard.length():
		return touch
	return keyboard

func _update_movement(delta: float) -> void:
	var stick := move_input()
	var relative := Vector3(stick.x, 0.0, stick.y)
	var direction := relative.rotated(Vector3.UP, _camera_yaw)
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		var target_yaw := atan2(-direction.x, -direction.z)
		var turn_delta := wrapf(target_yaw - rotation.y, -PI, PI)
		if attack_phase == "ready" and _character_action_time <= 0.0 and absf(turn_delta) > 0.72:
			var turn_action := "Turn_Left" if turn_delta > 0.0 else "Turn_Right"
			_play_character_action(turn_action, float(CHARACTER_MOTION.ACTIONS.get(turn_action, 0.28)))
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 16.0))
	var speed := 4.8 * movement_slow_factor
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func request_attack(kind: String, side: String = "right") -> bool:
	if not ATTACKS.has(kind) or side not in ["left", "right"] or rage.current_soul_condemned:
		return false
	if attack_phase == "windup" or attack_phase == "active":
		_queue_attack(kind, side)
		return true
	if attack_phase == "recovery":
		if _attack_recovery_locked:
			_queue_attack(kind, side)
			return true
		_finish_attack()
	_start_attack(kind, side)
	return true

func _queue_attack(kind: String, side: String) -> void:
	_queued_attack_kind = kind
	_queued_attack_side = side

func _start_attack(kind: String, side: String) -> void:
	attack_kind = kind
	attack_side = side
	attack_phase = "windup"
	attack_phase_time = float(ATTACKS[kind].windup)
	_attack_recovery_locked = false
	_character_action_time = 0.0
	attack_count += 1
	attack_started.emit(kind)
	_spawn_attack_sweep(kind, side)
	if _animation_player != null:
		if _fight_animations_ready:
			_animation_player.play(FIGHT_ANIMATION_BUILDER.clip_path(kind, side), ATTACK_ANIMATION_BLEND_SECONDS)
			# play() on the same currently playing clip does not restart it.
			# Every accepted strike, including held input, needs a new windup.
			_animation_player.seek(0.0, true)
		else:
			_animation_player.stop()

func _start_queued_attack() -> bool:
	if _queued_attack_kind.is_empty():
		return false
	var next_kind := _queued_attack_kind
	var next_side := _queued_attack_side
	_queued_attack_kind = ""
	_queued_attack_side = ""
	_finish_attack()
	_start_attack(next_kind, next_side)
	return true

func _finish_attack() -> void:
	var finished := attack_kind
	attack_phase = "ready"
	attack_kind = ""
	attack_phase_time = 0.0
	_attack_recovery_locked = false
	if not finished.is_empty():
		attack_finished.emit(finished)

func _update_attack(delta: float) -> void:
	if attack_phase == "ready":
		return
	var elapsed_time := maxf(0.0, delta)
	if elapsed_time + MELEE_TIMER_EPSILON < attack_phase_time:
		attack_phase_time -= elapsed_time
		return
	var overflow_time := maxf(0.0, elapsed_time - attack_phase_time)
	attack_phase_time = 0.0
	match attack_phase:
		"windup":
			attack_phase = "active"
			_resolve_attack()
			attack_phase_time = float(ATTACKS[attack_kind].active)
		"active":
			if not _start_queued_attack():
				attack_phase = "recovery"
				attack_phase_time = float(ATTACKS[attack_kind].recovery)
				_attack_recovery_locked = false
		"recovery":
			if not _start_queued_attack():
				_finish_attack()
				return
		_:
			_finish_attack()
			return
	if attack_phase != "ready":
		attack_phase_time = maxf(0.0, attack_phase_time - overflow_time)

func _resolve_attack() -> void:
	var profile: Dictionary = ATTACKS[attack_kind]
	if _fight_animations_ready and _animation_player.current_animation == FIGHT_ANIMATION_BUILDER.clip_path(attack_kind, attack_side):
		_animation_player.seek(float(profile.windup), true)
	var target := _find_target(float(profile.range), float(profile.cone))
	if target == null:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	var dealt: int = target.receive_hit(int(profile.damage), direction.normalized())
	if dealt > 0:
		rage.record_effective_hit(float(dealt))
		attack_connected.emit(attack_kind, target)
		_spawn_attack_impact(target.global_position + Vector3(0.0, 1.0, 0.0), attack_kind)

func try_jump() -> bool:
	if not is_on_floor() or rage.current_soul_condemned:
		return false
	velocity.y = 8.2
	jump_impact_armed = true
	_was_airborne = true
	return true

func _resolve_jump_impact() -> void:
	var target := _find_target(2.25, 0.1)
	if target == null:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	var dealt: int = target.receive_hit(22, direction.normalized(), true)
	if dealt > 0:
		rage.record_effective_hit(float(dealt))
		jump_impact.emit(target)

func _camera_aim_direction() -> Vector3:
	var aim_camera := get_tree().get_first_node_in_group("foundation_camera") as Camera3D
	if aim_camera != null and is_instance_valid(aim_camera):
		return -aim_camera.global_transform.basis.z.normalized()
	return -global_transform.basis.z.normalized()

func try_dash(direction: Vector3 = Vector3.ZERO) -> bool:
	if dash_time > 0.0 or rage.current_soul_condemned:
		return false
	if direction.length_squared() < 0.01:
		direction = _camera_aim_direction()
		# The camera looks down at the arena; do not drive the 15 m dash
		# into the floor or shorten its horizontal reach.
		direction.y = 0.0
	if direction.length_squared() < 0.01:
		direction = -global_transform.basis.z
	dash_direction = direction.normalized()
	if dash_direction.length_squared() < 0.01:
		dash_direction = Vector3.FORWARD
	dash_time = DASH_DURATION
	_play_character_action("Dash", DASH_DURATION)
	return true

func interrupt_by_zombie(slow_seconds: float = 0.7, recovery_penalty: float = 0.45) -> void:
	movement_slow_factor = minf(movement_slow_factor, 0.58)
	movement_slow_time = maxf(movement_slow_time, slow_seconds)
	if attack_phase != "ready":
		attack_phase = "recovery"
		attack_phase_time = maxf(attack_phase_time, recovery_penalty)
		_attack_recovery_locked = true
	_play_character_action("Hit", float(CHARACTER_MOTION.ACTIONS.get("Hit", 0.34)))
	interrupted.emit(slow_seconds)

func take_boss_damage(amount: int) -> void:
	if rage.current_soul_condemned or amount <= 0:
		return
	var was_alive := health > 0
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if was_alive:
		if health == 0:
			_play_character_action("Defeat", float(CHARACTER_MOTION.ACTIONS.get("Defeat", 1.25)))
		else:
			_play_character_action("Hit", float(CHARACTER_MOTION.ACTIONS.get("Hit", 0.34)))

func cycle_spell() -> bool:
	var available: Array[String] = rage.unlocked_spells
	if available.is_empty():
		return false
	var index := available.find(current_spell)
	current_spell = available[(index + 1) % available.size()]
	magic_changed.emit(magic_energy, MAX_MAGIC, current_spell)
	return true

func cast_spell() -> bool:
	if rage.current_soul_condemned or rage.unlocked_spells.is_empty():
		return false
	if not rage.unlocked_spells.has(current_spell):
		current_spell = rage.unlocked_spells[0]
	return _cast_spell(current_spell)

func cast_blast() -> bool:
	if rage.current_soul_condemned or not rage.unlocked_spells.has("fire"):
		return false
	return _cast_spell("fire")

func _cast_spell(school: String) -> bool:
	if rage.current_soul_condemned or not rage.unlocked_spells.has(school):
		return false
	var spec: Dictionary = SPELLS[school]
	if magic_energy < float(spec.cost):
		return false
	var target: FoundationEnemy = null
	if school != "light":
		target = _find_target(float(spec.range), 0.25)
		if target == null:
			return false
	magic_energy -= float(spec.cost)
	match school:
		"light":
			health = mini(MAX_HEALTH, health + 30)
			health_changed.emit(health, MAX_HEALTH)

		"judgment":
			_apply_spell_damage(target, 35)
			if target.hp > 0:
				target.apply_stun(0.7)
		"fire":
			_apply_spell_damage(target, 20)
			if target.hp > 0:
				_burns.append({"target": weakref(target), "ticks": 4, "time": 1.0})
		"shadow":
			var damage := _apply_spell_damage(target, 25)
			if target.hp > 0:
				target.apply_slow(0.4, 5.0)
			health = mini(MAX_HEALTH, health + roundi(float(damage) * 0.3))
			health_changed.emit(health, MAX_HEALTH)
	if target != null:
		_spawn_spell_burst(target.global_position + Vector3(0.0, 1.0, 0.0), school)
	var action_name := "Magic_" + school.capitalize()
	_play_character_action(action_name, float(CHARACTER_MOTION.ACTIONS.get(action_name, 0.62)))
	magic_changed.emit(magic_energy, MAX_MAGIC, current_spell)
	return true

func cast_spell_slot(slot: int) -> bool:
	if slot < 0 or slot >= rage.unlocked_spells.size() or rage.current_soul_condemned:
		return false
	current_spell = rage.unlocked_spells[slot]
	return cast_spell()

func _apply_spell_damage(target: FoundationEnemy, amount: int) -> int:
	var direction := target.global_position - global_position
	direction.y = 0.0
	var dealt: int = target.receive_hit(amount, direction.normalized())
	if dealt > 0:
		rage.record_effective_hit(float(dealt))
	return dealt

func _update_burns(delta: float) -> void:
	for index in range(_burns.size() - 1, -1, -1):
		var burn: Dictionary = _burns[index]
		burn.time = float(burn.time) - delta
		if float(burn.time) > 0.0:
			continue
		var ref: WeakRef = burn.target
		var target := ref.get_ref() as FoundationEnemy
		if target != null and is_instance_valid(target) and target.hp > 0:
			target.receive_hit(4, Vector3.ZERO)
		burn.ticks = int(burn.ticks) - 1
		if int(burn.ticks) <= 0 or target == null or not is_instance_valid(target) or target.hp <= 0:
			_burns.remove_at(index)
		else:
			burn.time = 1.0

func _find_target(max_range: float, min_facing_dot: float) -> FoundationEnemy:
	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var chosen: FoundationEnemy = null
	var best_distance := max_range
	for candidate_node in get_tree().get_nodes_in_group("enemies"):
		var candidate := candidate_node as FoundationEnemy
		if candidate == null or not is_instance_valid(candidate) or candidate.hp <= 0:
			continue
		var offset: Vector3 = candidate.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > best_distance:
			continue
		if distance > 0.1 and facing.dot(offset.normalized()) < min_facing_dot:
			continue
		best_distance = distance
		chosen = candidate
	return chosen

func _spawn_attack_sweep(kind: String, side: String) -> void:
	if is_instance_valid(combat_fx_pool) and combat_fx_pool.has_method("play_attack_sweep"):
		combat_fx_pool.call("play_attack_sweep", kind, side, get_viewport().get_visible_rect().size)
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	var sweep_layer := CanvasLayer.new()
	sweep_layer.layer = 12
	scene_root.add_child(sweep_layer)

	var sweep := Node2D.new()
	sweep_layer.add_child(sweep)
	var viewport_size := get_viewport().get_visible_rect().size
	sweep.position = viewport_size * Vector2(0.50, 0.49)
	sweep.z_index = 100

	var radius := 168.0 if kind == "kick" else 122.0
	var points := PackedVector2Array()
	for point_index in range(25):
		var progress := float(point_index) / 24.0
		var angle := lerpf(-1.22, 1.22, progress)
		points.append(Vector2(sin(angle) * radius, -cos(angle) * radius * 0.76))

	var hot_color := Color(0.22, 0.76, 1.0, 0.96) if kind == "kick" else Color(1.0, 0.26, 0.045, 0.96)
	var glow := Line2D.new()
	glow.points = points
	glow.width = 22.0 if kind == "kick" else 17.0
	glow.default_color = hot_color
	glow.antialiased = true
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	sweep.add_child(glow)

	var core := Line2D.new()
	core.points = points
	core.width = 5.0
	core.default_color = Color(0.83, 0.96, 1.0, 1.0) if kind == "kick" else Color(1.0, 0.94, 0.72, 1.0)
	core.antialiased = true
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	sweep.add_child(core)

	var side_sign := 1.0 if side == "right" else -1.0
	var rotation_start := -0.28 * side_sign
	sweep.rotation = rotation_start
	sweep.scale = Vector2.ONE * 0.62
	sweep.modulate = Color(1.0, 1.0, 1.0, 0.96)
	var tween := create_tween()
	tween.tween_property(sweep, "scale", Vector2.ONE * 1.18, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sweep, "rotation", rotation_start + 0.78 * side_sign, 0.22)
	tween.parallel().tween_property(sweep, "modulate:a", 0.0, 0.22)
	tween.tween_callback(sweep_layer.queue_free)

func _spawn_attack_impact(at: Vector3, kind: String) -> void:
	if is_instance_valid(combat_fx_pool) and combat_fx_pool.has_method("play_attack_impact"):
		combat_fx_pool.call("play_attack_impact", at, kind)
		return
	var impact := Node3D.new()
	impact.name = "CombatImpact"
	impact.add_to_group("attack_impact_fx")
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(impact)
	impact.global_position = at

	var color := Color(1.0, 0.74, 0.30) if kind == "punch" else Color(1.0, 0.38, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.20
	sphere.height = 0.40
	flash.mesh = sphere
	flash.material_override = material
	impact.add_child(flash)
	for spark_index in range(8):
		var spark := MeshInstance3D.new()
		var shard := BoxMesh.new()
		shard.size = Vector3(0.055, 0.055, 0.30)
		spark.mesh = shard
		spark.material_override = material
		var angle := TAU * float(spark_index) / 8.0
		spark.position = Vector3(cos(angle) * 0.18, sin(angle) * 0.18, 0.0)
		spark.rotation.y = angle
		impact.add_child(spark)

	impact.scale = Vector3.ONE * 0.72
	var tween := create_tween()
	tween.tween_property(impact, "scale", Vector3.ONE * 2.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.18)
	tween.tween_callback(impact.queue_free)

func _spawn_spell_burst(at: Vector3, school: String = "") -> void:
	var effect_school: String = school if not school.is_empty() else current_spell
	var spell_color: Color = SPELLS[effect_school].color
	if is_instance_valid(combat_fx_pool) and combat_fx_pool.has_method("play_spell_burst"):
		combat_fx_pool.call("play_spell_burst", at, spell_color)
		return
	var root := MeshInstance3D.new()
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	root.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = spell_color
	material.emission_enabled = true
	material.emission = spell_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	root.material_override = material
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(root)
	root.global_position = at
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * 2.8, 0.22)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(root.queue_free)

func _update_attack_pose() -> void:
	if _skeleton == null or attack_phase == "ready" or _fight_animations_ready:
		return
	if _animation_player != null:
		_animation_player.stop()
	_skeleton.reset_bone_poses()
	var windup_blend := 1.0 if attack_phase == "active" else 0.55
	var limb := "Left" if attack_side == "left" else "Right"
	var mirror := -1.0 if attack_side == "left" else 1.0
	if attack_kind == "punch":
		_set_bone_rotation("Chest", Vector3(-0.08, -0.18 * windup_blend * mirror, 0.03 * mirror))
		_set_bone_rotation(limb + "UpperArm", Vector3(1.24 * windup_blend, 0.0, -0.15 * mirror))
		_set_bone_rotation(limb + "Forearm", Vector3(0.30 * windup_blend, 0.0, 0.0))
	else:
		_set_bone_rotation("Chest", Vector3(-0.12, 0.04 * mirror, 0.0))
		_set_bone_rotation(limb + "Thigh", Vector3(-1.28 * windup_blend, 0.0, 0.0))
		_set_bone_rotation(limb + "Shin", Vector3(0.42 * windup_blend, 0.0, 0.0))

func _set_bone_rotation(bone_name: String, euler: Vector3) -> void:
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index >= 0:
		_skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(euler))

func _set_locomotion_animation(animation_name: String) -> void:
	if _animation_player == null:
		return
	var selected_animation := StringName(animation_name)
	if not _animation_player.has_animation(selected_animation):
		return
	if _animation_player.current_animation != selected_animation or not _animation_player.is_playing():
		_animation_player.play(selected_animation, LOCOMOTION_ANIMATION_BLEND_SECONDS)

func _update_locomotion_animation() -> void:
	if _animation_player == null or attack_phase != "ready" or _character_action_time > 0.0:
		return
	if not is_on_floor():
		_set_locomotion_animation("Jump")
	elif Vector2(velocity.x, velocity.z).length() > 0.4:
		_set_locomotion_animation("Walk")
	else:
		_set_locomotion_animation("Idle")

func _play_character_action(action_name: String, duration: float) -> void:
	# Movement, landing, and casting must not silently replace a melee clip
	# while its damage timer continues. Explicit hit/defeat reactions may win.
	if attack_phase != "ready" and action_name not in ["Hit", "Defeat"]:
		return
	if not _character_motion_ready or _animation_player == null:
		return
	var clip := CHARACTER_MOTION.clip_path(action_name)
	if not _animation_player.has_animation(clip):
		return
	_character_action_time = maxf(0.0, duration)
	_animation_player.play(clip, ATTACK_ANIMATION_BLEND_SECONDS)

func _on_selection_resolved(_milestone: int, aura_id: String) -> void:
	current_spell = aura_id

func _on_condemned(_threshold: float, _maximum: float) -> void:
	call_deferred("_reset_at_safe_base")

func _reset_at_safe_base() -> void:
	global_position = safe_base_position
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	magic_energy = MAX_MAGIC
	current_spell = ""
	attack_phase = "ready"
	attack_kind = ""
	attack_phase_time = 0.0
	_queued_attack_kind = ""
	_queued_attack_side = ""
	_attack_recovery_locked = false
	_burns.clear()
	rage.reset_soul()
	health_changed.emit(health, MAX_HEALTH)
