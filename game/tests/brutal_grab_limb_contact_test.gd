extends SceneTree
## Stage 3 synthetic-rig host tests. Geometry tests are NOT a Redmi visual pass.
const CONTACT := preload("res://scripts/brutal_grab_limb_contact.gd")
const ORIENTATION := preload("res://scripts/brutal_grab_hand_orientation.gd")

class TestOwner extends Node3D:
	var _skeleton: Skeleton3D
	var _exo_retarget: PlayerExoGrayRetarget
	var health := 100
	var id := 0
	var enemy: Node
	func get_active_grab_session_id() -> int:
		return id
	func get_active_grab_enemy() -> Node:
		return enemy

class TestEnemy extends Node3D:
	var _skeleton: Skeleton3D
	var state := "limb_hold"
	var hp := 90

var checks := 0
var failures: Array[String] = []
var owner: TestOwner
var zombie: TestEnemy
var contact: BrutalGrabLimbContact
var host: Node3D
var counter := 100

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("Stage 3 contact: " + label)

func _rig(parent: Node3D, exo: bool = false) -> Skeleton3D:
	var skeleton := Skeleton3D.new()
	skeleton.name = "ExoSkeleton" if exo else "UniversalSkeleton"
	parent.add_child(skeleton)
	for side in ["l", "r"]:
		var side_sign := -1.0 if side == "l" else 1.0
		var suffix := "Left" if side == "l" else "Right"
		var upper: String = suffix + "Arm" if exo else "upperarm_" + side
		var lower: String = suffix + "ForeArm" if exo else "lowerarm_" + side
		var hand: String = suffix + "Hand" if exo else "hand_" + side
		var upper_idx := skeleton.add_bone(upper)
		var lower_idx := skeleton.add_bone(lower)
		var hand_idx := skeleton.add_bone(hand)
		skeleton.set_bone_parent(lower_idx, upper_idx)
		skeleton.set_bone_parent(hand_idx, lower_idx)
		skeleton.set_bone_rest(upper_idx, Transform3D(Basis.IDENTITY, Vector3(0.22 * side_sign, 1.4, 0.0)))
		skeleton.set_bone_rest(lower_idx, Transform3D(Basis.IDENTITY, Vector3(0.17 * side_sign, -0.13, 0.08)))
		skeleton.set_bone_rest(hand_idx, Transform3D(Basis.IDENTITY, Vector3(0.15 * side_sign, -0.16, 0.10)))
		var index_name: String = ("LeftHandIndex1" if side == "l" else "RightHandIndex1") if exo else "index_01_" + side
		var middle_names: Array = [
			("LeftHandMiddle1" if side == "l" else "RightHandMiddle1"),
			("LeftHandMiddle2" if side == "l" else "RightHandMiddle2"),
			("LeftHandMiddle3" if side == "l" else "RightHandMiddle3"),
			("LeftHandMiddle4" if side == "l" else "RightHandMiddle4"),
		] if exo else ["middle_01_" + side, "middle_02_" + side, "middle_03_" + side, "middle_04_leaf_" + side]
		var pinky_name: String = ("LeftHandPinky1" if side == "l" else "RightHandPinky1") if exo else "pinky_01_" + side
		var across_sign := -1.0 if side == "l" else 1.0
		var index_idx := skeleton.add_bone(index_name)
		var middle_idx := skeleton.add_bone(middle_names[0])
		var pinky_idx := skeleton.add_bone(pinky_name)
		skeleton.set_bone_parent(index_idx, hand_idx)
		skeleton.set_bone_parent(middle_idx, hand_idx)
		skeleton.set_bone_parent(pinky_idx, hand_idx)
		var index_rest := Vector3(0.04 * across_sign, 0.08, 0.0) if exo else Vector3(0.0, 0.08, 0.04)
		var pinky_rest := Vector3(-0.04 * across_sign, 0.08, 0.0) if exo else Vector3(0.0, 0.08, -0.04)
		skeleton.set_bone_rest(index_idx, Transform3D(Basis.IDENTITY, index_rest))
		skeleton.set_bone_rest(middle_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.09, 0.0)))
		skeleton.set_bone_rest(pinky_idx, Transform3D(Basis.IDENTITY, pinky_rest))
		var previous_middle := middle_idx
		for finger_segment in range(1, 4):
			var finger_name: String = String(middle_names[finger_segment])
			var finger_idx := skeleton.add_bone(finger_name)
			skeleton.set_bone_parent(finger_idx, previous_middle)
			skeleton.set_bone_rest(finger_idx, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.05, 0.0)))
			previous_middle = finger_idx
	# Newly created bones have identity pose, not the authored rest transform.
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	return skeleton

func _valid_session() -> int:
	counter += 1
	owner.id = counter
	owner.enemy = zombie
	owner.health = 100
	zombie.hp = 90
	zombie.state = "limb_hold"
	return counter

func _begin(limb: String = "LEFT ARM", hand: String = "left") -> bool:
	return contact.begin_contact(zombie, owner, limb, hand, _valid_session())

func _run() -> void:
	host = Node3D.new()
	root.add_child(host)
	owner = TestOwner.new()
	host.add_child(owner)
	owner._skeleton = _rig(owner)
	zombie = TestEnemy.new()
	host.add_child(zombie)
	zombie.position.z = 0.32
	zombie._skeleton = _rig(zombie)
	contact = CONTACT.new() as BrutalGrabLimbContact
	host.add_child(contact)
	await process_frame

	var left := CONTACT.resolve_player_bones(owner._skeleton, "LEFT ARM", false)
	var right := CONTACT.resolve_player_bones(owner._skeleton, "RIGHT ARM", false)
	var enemy_left := CONTACT.resolve_enemy_bones(zombie._skeleton, "left")
	var enemy_right := CONTACT.resolve_enemy_bones(zombie._skeleton, "right")
	_check(not left.is_empty() and owner._skeleton.get_bone_name(left.wrist) == "hand_l", "left target mapped")
	_check(not right.is_empty() and owner._skeleton.get_bone_name(right.wrist) == "hand_r", "right target mapped")
	_check(not enemy_left.is_empty() and zombie._skeleton.get_bone_name(enemy_left.middle) == "lowerarm_l", "left elbow mapped")
	_check(not enemy_right.is_empty() and zombie._skeleton.get_bone_name(enemy_right.end) == "hand_r", "right hand mapped")
	var left_enemy_frame := ORIENTATION.resolve_hand_frame(zombie._skeleton, "left", false)
	var right_enemy_frame := ORIENTATION.resolve_hand_frame(zombie._skeleton, "right", false)
	var left_player_frame := ORIENTATION.resolve_hand_frame(owner._skeleton, "left", false)
	var right_player_frame := ORIENTATION.resolve_hand_frame(owner._skeleton, "right", false)
	_check(not left_enemy_frame.is_empty() and not right_enemy_frame.is_empty(), "both synthetic zombie palm frames resolve from finger hierarchies")
	_check(not left_player_frame.is_empty() and not right_player_frame.is_empty(), "both synthetic player palm frames resolve from finger hierarchies")
	_check(CONTACT.REACH_MARGIN_M <= 0.05, "reach allowance stays within the 5 cm contact tolerance")
	_check(contact.can_reach_contact(zombie, owner, "LEFT ARM", "left"), "valid finger frames pass the pre-QTE visual-contact preflight")
	_check(CONTACT.resolve_player_bones(owner._skeleton, "LEFT LEG", false).is_empty(), "leg contact intentionally not enabled")
	_check(CONTACT.resolve_player_bones(null, "LEFT ARM", false).is_empty(), "invalid player skeleton rejected")
	_check(CONTACT.resolve_enemy_bones(null, "left").is_empty(), "invalid enemy skeleton rejected")
	var bad_skeleton := Skeleton3D.new()
	host.add_child(bad_skeleton)
	bad_skeleton.add_bone("hand_l")
	_check(CONTACT.resolve_enemy_bones(bad_skeleton, "left").is_empty(), "missing enemy bones rejected")
	_check(ORIENTATION.resolve_hand_frame(bad_skeleton, "left", false).is_empty(), "missing zombie finger frame rejected safely")
	_check(CONTACT.resolve_player_bones(bad_skeleton, "LEFT ARM", false).is_empty(), "missing player bones rejected")
	var missing_finger_rig := Skeleton3D.new()
	host.add_child(missing_finger_rig)
	var incomplete_upper := missing_finger_rig.add_bone("upperarm_l")
	var incomplete_lower := missing_finger_rig.add_bone("lowerarm_l")
	var incomplete_hand := missing_finger_rig.add_bone("hand_l")
	missing_finger_rig.set_bone_parent(incomplete_lower, incomplete_upper)
	missing_finger_rig.set_bone_parent(incomplete_hand, incomplete_lower)
	missing_finger_rig.reset_bone_poses()
	var saved_enemy_rig := zombie._skeleton
	zombie._skeleton = missing_finger_rig
	_check(not contact.can_reach_contact(zombie, owner, "LEFT ARM", "left"), "missing zombie finger frame is rejected before QTE admission")
	var missing_frame_session := _valid_session()
	_check(not contact.begin_contact(zombie, owner, "LEFT ARM", "left", missing_frame_session) and contact.last_reject_reason == "missing_or_incompatible_hand_frame", "owned grab rejects a wrist without a verifiable palm frame")
	_check(contact._ik == null and contact._hand_orientation == null, "missing hand frame creates no skeletal modifier")
	zombie._skeleton = saved_enemy_rig
	_check(not contact.begin_contact(null, owner, "LEFT ARM", "left", 1), "invalid enemy reference rejected")
	_check(not contact.begin_contact(zombie, null, "LEFT ARM", "left", 1), "invalid player reference rejected")

	var initial_contact := _begin()
	_check(initial_contact, "left-arm contact initializes: %s" % contact.last_reject_reason)
	if not initial_contact:
		print("FAIL: Stage 3 IK fixture setup rejected: " + contact.last_reject_reason)
		quit(1)
		return
	_check(contact.is_solver_active() and contact.session_id == owner.id and contact.is_processing(), "exactly one active solver")
	_check(contact._ik.setting_count == 1 and contact._ik.get_end_bone_name(0) == "hand_l", "two-bone IK uses chosen hand")
	_check(is_zero_approx(contact._hand_orientation.influence), "palm correction begins at zero influence")
	contact.update_contact(CONTACT.BLEND_IN_SECONDS * 0.5)
	_check(absf(contact._hand_orientation.influence - 0.5) < 0.001, "palm correction follows the halfway blend-in")
	contact.update_contact(CONTACT.BLEND_IN_SECONDS * 0.5)
	_check(is_equal_approx(contact._hand_orientation.influence, 1.0), "palm correction reaches full influence with IK")
	# Godot applies modifiers in a deferred skeleton update. Only the
	# modification_processed signal exposes the solved bone pose.
	var left_sample := {"count": 0, "error": INF, "palm": INF, "finger": INF}
	var left_order: Array[String] = []
	contact._ik.modification_processed.connect(func() -> void:
		left_order.append("ik")
	)
	contact._hand_orientation.modification_processed.connect(func() -> void:
		left_order.append("orientation")
		if is_instance_valid(contact._target):
			left_sample.count = int(left_sample.count) + 1
			left_sample.error = CONTACT.bone_world(zombie._skeleton, enemy_left.end).distance_to(contact._target.global_position)
			var alignment: Dictionary = contact._hand_orientation.get_alignment_errors_degrees()
			if not alignment.is_empty():
				left_sample.palm = float(alignment.palm)
				left_sample.finger = float(alignment.finger)
	)
	contact.update_contact(0.20)
	await process_frame
	await process_frame
	_check(int(left_sample.count) > 0, "left orientation modifier processed after IK")
	_check(left_order.find("ik") >= 0 and left_order.find("orientation") > left_order.find("ik"), "left orientation correction runs after TwoBoneIK3D")
	_check(float(left_sample.error) <= 0.05, "left wrist attachment within 5 cm after orientation correction: %.3fm" % float(left_sample.error))
	_check(float(left_sample.palm) <= 1.0 and float(left_sample.finger) <= 1.0, "left palm and curled-finger axes resolve to the target frame")
	var release_modifier := contact._ik
	var release_orientation: SkeletonModifier3D = contact._hand_orientation as SkeletonModifier3D
	var influence_before_release := release_modifier.influence
	var orientation_before_release: float = release_orientation.influence
	contact.end_contact("escaped")
	_check(contact.is_solver_active() and not contact.is_processing() and contact.session_id == 0, "QTE success stops contact sampling and blends solver out")
	await create_timer(CONTACT.BLEND_OUT_SECONDS * 0.5).timeout
	_check(release_modifier.influence > 0.0 and release_modifier.influence < influence_before_release, "IK influence decreases during release blend")
	_check(release_orientation.influence > 0.0 and release_orientation.influence < orientation_before_release, "palm correction influence decreases during release blend")
	await create_timer(CONTACT.BLEND_OUT_SECONDS).timeout
	_check(not contact.is_solver_active(), "QTE success disables solver after blend-out")
	contact.end_contact("repeat")
	_check(not contact.is_solver_active() and contact.session_id == 0, "cleanup idempotent")
	await process_frame
	_check(zombie._skeleton.find_child("BrutalGrabArmIK", false, false) == null and zombie._skeleton.find_child("BrutalGrabHandOrientation", false, false) == null, "no stale skeletal modifiers after release")

	_check(_begin("RIGHT ARM", "right"), "right-arm contact initializes")
	var right_sample := {"count": 0, "error": INF, "palm": INF, "finger": INF}
	contact._hand_orientation.modification_processed.connect(func() -> void:
		if is_instance_valid(contact._target):
			right_sample.count = int(right_sample.count) + 1
			right_sample.error = CONTACT.bone_world(zombie._skeleton, enemy_right.end).distance_to(contact._target.global_position)
			var alignment: Dictionary = contact._hand_orientation.get_alignment_errors_degrees()
			if not alignment.is_empty():
				right_sample.palm = float(alignment.palm)
				right_sample.finger = float(alignment.finger)
	)
	contact.update_contact(0.20)
	await process_frame
	await process_frame
	_check(int(right_sample.count) > 0, "right orientation modifier processed")
	_check(float(right_sample.error) <= 0.05, "right wrist attachment within 5 cm after orientation correction: %.3fm" % float(right_sample.error))
	_check(float(right_sample.palm) <= 1.0 and float(right_sample.finger) <= 1.0, "right mirrored palm frame resolves independently")
	owner.rotation.y = 0.05
	zombie.rotation.y = -0.05
	contact.update_contact(0.05)
	await process_frame
	await process_frame
	_check(contact.is_solver_active() and float(right_sample.palm) <= 1.0 and float(right_sample.finger) <= 1.0, "small player and zombie rotations keep palm alignment without twist accumulation")
	owner.rotation.y = 0.0
	zombie.rotation.y = 0.0
	contact.end_contact("cancelled")

	# Exo Gray's visibly retargeted skeleton, not the hidden source rig.
	var exo := PlayerExoGrayRetarget.new()
	owner.add_child(exo)
	exo.target_skeleton = _rig(owner, true)
	exo.set_process(false)
	owner._exo_retarget = exo
	var exo_map := CONTACT.resolve_player_bones(exo.target_skeleton, "LEFT ARM", true)
	_check(not exo_map.is_empty() and exo.target_skeleton.get_bone_name(exo_map.wrist) == "LeftHand", "Exo Gray wrist mapping")
	_check(_begin(), "rendered Exo forearm contact initializes")
	_check(contact._player_skeleton == exo.target_skeleton, "contact samples visible Exo model")
	contact.end_contact("exo_release")
	owner._exo_retarget = null

	_check(_begin(), "death test setup")
	zombie.hp = 0
	contact.update_contact(0.016)
	_check(not contact.is_solver_active() and contact.last_end_reason == "dead_or_model_changed", "zombie death releases")
	_check(_begin(), "timeout test setup")
	owner.id = 0
	contact.update_contact(0.016)
	_check(not contact.is_solver_active(), "QTE timeout releases session")
	_check(_begin(), "player death test setup")
	owner.health = 0
	contact.update_contact(0.016)
	_check(not contact.is_solver_active(), "player death releases solver")
	_check(_begin(), "ownership test setup")
	owner.enemy = null
	contact.update_contact(0.016)
	_check(not contact.is_solver_active(), "ownership loss releases solver")
	_check(_begin(), "interrupted windup test setup")
	zombie.state = "recovery"
	contact.update_contact(0.016)
	_check(not contact.is_solver_active(), "interrupted grabber releases solver")
	_check(_begin(), "repeated sessions test setup")
	var old_id := owner.id
	contact.end_contact("escaped")
	_check(_begin("RIGHT ARM", "right") and owner.id > old_id and contact.session_id == owner.id, "consecutive session has new owner ID")
	contact.end_contact("reset")
	await create_timer(CONTACT.BLEND_OUT_SECONDS + 0.02).timeout
	await process_frame
	_check(zombie._skeleton.find_child("BrutalGrabArmIK", false, false) == null and zombie._skeleton.find_child("BrutalGrabHandOrientation", false, false) == null, "consecutive sessions leave no skeletal overrides")

	zombie.position.z = 4.0
	_check(not _begin() and contact.last_reject_reason == "target_outside_reach", "out-of-reach target rejected without stretching")
	_check(not contact.is_solver_active(), "unreachable contact cannot run per-frame solver")
	zombie.position.z = 0.32
	var other := TestEnemy.new()
	host.add_child(other)
	other._skeleton = _rig(other)
	owner.enemy = other
	_check(not contact.begin_contact(zombie, owner, "LEFT ARM", "left", owner.id), "stale enemy cannot reattach")
	owner.enemy = zombie

	_check(_begin(), "despawn test setup")
	zombie.queue_free()
	await process_frame
	contact.update_contact(0.016)
	_check(not contact.is_solver_active(), "despawn releases solver")
	_check(not contact.is_processing(), "inactive solver has no tick")
	host.queue_free()
	await process_frame

	if failures.is_empty():
		print("PASS: %d brutal grab Stage 3 limb-contact checks" % checks)
		quit(0)
	else:
		print("FAIL: %d / %d brutal grab Stage 3 limb-contact checks" % [failures.size(), checks])
		quit(1)
