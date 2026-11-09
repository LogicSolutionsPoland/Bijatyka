extends SceneTree
## Stage 6 P1: production AI natural-grab diagnostic in the real ground encounter.
## Never calls try_reserve_limb_grab(), begin_limb_grab() or emits QTE signals.
## Only test-time positioning is controlled; AI, slots, visibility and contact stay live.
const WORLD := preload("res://scenes/foundation.tscn")
const CONTACT := preload("res://scripts/brutal_grab_limb_contact.gd")
const ELEVATOR := preload("res://scripts/starting_elevator.gd")

var errors: Array[String] = []
var event_log: Array[String] = []
var windup_count := 0
var qte_count := 0
var qte_end_count := 0

func _initialize() -> void:
	seed(0xB16A7)
	call_deferred("_run")

func _assert(ok: bool, message: String) -> bool:
	if not ok:
		errors.append(message)
		push_error("P1_NATURAL_GRAB " + message)
	return ok

func _run() -> void:
	var game = WORLD.instantiate()
	root.add_child(game)
	for frame in range(6):
		await process_frame
	var lift = game.starting_tower.elevator
	var loader = game._ground_loading_coordinator
	lift._car_root.position.y = ELEVATOR.BOTTOM_CAR_Y
	if not _assert(lift.interact(game.player), "initial roof elevator call"):
		_finish(game)
		return
	lift._car_root.position.y = ELEVATOR.TOP_CAR_Y
	for frame in range(480):
		await process_frame
		if not loader.is_active():
			break
	if not _assert(lift.interact(game.player), "enter elevator"):
		_finish(game)
		return
	for frame in range(480):
		await process_frame
		if game._ground_map_ready:
			break
	if not _assert(game._ground_map_ready, "ground map loads"):
		_finish(game)
		return
	lift._car_root.position.y = ELEVATOR.BOTTOM_CAR_Y
	for frame in range(160):
		await process_frame
		if not loader.is_active() and game._ground_wave_started:
			break
	if not _assert(game._ground_wave_started and game.ai_director.active, "real Director and horde active"):
		_finish(game)
		return

	# The same unobstructed ground point is used by the successful Stage 5B
	# transition probe. No attack state, slot, rig or character pose is forced.
	game.player.global_position = Vector3(20.0, 1.2, 20.0)
	for frame in range(120):
		await physics_frame
		if frame > 5 and game.player.is_on_floor():
			break
	if not _assert(game.player.is_on_floor(), "real player on ground"):
		_finish(game)
		return

	var actor: FoundationEnemy = null
	for entry in game.spawn_director._live.values():
		var ordinary := entry as FoundationEnemy
		if is_instance_valid(ordinary) and ordinary.hp > 0 and not ordinary.is_boss:
			actor = ordinary
			break
	if not _assert(is_instance_valid(actor), "ordinary actor registered by real spawn manager"):
		_finish(game)
		return
	# Controlled positioning is permitted for reproducibility. Normal character
	# physics, AI updates, the Director's roles and flashlight/LOD remain enabled.
	actor.global_position = Vector3(20.0, 0.05, 16.6)
	actor.velocity = Vector3.ZERO
	# Production assault handoff, target selection, attack slots and windup remain automatic.
	# Do not assign a target, slot or force attack, reservation, rig or QTE.
	var started := {"value": 0}
	var ended := {"value": 0}
	game.player.grab_windup_started.connect(func(enemy: FoundationEnemy, limb: String) -> void:
		windup_count += 1
		event_log.append("GRAB_WINDUP %s limb=%s" % [str(enemy.get_instance_id()), limb])
	)
	game.player.grab_qte_started.connect(func(id: int, enemy: FoundationEnemy, limb: String, count: int, seconds: float) -> void:
		qte_count += 1
		started.value = id
		event_log.append("QTE_STARTED id=%d enemy=%s limb=%s presses=%d seconds=%.2f" % [id, str(enemy.get_instance_id()), limb, count, seconds])
	)
	game.player.grab_qte_finished.connect(func(id: int, outcome: String) -> void:
		qte_end_count += 1
		ended.value = id
		event_log.append("QTE_FINISHED id=%d outcome=%s" % [id, outcome])
	)
	game.player.grab_interrupted.connect(func(reason: String, enemy: FoundationEnemy, limb: String) -> void:
		event_log.append("GRAB_INTERRUPTED reason=%s enemy=%s limb=%s" % [reason, str(enemy.get_instance_id()) if is_instance_valid(enemy) else "none", limb])
	)
	game.player.grab_fully_ended.connect(func(reason: String) -> void:
		event_log.append("GRAB_FINALLY_ENDED reason=%s" % reason)
	)
	var geometry_count := {"value": 0}
	game.player.grab_state_changed.connect(func(next_state: int, enemy: FoundationEnemy, limb: String) -> void:
		event_log.append("PLAYER_GRAB_STATE=%d limb=%s enemy=%s" % [next_state, limb, str(enemy.get_instance_id()) if is_instance_valid(enemy) else "none"])
		if next_state != FoundationPlayer.GrabState.GRABBED or not is_instance_valid(enemy) or int(geometry_count.value) >= 2:
			return
		geometry_count.value = int(geometry_count.value) + 1
		var exo: Skeleton3D = game.player._exo_retarget.target_skeleton if is_instance_valid(game.player._exo_retarget) else null
		var rig: Skeleton3D = enemy._skeleton
		if not is_instance_valid(exo) or not is_instance_valid(rig):
			event_log.append("CONTACT_METRIC missing visible rig")
			return
		for arm in ["LEFT ARM", "RIGHT ARM"]:
			var p: Dictionary = CONTACT.resolve_player_bones(exo, arm, true)
			if p.is_empty():
				event_log.append("CONTACT_METRIC missing Exo bones for " + arm)
				continue
			var contact_point: Vector3 = CONTACT.forearm_contact_point(exo, int(p.forearm), int(p.wrist))
			for hand in ["left", "right"]:
				var e: Dictionary = CONTACT.resolve_enemy_bones(rig, hand)
				if e.is_empty():
					event_log.append("CONTACT_METRIC missing enemy bones for " + hand)
					continue
				var shoulder: Vector3 = CONTACT.bone_world(rig, int(e.root))
				var elbow: Vector3 = CONTACT.bone_world(rig, int(e.middle))
				var wrist: Vector3 = CONTACT.bone_world(rig, int(e.end))
				var upper: float = shoulder.distance_to(elbow)
				var lower: float = elbow.distance_to(wrist)
				var dist: float = shoulder.distance_to(contact_point)
				event_log.append("CONTACT_METRIC " + JSON.stringify({
					"arm": arm, "hand": hand, "selected": arm == limb and hand == enemy._limb_grab_hand,
					"actor_distance": enemy.global_position.distance_to(game.player.global_position),
					"target_distance": dist, "upper": upper, "lower": lower,
					"max_reach": upper + lower + CONTACT.REACH_MARGIN_M,
					"min_reach": absf(upper - lower) + 0.02,
					"reachable": CONTACT.can_reach_contact(enemy, game.player, arm, hand),
					"shoulder": shoulder, "contact": contact_point
				}))
	)
	var attacks := 0
	var last_attack_sequence := actor._attack_sequence
	var last_state := actor.state
	var rejected_visual := 0
	var rejected_slot := 0
	var rejected_player := 0
	var rig_ready_samples := 0
	var active_slot_samples := 0
	var samples := 0
	for frame in range(1800):
		await physics_frame
		if not is_instance_valid(actor) or not is_instance_valid(game.player):
			break
		if actor._attack_sequence > last_attack_sequence:
			attacks += actor._attack_sequence - last_attack_sequence
			last_attack_sequence = actor._attack_sequence
		if actor.state != last_state:
			event_log.append("ENEMY_STATE %s -> %s at_frame=%d" % [last_state, actor.state, frame])
			last_state = actor.state
		if frame % 12 == 0:
			samples += 1
			var rig_ok := actor._full_animation_selected and is_instance_valid(actor._skeleton) and is_instance_valid(actor._animation_player)
			var visual_ok := rig_ok and is_instance_valid(actor._visual_root) and actor._visual_root.visible
			var slot_ok: bool = bool(game.spawn_director.can_maintain_limb_grab(actor))
			var player_ok: bool = bool(game.player._grab_player_eligible())
			if rig_ok:
				rig_ready_samples += 1
			if slot_ok:
				active_slot_samples += 1
			if not visual_ok:
				rejected_visual += 1
			if not slot_ok:
				rejected_slot += 1
			if not player_ok:
				rejected_player += 1
		if frame % 120 == 0:
			print("P1_NATURAL_SAMPLE " + JSON.stringify({
				"frame": frame, "hp": actor.hp, "player_health": game.player.health,
				"distance": actor.global_position.distance_to(game.player.global_position),
				"role": game.spawn_director.formation_role_for(actor),
				"slot": game.spawn_director._attackers.has(actor.get_instance_id()),
				"full_rig": actor._full_animation_selected, "visible": actor._visual_root.visible,
				"state": actor.state, "attacks": attacks, "windups": windup_count, "qtes": qte_count
			}))
		if qte_count > 0 and qte_end_count > 0:
			break
		if game.player.health <= 0:
			event_log.append("PLAYER_DIED before natural completion")
			break

	print("P1_NATURAL_DIAG " + JSON.stringify({
		"attacks": attacks, "windups": windup_count, "qte_started": qte_count,
		"qte_finished": qte_end_count, "sample_count": samples,
		"rig_ready": rig_ready_samples, "slot_allowed": active_slot_samples,
		"visual_rejected_samples": rejected_visual, "slot_rejected_samples": rejected_slot,
		"player_ineligible_samples": rejected_player, "target_state": actor.state if is_instance_valid(actor) else "invalid",
		"player_grab_state": game.player.grab_state, "events": event_log
	}))
	_assert(attacks > 0, "production AI must attempt at least one attack")
	_assert(windup_count > 0, "production AI must initiate real grab windup")
	_assert(qte_count > 0, "natural grab must start QTE from real contact")
	_assert(qte_end_count > 0, "natural QTE must finish and release session")
	_finish(game)

func _finish(game: Node) -> void:
	if is_instance_valid(game):
		game.queue_free()
	if errors.is_empty():
		print("PASS: Stage6 P1 production natural AI grab/QTE")
		quit(0)
	else:
		for error in errors:
			print("FAIL: Stage6 P1 " + error)
		quit(1)
