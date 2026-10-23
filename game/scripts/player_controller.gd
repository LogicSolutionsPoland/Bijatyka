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
const RIGHT_PUNCH_BUILDER := preload("res://scripts/right_punch_animation.gd")
const KICK_BUILDER := preload("res://scripts/kick_animation.gd")
const PLAYER_MODEL_PATH := "res://assets/characters/thornbound/Retribution_Player_Thornbound_Warrior_MOBILE.glb"
const GRAVITY := 24.0
const MAX_HEALTH := 100
const MAX_MAGIC := 100.0
const DASH_DISTANCE := 15.0
const DASH_DURATION := 0.30
const ATTACKS := {
	"punch": {"windup": 0.14, "active": 0.12, "recovery": 0.34, "range": 1.55, "damage": 18, "cone": 0.42},
	"kick": {"windup": 0.23, "active": 0.16, "recovery": 0.48, "range": 2.15, "damage": 28, "cone": 0.30}
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
var movement_slow_time := 0.0
var movement_slow_factor := 1.0
var dash_time := 0.0
var dash_direction := Vector3.ZERO
var jump_impact_armed := false
var _was_airborne := false
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _right_punch_animation_ready := false
var _punch_animation_ready: Dictionary = {"left": false, "right": false}
var _kick_animation_ready: Dictionary = {"left": false, "right": false}
var _camera_yaw := 0.0
var _burns: Array[Dictionary] = []
var _magic_hud_timer := 0.0
var safe_base_position := Vector3.ZERO

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
			var model := packed.instantiate()
			visual_root.add_child(model)
			_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
			_right_punch_animation_ready = RIGHT_PUNCH_BUILDER.install(_animation_player, _skeleton, ATTACKS["punch"])
			_punch_animation_ready = {
				"left": _animation_player != null and _animation_player.has_animation(RIGHT_PUNCH_BUILDER.clip_path("left")),
				"right": _right_punch_animation_ready
			}
			_kick_animation_ready = KICK_BUILDER.install(_animation_player, _skeleton, ATTACKS["kick"])
			_set_locomotion_animation("Idle")
	else:
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
	_read_desktop_input()
	_update_attack(delta)
	_update_burns(delta)
	magic_energy = minf(MAX_MAGIC, magic_energy + 5.0 * delta)
	if movement_slow_time > 0.0:
		movement_slow_time = maxf(0.0, movement_slow_time - delta)
		if movement_slow_time == 0.0:
			movement_slow_factor = 1.0
	if dash_time > 0.0:
		dash_time = maxf(0.0, dash_time - delta)
		velocity.x = dash_direction.x * DASH_DISTANCE / DASH_DURATION
		velocity.z = dash_direction.z * DASH_DISTANCE / DASH_DURATION
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

func _read_desktop_input() -> void:
	if Input.is_action_just_pressed("attack_punch"):
		request_attack("punch")
	if Input.is_action_just_pressed("attack_kick"):
		request_attack("kick")
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
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 16.0))
	var speed := 4.8 * movement_slow_factor
	if attack_phase != "ready":
		speed *= 0.48
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func request_attack(kind: String, side: String = "right") -> bool:
	if attack_phase != "ready" or not ATTACKS.has(kind) or side not in ["left", "right"] or rage.current_soul_condemned:
		return false
	attack_kind = kind
	attack_side = side
	attack_phase = "windup"
	attack_phase_time = float(ATTACKS[kind].windup)
	attack_count += 1
	attack_started.emit(kind)
	if _animation_player != null:
		var clip_path := _authored_attack_clip_path()
		if not clip_path.is_empty():
			_animation_player.play(clip_path, 0.04)
		else:
			_animation_player.stop()
	return true

func _update_attack(delta: float) -> void:
	if attack_phase == "ready":
		return
	attack_phase_time -= delta
	if attack_phase_time > 0.0:
		return
	match attack_phase:
		"windup":
			attack_phase = "active"
			_resolve_attack()
			attack_phase_time = float(ATTACKS[attack_kind].active)
		"active":
			attack_phase = "recovery"
			attack_phase_time = float(ATTACKS[attack_kind].recovery)
		"recovery":
			var finished := attack_kind
			attack_phase = "ready"
			attack_kind = ""
			attack_phase_time = 0.0
			attack_finished.emit(finished)

func _resolve_attack() -> void:
	var profile: Dictionary = ATTACKS[attack_kind]
	var target := _find_target(float(profile.range), float(profile.cone))
	if target == null:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	var dealt: int = target.receive_hit(int(profile.damage), direction.normalized())
	if dealt > 0:
		rage.record_effective_hit(float(dealt))
		attack_connected.emit(attack_kind, target)

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

func try_dash(direction: Vector3 = Vector3.ZERO) -> bool:
	if dash_time > 0.0 or rage.current_soul_condemned:
		return false
	if direction.length_squared() < 0.01:
		direction = -global_transform.basis.z
	dash_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	if dash_direction.length_squared() < 0.01:
		dash_direction = Vector3.FORWARD
	dash_time = DASH_DURATION
	return true

func interrupt_by_zombie(slow_seconds: float = 0.7, recovery_penalty: float = 0.45) -> void:
	movement_slow_factor = minf(movement_slow_factor, 0.58)
	movement_slow_time = maxf(movement_slow_time, slow_seconds)
	if attack_phase != "ready":
		attack_phase = "recovery"
		attack_phase_time = maxf(attack_phase_time, recovery_penalty)
	interrupted.emit(slow_seconds)

func take_boss_damage(amount: int) -> void:
	if rage.current_soul_condemned or amount <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)

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
	var spec: Dictionary = SPELLS[current_spell]
	if magic_energy < float(spec.cost):
		return false
	var target: FoundationEnemy = null
	if current_spell != "light":
		target = _find_target(float(spec.range), 0.25)
		if target == null:
			return false
	magic_energy -= float(spec.cost)
	match current_spell:
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
		_spawn_spell_burst(target.global_position + Vector3(0.0, 1.0, 0.0))
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

func _spawn_spell_burst(at: Vector3) -> void:
	var root := MeshInstance3D.new()
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	root.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = SPELLS[current_spell].color
	material.emission_enabled = true
	material.emission = SPELLS[current_spell].color
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
	if _skeleton == null:
		return
	if attack_phase == "ready":
		return
	if not _authored_attack_clip_path().is_empty():
		return
	if _animation_player != null:
		_animation_player.stop()
	_skeleton.reset_bone_poses()
	var windup_blend := 1.0 if attack_phase == "active" else 0.55
	var limb := "Left" if attack_side == "left" else "Right"
	var mirror := -1.0 if attack_side == "left" else 1.0
	if attack_kind == "punch":
		_set_bone_rotation("Chest", Vector3(-0.08, -0.18 * windup_blend * mirror, 0.03 * mirror))
		_set_bone_rotation(limb + "UpperArm", Vector3(-1.15 * windup_blend, 0.0, -0.15 * mirror))
		_set_bone_rotation(limb + "Forearm", Vector3(-0.70 * windup_blend, 0.0, 0.0))
	else:
		_set_bone_rotation("Chest", Vector3(-0.12, 0.04 * mirror, 0.0))
		_set_bone_rotation(limb + "Thigh", Vector3(-1.28 * windup_blend, 0.0, 0.0))
		_set_bone_rotation(limb + "Shin", Vector3(0.42 * windup_blend, 0.0, 0.0))

func _authored_attack_clip_path() -> String:
	if _animation_player == null:
		return ""
	if attack_kind == "punch" and bool(_punch_animation_ready.get(attack_side, false)):
		var punch_path := RIGHT_PUNCH_BUILDER.clip_path(attack_side)
		return punch_path if _animation_player.has_animation(punch_path) else ""
	if attack_kind == "kick" and bool(_kick_animation_ready.get(attack_side, false)):
		var kick_path := KICK_BUILDER.clip_path(attack_side)
		return kick_path if _animation_player.has_animation(kick_path) else ""
	return ""

func _set_bone_rotation(bone_name: String, euler: Vector3) -> void:
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index >= 0:
		_skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(euler))

func _set_locomotion_animation(animation_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(animation_name):
		_animation_player.play(animation_name)

func _update_locomotion_animation() -> void:
	if _animation_player == null or attack_phase != "ready":
		return
	if not is_on_floor():
		_set_locomotion_animation("Jump")
	elif Vector2(velocity.x, velocity.z).length() > 0.4:
		_set_locomotion_animation("Walk")
	else:
		_set_locomotion_animation("Idle")

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
	_burns.clear()
	rage.reset_soul()
	health_changed.emit(health, MAX_HEALTH)

