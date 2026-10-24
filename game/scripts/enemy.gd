extends CharacterBody3D
class_name FoundationEnemy

signal telegraph_started(enemy: Node, is_boss: bool)
signal attack_resolved(enemy: Node, hit: bool)
signal defeated(enemy: Node)

const ENEMY_MODEL_PATH := "res://assets/zombies/brutal_v2/Retribution_Zombie_01_Brutal_V2_RIGGED_LOD1.glb"
const ENEMY_MODEL_YAW_OFFSET := PI
const SHADOW_POLICY := preload("res://scripts/shadow_policy.gd")
const GRAVITY := 24.0
const RENDER_RADIUS := 30.0

@export_enum("shambler", "brute", "stalker", "boss") var enemy_variant := "shambler"
@export var is_boss := false
@export var starting_health := 90

var hp := 90
var move_speed := 2.5
var attack_range := 1.8
var telegraph_duration := 1.0
var recovery_duration := 1.15
var state := "approach"
var state_time := 0.0
var stun_time := 0.0
var slow_time := 0.0
var slow_factor := 1.0
var knockback := Vector3.ZERO
var _ai_accumulator := 0.0
var _ai_interval := 0.0
var _player: FoundationPlayer
var _model: Node3D
var _animation_player: AnimationPlayer
var _visual_root: Node3D
var _status_label: Label3D
var _health_bar_root: Node3D
var _health_bar_fill: MeshInstance3D
var _attack_latched := false
var _lod_band := -1

func configure(kind: String, boss_target: bool = false) -> void:
	enemy_variant = kind
	is_boss = boss_target or kind == "boss"

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 1
	name = enemy_variant.capitalize()
	_apply_variant()
	hp = starting_health
	_build_collision()
	_build_visual()

func _build_collision() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42 if not is_boss else 0.64
	capsule.height = 1.85 if not is_boss else 2.55
	collision.shape = capsule
	collision.position.y = capsule.height * 0.5
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

func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)
	if ResourceLoader.exists(ENEMY_MODEL_PATH):
		var packed := load(ENEMY_MODEL_PATH) as PackedScene
		if packed != null:
			_model = packed.instantiate()
			# The imported zombie rig faces +Z; enemy movement and targeting use -Z as forward.
			_model.rotation.y += ENEMY_MODEL_YAW_OFFSET
			_visual_root.add_child(_model)
			if is_boss:
				_model.scale = Vector3.ONE * 1.38
			elif enemy_variant == "brute":
				_model.scale = Vector3(1.16, 1.0, 1.15)
			elif enemy_variant == "stalker":
				_model.scale = Vector3(0.91, 1.03, 0.91)
			_animation_player = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if is_boss:
				_apply_variant_overlay()
	if _model == null:
		_build_debug_variant()
	if is_boss or enemy_variant == "brute":
		_add_silhouette_piece()
	_build_health_display()
	SHADOW_POLICY.disable_in_tree(_visual_root)

func attach_status_label(label: Label3D) -> void:
	_status_label = label
	if _visual_root != null:
		_visual_root.add_child(label)
	else:
		add_child(label)
	_update_health_display()

func _build_health_display() -> void:
	_health_bar_root = Node3D.new()
	_health_bar_root.name = "EnemyHealthBar"
	_health_bar_root.position.y = 3.05 if is_boss else 2.58
	_health_bar_root.visible = is_boss
	_visual_root.add_child(_health_bar_root)
	var back := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(0.90, 0.085)
	back.mesh = back_mesh
	back.material_override = _health_bar_material(Color(0.035, 0.025, 0.03))
	_health_bar_root.add_child(back)
	_health_bar_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.82, 0.044)
	_health_bar_fill.mesh = fill_mesh
	_health_bar_fill.position = Vector3(-0.41, 0.0, 0.006)
	_health_bar_fill.material_override = _health_bar_material(Color(0.86, 0.12, 0.09))
	_health_bar_root.add_child(_health_bar_fill)
	_update_health_display()

func _health_bar_material(tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint * 0.45
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return material

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

func _add_silhouette_piece() -> void:
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.05, 0.52, 0.42) if not is_boss else Vector3(1.45, 0.70, 0.52)
	plate.mesh = box
	plate.position = Vector3(0.0, 1.45 if not is_boss else 1.85, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.22, 0.25) if enemy_variant == "brute" else Color(0.28, 0.05, 0.08)
	material.roughness = 0.84
	material.metallic = 0.36
	plate.material_override = material
	_visual_root.add_child(plate)
	if is_boss:
		var halo := MeshInstance3D.new()
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
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	_player = get_tree().get_first_node_in_group("player") as FoundationPlayer
	if _player == null:
		return
	var distance := global_position.distance_to(_player.global_position)
	_set_distance_detail(distance)
	if distance > 70.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
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
		move_and_slide()
		return
	var step := _ai_accumulator
	_ai_accumulator = 0.0
	_update_ai(step, distance)
	move_and_slide()

func _set_distance_detail(distance: float) -> void:
	if _visual_root == null:
		return
	var band := 0 if distance <= 18.0 else (1 if distance <= RENDER_RADIUS else 2)
	if band == _lod_band:
		return
	_lod_band = band
	_visual_root.visible = distance <= RENDER_RADIUS
	if _animation_player != null:
		if distance <= 18.0:
			_animation_player.speed_scale = 1.0
		elif distance <= RENDER_RADIUS:
			_animation_player.speed_scale = 0.55
		else:
			_animation_player.stop()

func _update_ai(delta: float, distance: float) -> void:
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
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var direction := to_player.normalized()
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 8.0))
	state_time = maxf(0.0, state_time - delta)
	if state == "hit":
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
		if state_time <= 0.0:
			state = "approach"
	elif state == "windup":
		velocity.x = 0.0
		velocity.z = 0.0
		if state_time <= 0.0:
			_resolve_enemy_attack(distance)
	elif state == "recovery":
		velocity.x = 0.0
		velocity.z = 0.0
		if state_time <= 0.0:
			state = "approach"
	else:
		if distance > attack_range:
			velocity.x = direction.x * move_speed * slow_factor
			velocity.z = direction.z * move_speed * slow_factor
			_play_animation("Walk")
		elif _is_player_visible_to_player() and distance <= attack_range:
			state = "windup"
			state_time = telegraph_duration
			_attack_latched = true
			velocity.x = 0.0
			velocity.z = 0.0
			_play_animation("Attack")
			telegraph_started.emit(self, is_boss)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

func _resolve_enemy_attack(distance: float) -> void:
	var hit := false
	if distance <= attack_range + 0.18 and _is_player_visible_to_player():
		if is_boss:
			_player.take_boss_damage(22)
		else:
			_player.interrupt_by_zombie(0.75, 0.60)
		hit = true
	attack_resolved.emit(self, hit)
	state = "recovery"
	state_time = recovery_duration
	_attack_latched = false

func _is_player_visible_to_player() -> bool:
	var camera := get_tree().get_first_node_in_group("foundation_camera") as Camera3D
	if camera == null:
		return true
	var point := camera.unproject_position(global_position + Vector3(0.0, 1.0, 0.0))
	var rect := get_viewport().get_visible_rect()
	return not camera.is_position_behind(global_position) and rect.grow(-28.0).has_point(point)

func receive_hit(damage: int, hit_direction: Vector3 = Vector3.ZERO, is_jump_hit: bool = false) -> int:
	if hp <= 0 or damage <= 0:
		return 0
	var dealt := mini(hp, damage)
	hp -= dealt
	_update_health_display()
	_show_impact_flash(is_jump_hit)
	state = "hit"
	state_time = 0.30 if not is_jump_hit else 0.42
	if hit_direction.length_squared() > 0.01:
		knockback = hit_direction.normalized() * (4.5 if not is_jump_hit else 6.5)
	if hp <= 0:
		state = "dead"
		velocity = Vector3.ZERO
		defeated.emit(self)
		var tween := create_tween()
		tween.tween_property(_visual_root, "scale:y", 0.08, 0.45)
		tween.tween_callback(queue_free)
	return dealt

func apply_stun(duration: float) -> void:
	stun_time = maxf(stun_time, duration)

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = minf(slow_factor, clampf(factor, 0.1, 1.0))
	slow_time = maxf(slow_time, duration)

func _play_animation(animation_name: String) -> void:
	if _animation_player != null and _animation_player.has_animation(animation_name):
		if _animation_player.current_animation != animation_name or not _animation_player.is_playing():
			_animation_player.play(animation_name)
