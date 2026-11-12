extends SceneTree
## Deterministic host functional check. This is not Android performance acceptance.

const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")
const HUD := preload("res://scripts/mobile_hud.gd")

var _checks := 0
var _failures: Array[String] = []

func _send_pad(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

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
	var jump_signals := {"started": [], "landed": [], "impact_count": 0}
	player.parabolic_jump_started.connect(func(takeoff: Vector3, _direction: Vector3) -> void:
		jump_signals["started"].append(takeoff)
	)
	player.parabolic_jump_landed.connect(func(landing: Vector3, _direction: Vector3) -> void:
		jump_signals["landed"].append(landing)
	)
	player.jump_impact.connect(func(_target: Node) -> void:
		jump_signals["impact_count"] = int(jump_signals["impact_count"]) + 1
	)
	_check(world.game_music_player.playing, "game music plays during the encounter")
	_check(InputMap.has_action("jump") and InputMap.has_action("jump_forward")
		and InputMap.has_action("pad_jump") and InputMap.has_action("pad_jump_forward")
		and not InputMap.has_action("dash") and not InputMap.has_action("pad_dash"),
		"ordinary and forward jumps have separate controls")
	_check(InputMap.has_action("pad_escape_limb_grab")
		and HUD.GAMEPAD_ACTIONS.get(&"pad_jump") == "jump"
		and HUD.GAMEPAD_ACTIONS.get(&"pad_jump_forward") == "jump_forward"
		and HUD.GAMEPAD_ACTIONS.get(&"pad_escape_limb_grab") == "escape_limb_grab",
		"A/Cross, X/Square and R3 remain routed to jump, forward jump and grab escape")
	# Keep the live 20-zombie population registered but prevent its 15 m assault from interrupting this deterministic jump/grab scenario.
	spawns.spawn_requested.connect(func(_at: Vector3) -> void:
		if not spawns._live.is_empty():
			var spawned: FoundationEnemy = spawns._live.values().back() as FoundationEnemy
			if is_instance_valid(spawned):
				spawned.set_physics_process(false)
	)
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
	_send_pad(JOY_BUTTON_A, true)
	_check(player.velocity.y > 0.0 and not player._parabolic_jump_active,
		"A/Cross input starts ordinary Jump independently")
	_send_pad(JOY_BUTTON_A, false)
	for frame in range(120):
		await physics_frame
		if frame > 3 and player.is_on_floor() and player.velocity.y <= 0.0:
			break
	_check(player.is_on_floor() and not spawns._initial_horde_activated,
		"ordinary Jump landing cannot activate the prepared group")
	_check(jump_signals["started"].is_empty() and jump_signals["landed"].is_empty()
		and int(jump_signals["impact_count"]) == 0,
		"ordinary Jump emits no forward-jump signal or impact in the empty arena")
	var forward_takeoff := player.global_position
	_send_pad(JOY_BUTTON_X, true)
	_check(player._parabolic_jump_active, "X/Square input starts the forward parabolic Jump")
	_send_pad(JOY_BUTTON_X, false)
	for frame in range(130):
		await physics_frame
		if frame > 3 and not player._parabolic_jump_active:
			break
	_check(not player._parabolic_jump_active and player.is_on_floor(), "forward jump lands")
	var forward_displacement := player.global_position - forward_takeoff
	forward_displacement.y = 0.0
	_check(absf(forward_displacement.length() - player.forward_jump_distance_m) <= 0.15,
		"unobstructed forward jump preserves its intended 5 m travel")
	_check(jump_signals["started"].size() == 1 and jump_signals["landed"].size() == 1
		and int(jump_signals["impact_count"]) == 0,
		"forward jump emits one start and landing and no ordinary impact")
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
	_check(director.local_living_count <= BijatykaAIDirector.LOCAL_LIVING_LIMIT and director.attacker_role_count <= 4
		and director.reserve_role_count <= 7 and spawns._attackers.size() <= 4,
		"local, attacker and reserve counts stay within their caps")
	_check(world.horde_far_visuals.get_resident_rig_count() <= 7,
		"resident ordinary detail rigs stay within seven")
	var grabber: FoundationEnemy
	for value in spawns._live.values():
		var enemy := value as FoundationEnemy
		if spawns.formation_role_for(enemy) != "attacker":
			continue
		if grabber == null:
			grabber = enemy
		# Prefer an already locked attacker when four slots are occupied.
		if spawns._attackers.has(enemy.get_instance_id()):
			grabber = enemy
			break
	if is_instance_valid(grabber) and player.is_on_floor():
		grabber.set_physics_process(false)
		grabber._player = player
		grabber.global_position = player.global_position + Vector3(1.5, 0.0, 0.0)
		_check(spawns.try_acquire_attacker(grabber), "grabber obtains a valid attacker reservation")
		_check(player.try_reserve_limb_grab(grabber, "LEFT ARM")
			and player.begin_limb_grab(grabber, "LEFT ARM"), "zombie can hold one arm")
		grabber.state = "limb_hold"
		_send_pad(JOY_BUTTON_RIGHT_STICK, true)
		_check(player._limb_grab_owner == grabber and player.get_grab_qte_progress() == 1,
			"first R3 press advances QTE without instant release")
		_send_pad(JOY_BUTTON_RIGHT_STICK, true)
		_check(player.get_grab_qte_progress() == 1, "duplicate held R3 event is rejected")
		_send_pad(JOY_BUTTON_RIGHT_STICK, false)
		_send_pad(JOY_BUTTON_RIGHT_STICK, true)
		_check(player._limb_grab_owner == grabber and player.get_grab_qte_progress() == 2,
			"second R3 press still holds zombie ownership")
		_send_pad(JOY_BUTTON_RIGHT_STICK, false)
		_send_pad(JOY_BUTTON_RIGHT_STICK, true)
		_check(player._limb_grab_owner == null, "third R3 input escapes the grab and returns control")
		_send_pad(JOY_BUTTON_RIGHT_STICK, false)
		player._limb_grab_cooldown = 0.0
		_check(spawns.try_acquire_attacker(grabber), "grabber reacquires its attacker slot after escape")
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
