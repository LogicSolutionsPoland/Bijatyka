extends SceneTree
## Stage 3 imported-rig IK check. Host geometry only; not visual/Android acceptance.
const PLAYER_SCENE := preload("res://scripts/player_controller.gd")
const ENEMY_SCENE := preload("res://scripts/enemy.gd")
const CONTACT := preload("res://scripts/brutal_grab_limb_contact.gd")

var checks := 0
var failures: Array[String] = []
var _host: Node3D
var _player: FoundationPlayer
var _zombie: FoundationEnemy
var _contact: BrutalGrabLimbContact

class SlotLedger extends Node:
	func can_maintain_limb_grab(_enemy: FoundationEnemy) -> bool:
		return true
	func release_attacker(_enemy: FoundationEnemy) -> void:
		pass

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("Real grab rig: " + label)

func _prepare_reachable_hold(player_exo: Skeleton3D, enemy_rig: Skeleton3D, limb: String, side: String) -> bool:
	var holding_clip := String(FoundationEnemy.FIGHT_ANIMATION_BUILDER.clip_path("punch", side, FoundationEnemy.ENEMY_FIGHT_LIBRARY))
	if not _zombie._animation_player.has_animation(holding_clip):
		return false
	_zombie._animation_player.play(holding_clip, 0.0)
	_zombie._animation_player.seek(_zombie._attack_clip_contact_time(holding_clip), true)
	_zombie._animation_player.pause()
	_player._animation_player.play(FoundationPlayer.CHARACTER_MOTION.clip_path("Hit"), 0.0)
	_player._animation_player.seek(0.12, true)
	_player._animation_player.pause()
	_player._exo_retarget.synchronize_pose()
	await process_frame
	var player_bones := CONTACT.resolve_player_bones(player_exo, limb, true)
	var enemy_bones := CONTACT.resolve_enemy_bones(enemy_rig, side)
	if player_bones.is_empty() or enemy_bones.is_empty():
		return false
	var target := CONTACT.forearm_contact_point(player_exo, int(player_bones.forearm), int(player_bones.wrist))
	var shoulder := CONTACT.bone_world(enemy_rig, int(enemy_bones.root))
	_zombie.global_position += target - shoulder + Vector3(0.0, 0.0, 0.20)
	_zombie._limb_grab_limb = limb
	_zombie._limb_grab_hand = side
	_zombie.state = "limb_grab_windup"
	_player._limb_grab_cooldown = 0.0
	return _player.try_reserve_limb_grab(_zombie, limb)

func _run() -> void:
	_host = Node3D.new()
	root.add_child(_host)
	_player = PLAYER_SCENE.new() as FoundationPlayer
	_host.add_child(_player)
	_player.set_physics_process(false)
	_zombie = ENEMY_SCENE.new() as FoundationEnemy
	_host.add_child(_zombie)
	_zombie.set_physics_process(false)
	_zombie._set_full_animation_selected(true)
	await process_frame
	_contact = _player._grab_contact
	var player_exo: Skeleton3D = null
	if is_instance_valid(_player._exo_retarget):
		player_exo = _player._exo_retarget.target_skeleton
	var enemy_rig := _zombie._skeleton
	_check(is_instance_valid(player_exo) and player_exo.get_bone_count() == 112, "live Exo 112-bone rig available")
	_check(is_instance_valid(enemy_rig) and enemy_rig.get_bone_count() == 65, "live zombie 65-bone rig available")
	_check(is_instance_valid(_contact), "player owns exactly one contact component")
	if not is_instance_valid(player_exo) or not is_instance_valid(enemy_rig) or not is_instance_valid(_contact):
		_finish()
		return
	_player._animation_player.play(FoundationPlayer.CHARACTER_MOTION.clip_path("Hit"), 0.0)
	_player._animation_player.seek(0.12, true)
	_player._animation_player.pause()
	await process_frame

	for side in ["left", "right"]:
		var limb := "LEFT ARM" if side == "left" else "RIGHT ARM"
		var player_bones := CONTACT.resolve_player_bones(player_exo, limb, true)
		var zombie_bones := CONTACT.resolve_enemy_bones(enemy_rig, side)
		_check(not player_bones.is_empty(), "real Exo %s forearm/wrist parent chain" % side)
		_check(not zombie_bones.is_empty(), "real zombie %s upper/forearm/hand parent chain" % side)
		if player_bones.is_empty() or zombie_bones.is_empty():
			continue
		# The original per-side punch is held at its authored contact marker.
		_zombie.global_position = Vector3.ZERO
		var punch := String(FoundationEnemy.FIGHT_ANIMATION_BUILDER.clip_path("punch", side, FoundationEnemy.ENEMY_FIGHT_LIBRARY))
		_check(_zombie._animation_player.has_animation(punch), "%s existing zombie hold animation" % side)
		if not _zombie._animation_player.has_animation(punch):
			continue
		_zombie._animation_player.play(punch, 0.0)
		_zombie._animation_player.seek(_zombie._attack_clip_contact_time(punch), true)
		_zombie._animation_player.pause()
		await process_frame
		var target := CONTACT.forearm_contact_point(player_exo, int(player_bones.forearm), int(player_bones.wrist))
		var shoulder := CONTACT.bone_world(enemy_rig, int(zombie_bones.root))
		var elbow := CONTACT.bone_world(enemy_rig, int(zombie_bones.middle))
		var hand := CONTACT.bone_world(enemy_rig, int(zombie_bones.end))
		var reach := shoulder.distance_to(elbow) + elbow.distance_to(hand)
		_check(reach > 0.20 and reach < 1.20, "%s real zombie arm reach %.3fm" % [side, reach])
		# Test geometry deliberately aligns the actors before the session.
		# Runtime characters are NEVER teleported by the actual component.
		_zombie.global_position.x += target.x - shoulder.x
		_zombie.global_position.z += target.z - shoulder.z + 0.20
		_zombie.state = "limb_hold"
		_zombie.hp = 90
		_zombie._limb_grab_hand = side
		_player._grab_session_serial += 1
		_player._grab_session_id = _player._grab_session_serial
		_player.grab_state = FoundationPlayer.GrabState.GRABBED
		_player._limb_grab_owner = _zombie
		var opened := _contact.begin_contact(_zombie, _player, limb, side, _player._grab_session_id)
		_check(opened, "%s imported rig starts contact: %s" % [side, _contact.last_reject_reason])
		if not opened:
			_player._grab_session_id = 0
			_player._limb_grab_owner = null
			_player.grab_state = FoundationPlayer.GrabState.READY
			continue
		_check(_contact._player_skeleton == player_exo, "%s uses visible Exo pose" % side)
		_check(_contact._enemy_skeleton == enemy_rig, "%s modifies actual zombie bones" % side)
		var sample := {"count": 0, "error": INF, "elbow_before": CONTACT.bone_world(enemy_rig, int(zombie_bones.middle)), "elbow_after": Vector3.ZERO}
		var modifier := _contact._ik
		modifier.modification_processed.connect(func() -> void:
			if is_instance_valid(_contact._target):
				sample.count = int(sample.count) + 1
				sample.error = CONTACT.bone_world(enemy_rig, int(zombie_bones.end)).distance_to(_contact._target.global_position)
				sample.elbow_after = CONTACT.bone_world(enemy_rig, int(zombie_bones.middle))
		)
		_contact.update_contact(0.15)
		await process_frame
		await process_frame
		_check(int(sample.count) > 0, "%s imported two-bone IK runs" % side)
		_check(float(sample.error) <= 0.05, "%s imported hand reaches Exo forearm within 5 cm (%.3fm)" % [side, float(sample.error)])
		_check((sample.elbow_after as Vector3).distance_to(sample.elbow_before as Vector3) > 0.005, "%s elbow actually bends" % side)
		_check(_contact.last_hand_error_m <= 0.05, "%s runtime metric captures post-IK error" % side)
		var enemy_anchor := _zombie.global_position
		var player_anchor := _player.global_position
		_player.rotation.y = 0.05
		_zombie.rotation.y = -0.05
		await process_frame
		await process_frame
		_check(_contact.is_solver_active() and float(sample.error) <= 0.05, "%s follows both small character rotations" % side)
		_check(_zombie.global_position.distance_to(enemy_anchor) < 0.00001 and _player.global_position.distance_to(player_anchor) < 0.00001, "%s modifier does not move either CharacterBody3D" % side)
		_player.global_position += Vector3(0.025, 0.0, 0.025)
		await process_frame
		await process_frame
		_check(_contact.is_solver_active() and float(sample.error) <= 0.05, "%s follows small player translation" % side)
		_player.global_position = player_anchor
		_player.rotation.y = 0.0
		_zombie.rotation.y = 0.0
		print("STAGE3_IMPORTED_RIG side=%s reach=%.4f error=%.4f count=%d" % [side, reach, float(sample.error), int(sample.count)])
		_contact.end_contact("test_released")
		_player._grab_session_id = 0
		_player._limb_grab_owner = null
		_player.grab_state = FoundationPlayer.GrabState.READY
		await create_timer(CONTACT.BLEND_OUT_SECONDS + 0.02).timeout
		await process_frame
		_check(not _contact.is_solver_active() and enemy_rig.find_child("BrutalGrabArmIK", false, false) == null, "%s imported skeleton released cleanly" % side)

	# Verify real reach preflight against the authoritative Stage 1/2 transition.
	var floor := StaticBody3D.new()
	floor.collision_layer = 2
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.3, 30.0)
	collider.shape = shape
	floor.add_child(collider)
	floor.position.y = -0.15
	_host.add_child(floor)
	_player.global_position = Vector3(0.0, 1.5, 0.0)
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(true)
	var grounded := false
	for index in range(100):
		await physics_frame
		if index > 2 and _player.is_on_floor() and is_zero_approx(_player.velocity.y):
			grounded = true
			break
	_player.set_physics_process(false)
	_check(grounded, "player settles on collision floor for real Stage 2 admission")
	var ledger := SlotLedger.new()
	_host.add_child(ledger)
	_zombie.attack_director = ledger
	_zombie._player = _player
	var starts := {"count": 0}
	_player.grab_qte_started.connect(func(_id: int, _grabber: FoundationEnemy, _limb: String, _required: int, _seconds: float) -> void:
		starts.count = int(starts.count) + 1
	)
	_zombie.global_position = _player.global_position + Vector3(5.0, 0.0, 0.0)
	_zombie._limb_grab_limb = "LEFT ARM"
	_zombie._limb_grab_hand = "left"
	_zombie.state = "limb_grab_windup"
	_player._limb_grab_cooldown = 0.0
	if grounded:
		_check(_player.try_reserve_limb_grab(_zombie, "LEFT ARM"), "far real rig reservation accepted for controlled preflight test")
		_zombie.state = "limb_hold"
		_check(not _player.begin_limb_grab(_zombie, "LEFT ARM"), "out-of-reach real rig cannot start QTE")
		_check(_player.get_grab_state() == FoundationPlayer.GrabState.READY and _player.get_active_grab_session_id() == 0 and not _player._grab_qte.is_active() and int(starts.count) == 0, "unreachable hold cleans before publishing QTE")
		_check(not _contact.is_solver_active() and _zombie.state == "recovery", "unreachable preflight safely releases enemy")

		# Same imported actors can still begin one reachable QTE.
		var holding_clip := String(FoundationEnemy.FIGHT_ANIMATION_BUILDER.clip_path("punch", "left", FoundationEnemy.ENEMY_FIGHT_LIBRARY))
		_zombie._animation_player.play(holding_clip, 0.0)
		_zombie._animation_player.seek(_zombie._attack_clip_contact_time(holding_clip), true)
		_zombie._animation_player.pause()
		_player._animation_player.play(FoundationPlayer.CHARACTER_MOTION.clip_path("Hit"), 0.0)
		_player._animation_player.seek(0.12, true)
		_player._animation_player.pause()
		_player._exo_retarget.synchronize_pose()
		var current_target := CONTACT.resolve_player_bones(player_exo, "LEFT ARM", true)
		var wrist_target := CONTACT.forearm_contact_point(player_exo, int(current_target.forearm), int(current_target.wrist))
		var current_hand := CONTACT.resolve_enemy_bones(enemy_rig, "left")
		var shoulder_now := CONTACT.bone_world(enemy_rig, int(current_hand.root))
		_zombie.global_position.x += wrist_target.x - shoulder_now.x
		_zombie.global_position.y += wrist_target.y - shoulder_now.y
		_zombie.global_position.z += wrist_target.z - shoulder_now.z + 0.20
		_zombie._limb_grab_limb = "LEFT ARM"
		_zombie._limb_grab_hand = "left"
		_zombie.state = "limb_grab_windup"
		_player._limb_grab_cooldown = 0.0
		_check(_player.try_reserve_limb_grab(_zombie, "LEFT ARM"), "near real rig reservation accepted")
		_zombie.state = "limb_hold"
		var successful := _player.begin_limb_grab(_zombie, "LEFT ARM")
		_check(successful and int(starts.count) == 1 and _contact.is_solver_active(), "reachable imported rig starts exactly one QTE with active IK")
		if successful:
			var id := _player.get_active_grab_session_id()
			for press in range(3):
				_player.try_escape_limb_grab(id)
			_check(_player.get_active_grab_session_id() == 0 and _contact.is_solver_active() and not _contact.is_processing() and _zombie.state == "recovery", "real QTE escape stops target sampling and blends IK out")
			await create_timer(CONTACT.BLEND_OUT_SECONDS + 0.02).timeout
			_check(not _contact.is_solver_active(), "real QTE escape removes IK after blend-out")

		# A real Stage 2 timeout must release the imported-rig modifier through
		# the same authoritative completion signal as a successful escape.
		var timeout_reserved := await _prepare_reachable_hold(player_exo, enemy_rig, "LEFT ARM", "left")
		_check(timeout_reserved, "reachable imported rig can reserve the timeout session")
		if timeout_reserved:
			_zombie.state = "limb_hold"
			var timeout_started := _player.begin_limb_grab(_zombie, "LEFT ARM")
			_check(timeout_started and _contact.is_solver_active(), "real timeout session starts with active IK")
			if timeout_started:
				_player._update_limb_grab(_player.grab_qte_duration_seconds + 0.01)
				_check(_player.get_active_grab_session_id() == 0 and _contact.is_solver_active() and not _contact.is_processing() and _zombie.state == "recovery", "real QTE timeout starts imported-rig IK blend-out")
				await create_timer(CONTACT.BLEND_OUT_SECONDS + 0.02).timeout
				_check(not _contact.is_solver_active(), "real QTE timeout removes IK after blend-out")

		# Dynamic overreach asks FoundationPlayer to cancel its owned QTE. The
		# contact component never leaves a ghost HUD session or moves either body.
		var reach_reserved := await _prepare_reachable_hold(player_exo, enemy_rig, "LEFT ARM", "left")
		_check(reach_reserved, "reachable imported rig can reserve the reach-loss session")
		if reach_reserved:
			_zombie.state = "limb_hold"
			var reach_started := _player.begin_limb_grab(_zombie, "LEFT ARM")
			_check(reach_started and _contact.is_solver_active(), "reach-loss session starts with active IK")
			if reach_started:
				var enemy_anchor := _zombie.global_position
				_player.global_position += Vector3(0.0, 0.0, 1.0)
				_contact.update_contact(0.016)
				_check(_player.get_active_grab_session_id() == 0 and not _contact.is_solver_active() and _zombie.state == "recovery", "out-of-reach contact cancels owner QTE and releases IK")
				_check(_zombie.global_position.distance_to(enemy_anchor) < 0.00001, "reach cancellation never moves the enemy CharacterBody3D")

	_finish()

func _finish() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	if failures.is_empty():
		print("PASS: %d imported Exo/zombie grab rig checks" % checks)
		quit(0)
	else:
		print("FAIL: %d / %d imported Exo/zombie grab rig checks" % [failures.size(), checks])
		quit(1)
