extends SceneTree
## Stage 3 synthetic-rig host tests. Geometry tests are NOT a Redmi visual pass.
const CONTACT := preload("res://scripts/brutal_grab_limb_contact.gd")

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
		var upper := suffix + "Arm" if exo else "upperarm_" + side
		var lower := suffix + "ForeArm" if exo else "lowerarm_" + side
		var hand := suffix + "Hand" if exo else "hand_" + side
		var upper_idx := skeleton.add_bone(upper)
		var lower_idx := skeleton.add_bone(lower)
		var hand_idx := skeleton.add_bone(hand)
		skeleton.set_bone_parent(lower_idx, upper_idx)
		skeleton.set_bone_parent(hand_idx, lower_idx)
		skeleton.set_bone_rest(upper_idx, Transform3D(Basis.IDENTITY, Vector3(0.22 * side_sign, 1.4, 0.0)))
		skeleton.set_bone_rest(lower_idx, Transform3D(Basis.IDENTITY, Vector3(0.17 * side_sign, -0.13, 0.08)))
		skeleton.set_bone_rest(hand_idx, Transform3D(Basis.IDENTITY, Vector3(0.15 * side_sign, -0.16, 0.10)))
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
	_check(CONTACT.resolve_player_bones(owner._skeleton, "LEFT LEG", false).is_empty(), "leg contact intentionally not enabled")
	_check(CONTACT.resolve_player_bones(null, "LEFT ARM", false).is_empty(), "invalid player skeleton rejected")
	_check(CONTACT.resolve_enemy_bones(null, "left").is_empty(), "invalid enemy skeleton rejected")
	var bad_skeleton := Skeleton3D.new()
	host.add_child(bad_skeleton)
	bad_skeleton.add_bone("hand_l")
	_check(CONTACT.resolve_enemy_bones(bad_skeleton, "left").is_empty(), "missing enemy bones rejected")
	_check(CONTACT.resolve_player_bones(bad_skeleton, "LEFT ARM", false).is_empty(), "missing player bones rejected")
	_check(not contact.begin_contact(null, owner, "LEFT ARM", "left", 1), "invalid enemy reference rejected")
	_check(not contact.begin_contact(zombie, null, "LEFT ARM", "left", 1), "invalid player reference rejected")

	_check(_begin(), "left-arm contact initializes")
	_check(contact.is_solver_active() and contact.session_id == owner.id and contact.is_processing(), "exactly one active solver")
	_check(contact._ik.setting_count == 1 and contact._ik.get_end_bone_name(0) == "hand_l", "two-bone IK uses chosen hand")
	contact.update_contact(0.20)
	zombie._skeleton.advance(0.016)
	var left_error := CONTACT.bone_world(zombie._skeleton, enemy_left.end).distance_to(contact._target.global_position)
	_check(left_error <= 0.05, "left wrist attachment within 5 cm: %.3fm" % left_error)
	contact.end_contact("escaped")
	_check(not contact.is_solver_active() and not contact.is_processing(), "QTE success disables solver")
	contact.end_contact("repeat")
	_check(not contact.is_solver_active() and contact.session_id == 0, "cleanup idempotent")
	await process_frame
	_check(zombie._skeleton.find_child("BrutalGrabArmIK", false, false) == null, "no stale IK node after release")

	_check(_begin("RIGHT ARM", "right"), "right-arm contact initializes")
	contact.update_contact(0.20)
	zombie._skeleton.advance(0.016)
	var right_error := CONTACT.bone_world(zombie._skeleton, enemy_right.end).distance_to(contact._target.global_position)
	_check(right_error <= 0.05, "right wrist attachment within 5 cm: %.3fm" % right_error)
	owner.rotation.y = 0.05
	zombie.rotation.y = -0.05
	contact.update_contact(0.05)
	zombie._skeleton.advance(0.016)
	_check(contact.is_solver_active(), "small player and zombie rotations keep contact")
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
	await process_frame
	_check(zombie._skeleton.find_child("BrutalGrabArmIK", false, false) == null, "consecutive sessions leave no overrides")

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
