extends CharacterBody3D
class_name FoundationEnemy

signal telegraph_started(enemy: Node, is_boss: bool)
signal attack_resolved(enemy: Node, hit: bool)
signal defeated(enemy: Node)

const ENEMY_MODEL_PATH := "res://assets/characters/universal_base/Universal_Base_Characters_Male.glb"
const BOSS_MODEL_PATH := "res://assets/characters/universal_base/Universal_Base_Characters_Female.glb"
const UNIVERSAL_BASE_MOTION := preload("res://scripts/universal_base_motion.gd")
const ENEMY_MODEL_YAW_OFFSET := PI
const FIGHT_ANIMATION_BUILDER := preload("res://scripts/universal_base_enemy_combat.gd")
const ENEMY_FIGHT_LIBRARY := &"enemy_combat"
const SHADOW_POLICY := preload("res://scripts/shadow_policy.gd")
const GRAVITY := 24.0
const RENDER_RADIUS := 30.0
const DETAILED_RADIUS := 18.0
const FAR_PHYSICS_INTERVAL := 0.10
const FULL_ANIMATION_BUDGET := 20
const SPAWN_ASSAULT_DURATION := 4.5
const SPAWN_ASSAULT_SPEED_MULTIPLIER := 3.2
const SPAWN_ASSAULT_HANDOFF_DISTANCE := 6.0

@export_enum("shambler", "brute", "stalker", "boss") var enemy_variant := "shambler"
@export var is_boss := false
@export var starting_health := 90

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
var combat_target: Node3D
var _decision_time := 0.0
var _wander_time := 0.0
var _wander_direction := Vector3.ZERO
var _spawn_assault_time := 0.0
var _base_visual_meshes: Array[MeshInstance3D] = []
var _quality_shadows_enabled := false
# Rebuilt once per decision frame, shared by the whole population.
static var _grid_frame := -1
static var _grid: Dictionary = {}
static var _enemy_model_scene: PackedScene
static var _boss_model_scene: PackedScene
var _rig_budget_owner: Node
var _low_poly_death_scale := 1.0
var _player_grapple_owner: FoundationPlayer
var _player_grapple_time := 0.0

func _nearby() -> Array[FoundationEnemy]:
	var frame := Engine.get_physics_frames()
	if _grid_frame != frame:
		_grid_frame = frame
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
				if is_instance_valid(node) and node != self and node.hp > 0:
					result.append(node)
	return result

func _clear_sight(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target.global_position + Vector3.UP, 1)
	query.exclude = [get_rid(), target.get_rid()] if target is CollisionObject3D else [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _valid_target() -> bool:
	return is_instance_valid(combat_target) and not combat_target.is_queued_for_deletion() and (not combat_target is FoundationEnemy or combat_target.hp > 0)

func _choose_target() -> void:
	if is_boss:
		combat_target = _player
		return
	if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= 14.0 and _clear_sight(_player):
		var newly_alerted := combat_target != _player
		combat_target = _player
		if newly_alerted:
			for ally in _nearby():
				if ally.global_position.distance_squared_to(global_position) <= 100.0 and ally.state != "windup":
					ally.combat_target = _player
		return
	if _valid_target() and global_position.distance_to(combat_target.global_position) < 24.0:
		return
	combat_target = null
	var best := 36.0
	for rival in _nearby():
		if rival.is_boss:
			continue
		var distance := global_position.distance_squared_to(rival.global_position)
		if distance < best and _clear_sight(rival):
			best = distance
			combat_target = rival

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
	rotation.y = atan2(-direction.x, -direction.z)
	velocity.x = direction.x * move_speed * SPAWN_ASSAULT_SPEED_MULTIPLIER * slow_factor
	velocity.z = direction.z * move_speed * SPAWN_ASSAULT_SPEED_MULTIPLIER * slow_factor
	if _visual_root.visible:
		_play_animation("Sprint")
	return true

func _ready() -> void:
	add_to_group("enemies")
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
	return _enemy_model_scene.instantiate() as Node3D if _enemy_model_scene != null else null

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
		UNIVERSAL_BASE_MOTION.install(_animation_player, _skeleton)
		_fight_animations_ready = FIGHT_ANIMATION_BUILDER.install(_animation_player, _skeleton, _fight_attack_profiles())
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
	SHADOW_POLICY.disable_in_tree(model)
	set_quality_shadow_enabled(_quality_shadows_enabled)

func _release_detailed_model() -> void:
	if _model == null:
		return
	var model := _model
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
	# Outside the visible ring, sample collision and motion at 10 Hz. Spawn
	# assaults stay at full rate so the initial dash and wall handoff are exact.
	if not is_boss and distance > RENDER_RADIUS and _spawn_assault_time <= 0.0:
		_far_physics_time += delta
		if _far_physics_time < FAR_PHYSICS_INTERVAL:
			return
		delta = _far_physics_time
		_far_physics_time = 0.0
	else:
		_far_physics_time = 0.0
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
		_update_visual_visibility()
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
		"hit": _play_animation("Hit_React", 1.0, 0.04, true)
		"assault": _play_animation("Sprint")
		"wander": _play_animation("Walk")
		"approach": _play_animation("Sprint" if _is_high_speed_chase() else "Walk")
		_: _play_animation("Idle")

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
	if _spawn_assault_time > 0.0 and _update_spawn_assault(delta):
		return
	_decision_time -= delta
	if _decision_time <= 0.0 and state != "windup":
		_decision_time = randf_range(0.35, 0.55)
		_choose_target()
	if not _valid_target():
		combat_target = null
		if state == "windup":
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
		if distance > attack_range:
			velocity.x = direction.x * move_speed * slow_factor * (1.0 if is_boss else 1.45)
			velocity.z = direction.z * move_speed * slow_factor * (1.0 if is_boss else 1.45)
			_play_animation("Sprint" if _is_high_speed_chase() else "Walk")
		elif distance <= attack_range and _clear_sight(combat_target):
			state = "windup"
			state_time = telegraph_duration if is_boss else telegraph_duration * 0.55
			_attack_sequence += 1
			_attack_latched = true
			velocity.x = 0.0
			velocity.z = 0.0
			_begin_attack_animation(combat_target, distance, state_time)
			telegraph_started.emit(self, is_boss)
		else:
			velocity.x = 0.0
			velocity.z = 0.0

func _resolve_enemy_attack(distance: float) -> void:
	var hit := false
	# Legacy direct callers resolve against the player; active AI locks its target during windup.
	var target: Node3D = combat_target if _valid_target() else _player
	if is_instance_valid(target):
		distance = global_position.distance_to(target.global_position)
		if distance <= attack_range + 0.18 and _clear_sight(target):
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
	_finish_spawn_assault()
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
	_finish_spawn_assault()
	stun_time = maxf(stun_time, duration)

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
