extends Node3D

const BURNING_HORIZON := preload("res://scripts/burning_horizon.gd")
const ROOFTOP_CITY_TEXTURE := preload("res://assets/environment/rooftop_burning_city.jpg")
const ROOFTOP_LOWER_SKY_SHADER := preload("res://shaders/rooftop_lower_city_sky.gdshader")
const GAME_MUSIC := preload("res://assets/audio/menu_music.mp3")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_SCRIPT := preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const CONCEALED_SPAWN := preload("res://scripts/concealed_spawn.gd")
const HORDE_FAR_VISUALS := preload("res://scripts/horde_far_visuals.gd")
const PERFORMANCE_DIAGNOSTICS := preload("res://scripts/performance_diagnostics.gd")
const COMBAT_FX_POOL := preload("res://scripts/combat_fx_pool.gd")
const HUD_SCRIPT := preload("res://scripts/mobile_hud.gd")
const SHADOW_POLICY := preload("res://scripts/shadow_policy.gd")
const FLASHLIGHT_VISIBILITY := preload("res://scripts/flashlight_visibility.gd")
const PENCIL := preload("res://scripts/pencil.gd")
const RADIAL_GROUND_SHADER := preload("res://shaders/radial_ground.gdshader")
const RUIN_SURFACE_SHADER := preload("res://shaders/ruined_surface.gdshader")
const ARENA_MAP_SCRIPT := preload("res://scripts/arena_map_upgrade.gd")
const STARTING_TOWER := preload("res://scripts/starting_tower.gd")
const ZOMBIE_HORDE_SIZE := 5
const GROUND_ZOMBIE_HORDE_SIZE := 13
const ZOMBIE_PERFORMANCE_CAPACITY := 200
const ZOMBIE_SPAWN_DISTANCE := 50.0
const VISIBILITY_RADIUS := 30.0
# Bilinear 3D scaling keeps the touch HUD at native resolution. The fullscreen
# depth-based flashlight and the arena are rendered at this scale on phones.
const MOBILE_3D_RENDER_SCALE := 0.50
const MOBILE_BALANCED_RENDER_SCALE := 0.67
const PLAYER_BASE_CENTER := Vector3(0.0, 0.0, -5.2)
const PLAYER_BASE_POSITION := PLAYER_BASE_CENTER + Vector3(0.0, StartingTower.HEIGHT + 0.05, 0.0)
const PLAYER_BASE_SAFE_RADIUS := 6.35
const PLAYER_BASE_BOUNDARY_RADIUS := 6.70
const PLAYER_BASE_BOUNDARY_SEGMENTS := 48
const ROOFTOP_SKY_MIN_HEIGHT := StartingTower.HEIGHT - 1.0
# Ground-floor reference: close third-person shoulder framing; keep Thornbound
# large at screen-left with combat clear ahead. The rooftop photo gets its own
# wider, elevated camera profile so the zombie-filled city clears the parapet.
# Height is measured above the player's ground origin, not added to an existing camera offset.
const CAMERA_PIVOT_HEIGHT := 1.20
const CAMERA_FOLLOW_DISTANCE := 2.5
const ROOFTOP_CAMERA_PIVOT_LIFT := 1.0
const ROOFTOP_CAMERA_FOLLOW_DISTANCE := 5.0
const ROOFTOP_CAMERA_PITCH_BIAS_DEGREES := 10.0
const ROOFTOP_CAMERA_BLEND_SPEED := 3.0
const CAMERA_TARGET_SCREEN_X := 0.35
const CAMERA_VERTICAL_FOV := 66.0
const CAMERA_PITCH_DEGREES := -16.0
const CAMERA_YAW_RADIANS_PER_PIXEL := 0.006
const CAMERA_PITCH_RADIANS_PER_PIXEL := 0.004
const GAMEPAD_LOOK_DEADZONE := 0.12
const CAMERA_GAMEPAD_YAW_RADIANS_PER_SECOND := 2.4
const CAMERA_GAMEPAD_PITCH_RADIANS_PER_SECOND := 1.8
const CAMERA_MIN_PITCH_DEGREES := -20.0
const CAMERA_MAX_PITCH_DEGREES := -4.0

var player: FoundationPlayer
var camera_rig: Node3D
var camera_arm: SpringArm3D
var camera: Camera3D
var flashlight_visibility_manager: Node
var flashlight_visibility_enabled := true
var _camera_yaw := 0.0
var _camera_pitch := deg_to_rad(CAMERA_PITCH_DEGREES)
var _rooftop_camera_blend := 0.0
var _rooftop_camera_target := 0.0
var hud: FoundationHUD
var _status_timer := 0.0
var _pending_notice := ""
var _visibility_timer := 0.0
var _floor_material: ShaderMaterial
var _floor_skip_enabled := true
var _mask_comparison_visible := true
var _floor_fast_detail_enabled := false
var _local_lights_enabled := true
var _character_shadows_enabled := false
var _ruin_materials: Dictionary = {}
var _emissive_materials: Dictionary = {}
var _boss_enemy: FoundationEnemy
var _key_light: DirectionalLight3D
var _high_detail_zombie_sample_assigned := false
var _ground_wave_started := false
var burning_horizon: Node3D
var _environment: Environment
var _ground_sky: Sky
var _rooftop_city_sky: Sky
var _rooftop_sky_active := false
var arena_map: Node3D
var starting_tower: StartingTower
var game_music_player: AudioStreamPlayer
var spawn_director: Node3D
var horde_far_visuals: HordeFarVisuals
var performance_diagnostics: FoundationPerformanceDiagnostics
var combat_fx_pool: FoundationCombatFxPool
var _performance_scenario := ""
var _spawn_blockers: Array[AABB] = []

func _ready() -> void:
	if OS.has_feature("mobile"):
		get_viewport().scaling_3d_scale = MOBILE_3D_RENDER_SCALE
		_floor_fast_detail_enabled = true
		_local_lights_enabled = false
	flashlight_visibility_enabled = bool(ProjectSettings.get_setting("gameplay/flashlight_visibility_enabled", true))
	_start_game_music()
	_build_environment()
	_build_arena()
	_build_starting_tower()
	arena_map = ARENA_MAP_SCRIPT.new() as Node3D
	arena_map.name = "AshenQuarantineMap"
	add_child(arena_map)
	player = PLAYER_SCENE.instantiate() as FoundationPlayer
	player.name = "ThornboundPlayer"
	player.position = PLAYER_BASE_POSITION
	player.safe_base_position = PLAYER_BASE_POSITION
	add_child(player)
	player.respawned.connect(_on_player_respawned)
	combat_fx_pool = COMBAT_FX_POOL.new() as FoundationCombatFxPool
	combat_fx_pool.name = "CombatEffectPool"
	combat_fx_pool.visibility_origin = player
	add_child(combat_fx_pool)
	player.combat_fx_pool = combat_fx_pool
	_build_camera()
	flashlight_visibility_manager = FLASHLIGHT_VISIBILITY.new()
	flashlight_visibility_manager.name = "FlashlightVisibilityManager"
	flashlight_visibility_manager.configure(player, camera, flashlight_visibility_enabled)
	add_child(flashlight_visibility_manager)
	player.flashlight_visibility_manager = flashlight_visibility_manager
	burning_horizon = BURNING_HORIZON.new()
	burning_horizon.name = "BurningHorizon"
	add_child(burning_horizon)
	burning_horizon.follow_player(player.global_position)
	_update_rooftop_sky()
	_build_hud()
	_spawn_enemies()
	_setup_performance_diagnostics()
	_update_distance_visibility()
	# Convert lit mesh materials, then draw the graphite pass before the
	# flashlight's priority-126 black mask.
	PENCIL.convert(self)
	PENCIL.set_param(self, &"wash", 0.16)
	var pencil_screen := PENCIL.add_screen_pass(camera)
	pencil_screen.set_shader_parameter(&"line_color", Color(0.075, 0.075, 0.10))
	pencil_screen.set_shader_parameter(&"line_width", 1.7)
	pencil_screen.set_shader_parameter(&"depth_threshold", 0.015)
	pencil_screen.set_shader_parameter(&"crease_threshold", 0.25)
	pencil_screen.set_shader_parameter(&"creases", 0.60)
	pencil_screen.set_shader_parameter(&"wobble", 1.2)
	pencil_screen.set_shader_parameter(&"line_roughness", 0.22)
	pencil_screen.set_shader_parameter(&"fade_start", 19.0)
	pencil_screen.set_shader_parameter(&"fade_end", 34.0)
	pencil_screen.set_shader_parameter(&"saturation", 0.24)
	pencil_screen.set_shader_parameter(&"contrast", 1.12)
	pencil_screen.set_shader_parameter(&"paper_color", Color(0.91, 0.90, 0.86))
	pencil_screen.set_shader_parameter(&"paper_amount", 0.36)
	pencil_screen.set_shader_parameter(&"edge_fade", 0.0)
	_floor_material.set_shader_parameter("player_position", player.global_position)
	_floor_material.set_shader_parameter("flashlight_forward", flashlight_visibility_manager.aim_direction)
	SHADOW_POLICY.disable_in_tree(self)
	_set_character_shadow_state(_character_shadows_enabled)
	player.rage.rage_changed.connect(_refresh_hud)
	player.rage.selection_pending.connect(_on_selection_pending)
	player.rage.condemned.connect(_on_condemned)
	player.health_changed.connect(func(_current: int, _maximum: int) -> void: _refresh_hud())
	player.magic_changed.connect(func(_current: float, _maximum: float, _school: String) -> void: _refresh_hud())
	_refresh_hud(player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold())
	hud.show_notice("Zombies interrupt attacks; only the boss damages HP.")

func _start_game_music() -> void:
	game_music_player = AudioStreamPlayer.new()
	game_music_player.name = "GameMusic"
	var track := GAME_MUSIC.duplicate() as AudioStreamMP3
	track.loop = true
	game_music_player.stream = track
	game_music_player.volume_db = -16.0
	add_child(game_music_player)
	game_music_player.play()

func _process(delta: float) -> void:
	if player == null or camera_rig == null:
		return
	burning_horizon.follow_player(player.global_position)
	_update_rooftop_sky()
	_rooftop_camera_blend = move_toward(
		_rooftop_camera_blend,
		_rooftop_camera_target,
		delta * ROOFTOP_CAMERA_BLEND_SPEED
	)
	var target_position := player.global_position + Vector3.UP * _camera_pivot_height()
	camera_rig.global_position = camera_rig.global_position.lerp(target_position, 1.0 - exp(-delta * 7.5))
	camera_arm.spring_length = _camera_follow_distance()
	camera_arm.rotation.x = _effective_camera_pitch()
	_update_camera_framing()
	_update_gamepad_camera(delta)
	if Input.is_action_just_pressed("interact_elevator"):
		_on_elevator_requested()
	if hud != null and is_instance_valid(starting_tower) and is_instance_valid(starting_tower.elevator):
		hud.set_elevator_prompt(starting_tower.elevator.get_prompt_for_player(player))
	player.set_camera_yaw(_camera_yaw)
	if flashlight_visibility_manager != null:
		flashlight_visibility_manager.set_aim_yaw(_camera_yaw)
	_status_timer += delta
	if _status_timer >= 0.18:
		_status_timer = 0.0
		_refresh_hud(player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold())
	_visibility_timer += delta
	if _visibility_timer >= 0.12:
		_visibility_timer = 0.0
		_update_distance_visibility()
		_update_boss_locator()
	if _floor_material != null and player != null:
		_floor_material.set_shader_parameter("player_position", player.global_position)
		_floor_material.set_shader_parameter("flashlight_forward", flashlight_visibility_manager.aim_direction)

# The physical parapet stops regular movement. Confinement also catches
# unusual aerial dashes or physics tunnelling; never move a grounded player
# upward each tick, so normal floor contact and jumping keep working.
func _physics_process(_delta: float) -> void:
	_enforce_rooftop_boundary()


func _enforce_rooftop_boundary() -> void:
	if not is_instance_valid(player) or not is_instance_valid(starting_tower):
		return
	if is_instance_valid(starting_tower.elevator) and starting_tower.elevator.is_player_riding(player):
		return
	var local_at := starting_tower.to_local(player.global_position)
	# Ground-floor travel is a normal gameplay route after leaving the lift.
	if local_at.y < 5.0:
		return
	var safe_half := StartingTower.ROOF_SAFE_HALF_EXTENT
	var adjusted_at := Vector3(
		clampf(local_at.x, -safe_half, safe_half),
		local_at.y,
		clampf(local_at.z, -safe_half, safe_half)
	)
	# Reset only after falling below the solid roof; avoid disrupting contact
	# when the capsule naturally settles on the rooftop at y = HEIGHT.
	if local_at.y < StartingTower.HEIGHT - 0.50 and not starting_tower.elevator.contains_local_shaft(local_at):
		adjusted_at.y = StartingTower.HEIGHT + 0.05
	if local_at.is_equal_approx(adjusted_at):
		return
	player.global_position = starting_tower.to_global(adjusted_at)
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.velocity.y = maxf(0.0, player.velocity.y)


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	_environment = environment
	_ground_sky = BURNING_HORIZON.make_sky()
	var city_material := ShaderMaterial.new()
	city_material.shader = ROOFTOP_LOWER_SKY_SHADER
	city_material.set_shader_parameter("lower_city_panorama", ROOFTOP_CITY_TEXTURE)
	_rooftop_city_sky = Sky.new()
	_rooftop_city_sky.sky_material = city_material
	_rooftop_city_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	# The photo fills the lower field of view from the rooftop while the
	# existing procedural sky continues overhead. The flashlight still
	# blacks out the ground-level sky; the world sky is unobscured on the roof.
	environment.background_mode = Environment.BG_SKY
	environment.sky = _ground_sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE if flashlight_visibility_enabled else Color(0.43, 0.39, 0.40)
	environment.ambient_light_energy = 0.72 if flashlight_visibility_enabled else 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = not flashlight_visibility_enabled
	environment.fog_light_color = Color(0.23, 0.15, 0.14)
	environment.fog_light_energy = 0.7
	environment.fog_depth_begin = 24.0
	environment.fog_depth_end = VISIBILITY_RADIUS
	environment.fog_density = 0.004
	environment.fog_sun_scatter = 0.10
	environment.glow_enabled = not flashlight_visibility_enabled
	environment.glow_intensity = 0.28
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 0.88
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "ChemicalDuskKeyLight"
	sun.rotation_degrees = Vector3(-39.0, -34.0, 0.0)
	sun.light_color = Color.WHITE if flashlight_visibility_enabled else Color(1.0, 0.72, 0.54)
	sun.light_energy = 1.0 if flashlight_visibility_enabled else 1.15
	sun.shadow_enabled = false
	_key_light = sun
	add_child(sun)

func _update_rooftop_sky() -> void:
	# Hold the current camera and render profile for the full elevator ride.
	# Apply the floor change once the arrival signal confirms the car has stopped.
	if _is_player_in_elevator():
		return
	var on_roof := player.global_position.y >= ROOFTOP_SKY_MIN_HEIGHT
	_rooftop_camera_target = 1.0 if on_roof else 0.0
	if on_roof == _rooftop_sky_active:
		return
	_rooftop_sky_active = on_roof
	_environment.sky = _rooftop_city_sky if on_roof else _ground_sky
	# Keep the original four-panel Burning Horizon for ground-level play.
	burning_horizon.visible = not on_roof
	flashlight_visibility_manager.set_rooftop_sky_visible(on_roof)


func _is_player_in_elevator() -> bool:
	return (
		is_instance_valid(player)
		and is_instance_valid(starting_tower)
		and is_instance_valid(starting_tower.elevator)
		and starting_tower.elevator.is_player_riding(player)
	)

func _build_arena() -> void:
	var ground := StaticBody3D.new()
	ground.name = "QuarantineCourtyardGround"
	ground.collision_layer = 1
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(220.0, 0.35, 220.0)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.18
	ground.add_child(ground_collision)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(220.0, 220.0)
	floor.mesh = floor_mesh
	_floor_material = ShaderMaterial.new()
	_floor_material.shader = RADIAL_GROUND_SHADER
	_floor_material.set_shader_parameter("floor_color", Color(0.105, 0.118, 0.135))
	_floor_material.set_shader_parameter("player_position", Vector3.ZERO)
	_floor_material.set_shader_parameter("floor_skip_enabled", flashlight_visibility_enabled)
	_floor_material.set_shader_parameter("floor_fast_detail", _floor_fast_detail_enabled)
	floor.material_override = _floor_material
	floor.add_to_group("radial_floor")
	ground.add_child(floor)
	add_child(ground)

	var concrete := _material(Color(0.24, 0.255, 0.27), 0.93)
	var dark_concrete := _material(Color(0.075, 0.085, 0.10), 0.98)
	var rust := _material(Color(0.29, 0.15, 0.10), 0.88)
	var hazard := _material(Color(0.78, 0.32, 0.10), 0.74)
	var glass := _material(Color(0.035, 0.065, 0.078), 0.26, 0.55)

	# Enclosed edges and a broken industrial skyline keep the combat space readable.
	# Keep the encounter courtyard open so horde members can approach from 50 m.
	_add_arena_box("WestWorldBoundary", Vector3(-100.0, 2.1, 0.0), Vector3(0.9, 4.2, 200.0), concrete, true)
	_add_arena_box("EastWorldBoundary", Vector3(100.0, 2.1, 0.0), Vector3(0.9, 4.2, 200.0), concrete, true)
	_add_arena_box("NorthWorldBoundary", Vector3(0.0, 2.1, -100.0), Vector3(200.0, 4.2, 0.9), concrete, true)
	_add_arena_box("SouthWorldBoundary", Vector3(0.0, 2.1, 100.0), Vector3(200.0, 4.2, 0.9), concrete, true)
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
	_add_player_base_boundary()
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

func _build_starting_tower() -> void:
	# Begin gameplay on the enclosed rooftop instead of inside the tower.
	# Its northern exit faces the existing courtyard and boss approach.
	starting_tower = STARTING_TOWER.new() as StartingTower
	starting_tower.name = "StartingTower"
	starting_tower.position = PLAYER_BASE_CENTER
	starting_tower.configure(_material(Color(0.16, 0.18, 0.19), 0.94),
		_material(Color(0.32, 0.19, 0.13), 0.84))
	add_child(starting_tower)
	starting_tower.elevator.rider_arrived.connect(_on_elevator_rider_arrived)
	# Exclude the tower volume from concealed enemy placement, even in
	# performance scenarios; the existing enemy-safe base remains intact.
	var half_width := StartingTower.WIDTH * 0.5
	_spawn_blockers.append(AABB(
		PLAYER_BASE_CENTER + Vector3(-half_width, 0.0, -half_width),
		Vector3(StartingTower.WIDTH, StartingTower.HEIGHT, StartingTower.WIDTH)
	))


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
		body.add_to_group("zombie_spawn_occluder")
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
	if not collidable and dimensions.y >= 1.0:
		# Non-colliding skyline buildings still cannot contain new enemies.
		_spawn_blockers.append(root.global_transform * AABB(-dimensions * 0.5, dimensions))

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

func _add_player_base_boundary() -> void:
	# Segment colliders form a low-cost invisible wall. Ordinary enemies and the
	# boss collide with layer 3; the player mask omits that layer and can leave.
	var segment_length := 2.0 * PLAYER_BASE_BOUNDARY_RADIUS * sin(PI / float(PLAYER_BASE_BOUNDARY_SEGMENTS)) + 0.08
	for index in range(PLAYER_BASE_BOUNDARY_SEGMENTS):
		var angle := TAU * (float(index) + 0.5) / float(PLAYER_BASE_BOUNDARY_SEGMENTS)
		var barrier := StaticBody3D.new()
		barrier.name = "PlayerBaseBoundary_%02d" % index
		barrier.collision_layer = 4
		barrier.collision_mask = 2
		barrier.position = PLAYER_BASE_CENTER + Vector3(cos(angle) * PLAYER_BASE_BOUNDARY_RADIUS, 1.25, sin(angle) * PLAYER_BASE_BOUNDARY_RADIUS)
		barrier.rotation.y = angle - PI * 0.5
		barrier.add_to_group("zombie_base_boundary")
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(segment_length, 2.5, 0.65)
		collision.shape = shape
		barrier.add_child(collision)
		add_child(barrier)

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
	bulb.material_override = _emissive_material(tint)
	lamp.add_child(bulb)
	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 0.72
	light.omni_range = 9.0
	light.shadow_enabled = false
	light.visible = _local_lights_enabled
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
	flame.material_override = _emissive_material(flame_color)
	brazier.add_child(flame)
	var light := OmniLight3D.new()
	light.position.y = 0.98
	light.light_color = flame_color
	light.light_energy = 0.82
	light.omni_range = 8.0
	light.shadow_enabled = false
	light.visible = _local_lights_enabled
	brazier.add_child(light)

func _build_camera() -> void:
	camera_rig = Node3D.new()
	camera_rig.name = "FollowCameraRig"
	_rooftop_camera_blend = 1.0 if player.global_position.y >= ROOFTOP_SKY_MIN_HEIGHT else 0.0
	_rooftop_camera_target = _rooftop_camera_blend
	camera_rig.position = player.global_position + Vector3.UP * _camera_pivot_height()
	_camera_yaw = player.rotation.y
	camera_rig.rotation.y = _camera_yaw
	add_child(camera_rig)
	camera_arm = SpringArm3D.new()
	camera_arm.name = "CollisionSpringArm"
	camera_arm.spring_length = _camera_follow_distance()
	camera_arm.margin = 0.15
	camera_arm.collision_mask = 1
	camera_arm.add_excluded_object(player.get_rid())
	camera_arm.rotation.x = _effective_camera_pitch()
	camera_rig.add_child(camera_arm)
	camera = Camera3D.new()
	camera.name = "BehindPlayerCamera"
	camera.fov = CAMERA_VERTICAL_FOV
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.08
	camera.far = 140.0
	camera.current = true
	camera.add_to_group("foundation_camera")
	camera_arm.add_child(camera)
	_update_camera_framing()

func _update_camera_framing() -> void:
	if camera_arm == null or camera == null or not is_instance_valid(camera):
		return
	var viewport_size := camera.get_viewport().get_visible_rect().size
	if viewport_size.y <= 1.0:
		return
	var aspect := viewport_size.x / viewport_size.y
	var half_horizontal_fov := atan(tan(deg_to_rad(CAMERA_VERTICAL_FOV * 0.5)) * aspect)
	# Camera-space shoulder framing keeps the player in the lower-left reference
	# region without shifting the player model away from the protected base.
	camera_arm.position.x = (0.5 - CAMERA_TARGET_SCREEN_X) * 2.0 * _camera_follow_distance() * tan(half_horizontal_fov)

func _camera_pivot_height() -> float:
	return CAMERA_PIVOT_HEIGHT + ROOFTOP_CAMERA_PIVOT_LIFT * _rooftop_camera_blend

func _camera_follow_distance() -> float:
	return lerpf(CAMERA_FOLLOW_DISTANCE, ROOFTOP_CAMERA_FOLLOW_DISTANCE, _rooftop_camera_blend)

func _effective_camera_pitch() -> float:
	return _camera_pitch + deg_to_rad(ROOFTOP_CAMERA_PITCH_BIAS_DEGREES) * _rooftop_camera_blend

func _build_hud() -> void:
	hud = HUD_SCRIPT.new() as FoundationHUD
	hud.name = "MobileCombatHUD"
	hud.action_requested.connect(_on_hud_action)
	hud.elevator_requested.connect(_on_elevator_requested)
	hud.aura_chosen.connect(_on_aura_chosen)
	hud.camera_dragged.connect(_on_camera_dragged)
	add_child(hud)

func _on_camera_dragged(relative: Vector2) -> void:
	_apply_camera_look(
		-relative.x * CAMERA_YAW_RADIANS_PER_PIXEL,
		-relative.y * CAMERA_PITCH_RADIANS_PER_PIXEL
	)

func _update_gamepad_camera(delta: float) -> void:
	if get_tree().paused or (hud != null and hud._selection_panel != null):
		return
	var look := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if look.length() < GAMEPAD_LOOK_DEADZONE:
		return
	_apply_camera_look(
		-look.x * CAMERA_GAMEPAD_YAW_RADIANS_PER_SECOND * delta,
		-look.y * CAMERA_GAMEPAD_PITCH_RADIANS_PER_SECOND * delta
	)

func _apply_camera_look(yaw_delta: float, pitch_delta: float) -> void:
	_camera_yaw = wrapf(_camera_yaw + yaw_delta, -PI, PI)
	_camera_pitch = clampf(
		_camera_pitch + pitch_delta,
		deg_to_rad(CAMERA_MIN_PITCH_DEGREES),
		deg_to_rad(CAMERA_MAX_PITCH_DEGREES)
	)
	if camera_rig != null:
		camera_rig.rotation.y = _camera_yaw
	if camera_arm != null:
		camera_arm.rotation.x = _effective_camera_pitch()
	if player != null:
		player.set_camera_yaw(_camera_yaw)
	if flashlight_visibility_manager != null:
		flashlight_visibility_manager.set_aim_yaw(_camera_yaw)

func _spawn_enemies() -> void:
	horde_far_visuals = HORDE_FAR_VISUALS.new()
	horde_far_visuals.configure(ZOMBIE_PERFORMANCE_CAPACITY)
	horde_far_visuals.player = player
	horde_far_visuals.visibility_manager = flashlight_visibility_manager
	add_child(horde_far_visuals)
	spawn_director = CONCEALED_SPAWN.new()
	spawn_director.name = "ConcealedForwardSpawns"
	spawn_director.player = player
	spawn_director.camera = camera
	spawn_director.population_limit = ZOMBIE_HORDE_SIZE
	spawn_director.spawn_distance = ZOMBIE_SPAWN_DISTANCE
	spawn_director.visibility_radius = VISIBILITY_RADIUS
	spawn_director.blocked_boxes = _spawn_blockers
	spawn_director.spawn_requested.connect(_spawn_assault_zombie)
	add_child(spawn_director)
	# Seed the opening horde around the arena, concealed beyond the 30 m view.
	spawn_director.request_initial_population()
	# Keep one boss in the original arena; the HUD locator can point to it when
	# the player moves beyond the 30 m render radius.
	_spawn_enemy("boss", Vector3(0.6, 0.05, -16.2), true)

func _spawn_assault_zombie(at: Vector3) -> void:
	var is_visual_sample := not _high_detail_zombie_sample_assigned
	if is_visual_sample:
		_high_detail_zombie_sample_assigned = true
	var enemy := _spawn_enemy("shambler", at, false, is_visual_sample)
	spawn_director.register_enemy(enemy)
	horde_far_visuals.register_enemy(enemy)
	enemy.begin_spawn_assault(player)

func _spawn_enemy(kind: String, at: Vector3, boss_target: bool = false, high_detail_visual_sample: bool = false) -> FoundationEnemy:
	var enemy := ENEMY_SCRIPT.new() as FoundationEnemy
	enemy.configure(kind, boss_target, high_detail_visual_sample)
	enemy.position = at
	enemy._player = player
	enemy.set_quality_shadow_enabled(_character_shadows_enabled)
	enemy.combat_fx_pool = combat_fx_pool
	enemy.telegraph_started.connect(_on_enemy_telegraph)
	enemy.defeated.connect(_on_enemy_defeated)
	add_child(enemy)
	if enemy.is_boss:
		_boss_enemy = enemy
		flashlight_visibility_manager.track_enemy(enemy)
		enemy.tree_exiting.connect(flashlight_visibility_manager.untrack_enemy.bind(enemy.get_instance_id()))
		var label := Label3D.new()
		label.text = "BOSS"
		label.position = Vector3(0.0, 3.35, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 22
		label.outline_size = 6
		label.modulate = Color(1.0, 0.18, 0.12)
		enemy.attach_status_label(label)
	return enemy

func _on_elevator_requested() -> void:
	_interact_with_starting_elevator()

func _on_elevator_rider_arrived(floor: StringName) -> void:
	# Arrival is the single transition point for the roof/ground render profile.
	_update_rooftop_sky()
	if floor != &"ground" or _ground_wave_started or not is_instance_valid(spawn_director):
		return
	_ground_wave_started = true
	if not _performance_scenario.is_empty():
		return
	spawn_director.population_limit = GROUND_ZOMBIE_HORDE_SIZE
	# Bring this new wave into the fight during its 4.5 s opening assault,
	# while keeping every visual envelope outside the 30 m culling edge.
	spawn_director.initial_spawn_min_distance = 34.0
	spawn_director.initial_spawn_max_distance = 45.0
	# Existing rooftop zombies count toward the wave. The remaining slots use
	# the concealed all-around opening sampler, capped at two births per tick.
	spawn_director.request_initial_population()

func _on_player_respawned() -> void:
	if is_instance_valid(starting_tower) and is_instance_valid(starting_tower.elevator):
		starting_tower.elevator.reset_to_roof()
	_update_rooftop_sky()
	_rooftop_camera_blend = 1.0
	_rooftop_camera_target = 1.0
	if is_instance_valid(camera_rig):
		camera_rig.global_position = player.global_position + Vector3.UP * _camera_pivot_height()
	if is_instance_valid(camera_arm):
		camera_arm.spring_length = _camera_follow_distance()
		camera_arm.rotation.x = _effective_camera_pitch()
	_update_camera_framing()
	# A new rooftop life starts with five ordinary zombies, even if the last
	# life had activated the thirteen-zombie ground encounter.
	_ground_wave_started = false
	_performance_scenario = ""
	_reset_ordinary_population()

func _interact_with_starting_elevator() -> bool:
	if get_tree().paused or not is_instance_valid(player) or not is_instance_valid(starting_tower) or not is_instance_valid(starting_tower.elevator):
		return false
	return starting_tower.elevator.interact(player)

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
		"cast_spell": player.cast_spell()
		"blast": player.cast_blast()
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

func _on_enemy_defeated(enemy: Node) -> void:
	if enemy == _boss_enemy:
		_boss_enemy = null
		hud.hide_boss_marker()
		return
	if is_instance_valid(spawn_director):
		spawn_director.replace_enemy(enemy)

func _update_boss_locator() -> void:
	if hud == null or not is_instance_valid(_boss_enemy) or _boss_enemy.hp <= 0:
		if hud != null:
			hud.hide_boss_marker()
		return
	var target := _boss_enemy.global_position + Vector3(0.0, 2.8, 0.0)
	hud.update_boss_marker(camera.unproject_position(target), player.global_position.distance_to(_boss_enemy.global_position), camera.is_position_behind(target))

func _update_distance_visibility() -> void:
	if player == null:
		return
	_apply_distance_visibility(self)

func _apply_distance_visibility(node: Node) -> void:
	# Enemy rigs own their 18/30 m bands; walking every bone and mesh every
	# 120 ms scales with the full 200-zombie population.
	if node is FoundationEnemy or node == horde_far_visuals or node.is_in_group("distant_backdrop") or node.is_in_group("static_map_batch") or node.is_in_group("nature_scenery_batch") or node.is_in_group("flashlight_beam"):
		return
	if node.is_in_group("radial_floor"):
		node.visible = true
	elif node is GeometryInstance3D or node is Label3D:
		node.visible = node.global_position.distance_squared_to(player.global_position) <= VISIBILITY_RADIUS * VISIBILITY_RADIUS
	elif node is OmniLight3D or node is SpotLight3D:
		node.visible = _local_lights_enabled and node.global_position.distance_squared_to(player.global_position) <= VISIBILITY_RADIUS * VISIBILITY_RADIUS
	for child in node.get_children():
		_apply_distance_visibility(child)

func _refresh_hud(_a: float = 0.0, _b: float = 0.0, _c: float = 0.0) -> void:
	if hud == null or player == null:
		return
	hud.update_status(player.health, player.MAX_HEALTH, player.rage.rage, player.rage.maximum_rage, player.rage.condemnation_threshold(), player.magic_energy, player.current_spell, player.rage.unlocked_spells)

func _material(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> ShaderMaterial:
	var key := [color, roughness, metallic]
	if _ruin_materials.has(key):
		return _ruin_materials[key] as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = RUIN_SURFACE_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("surface_roughness", roughness)
	material.set_shader_parameter("surface_metallic", metallic)
	_ruin_materials[key] = material
	return material

func _emissive_material(color: Color) -> StandardMaterial3D:
	if _emissive_materials.has(color):
		return _emissive_materials[color] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_emissive_materials[color] = material
	return material

func _setup_performance_diagnostics() -> void:
	# Keep all profiling UI and controls out of release gameplay.
	if not OS.is_debug_build():
		return
	performance_diagnostics = PERFORMANCE_DIAGNOSTICS.new() as FoundationPerformanceDiagnostics
	performance_diagnostics.name = "DevelopmentPerformanceDiagnostics"
	performance_diagnostics.scenario_requested.connect(start_performance_scenario)
	performance_diagnostics.stop_requested.connect(stop_performance_scenario)
	performance_diagnostics.render_scale_requested.connect(_set_debug_render_scale)
	performance_diagnostics.mask_comparison_requested.connect(_set_debug_mask_visible)
	performance_diagnostics.map_comparison_requested.connect(_set_debug_map_visible)
	performance_diagnostics.floor_skip_comparison_requested.connect(_set_debug_floor_skip_enabled)
	performance_diagnostics.floor_detail_comparison_requested.connect(_set_debug_floor_fast_detail_enabled)
	performance_diagnostics.set_initial_floor_detail_mode(_floor_fast_detail_enabled)
	performance_diagnostics.local_lights_comparison_requested.connect(_set_debug_local_lights_enabled)
	performance_diagnostics.set_initial_local_lights_mode(_local_lights_enabled)
	performance_diagnostics.character_shadows_comparison_requested.connect(_set_debug_character_shadows_enabled)
	performance_diagnostics.set_initial_character_shadows_mode(_character_shadows_enabled)
	add_child(performance_diagnostics)

func _set_debug_render_scale(scale: float) -> void:
	if OS.is_debug_build() and [MOBILE_3D_RENDER_SCALE, MOBILE_BALANCED_RENDER_SCALE, 1.0].has(scale):
		get_viewport().scaling_3d_scale = scale

func _set_debug_mask_visible(is_visible: bool) -> void:
	if OS.is_debug_build() and flashlight_visibility_manager != null:
		_mask_comparison_visible = is_visible
		flashlight_visibility_manager.set_composite_visible_for_comparison(is_visible)
		_update_floor_skip_enabled()

func _set_debug_floor_skip_enabled(is_enabled: bool) -> void:
	if OS.is_debug_build():
		_floor_skip_enabled = is_enabled
		_update_floor_skip_enabled()

func _set_debug_floor_fast_detail_enabled(is_enabled: bool) -> void:
	if OS.is_debug_build() and _floor_material != null:
		_floor_fast_detail_enabled = is_enabled
		_floor_material.set_shader_parameter("floor_fast_detail", is_enabled)

func _set_debug_local_lights_enabled(is_enabled: bool) -> void:
	if OS.is_debug_build():
		_local_lights_enabled = is_enabled
		_update_distance_visibility()

func _set_debug_character_shadows_enabled(is_enabled: bool) -> void:
	if OS.is_debug_build():
		_character_shadows_enabled = is_enabled
		_set_character_shadow_state(is_enabled)

func _set_character_shadow_state(is_enabled: bool) -> void:
	if _key_light != null:
		_key_light.shadow_enabled = is_enabled
	if is_instance_valid(player) and player.visual_root != null:
		for node in player.visual_root.find_children("*", "GeometryInstance3D", true, false):
			var instance := node as GeometryInstance3D
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if is_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _update_floor_skip_enabled() -> void:
	if _floor_material != null:
		# The mask A/B control restores the unmasked ground as well.
		_floor_material.set_shader_parameter("floor_skip_enabled",
			flashlight_visibility_enabled and _mask_comparison_visible and _floor_skip_enabled)

func _set_debug_map_visible(is_visible: bool) -> void:
	if OS.is_debug_build() and is_instance_valid(arena_map):
		arena_map.visible = is_visible

func start_performance_scenario(population: int, mode: String) -> bool:
	if not [15, 20, 69, 100, 200].has(population) or not ["concentrated", "approach"].has(mode):
		return false
	if not is_instance_valid(spawn_director) or not is_instance_valid(player):
		return false

	# Scenario changes are transient and isolated to debug profiling. Clear only
	# ordinary zombies; keep the boss, arena, camera, HUD, and gameplay systems.
	spawn_director.set_physics_process(false)
	spawn_director._live.clear()
	spawn_director._pending.clear()
	spawn_director._initial_population_pending = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is FoundationEnemy and not enemy.is_boss:
			enemy.queue_free()

	spawn_director.population_limit = population
	_performance_scenario = "%d/%s" % [population, mode]
	# The spawn director's candidate selection and enemy initial state use the
	# global RNG. A fixed seed makes comparison runs repeatable where practical.
	seed(0xB1A7 + population + (1000 if mode == "approach" else 0))
	if mode == "concentrated":
		for index in range(population):
			var angle := float(index) * 2.399963229728653
			var radius := 3.5 + 8.5 * sqrt((float(index) + 0.5) / float(population))
			var offset := Vector3(cos(angle) * radius, 0.05, sin(angle) * radius)
			var enemy := _spawn_enemy("shambler", player.global_position + offset)
			spawn_director.register_enemy(enemy)
			horde_far_visuals.register_enemy(enemy)
		spawn_director.set_physics_process(true)
	else:
		spawn_director.set_physics_process(true)
		spawn_director.request_population()
	return true

func stop_performance_scenario() -> void:
	_performance_scenario = ""
	_reset_ordinary_population()

func _reset_ordinary_population() -> void:
	if not is_instance_valid(spawn_director):
		return
	var was_processing := spawn_director.is_physics_processing()
	spawn_director.set_physics_process(false)
	spawn_director._live.clear()
	spawn_director._pending.clear()
	spawn_director._initial_population_pending = 0
	spawn_director._recent.clear()
	spawn_director._retry_time = 0.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is FoundationEnemy and not enemy.is_boss:
			enemy.queue_free()
	spawn_director.population_limit = GROUND_ZOMBIE_HORDE_SIZE if _ground_wave_started else ZOMBIE_HORDE_SIZE
	spawn_director.initial_spawn_min_distance = 34.0 if _ground_wave_started else CONCEALED_SPAWN.INITIAL_SPAWN_MIN_DISTANCE
	spawn_director.initial_spawn_max_distance = 45.0 if _ground_wave_started else CONCEALED_SPAWN.INITIAL_SPAWN_MAX_DISTANCE
	# Restore the active floor's ordinary population with a concealed map spread.
	seed(int(Time.get_ticks_usec() & 0x7fffffff))
	spawn_director.request_initial_population()
	spawn_director.set_physics_process(was_processing)
