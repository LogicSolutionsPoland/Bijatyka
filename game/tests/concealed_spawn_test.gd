extends SceneTree

const Director := preload("res://scripts/concealed_spawn.gd")
const Foundation := preload("res://scripts/foundation.gd")
const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _box(parent: Node3D, at: Vector3, size: Vector3, opaque: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	if not opaque:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	body.add_child(mesh)
	body.add_to_group("zombie_spawn_occluder")
	parent.add_child(body)
	return body

func _fixture() -> Node3D:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Player.new() as FoundationPlayer
	player.name = "Player"
	player.set_physics_process(false)
	fixture.add_child(player)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(0, 2.5, 4)
	camera.fov = 66.0
	camera.current = true
	fixture.add_child(camera)
	var director := Director.new()
	director.name = "Director"
	director.player = player
	director.camera = camera
	director.set_physics_process(false)
	fixture.add_child(director)
	var ground := _box(fixture, Vector3(0, -0.2, 0), Vector3(220, 0.4, 220))
	ground.name = "Ground"
	ground.remove_from_group("zombie_spawn_occluder")
	return fixture

func run() -> void:
	root.size = Vector2i(1280, 720)
	await _test_placement_and_visibility()
	await _test_initial_population_distribution()
	await _test_assault()
	await _test_wall_collision()
	await _test_player_base_boundary()
	await _test_elevator_ground_wave()
	await _test_attacker_slots()
	await _test_population_and_replacements()
	if failures.is_empty():
		print("PASS: concealed spawn — %d checks" % checks)
	else:
		for message in failures:
			push_error(message)
		print("FAIL: concealed spawn — %d of %d checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _test_placement_and_visibility() -> void:
	var fixture := _fixture()
	var director = fixture.get_node("Director")
	var player := fixture.get_node("Player") as FoundationPlayer
	var camera := fixture.get_node("Camera") as Camera3D
	await physics_frame
	check(director.forward_direction().is_equal_approx(Vector3.FORWARD), "stationary spawn direction uses player heading")
	camera.rotation.y = PI * 0.5
	check(director.forward_direction().is_equal_approx(Vector3.FORWARD), "independent camera look cannot change the forward spawn arc")
	player.velocity = Vector3(4, 20, 0)
	check(director.forward_direction().is_equal_approx(Vector3.RIGHT), "horizontal movement takes priority and ignores vertical dash speed")
	player.velocity = Vector3.ZERO
	camera.rotation.y = 0.0
	for index in range(160):
		var at: Vector3 = director._sample_candidate()
		check(at.length() >= 46.0 and at.length() <= 54.0 and at.normalized().dot(Vector3.FORWARD) >= cos(Director.FORWARD_HALF_ANGLE) - 0.001, "sample stays in the forward 50 m band")
	var far := Vector3(0, 0.05, -50)
	check(director.is_valid_spawn(far), "concealed open ground at 50 m is accepted")
	check(director._grounded_candidate(far).distance_to(far) < 0.01, "floor ray places feet above actual ground")
	check(director.is_concealed(far), "30 m cull conceals the whole far envelope even inside the frustum")
	check(not director.is_concealed(Vector3(0, 0.05, -20)), "visible unobstructed point is rejected")
	check(not director.is_valid_spawn(Vector3(0, 0.05, 50)), "rear spawn is rejected")
	check(not director.is_valid_spawn(Vector3(0, 0.05, -8)), "spawn cannot create immediate contact")
	check(not director.is_valid_spawn(Vector3(95, 0.05, -50)), "world boundary cannot be bypassed")
	check(director.is_concealed(Vector3(25, 0.05, -13)), "whole volume outside actual camera frustum is concealed")
	camera.look_at(Vector3(25, 1.6, -13))
	check(not director.is_concealed(Vector3(25, 0.05, -13)), "rotating the actual camera changes concealment immediately")
	camera.rotation = Vector3.ZERO
	var partial_envelope_rejected := false
	for x in range(8, 25):
		var at := Vector3(float(x), 0.05, -16)
		if not camera.is_position_in_frustum(at + Vector3.UP * 1.6) and not director.is_concealed(at):
			partial_envelope_rejected = true
	check(partial_envelope_rejected, "frustum-edge placement checks the full envelope, not only its center")
	# Camera-center and far-plane tests also exercise the orientation of frustum planes.
	check(not director.is_concealed(Vector3(0, 0.05, -12)), "in-frustum near envelope cannot be classified as outside a plane")
	var wall := _box(fixture, Vector3(0, 2.5, -10), Vector3(12, 5, 1))
	await physics_frame
	check(director.is_concealed(Vector3(0, 0.05, -20)), "opaque cover blocks every corner of the spawn envelope")
	var cover_mesh := wall.get_child(1) as MeshInstance3D
	var pencil_cover := Pencil.from_material(StandardMaterial3D.new())
	cover_mesh.material_override = pencil_cover
	check(director.is_concealed(Vector3(0, 0.05, -20)), "opaque Pencil cover blocks a concealed spawn")
	var ruin_cover := ShaderMaterial.new()
	ruin_cover.shader = load("res://shaders/ruined_surface.gdshader")
	cover_mesh.material_override = ruin_cover
	check(director.is_concealed(Vector3(0, 0.05, -20)), "opaque ruin shader blocks a concealed spawn")
	var transparent_cover := StandardMaterial3D.new()
	transparent_cover.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cover_mesh.material_override = transparent_cover
	check(not director.is_concealed(Vector3(0, 0.05, -20)), "transparent cover cannot conceal a spawn")
	cover_mesh.material_override = pencil_cover
	cover_mesh.visible = false
	check(not director.is_concealed(Vector3(0, 0.05, -20)), "invisible collider cannot serve as visual cover")
	cover_mesh.visible = true
	cover_mesh.position.x = 10.0
	check(not director.is_concealed(Vector3(0, 0.05, -20)), "cover mesh must actually match its collider")
	wall.queue_free()
	await process_frame
	var low_wall := _box(fixture, Vector3(0, 0.5, -10), Vector3(12, 1, 1))
	await physics_frame
	check(not director.is_concealed(Vector3(0, 0.05, -20)), "low cover cannot conceal exposed head or arms")
	low_wall.queue_free()
	await process_frame
	var pillar := _box(fixture, Vector3(0, 2.5, -10), Vector3(0.25, 5, 1))
	await physics_frame
	check(not director.is_concealed(Vector3(0, 0.05, -20)), "a blocked center ray is insufficient beside a narrow pillar")
	pillar.queue_free()
	await process_frame
	var glass := _box(fixture, Vector3(0, 2.5, -10), Vector3(12, 5, 1), false)
	await physics_frame
	check(not director.is_concealed(Vector3(0, 0.05, -20)), "transparent collider is not visual cover")
	glass.queue_free()
	await process_frame
	var area := Area3D.new()
	area.position = Vector3(0, 1, -50)
	area.collision_layer = 128
	var area_shape := CollisionShape3D.new()
	var reserved := BoxShape3D.new()
	reserved.size = Vector3(6, 2, 6)
	area_shape.shape = reserved
	area.add_child(area_shape)
	fixture.add_child(area)
	await physics_frame
	check(not director.is_valid_spawn(far), "protected Area3D on another collision layer excludes spawning")
	area.queue_free()
	await process_frame
	await physics_frame
	var obstacle := _box(fixture, Vector3(0, 1.5, -50), Vector3(3, 3, 3))
	await physics_frame
	check(not director.is_valid_spawn(far), "capsule cannot be born inside a world obstacle")
	obstacle.queue_free()
	await process_frame
	var lane_blocker := _box(fixture, Vector3(0, 1.5, -47), Vector3(3, 3, 1))
	await physics_frame
	check(not director.is_valid_spawn(far), "dash needs four meters of initial world clearance")
	lane_blocker.queue_free()
	await process_frame
	var occupant := Enemy.new() as FoundationEnemy
	occupant.position = far
	occupant.set_physics_process(false)
	fixture.add_child(occupant)
	await physics_frame
	await physics_frame
	check(not director.is_valid_spawn(far), "live zombie occupancy excludes another spawn")
	occupant.queue_free()
	await process_frame
	await physics_frame
	director.blocked_boxes.append(AABB(Vector3(-3, 0, -53), Vector3(6, 10, 6)))
	check(not director.is_valid_spawn(far), "non-colliding visual buildings also exclude spawning")
	director.blocked_boxes.clear()
	player.safe_base_position = far
	check(not director.is_valid_spawn(far), "safe return base is protected")
	player.safe_base_position = Vector3(0.0, 0.05, -50.0)
	check(not director.is_valid_spawn(Vector3(0.0, 0.05, -43.0)), "7.5 m base exclusion applies even when the player is farther away")
	player.safe_base_position = Vector3.ZERO
	director._recent.append({"position": far, "time": 0.0})
	check(not director.is_valid_spawn(far + Vector3.RIGHT), "recent spots retain a two meter exclusion")
	director._recent.clear()
	check(director.is_valid_spawn(far), "removing exclusions restores the valid placement")
	var ground := fixture.get_node("Ground/CollisionShape3D") as CollisionShape3D
	ground.disabled = true
	await physics_frame
	check(not director._grounded_candidate(far).is_finite(), "unsupported ground is deferred")
	director.camera = null
	check(not director.is_concealed(far), "missing actual camera fails closed")
	fixture.queue_free()
	await process_frame

func _test_assault() -> void:
	var fixture := _fixture()
	var player := fixture.get_node("Player") as FoundationPlayer
	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Vector3(0, 0.05, -50)
	enemy.set_physics_process(false)
	fixture.add_child(enemy)
	await physics_frame
	check(enemy.begin_spawn_assault(player), "new ordinary zombie activates its assault")
	check(enemy.state == "assault" and enemy.combat_target == player, "activation targets the player without changing existing AI targets")
	check(enemy.velocity.z > enemy.move_speed * 1.45, "pursuit burst is faster than existing chase immediately")
	check((-enemy.global_basis.z).dot(Vector3.BACK) > 0.99, "zombie faces its pursuit before becoming visible")
	check(not enemy._visual_root.visible, "far newborn is culled before the first frame")
	check(enemy._animation_player == null or not enemy._animation_player.is_playing(), "far assault does not restart a culled animation")
	player.position.x = 8.0
	enemy._update_ai(0.1, 50.0)
	check(enemy.velocity.x > 0.0 and enemy.velocity.z > 0.0, "burst steers toward the player's current location")
	enemy.apply_slow(0.5, 1.0)
	enemy._update_ai(0.1, 50.0)
	check(is_equal_approx(Vector2(enemy.velocity.x, enemy.velocity.z).length(), enemy.move_speed * Enemy.SPAWN_ASSAULT_SPEED_MULTIPLIER * 0.5), "burst respects existing slow effects")
	enemy.receive_hit(1)
	check(enemy._spawn_assault_time == 0.0 and enemy.state == "hit", "rival or player damage cancels assault and preserves hit reaction")
	enemy.begin_spawn_assault(player)
	enemy.apply_stun(0.5)
	check(enemy._spawn_assault_time == 0.0 and enemy.stun_time > 0.0, "stun cancels the burst")
	enemy.stun_time = 0.0
	enemy.slow_time = 0.0
	enemy.slow_factor = 1.0
	player.position = Vector3.ZERO
	enemy.position = Vector3(0, 0.05, -20)
	enemy.begin_spawn_assault(player)
	enemy._update_ai(Enemy.SPAWN_ASSAULT_DURATION + 0.01, 20.0)
	check(enemy._spawn_assault_time == 0.0 and enemy.combat_target == player and enemy.state == "approach", "expiry hands off to existing chase and target retention")
	check(is_equal_approx(enemy.velocity.z, enemy.move_speed * 1.45), "handoff restores normal chase speed")
	enemy.position.z = -5.0
	enemy.begin_spawn_assault(player)
	enemy._update_ai(0.1, 5.0)
	check(enemy._spawn_assault_time == 0.0 and enemy.state == "approach", "close approach ends the burst with reaction space")
	var health_before := player.health
	enemy.position.z = -1.5
	enemy._update_ai(0.1, 1.5)
	check(enemy.state == "windup" and player.health == health_before and player.movement_slow_time == 0.0, "contact must begin the existing telegraph instead of an immediate hit")
	enemy._update_ai(0.1, 1.5)
	check(player.movement_slow_time == 0.0, "normal windup still provides reaction time")
	enemy._update_ai(1.0, 1.5)
	check(player.health == health_before and player.movement_slow_time > 0.0, "ordinary zombie still only interrupts after its windup")
	var boss := Enemy.new() as FoundationEnemy
	boss.configure("boss", true)
	boss.set_physics_process(false)
	fixture.add_child(boss)
	check(not boss.begin_spawn_assault(player), "boss behavior is excluded from replacement assaults")
	fixture.queue_free()
	await process_frame

func _test_wall_collision() -> void:
	var fixture := _fixture()
	var player := fixture.get_node("Player") as FoundationPlayer
	_box(fixture, Vector3(0, 2, -10), Vector3(12, 4, 1))
	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Vector3(0, 0.05, -18)
	fixture.add_child(enemy)
	enemy.begin_spawn_assault(player)
	for frame in range(110):
		await physics_frame
	check(enemy.global_position.z < -10.8, "burst uses CharacterBody collision and cannot dash through cover")
	check(enemy._spawn_assault_time == 0.0, "wall collision hands control back to normal AI")
	fixture.queue_free()
	await process_frame

func _test_initial_population_distribution() -> void:
	var fixture := _fixture()
	var director = fixture.get_node("Director")
	var player := fixture.get_node("Player") as FoundationPlayer
	director.population_limit = Foundation.ZOMBIE_HORDE_SIZE
	var positions: Array[Vector3] = []
	director.spawn_requested.connect(func(at: Vector3) -> void: positions.append(at))
	director.request_initial_population()
	check(director._initial_population_pending == 4, "opening population queues exactly 4 ordinary zombies")
	var budgets_ok := true
	for frame in range(120):
		await physics_frame
		budgets_ok = budgets_ok and director.last_candidate_count <= Director.MAX_CANDIDATES_PER_TICK and director.last_spawn_count <= Director.MAX_SPAWNS_PER_TICK
		if positions.size() == 4:
			break
	check(positions.size() == 4, "initial population finishes at exactly 4 zombies")
	check(director._initial_population_pending == 0 and director._pending.is_empty(), "initial population does not create replacement debt")
	check(budgets_ok, "initial map spread respects candidate and per-tick spawn budgets")
	var sectors := [0, 0, 0, 0]
	for at in positions:
		var offset := at - player.global_position
		offset.y = 0.0
		var radius := offset.length()
		check(radius >= Director.INITIAL_SPAWN_MIN_DISTANCE - 0.1 and radius <= Director.INITIAL_SPAWN_MAX_DISTANCE + 0.1, "opening zombie stays in the concealed 36–64 m arena band")
		check(director.is_concealed(at), "opening zombie stays outside the full 30 m visible envelope")
		var base_offset := at - player.safe_base_position
		base_offset.y = 0.0
		check(base_offset.length() >= Director.BASE_EXCLUSION_RADIUS, "opening zombie stays outside the player base")
		var sector := clampi(int(floor((atan2(offset.z, offset.x) + PI) / (TAU / 4.0))), 0, 3)
		sectors[sector] += 1
	for count in sectors:
		check(count > 0, "opening horde covers all four directions around the player")
	fixture.queue_free()
	await process_frame

func _test_elevator_ground_wave() -> void:
	var arena := Foundation.new()
	root.add_child(arena)
	var director = arena.spawn_director
	var player := arena.player
	var elevator := arena.starting_tower.elevator
	check(director.population_limit == 4 and director.ordinary_population_count() == 4
		and director._stored_population.size() == 4 and director._live.is_empty()
		and not director.is_physics_processing() and not arena.horde_far_visuals.visible,
		"roof holds four data entries without any ordinary zombie actor or processing")
	check(is_instance_valid(arena._boss_enemy) and not director._live.has(arena._boss_enemy.get_instance_id()),
		"boss stays outside the ordinary population")
	var positions: Array[Vector3] = []
	director.spawn_requested.connect(func(at: Vector3) -> void:
		positions.append(at)
		var enemy: FoundationEnemy = director._live.values().back()
		enemy.set_physics_process(false)
	)
	arena._apply_camera_look(0.1, 0.0)
	check(not arena._ground_map_preparing and not arena._ground_map_ready
		and not arena._ground_wave_started, "camera movement alone cannot begin the ground transition")
	check(not arena._ground_wave_started and elevator.interact(player),
		"the roof lift starts with the player aboard")
	var map_instance_id := arena.arena_map.get_instance_id()
	var map_batch_count := arena._ground_map_visuals.size()
	check(arena._ground_map_preparing and not arena._ground_map_ready
		and elevator._car_enclosure.visible and not elevator._ground_floor_ready
		and map_batch_count > 0, "downward ride starts staged map preparation inside the closed car")
	arena._apply_camera_look(0.1, 0.0)
	check(arena._ground_map_visual_index == 0 and director._live.is_empty(),
		"camera look cannot trigger map setup or zombie activation")
	director._physics_process(1.0)
	check(elevator._travelling and director.ordinary_population_count() == 4
		and director._live.is_empty() and positions.is_empty(),
		"camera and elevator movement cannot activate the four stored zombies")
	# Freeze map preparation to simulate a slow device: the car must stop at
	# the bottom with the rider enclosed until preparation resumes.
	arena.set_process(false)
	for frame in range(360):
		await physics_frame
		if is_equal_approx(elevator._car_root.position.y, elevator.BOTTOM_CAR_Y):
			break
	check(elevator._travelling and elevator.is_player_riding(player)
		and elevator._car_enclosure.visible and not arena._ground_wave_started
		and director.ordinary_population_count() == 4,
		"bottom doors stay closed and four zombies stay stored while map preparation is incomplete")
	arena.set_process(true)
	for frame in range(180):
		await physics_frame
		if not elevator._travelling:
			break
	check(player.global_position.y < 1.0 and arena._ground_wave_started,
		"player arrival at ground level activates the encounter")
	var all_batches_ready := true
	for visual in arena._ground_map_visuals:
		all_batches_ready = all_batches_ready and visual.visible
	check(arena._ground_map_ready and not arena._ground_map_preparing and all_batches_ready
		and not elevator._car_enclosure.visible and arena._environment.sky == arena._ground_sky
		and arena.arena_map.get_instance_id() == map_instance_id,
		"ground map and render profile finish before doors open without a second map instance")
	check(director.population_limit == 13 and director._initial_population_pending + director._live.size() == 4
		and director._stored_population.is_empty() and director._pending.is_empty(),
		"ground arrival activates exactly four stored entries with a thirteen-zombie cap")
	director.set_physics_process(false)
	for frame in range(180):
		await physics_frame
		director._physics_process(1.0 / 60.0)
		if director._live.size() == 4:
			break
	check(director._live.size() == 4 and director._initial_population_pending == 0,
		"only the four stored zombies are materialized for the first fight")
	for at in positions:
		var horizontal := at - player.global_position
		horizontal.y = 0.0
		check(horizontal.length() >= 34.0 and horizontal.length() <= 45.0
			and absf(at.y - 0.05) < 0.1 and director.is_concealed(at),
			"each opening fighter starts on valid concealed ground")
	elevator.rider_arrived.emit(&"ground")
	check(director._live.size() == 4 and director._pending.is_empty() and director._initial_population_pending == 0,
		"repeat ground arrival does not add a zombie")
	var first_victim: FoundationEnemy = director._live.values()[0]
	first_victim.receive_hit(10000)
	first_victim._complete_death()
	arena._on_enemy_defeated(first_victim)
	check(director._live.size() == 3 and director._pending.size() == 2,
		"first confirmed death adds two slots exactly once")
	for target_count in range(5, 14):
		for frame in range(120):
			await physics_frame
			director._physics_process(0.1)
			if director._live.size() == target_count:
				break
		check(director._live.size() == target_count and director._pending.is_empty(),
			"confirmed kills grow the living horde by one up to %d" % target_count)
		if target_count < 13:
			var victim: FoundationEnemy = director._live.values()[0]
			victim.receive_hit(10000)
			victim._complete_death()
			check(director._pending.size() == 2 and director._live.size() == target_count - 1,
				"death below cap reserves both replacement slots")
	var capped_victim: FoundationEnemy = director._live.values()[0]
	capped_victim.receive_hit(10000)
	capped_victim._complete_death()
	check(director._live.size() == 12 and director._pending.size() == 1,
		"a death at thirteen reserves only one free slot")
	check(arena._interact_with_starting_elevator() and elevator.is_player_riding(player),
		"ground-floor lift can start its return trip")
	check(director.ordinary_population_count() == 4 and director._live.is_empty()
		and director._pending.is_empty() and not director.is_physics_processing()
		and not arena.horde_far_visuals.visible,
		"boarding for the roof immediately removes all actors and replacement debt")
	var rooftop_batches_hidden := true
	for visual in arena._ground_map_visuals:
		rooftop_batches_hidden = rooftop_batches_hidden and not visual.visible
	check(not arena._ground_map_preparing and not arena._ground_map_ready and rooftop_batches_hidden
		and arena.arena_map.get_instance_id() == map_instance_id,
		"upward ride restores roof profile and hides the same ground map batches")
	await process_frame
	var ordinary_actors := 0
	for node in get_nodes_in_group("enemies"):
		if node is FoundationEnemy and not node.is_boss:
			ordinary_actors += 1
	check(ordinary_actors == 0, "roof trip runs no ordinary actor physics or animation")
	for frame in range(360):
		await physics_frame
		if not elevator._travelling:
			break
	check(player.global_position.y > 19.0 and director.ordinary_population_count() == 4,
		"roof arrival retains exactly four dormant entries")
	check(arena._interact_with_starting_elevator(), "player can descend again after the roof reset")
	for frame in range(360):
		await physics_frame
		if not elevator._travelling:
			break
	check(arena._ground_wave_started and director._initial_population_pending + director._live.size() == 4,
		"a second ground arrival activates a fresh group of four")
	player._reset_at_safe_base()
	check(not elevator._travelling and not elevator.is_player_riding(player)
		and is_equal_approx(elevator._car_root.position.y, elevator.TOP_CAR_Y),
		"respawn releases a travelling rider and restores the rooftop lift")
	check(player.global_position.is_equal_approx(Foundation.PLAYER_BASE_POSITION)
		and arena.camera_rig.global_position.is_equal_approx(
			player.global_position + Vector3.UP * (Foundation.CAMERA_PIVOT_HEIGHT + Foundation.ROOFTOP_CAMERA_PIVOT_LIFT)),
		"respawn returns player and camera to the roof together")
	check(not arena._ground_wave_started and director.population_limit == 4
		and director._live.is_empty() and director._pending.is_empty()
		and director._initial_population_pending == 0 and director._stored_population.size() == 4,
		"rooftop respawn clears the wave and restores four data-only zombies")
	check(arena.arena_map.get_instance_id() == map_instance_id
		and arena._ground_map_visuals.size() == map_batch_count and not arena._ground_map_ready,
		"respawn retains one dormant map and cancels the ground state")
	check(elevator.interact(player), "lift can start another descent before a mid-ride respawn")
	await process_frame
	player._reset_at_safe_base()
	check(not elevator._travelling and not elevator._car_enclosure.visible
		and not arena._ground_map_preparing and director.ordinary_population_count() == 4,
		"mid-ride rooftop respawn cancels preparation without waking zombies")
	arena.queue_free()
	await process_frame

func _test_attacker_slots() -> void:
	var fixture := _fixture()
	var director = fixture.get_node("Director")
	var player := fixture.get_node("Player") as FoundationPlayer
	director.population_limit = 13
	var enemies: Array[FoundationEnemy] = []
	for index in range(5):
		var enemy := Enemy.new() as FoundationEnemy
		enemy._player = player
		enemy.position = Vector3(8.0 + float(index) * 2.0, 0.05, -2.0)
		fixture.add_child(enemy)
		enemy.set_physics_process(false)
		director.register_enemy(enemy)
		enemy.defeated.connect(director.replace_enemy)
		enemies.append(enemy)
	for index in range(4):
		check(director.try_acquire_attacker(enemies[index]), "one of four zombies reserves a player attack")
	check(not director.try_acquire_attacker(enemies[4]) and director._attackers.size() == 4,
		"fifth simultaneous player attacker must wait")
	check(director.try_acquire_attacker(enemies[0]) and director._attackers.size() == 4,
		"repeated windup cannot occupy two attacker slots")
	enemies[4].global_position = Vector3(0.0, 0.05, -1.5)
	enemies[4].combat_target = player
	enemies[4]._decision_time = 1.0
	enemies[4]._update_ai(0.2, 1.5)
	check(enemies[4].state != "windup", "waiting enemy AI cannot begin a fifth player windup")
	enemies[0].receive_hit(1)
	enemies[4]._update_ai(0.2, 1.5)
	check(enemies[4].state == "windup" and director._attackers.size() == 4,
		"a hit interrupts a windup and waiting AI acquires the freed slot")
	enemies[4].apply_stun(0.5)
	check(director._attackers.size() == 3, "stun releases an attacker slot")
	enemies[1].combat_target = player
	enemies[1]._resolve_enemy_attack(1.0)
	check(director._attackers.size() == 2, "resolved attack releases its slot")
	enemies[2].receive_hit(10000)
	enemies[2]._complete_death()
	check(director._attackers.size() == 1 and director._pending.size() == 2,
		"confirmed death releases its slot and queues two replacements")
	fixture.queue_free()
	await process_frame

func _test_player_base_boundary() -> void:
	var arena := Foundation.new()
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_physics_process(false)
	arena.spawn_director.set_physics_process(false)
	arena.spawn_director._initial_population_pending = 0
	await process_frame
	check(arena.player.global_position.distance_to(Foundation.PLAYER_BASE_POSITION) < 0.1, "player starts inside the marked base")
	var boundaries := get_nodes_in_group("zombie_base_boundary")
	check(boundaries.size() == Foundation.PLAYER_BASE_BOUNDARY_SEGMENTS, "base has a continuous segmented enemy boundary")
	var barrier_layers_ok := true
	for barrier_variant in boundaries:
		var barrier := barrier_variant as StaticBody3D
		barrier_layers_ok = barrier_layers_ok and barrier.collision_layer == 4 and barrier.collision_mask == 2
	check(barrier_layers_ok, "base boundary uses a collision layer the player can pass through")
	check((arena.player.collision_mask & 4) == 0, "player can leave the protected base")
	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Foundation.PLAYER_BASE_CENTER + Vector3(0.0, 0.05, 8.0)
	arena.add_child(enemy)
	enemy.begin_spawn_assault(arena.player)
	for frame in range(180):
		await physics_frame
	var enemy_offset := enemy.global_position - Foundation.PLAYER_BASE_CENTER
	enemy_offset.y = 0.0
	check((enemy.collision_mask & 4) != 0, "ordinary zombies collide with the base boundary")
	check(enemy_offset.length() >= Foundation.PLAYER_BASE_SAFE_RADIUS, "approaching zombie cannot enter the player base")
	arena.queue_free()
	await process_frame

func _test_population_and_replacements() -> void:
	var arena := Foundation.new()
	root.add_child(arena)
	arena.set_process(false)
	arena.player.set_physics_process(false)
	arena._boss_enemy.set_physics_process(false)
	var director = arena.spawn_director
	director.set_physics_process(false)
	check(Foundation.ZOMBIE_HORDE_SIZE == 4 and director.population_limit == 4 and director._stored_population.size() == 4, "normal game stores four ordinary zombies separately from the boss")
	director.request_population()
	check(director._pending.is_empty() and director._initial_population_pending == 0, "upstairs cannot schedule an ordinary zombie")
	director.activate_profiling_population(200)
	director.set_physics_process(false)
	director.spawn_requested.connect(func(at: Vector3) -> void:
		var enemy: FoundationEnemy = director._live.values().back()
		enemy.set_physics_process(false)
		var offset := at - arena.player.global_position
		offset.y = 0.0
		check(offset.length() >= 46.0 and offset.length() <= 54.0, "newborn remains around the preserved 50 m spawn distance")
		check(offset.normalized().dot(director.forward_direction()) >= cos(Director.FORWARD_HALF_ANGLE) - 0.001, "newborn is ahead of current movement/facing")
		check(enemy.state == "assault" and enemy._spawn_assault_time > 0.0, "every actual new horde member receives its initial burst")
		check(not enemy._visual_root.visible, "actual birth cannot render beyond the visibility limit")
	)
	director.request_population()
	check(director._pending.size() == 200, "200-zombie profiling stress population is queued once")
	director.request_population()
	check(director._pending.size() == 200, "duplicate fill request cannot exceed the profiling population cap")
	var budgets_ok := true
	for frame in range(500):
		await physics_frame
		director._physics_process(1.0 / 60.0)
		budgets_ok = budgets_ok and director.last_candidate_count <= Director.MAX_CANDIDATES_PER_TICK and director.last_spawn_count <= Director.MAX_SPAWNS_PER_TICK
		if director._live.size() == 200:
			break
	check(budgets_ok, "startup never exceeds shared query or spawn budget")
	check(director._live.size() == 200 and director._pending.is_empty(), "budgeted startup reaches all 200 ordinary zombies")
	check(is_instance_valid(arena._boss_enemy), "existing boss remains separate from the horde cap")
	if director._live.size() < 10:
		arena.queue_free()
		await process_frame
		return
	var existing: Array = director._live.values()
	var behind: FoundationEnemy = existing[5]
	var visible: FoundationEnemy = existing[6]
	behind.position = Vector3(0, 0.05, 8)
	behind.state = "wander"
	visible.position = Vector3(0, 0.05, -10)
	visible.state = "idle"
	var behind_transform := behind.transform
	var visible_transform := visible.transform
	for index in range(4):
		var defeated: FoundationEnemy = existing[index]
		defeated.receive_hit(10000)
		defeated._complete_death() # Advance the death animation deterministically for this spawn-director test.
		arena._on_enemy_defeated(defeated) # Duplicate notifications are harmless.
	check(director._live.size() == 196 and director._pending.size() == 4, "four deaths queue exactly four replacements")
	director._physics_process(0.99)
	check(director._live.size() == 196, "one second replacement delay is retained")
	await physics_frame
	director._physics_process(0.02)
	check(director.last_spawn_count <= 2 and director._live.size() <= 198, "simultaneous deaths cannot create an unbounded spawn frame")
	for frame in range(100):
		await physics_frame
		director._physics_process(1.0 / 60.0)
		if director._live.size() == 200:
			break
	check(director._live.size() == 200 and director._pending.is_empty(), "endless replacements restore the full population")
	check(behind.transform == behind_transform and behind.state == "wander", "zombie left behind is neither teleported nor retargeted")
	check(visible.transform == visible_transform and visible.state == "idle", "visible living zombie is untouched by replacements")
	var victim: FoundationEnemy = director._live.values().back()
	victim.receive_hit(10000)
	victim._complete_death() # Replacement is requested only after the death animation completes.
	arena.player.position = Vector3(0, 0.05, -93)
	arena.player.rotation.y = 0.0
	arena.player.velocity = Vector3.ZERO
	arena.camera.global_position = arena.player.global_position + Vector3(0, 2.5, 4)
	arena.camera.global_rotation = Vector3.ZERO
	director._physics_process(1.1)
	check(director.last_candidate_count == 8 and director.last_spawn_count == 0 and director._pending.size() == 1, "outward-facing edge defers instead of spawning behind or outside the map")
	check(behind.transform == behind_transform and visible.transform == visible_transform, "edge recovery never moves an existing enemy")
	arena.player.rotation.y = PI
	arena.camera.global_rotation.y = PI
	for frame in range(30):
		await physics_frame
		director._physics_process(0.3)
		if director._live.size() == 200:
			break
	check(director._live.size() == 200 and director._pending.is_empty(), "deferred request succeeds after the player turns inward")
	var removed: FoundationEnemy = director._live.values().back()
	removed.queue_free()
	await process_frame
	check(director._live.size() == 199 and director._pending.size() == 1, "unexpected removal also queues one endless replacement")
	var saved_camera: Camera3D = director.camera
	director.camera = null
	director._physics_process(1.1)
	check(director._live.size() == 199 and director._pending.size() == 1, "camera unavailability retains the pending replacement")
	director.camera = saved_camera
	for frame in range(30):
		await physics_frame
		director._physics_process(0.3)
		if director._live.size() == 200:
			break
	check(director._live.size() == 200 and director._pending.is_empty(), "spawn queue recovers after the camera returns")
	arena._boss_enemy.receive_hit(10000)
	check(director._live.size() == 200 and director._pending.is_empty(), "boss defeat does not add a 201st ordinary zombie")
	check(Foundation.ZOMBIE_HORDE_SIZE == 4 and Foundation.ZOMBIE_SPAWN_DISTANCE == 50.0 and Foundation.VISIBILITY_RADIUS == 30.0, "four dormant entries, 50 m replacement distance and 30 m visibility remain intact")
	arena.queue_free()
	await process_frame
