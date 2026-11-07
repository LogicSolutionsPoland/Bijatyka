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

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("Real grab rig: " + label)

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
		await process_frame
		_check(not _contact.is_solver_active() and enemy_rig.find_child("BrutalGrabArmIK", false, false) == null, "%s imported skeleton released cleanly" % side)

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
