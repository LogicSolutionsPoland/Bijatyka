extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_SCRIPT := preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const HUD_SCRIPT := preload("res://scripts/mobile_hud.gd")
const SHADOW_POLICY := preload("res://scripts/shadow_policy.gd")
# Reference: close, right-shoulder third-person view, with Thornbound left of center.
# Height is measured above the player's ground origin, not added to an existing camera offset.
const CAMERA_PIVOT_HEIGHT := 1.55
const CAMERA_FOLLOW_DISTANCE := 2.35
const CAMERA_SHOULDER_OFFSET := 0.75
const CAMERA_PITCH_DEGREES := -6.0
const CAMERA_YAW_RADIANS_PER_PIXEL := 0.006
const CAMERA_PITCH_RADIANS_PER_PIXEL := 0.004
const CAMERA_MIN_PITCH_DEGREES := -28.0
const CAMERA_MAX_PITCH_DEGREES := 18.0

var player: FoundationPlayer
var camera_rig: Node3D
var camera_arm: SpringArm3D
var camera: Camera3D
var _camera_yaw := 0.0
var _camera_pitch := deg_to_rad(CAMERA_PITCH_DEGREES)
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
	SHADOW_POLICY.disable_in_tree(self)
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
	var target_position := player.global_position + Vector3(0.0, CAMERA_PIVOT_HEIGHT, 0.0)
	camera_rig.global_position = camera_rig.global_position.lerp(target_position, 1.0 - exp(-delta * 7.5))
	player.set_camera_yaw(_camera_yaw)
	_status_timer += delta
	if _status_timer >= 0.18:
		_status_timer = 0.0
		_refresh_hud(player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold())

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.035, 0.050, 0.095)
	sky_material.sky_horizon_color = Color(0.42, 0.20, 0.15)
	sky_material.ground_bottom_color = Color(0.025, 0.032, 0.042)
	sky_material.ground_horizon_color = Color(0.16, 0.11, 0.105)
	sky_material.sky_curve = 0.38
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.43, 0.39, 0.40)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.23, 0.15, 0.14)
	environment.fog_light_energy = 0.7
	environment.fog_depth_begin = 13.0
	environment.fog_depth_end = 58.0
	environment.fog_density = 0.004
	environment.fog_sun_scatter = 0.10
	environment.glow_enabled = true
	environment.glow_intensity = 0.28
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.88
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "ChemicalDuskKeyLight"
	sun.rotation_degrees = Vector3(-39.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.72, 0.54)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)

func _build_arena() -> void:
	var ground := StaticBody3D.new()
	ground.name = "QuarantineCourtyardGround"
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
	var floor_material := _material(Color(0.105, 0.118, 0.135), 0.96)
	floor_material.metallic = 0.06
	floor.material_override = floor_material
	ground.add_child(floor)
	add_child(ground)

	var concrete := _material(Color(0.24, 0.255, 0.27), 0.93)
	var dark_concrete := _material(Color(0.075, 0.085, 0.10), 0.98)
	var rust := _material(Color(0.29, 0.15, 0.10), 0.88)
	var hazard := _material(Color(0.78, 0.32, 0.10), 0.74)
	var glass := _material(Color(0.035, 0.065, 0.078), 0.26)
	glass.metallic = 0.55

	# Enclosed edges and a broken industrial skyline keep the combat space readable.
	_add_arena_box("WestRetainingWall", Vector3(-20.0, 2.1, -8.0), Vector3(0.9, 4.2, 50.0), concrete, true)
	_add_arena_box("EastRetainingWall", Vector3(20.0, 2.1, -8.0), Vector3(0.9, 4.2, 50.0), concrete, true)
	_add_arena_box("NorthRetainingWall", Vector3(0.0, 2.1, -32.0), Vector3(40.0, 4.2, 0.9), concrete, true)
	_add_arena_box("SouthRetainingWall", Vector3(0.0, 2.1, 24.0), Vector3(40.0, 4.2, 0.9), concrete, true)
	_add_arena_box("WestSkylineRuins", Vector3(-12.5, 7.0, -37.0), Vector3(11.0, 14.0, 5.5), dark_concrete, false)
	_add_arena_box("EastSkylineRuins", Vector3(12.0, 6.0, -38.0), Vector3(10.0, 12.0, 5.0), dark_concrete, false)
	_add_arena_box("RearSkylineTower", Vector3(1.0, 9.0, -40.0), Vector3(5.5, 18.0, 4.0), dark_concrete, false)
	for index in range(7):
		var x := -16.0 + float(index) * 5.25
		_add_arena_box("FacadeSupport%d" % index, Vector3(x, 4.15, -31.48), Vector3(0.28, 4.1, 0.16), rust if index % 2 == 0 else concrete, false)
		if index < 6:
			_add_arena_box("RuinedWindow%d" % index, Vector3(x + 2.55, 3.45 + float(index % 3) * 0.32, -31.46), Vector3(1.9, 1.25, 0.12), glass, false)

	# Scuffed boundary rails, broken columns and painted fight-ring markings.
	for side in [-1.0, 1.0]:
		for index in range(9):
			var rail_z := -27.0 + float(index) * 4.4
			_add_arena_box("FencePost_%d_%d" % [int(side), index], Vector3(side * 16.5, 1.35, rail_z), Vector3(0.14, 2.7, 0.14), rust, false)
		for rail_y in [0.42, 2.30]:
			_add_arena_box("FenceRail_%d_%.1f" % [int(side), rail_y], Vector3(side * 16.5, rail_y, -9.4), Vector3(0.12, 0.12, 35.2), rust, false)

	_add_arena_box("BrokenPillarA", Vector3(-7.4, 1.65, -4.8), Vector3(1.25, 3.3, 1.15), concrete, true)
	_add_arena_box("BrokenPillarB", Vector3(7.3, 1.15, -10.8), Vector3(1.1, 2.3, 1.35), rust, true)
	_add_arena_box("BrokenPillarC", Vector3(-8.4, 0.9, -17.0), Vector3(1.45, 1.8, 1.25), rust, true)
	_add_arena_box("LowRuin", Vector3(8.5, 0.62, -3.0), Vector3(2.8, 1.24, 0.9), concrete, true)
	_add_ground_ring("OuterHazardRing", Vector3(0.0, 0.035, -5.2), 6.72, 6.92, hazard)
	_add_ground_ring("InnerScuffRing", Vector3(0.0, 0.040, -5.2), 6.42, 6.50, rust)
	_add_ground_ring("CenterMark", Vector3(0.0, 0.045, -5.2), 1.65, 1.76, concrete)
	_add_arena_box("CenterCross_NS", Vector3(0.0, 0.018, -5.2), Vector3(0.10, 0.018, 2.8), hazard, false)
	_add_arena_box("CenterCross_EW", Vector3(0.0, 0.020, -5.2), Vector3(2.8, 0.018, 0.10), hazard, false)
	for index in range(8):
		var z := -1.0 - float(index) * 2.25
		_add_arena_box("LaneHazardMark%d" % index, Vector3(0.0, 0.014, z), Vector3(7.6, 0.018, 0.045), hazard, false)

	_add_barrel("ToxicDrumA", Vector3(-12.8, 0.58, -8.3), rust, hazard)
	_add_barrel("ToxicDrumB", Vector3(12.7, 0.58, -11.4), dark_concrete, hazard)
	_add_barrel("ToxicDrumC", Vector3(-13.0, 0.58, -20.2), dark_concrete, hazard)
	_add_barrel("ToxicDrumD", Vector3(13.0, 0.58, -22.0), rust, hazard)
	_add_quarantine_lamp(Vector3(-13.8, 4.0, -17.0), Color(1.0, 0.36, 0.16))
	_add_quarantine_lamp(Vector3(13.8, 4.0, -17.0), Color(0.23, 0.60, 0.78))
	_add_brazier(Vector3(-9.5, 0.0, -24.0), Color(1.0, 0.29, 0.08))
	_add_brazier(Vector3(9.5, 0.0, -24.0), Color(1.0, 0.29, 0.08))

	for index in range(14):
		var angle := TAU * float(index) / 14.0
		var radius := 9.2 + sin(float(index) * 1.7) * 1.4
		var size := Vector3(0.35 + float(index % 3) * 0.12, 0.22 + float(index % 2) * 0.15, 0.48 + float(index % 4) * 0.08)
		var at := Vector3(cos(angle) * radius, size.y * 0.5, sin(angle) * radius - 5.2)
		_add_arena_box("CourtyardRubble%d" % index, at, size, rust if index % 2 == 0 else concrete, false, angle)

func _add_arena_box(label: String, at: Vector3, dimensions: Vector3, material: Material, collidable: bool, yaw: float = 0.0) -> void:
	var root: Node3D
	if collidable:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		collision.position = Vector3.ZERO
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

func _add_ground_ring(label: String, at: Vector3, inner_radius: float, outer_radius: float, material: Material) -> void:
	var ring_instance := MeshInstance3D.new()
	ring_instance.name = label
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = inner_radius
	ring_mesh.outer_radius = outer_radius
	ring_mesh.rings = 36
	ring_mesh.ring_segments = 8
	ring_instance.mesh = ring_mesh
	ring_instance.material_override = material
	ring_instance.position = at
	add_child(ring_instance)

func _add_barrel(label: String, at: Vector3, body_material: Material, stripe_material: Material) -> void:
	var drum := Node3D.new()
	drum.name = label
	drum.position = at
	add_child(drum)
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.43
	cylinder.bottom_radius = 0.48
	cylinder.height = 1.16
	cylinder.radial_segments = 12
	var body := MeshInstance3D.new()
	body.mesh = cylinder
	body.material_override = body_material
	drum.add_child(body)
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.487
	band_mesh.bottom_radius = 0.487
	band_mesh.height = 0.12
	band_mesh.radial_segments = 12
	var band := MeshInstance3D.new()
	band.mesh = band_mesh
	band.material_override = stripe_material
	band.position.y = -0.18
	drum.add_child(band)

func _add_quarantine_lamp(at: Vector3, tint: Color) -> void:
	var lamp := Node3D.new()
	lamp.position = at
	add_child(lamp)
	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.16, 3.2, 0.16)
	pole.mesh = pole_mesh
	pole.position.y = -1.55
	pole.material_override = _material(Color(0.12, 0.13, 0.15), 0.62)
	lamp.add_child(pole)
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.20
	bulb_mesh.height = 0.40
	bulb.mesh = bulb_mesh
	var bulb_material := StandardMaterial3D.new()
	bulb_material.albedo_color = tint
	bulb_material.emission_enabled = true
	bulb_material.emission = tint
	bulb_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb.material_override = bulb_material
	lamp.add_child(bulb)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 0.72
	light.omni_range = 9.0
	light.shadow_enabled = false
	lamp.add_child(light)

func _add_brazier(at: Vector3, flame_color: Color) -> void:
	var brazier := Node3D.new()
	brazier.position = at
	add_child(brazier)
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.25
	base_mesh.bottom_radius = 0.34
	base_mesh.height = 0.80
	base_mesh.radial_segments = 8
	base.mesh = base_mesh
	base.position.y = 0.40
	base.material_override = _material(Color(0.12, 0.12, 0.13), 0.78)
	brazier.add_child(base)
	var flame := MeshInstance3D.new()
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.025
	flame_mesh.bottom_radius = 0.22
	flame_mesh.height = 0.62
	flame_mesh.radial_segments = 7
	flame.mesh = flame_mesh
	flame.position.y = 1.08
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = flame_color
	flame_material.emission_enabled = true
	flame_material.emission = flame_color
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame.material_override = flame_material
	brazier.add_child(flame)
	var light := OmniLight3D.new()
	light.position.y = 0.98
	light.light_color = flame_color
	light.light_energy = 0.82
	light.omni_range = 8.0
	light.shadow_enabled = false
	brazier.add_child(light)

func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "FollowCameraRig"
	camera_rig.position = player.global_position + Vector3(0.0, CAMERA_PIVOT_HEIGHT, 0.0)
	_camera_yaw = player.rotation.y
	camera_rig.rotation.y = _camera_yaw
	add_child(camera_rig)
	camera_arm = SpringArm3D.new()
	camera_arm.name = "CollisionSpringArm"
	camera_arm.spring_length = CAMERA_FOLLOW_DISTANCE
	camera_arm.margin = 0.15
	camera_arm.collision_mask = 1
	camera_arm.add_excluded_object(player.get_rid())
	# Offset the camera to the player's right to keep Thornbound in the left third
	# of the screen while the forward combat lane stays open near the center.
	camera_arm.position.x = CAMERA_SHOULDER_OFFSET
	camera_arm.rotation.x = _camera_pitch
	camera_rig.add_child(camera_arm)
	camera = Camera3D.new()
	camera.name = "BehindPlayerCamera"
	camera.fov = 60.0
	camera.near = 0.08
	camera.far = 140.0
	camera.current = true
	camera.add_to_group("foundation_camera")
	camera_arm.add_child(camera)

func _build_hud() -> void:
	hud = HUD_SCRIPT.new() as FoundationHUD
	hud.name = "MobileCombatHUD"
	hud.action_requested.connect(_on_hud_action)
	hud.aura_chosen.connect(_on_aura_chosen)
	hud.camera_dragged.connect(_on_camera_dragged)
	add_child(hud)

func _on_camera_dragged(relative: Vector2) -> void:
	_camera_yaw = wrapf(_camera_yaw - relative.x * CAMERA_YAW_RADIANS_PER_PIXEL, -PI, PI)
	_camera_pitch = clampf(
		_camera_pitch - relative.y * CAMERA_PITCH_RADIANS_PER_PIXEL,
		deg_to_rad(CAMERA_MIN_PITCH_DEGREES),
		deg_to_rad(CAMERA_MAX_PITCH_DEGREES)
	)
	if camera_rig != null:
		camera_rig.rotation.y = _camera_yaw
	if camera_arm != null:
		camera_arm.rotation.x = _camera_pitch
	if player != null:
		player.set_camera_yaw(_camera_yaw)

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
	label.position = Vector3(0.0, 2.85 if not enemy.is_boss else 3.35, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 22 if enemy.is_boss else 17
	label.outline_size = 6
	label.modulate = Color(1.0, 0.48, 0.33) if enemy.is_boss else Color(0.88, 0.91, 0.82)
	enemy.attach_status_label(label)

func _on_hud_action(action: String) -> void:
	if get_tree().paused:
		return
	match action:
		"punch_left": player.request_attack("punch", "left")
		"punch_right": player.request_attack("punch", "right")
		"kick_left": player.request_attack("kick", "left")
		"kick_right": player.request_attack("kick", "right")
		"jump": player.try_jump()
		"dash": player.try_dash()
		"spell_0", "spell_1", "spell_2", "spell_3": player.cast_spell_slot(int(action.get_slice("_", 1)))

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
	hud.update_status(player.health, player.MAX_HEALTH, player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold(), player.magic_energy, player.current_spell, player.rage.unlocked_spells)

func _material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
