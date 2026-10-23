extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_SCRIPT := preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const HUD_SCRIPT := preload("res://scripts/mobile_hud.gd")

var player: FoundationPlayer
var camera_rig: Node3D
var camera: Camera3D
var hud: FoundationHUD
var _status_timer := 0.0
var _pending_notice := ""

func _ready() -> void:
	_build_environment()
	_build_arena()
	player = PLAYER_SCENE.instantiate() as FoundationPlayer
	player.name = "ThornboundPlayer"
	player.position = Vector3(0.0, 0.05, 3.2)
	player.safe_base_position = player.position
	add_child(player)
	_build_camera()
	_build_hud()
	_spawn_enemies()
	player.rage.rage_changed.connect(_refresh_hud)
	player.rage.selection_pending.connect(_on_selection_pending)
	player.rage.condemned.connect(_on_condemned)
	player.health_changed.connect(func(_current: int, _maximum: int) -> void: _refresh_hud())
	player.magic_changed.connect(func(_current: float, _maximum: float, _school: String) -> void: _refresh_hud())
	_refresh_hud(player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold())
	hud.show_notice("Thornbound awakens. Zombies interrupt; only bosses damage HP.")

func _process(delta: float) -> void:
	if player == null or camera_rig == null:
		return
	var target_position := player.global_position + Vector3(0.0, 1.42, 0.0)
	camera_rig.global_position = camera_rig.global_position.lerp(target_position, 1.0 - exp(-delta * 7.5))
	camera_rig.rotation.y = lerp_angle(camera_rig.rotation.y, player.rotation.y, 1.0 - exp(-delta * 8.0))
	player.set_camera_yaw(camera_rig.rotation.y)
	_status_timer += delta
	if _status_timer >= 0.18:
		_status_timer = 0.0
		_refresh_hud(player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold())

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.047, 0.066)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.45, 0.50, 0.57)
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "LateDuskKeyLight"
	sun.rotation_degrees = Vector3(-43.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.66)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 34.0
	add_child(sun)

func _build_arena() -> void:
	var ground := StaticBody3D.new()
	ground.name = "CourtyardGround"
	ground.collision_layer = 1
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(80.0, 0.35, 80.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.18
	ground.add_child(ground_collision)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80.0, 80.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.19, 0.205, 0.22)
	floor_material.roughness = 0.95
	floor.material_override = floor_material
	ground.add_child(floor)
	add_child(ground)
	var rust := _material(Color(0.28, 0.19, 0.15), 0.92)
	var concrete := _material(Color(0.30, 0.32, 0.34), 0.90)
	var warning := _material(Color(0.62, 0.28, 0.10), 0.82)
	_add_arena_box("BrokenPillarA", Vector3(-6.8, 1.75, -4.8), Vector3(1.2, 3.5, 1.1), concrete, true)
	_add_arena_box("BrokenPillarB", Vector3(6.4, 1.15, -9.0), Vector3(1.1, 2.3, 1.4), rust, true)
	_add_arena_box("BrokenPillarC", Vector3(-7.4, 0.9, -13.0), Vector3(1.5, 1.8, 1.3), rust, true)
	_add_arena_box("LowRuin", Vector3(7.3, 0.6, -2.0), Vector3(2.7, 1.2, 0.8), concrete, true)
	for index in range(6):
		var z := -1.0 - float(index) * 2.7
		_add_arena_box("PaintedWarningStripe%d" % index, Vector3(0.0, 0.012, z), Vector3(9.0, 0.018, 0.055), warning, false)
	for index in range(10):
		var angle := TAU * float(index) / 10.0
		var position := Vector3(cos(angle) * 16.0, 0.22, sin(angle) * 16.0 - 5.0)
		_add_arena_box("Debris%d" % index, position, Vector3(0.45, 0.42, 0.65), rust if index % 2 == 0 else concrete, false, angle)

func _add_arena_box(label: String, at: Vector3, dimensions: Vector3, material: Material, collidable: bool, yaw: float = 0.0) -> void:
	var root: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		collision.position.y = dimensions.y * 0.5 if at.y > dimensions.y * 0.5 else 0.0
		body.add_child(collision)
		root = body
	else:
		root = Node3D.new()
	root.name = label
	root.position = at
	root.rotation.y = yaw
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	add_child(root)

func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "FollowCameraRig"
	camera_rig.position = player.global_position + Vector3(0.0, 1.42, 0.0)
	add_child(camera_rig)
	var arm := SpringArm3D.new()
	arm.name = "CollisionSpringArm"
	arm.spring_length = 4.8
	arm.margin = 0.22
	arm.collision_mask = 1
	arm.position.x = 0.48
	arm.rotation_degrees.x = -9.0
	camera_rig.add_child(arm)
	camera = Camera3D.new()
	camera.name = "BehindPlayerCamera"
	camera.fov = 64.0
	camera.near = 0.08
	camera.far = 140.0
	camera.current = true
	camera.add_to_group("foundation_camera")
	arm.add_child(camera)

func _build_hud() -> void:
	hud = HUD_SCRIPT.new() as FoundationHUD
	hud.name = "MobileCombatHUD"
	hud.action_requested.connect(_on_hud_action)
	hud.aura_chosen.connect(_on_aura_chosen)
	add_child(hud)

func _spawn_enemies() -> void:
	_spawn_enemy("shambler", Vector3(-1.0, 0.05, -4.4))
	_spawn_enemy("brute", Vector3(4.7, 0.05, -8.6))
	_spawn_enemy("stalker", Vector3(-4.5, 0.05, -10.4))
	_spawn_enemy("boss", Vector3(0.6, 0.05, -16.2), true)

func _spawn_enemy(kind: String, at: Vector3, boss_target: bool = false) -> void:
	var enemy := ENEMY_SCRIPT.new() as FoundationEnemy
	enemy.configure(kind, boss_target)
	enemy.position = at
	enemy.telegraph_started.connect(_on_enemy_telegraph)
	add_child(enemy)
	var label := Label3D.new()
	label.text = "BOSS" if enemy.is_boss else kind.to_upper()
	label.position = Vector3(0.0, 2.35 if not enemy.is_boss else 3.05, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 26 if enemy.is_boss else 20
	label.modulate = Color(1.0, 0.44, 0.30) if enemy.is_boss else Color(0.86, 0.89, 0.80)
	enemy.add_child(label)

func _on_hud_action(action: String) -> void:
	match action:
		"punch": player.request_attack("punch")
		"kick": player.request_attack("kick")
		"jump": player.try_jump()
		"dash": player.try_dash()
		"spell": player.cast_spell()
		"cycle_spell": player.cycle_spell()

func _on_aura_chosen(aura_id: String) -> void:
	if not player.rage.resolve_selection(aura_id):
		return
	hud.close_aura_selection()
	if player.rage.pending_milestone() >= 0:
		call_deferred("_open_next_aura_selection")
	else:
		get_tree().paused = false
	_refresh_hud(player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold())

func _open_next_aura_selection() -> void:
	if player.rage.pending_milestone() >= 0:
		hud.show_aura_selection(player.rage.pending_milestone())

func _on_selection_pending(milestone: int) -> void:
	get_tree().paused = true
	if player.rage.pending_milestone() == milestone:
		hud.show_aura_selection(milestone)

func _on_condemned(_threshold: float, _maximum: float) -> void:
	hud.show_condemnation()
	get_tree().paused = false

func _on_enemy_telegraph(_enemy: Node, is_boss: bool) -> void:
	hud.show_enemy_telegraph(is_boss)

func _refresh_hud(_a: float = 0.0, _b: float = 0.0, _c: float = 0.0) -> void:
	if hud == null or player == null:
		return
	hud.update_status(player.health, player.MAX_HEALTH, player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold(), player.magic_energy, player.current_spell)

func _material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
