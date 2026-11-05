extends SceneTree
## Deterministic host functional check. This is not Android performance acceptance.

const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("Stage 6 host check: " + message)

func _run() -> void:
	var world = FOUNDATION_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	var player: FoundationPlayer = world.player
	var spawns = world.spawn_director
	var director: BijatykaAIDirector = world.ai_director
	_check(world.game_music_player.playing, "game music plays during the encounter")
	_check(InputMap.has_action("jump") and InputMap.has_action("jump_forward")
		and InputMap.has_action("pad_jump") and InputMap.has_action("pad_jump_forward")
		and not InputMap.has_action("dash") and not InputMap.has_action("pad_dash"),
		"ordinary and forward jumps have separate controls")
	_check(InputMap.has_action("pad_escape_limb_grab"), "gamepad escape action is configured")
	spawns.activate_ground_population(20)
	spawns.begin_local_pool_preparation()
	director.activate()
	world.horde_far_visuals.visible = true
	world.horde_far_visuals.set_process(true)
	player.global_position = Vector3(20.0, 1.2, 20.0)
	player.rotation.y = 0.0
	for frame in range(90):
		await physics_frame
	_check(player.is_on_floor(), "player settles on the arena floor")
	_check(spawns._prepared_local.size() == 14 and spawns.ordinary_population_count() <= 20,
		"four opening zombies and fourteen prepared actors fit the stage cap")
	world._apply_camera_look(0.2, 0.0)
	_check(not spawns._initial_horde_activated, "camera movement cannot activate the prepared group")
	_check(player.try_jump(), "ordinary Jump starts independently")
	for frame in range(120):
		await physics_frame
		if frame > 3 and player.is_on_floor() and player.velocity.y <= 0.0:
			break
	_check(player.is_on_floor() and not spawns._initial_horde_activated,
		"ordinary Jump landing cannot activate the prepared group")
	_check(player.try_parabolic_jump(), "former Dash control starts the forward jump")
	for frame in range(130):
		await physics_frame
		if frame > 3 and not player._parabolic_jump_active:
			break
	_check(not player._parabolic_jump_active and player.is_on_floor(), "forward jump lands")
	_check(spawns._initial_horde_activated and spawns._local_members.size() == 11,
		"confirmed forward landing activates eleven prepared local actors once")
	_check(spawns.ordinary_population_count() <= 20, "stage-wide ordinary population stays within twenty")
	var local_count: int = spawns._local_members.size()
	spawns.on_parabolic_jump_started(player.global_position, Vector3.FORWARD)
	spawns.on_parabolic_jump_landed(player.global_position + Vector3.FORWARD * 5.0, Vector3.FORWARD)
	_check(spawns._local_members.size() == local_count, "further landing events cannot activate the pool twice")
	director._refresh_formation()
	_check(director.attacker_role_count == 4 and director.reserve_role_count == 7,
		"confirmed landing assigns four attackers and seven reserves")
	_check(director.local_living_count <= 14 and director.attacker_role_count <= 4
		and director.reserve_role_count <= 7 and spawns._attackers.size() <= 4,
		"local, attacker and reserve counts stay within their caps")
	_check(world.horde_far_visuals.get_resident_rig_count() <= 7,
		"resident ordinary detail rigs stay within seven")
	var grabber: FoundationEnemy
	for value in spawns._live.values():
		var enemy := value as FoundationEnemy
		if spawns.formation_role_for(enemy) == "attacker":
			grabber = enemy
			break
	if is_instance_valid(grabber) and player.is_on_floor():
		grabber.set_physics_process(false)
		grabber._player = player
		grabber.global_position = player.global_position + Vector3(1.5, 0.0, 0.0)
		_check(player.try_reserve_limb_grab(grabber, "LEFT ARM")
			and player.begin_limb_grab(grabber, "LEFT ARM"), "zombie can hold one arm")
		grabber.state = "limb_hold"
		_check(player.try_escape_limb_grab() and player._limb_grab_owner == null,
			"escape clears the hold and returns control")
		player._limb_grab_cooldown = 0.0
		_check(player.try_reserve_limb_grab(grabber, "RIGHT ARM")
			and player.begin_limb_grab(grabber, "RIGHT ARM"), "new hold can start after cooldown")
		grabber.state = "limb_hold"
		player._update_limb_grab(3.1)
		_check(player._limb_grab_owner == null, "hold ends automatically by its configured timeout")
	else:
		_check(false, "formation provides a nearby attacker for the grab check")
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: Stage 6 integrated host loop (%d checks; Android device not tested)" % _checks)
	else:
		print("FAIL: Stage 6 integrated host loop (%d/%d checks)" % [_failures.size(), _checks])
	quit(0 if _failures.is_empty() else 1)
