extends Node
class_name BrutalGrabLimbContact
## Stage 3: visual-only, session-bound wrist contact. Never owns the QTE/hold.
## One TwoBoneIK3D on the active zombie rig; no CharacterBody3D motion.
const BLEND_IN_SECONDS := 0.10
const BLEND_OUT_SECONDS := 0.08
const REACH_MARGIN_M := 0.03
const FOREARM_CONTACT_FRACTION := 0.82
const HAND_ORIENTATION := preload("res://scripts/brutal_grab_hand_orientation.gd")
const IMMEDIATE_END_REASONS := [
	"actor_invalid", "session_or_hold_lost", "dead_or_model_changed",
	"scene_exit", "replaced", "visual_contact_unreachable", "model_released",
	"enemy_despawned", "enemy_died", "player_dead", "player_condemned", "respawn",
]

const PLAYER_BONES := {
	"LEFT ARM": {"exo": ["LeftForeArm", "LeftHand"], "base": ["lowerarm_l", "hand_l"]},
	"RIGHT ARM": {"exo": ["RightForeArm", "RightHand"], "base": ["lowerarm_r", "hand_r"]},
}
const ENEMY_BONES := {
	"left": ["upperarm_l", "lowerarm_l", "hand_l"],
	"right": ["upperarm_r", "lowerarm_r", "hand_r"],
}

var session_id := 0
var last_end_reason := ""
var last_reject_reason := ""
var last_hand_error_m := INF
var last_palm_alignment_error_degrees := INF
var last_finger_alignment_error_degrees := INF
var _owner_ref: WeakRef
var _enemy_ref: WeakRef
var _player_ref: WeakRef
var _player_skeleton: Skeleton3D
var _enemy_skeleton: Skeleton3D
var _target_forearm := -1
var _target_wrist := -1
var _upper_arm := -1
var _elbow := -1
var _hand := -1
var _reach_m := 0.0
var _elapsed := 0.0
var _target: Marker3D
var _pole: Marker3D
var _ik: TwoBoneIK3D
var _hand_orientation
var _release_tween: Tween
var _release_generation := 0
var _is_releasing := false

func configure(owner: Node) -> void:
	set_process(false)
	set_process_priority(200) # Exo Gray copies its visible pose at priority 100.
	_owner_ref = weakref(owner)
	owner.grab_qte_started.connect(_on_qte_started)
	owner.grab_fully_ended.connect(_on_grab_ended)

func _on_qte_started(id: int, enemy: FoundationEnemy, limb: String, _presses: int, _duration: float) -> void:
	var owner: Node = _owner_ref.get_ref() if _owner_ref != null else null
	if is_instance_valid(owner):
		begin_contact(enemy, owner, limb, String(enemy._limb_grab_hand), id)

func _on_grab_ended(reason: String) -> void:
	end_contact(reason)

static func resolve_player_bones(skeleton: Skeleton3D, limb: String, exo: bool) -> Dictionary:
	if not is_instance_valid(skeleton) or not PLAYER_BONES.has(limb):
		return {}
	var names: Array = PLAYER_BONES[limb]["exo" if exo else "base"]
	var forearm := skeleton.find_bone(String(names[0]))
	var wrist := skeleton.find_bone(String(names[1]))
	if forearm < 0 or wrist < 0 or skeleton.get_bone_parent(wrist) != forearm:
		return {}
	return {"forearm": forearm, "wrist": wrist}

static func resolve_enemy_bones(skeleton: Skeleton3D, side: String) -> Dictionary:
	if not is_instance_valid(skeleton) or not ENEMY_BONES.has(side):
		return {}
	var names: Array = ENEMY_BONES[side]
	var root := skeleton.find_bone(String(names[0]))
	var middle := skeleton.find_bone(String(names[1]))
	var end := skeleton.find_bone(String(names[2]))
	if root < 0 or middle < 0 or end < 0:
		return {}
	if skeleton.get_bone_parent(middle) != root or skeleton.get_bone_parent(end) != middle:
		return {}
	return {"root": root, "middle": middle, "end": end}

static func bone_world(skeleton: Skeleton3D, bone: int) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin

static func forearm_contact_point(skeleton: Skeleton3D, forearm: int, wrist: int) -> Vector3:
	return bone_world(skeleton, forearm).lerp(bone_world(skeleton, wrist), FOREARM_CONTACT_FRACTION)

# Read-only admission used before Stage 2 QTE starts on detailed actors.
# The same chain mapping and reach limits are enforced by begin_contact().
func can_reach_contact(enemy: Node, player: Node, limb: String, hand_side: String) -> bool:
	if not is_instance_valid(enemy) or not is_instance_valid(player):
		return false
	var rig := enemy.get("_skeleton") as Skeleton3D
	var driver := player.get("_exo_retarget") as PlayerExoGrayRetarget
	var exo := is_instance_valid(driver) and is_instance_valid(driver.target_skeleton)
	var target_rig: Skeleton3D = driver.target_skeleton if exo else player.get("_skeleton") as Skeleton3D
	var player_bones := resolve_player_bones(target_rig, limb, exo)
	var enemy_bones := resolve_enemy_bones(rig, hand_side)
	if player_bones.is_empty() or enemy_bones.is_empty():
		return false
	var player_side := "left" if limb == "LEFT ARM" else "right"
	if HAND_ORIENTATION.resolve_hand_frame(target_rig, player_side, exo).is_empty() or HAND_ORIENTATION.resolve_hand_frame(rig, hand_side, false).is_empty():
		return false
	var shoulder := bone_world(rig, int(enemy_bones.root))
	var elbow := bone_world(rig, int(enemy_bones.middle))
	var wrist := bone_world(rig, int(enemy_bones.end))
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	var distance := shoulder.distance_to(forearm_contact_point(target_rig, int(player_bones.forearm), int(player_bones.wrist)))
	return upper_length + lower_length > 0.02 and distance <= upper_length + lower_length + REACH_MARGIN_M and distance >= absf(upper_length - lower_length) + 0.02

func begin_contact(enemy: Node, player: Node, limb: String, hand_side: String, id: int) -> bool:
	end_contact("replaced")
	last_reject_reason = ""
	if id <= 0 or not is_instance_valid(enemy) or not is_instance_valid(player):
		last_reject_reason = "invalid_actor_or_session"
		return false
	if enemy.is_queued_for_deletion() or player.is_queued_for_deletion():
		last_reject_reason = "actor_queued_for_deletion"
		return false
	if not player.has_method("get_active_grab_session_id") or not player.has_method("get_active_grab_enemy"):
		last_reject_reason = "missing_grab_authority"
		return false
	if player.call("get_active_grab_session_id") != id or player.call("get_active_grab_enemy") != enemy:
		last_reject_reason = "session_not_owned"
		return false
	var skeleton := enemy.get("_skeleton") as Skeleton3D
	var driver := player.get("_exo_retarget") as PlayerExoGrayRetarget
	var visible_exo := is_instance_valid(driver) and is_instance_valid(driver.target_skeleton)
	var target_skeleton: Skeleton3D = driver.target_skeleton if visible_exo else player.get("_skeleton") as Skeleton3D
	var target_bones := resolve_player_bones(target_skeleton, limb, visible_exo)
	var hand_bones := resolve_enemy_bones(skeleton, hand_side)
	if target_bones.is_empty() or hand_bones.is_empty():
		last_reject_reason = "missing_or_incompatible_bones"
		return false
	var player_side := "left" if limb == "LEFT ARM" else "right"
	if HAND_ORIENTATION.resolve_hand_frame(target_skeleton, player_side, visible_exo).is_empty() or HAND_ORIENTATION.resolve_hand_frame(skeleton, hand_side, false).is_empty():
		last_reject_reason = "missing_or_incompatible_hand_frame"
		return false
	var root_idx: int = hand_bones.root
	var mid_idx: int = hand_bones.middle
	var hand_idx: int = hand_bones.end
	var shoulder := bone_world(skeleton, root_idx)
	var elbow := bone_world(skeleton, mid_idx)
	var wrist := bone_world(skeleton, hand_idx)
	var length_m := shoulder.distance_to(elbow) + elbow.distance_to(wrist)
	var contact := forearm_contact_point(target_skeleton, int(target_bones.forearm), int(target_bones.wrist))
	if length_m <= 0.02 or shoulder.distance_to(contact) > length_m + REACH_MARGIN_M:
		last_reject_reason = "target_outside_reach"
		return false
	if shoulder.distance_to(contact) < absf(shoulder.distance_to(elbow) - elbow.distance_to(wrist)) + 0.02:
		last_reject_reason = "target_too_close"
		return false
	_player_ref = weakref(player)
	_enemy_ref = weakref(enemy)
	_player_skeleton = target_skeleton
	_enemy_skeleton = skeleton
	_target_forearm = int(target_bones.forearm)
	_target_wrist = int(target_bones.wrist)
	_upper_arm = root_idx
	_elbow = mid_idx
	_hand = hand_idx
	_reach_m = length_m
	_elapsed = 0.0
	last_hand_error_m = INF
	last_palm_alignment_error_degrees = INF
	last_finger_alignment_error_degrees = INF
	_target = Marker3D.new()
	_target.name = "GrabContactTarget"
	_enemy_skeleton.add_child(_target)
	_pole = Marker3D.new()
	_pole.name = "GrabContactPole"
	_enemy_skeleton.add_child(_pole)
	_target.global_position = contact
	_update_pole()
	_ik = TwoBoneIK3D.new()
	_ik.name = "BrutalGrabArmIK"
	_ik.active = false
	_enemy_skeleton.add_child(_ik)
	_ik.set_setting_count(1)
	_ik.set_root_bone_name(0, String(skeleton.get_bone_name(root_idx)))
	_ik.set_middle_bone_name(0, String(skeleton.get_bone_name(mid_idx)))
	_ik.set_end_bone_name(0, String(skeleton.get_bone_name(hand_idx)))
	_ik.set_target_node(0, _ik.get_path_to(_target))
	_ik.set_pole_node(0, _ik.get_path_to(_pole))
	_ik.set_pole_direction(0, SkeletonModifier3D.SECONDARY_DIRECTION_PLUS_Y)
	# This fires *after* Godot solves and blends the skeleton pose.
	_ik.influence = 0.0
	_ik.active = true
	# Skeleton3D processes direct-child modifiers in tree order. This child is
	# deliberately added after TwoBoneIK3D so it sees the solved wrist chain.
	_hand_orientation = HAND_ORIENTATION.new()
	_hand_orientation.name = "BrutalGrabHandOrientation"
	_hand_orientation.influence = 0.0
	_hand_orientation.active = true
	_enemy_skeleton.add_child(_hand_orientation)
	if not _hand_orientation.configure(_enemy_skeleton, hand_idx, hand_side, target_skeleton,
			int(target_bones.forearm), int(target_bones.wrist), player_side, visible_exo):
		last_reject_reason = "hand_orientation_configuration_failed"
		_clear_contact_nodes()
		return false
	_hand_orientation.modification_processed.connect(_on_hand_orientation_processed)
	session_id = id
	set_process(true)
	return true

func _update_pole() -> void:
	var shoulder := bone_world(_enemy_skeleton, _upper_arm)
	var elbow := bone_world(_enemy_skeleton, _elbow)
	var hand := bone_world(_enemy_skeleton, _hand)
	var outward := elbow - (shoulder + hand) * 0.5
	if outward.length_squared() < 0.0001:
		var side: Vector3 = _enemy_skeleton.global_transform.basis.x.normalized()
		outward = side if String(_enemy_skeleton.get_bone_name(_hand)).ends_with("_r") else -side
	_pole.global_position = elbow + outward.normalized() * 0.40

func _process(delta: float) -> void:
	update_contact(delta)

func update_contact(delta: float) -> void:
	if session_id <= 0:
		set_process(false)
		return
	var player: Node = _player_ref.get_ref() if _player_ref != null else null
	var enemy: Node = _enemy_ref.get_ref() if _enemy_ref != null else null
	if not is_instance_valid(player) or not is_instance_valid(enemy) or not is_instance_valid(_enemy_skeleton) or not is_instance_valid(_player_skeleton):
		end_contact("actor_invalid")
		return
	if enemy.is_queued_for_deletion() or player.is_queued_for_deletion() or player.call("get_active_grab_session_id") != session_id or player.call("get_active_grab_enemy") != enemy or String(enemy.get("state")) != "limb_hold":
		end_contact("session_or_hold_lost")
		return
	if int(enemy.get("hp")) <= 0 or int(player.get("health")) <= 0 or enemy.get("_skeleton") != _enemy_skeleton:
		end_contact("dead_or_model_changed")
		return
	var contact := forearm_contact_point(_player_skeleton, _target_forearm, _target_wrist)
	var shoulder := bone_world(_enemy_skeleton, _upper_arm)
	if shoulder.distance_to(contact) > _reach_m + REACH_MARGIN_M:
		_cancel_owned_session("visual_contact_unreachable")
		return
	_target.global_position = contact
	_update_pole()
	_elapsed += maxf(0.0, delta)
	_ik.influence = clampf(_elapsed / BLEND_IN_SECONDS, 0.0, 1.0)
	if is_instance_valid(_hand_orientation):
		_hand_orientation.influence = _ik.influence

func _on_hand_orientation_processed() -> void:
	if session_id <= 0 or not is_instance_valid(_enemy_skeleton) or not is_instance_valid(_target) or not is_instance_valid(_hand_orientation):
		return
	last_hand_error_m = bone_world(_enemy_skeleton, _hand).distance_to(_target.global_position)
	var errors: Dictionary = _hand_orientation.get_alignment_errors_degrees()
	if not errors.is_empty():
		last_finger_alignment_error_degrees = float(errors.finger)
		last_palm_alignment_error_degrees = float(errors.palm)

func is_solver_active() -> bool:
	return is_instance_valid(_ik) and _ik.active

func _cancel_owned_session(reason: String) -> void:
	# The contact component requests cleanup, but FoundationPlayer remains the
	# sole authority that ends the grab/QTE and releases the attacker slot.
	var active_id := session_id
	var player: Node = _player_ref.get_ref() if _player_ref != null else null
	var enemy: Node = _enemy_ref.get_ref() if _enemy_ref != null else null
	if active_id > 0 and is_instance_valid(player) and is_instance_valid(enemy):
		if player.has_method("get_active_grab_session_id") and player.has_method("get_active_grab_enemy") and player.has_method("cancel_limb_grab"):
			if player.call("get_active_grab_session_id") == active_id and player.call("get_active_grab_enemy") == enemy:
				player.call("cancel_limb_grab", reason)
				return
	end_contact(reason)

func end_contact(reason: String = "cancelled") -> void:
	if session_id <= 0:
		if _is_releasing and reason in IMMEDIATE_END_REASONS:
			last_end_reason = reason
			_clear_contact_nodes()
		return
	last_end_reason = reason
	session_id = 0
	set_process(false)
	if not is_instance_valid(_ik) or reason in IMMEDIATE_END_REASONS:
		_clear_contact_nodes()
		return
	_is_releasing = true
	_release_generation += 1
	var release_token := _release_generation
	_release_tween = create_tween()
	_release_tween.tween_property(_ik, "influence", 0.0, BLEND_OUT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_hand_orientation):
		_release_tween.parallel().tween_property(_hand_orientation, "influence", 0.0, BLEND_OUT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_release_tween.tween_callback(_finish_blended_release.bind(release_token))

func _finish_blended_release(release_token: int) -> void:
	if release_token != _release_generation or not _is_releasing:
		return
	_release_tween = null
	_clear_contact_nodes()

func _clear_contact_nodes() -> void:
	_release_generation += 1
	if is_instance_valid(_release_tween):
		_release_tween.kill()
	_release_tween = null
	_is_releasing = false
	if is_instance_valid(_ik):
		_ik.influence = 0.0
		_ik.active = false
		_ik.queue_free()
	if is_instance_valid(_hand_orientation):
		_hand_orientation.influence = 0.0
		_hand_orientation.active = false
		_hand_orientation.queue_free()
	if is_instance_valid(_target):
		_target.queue_free()
	if is_instance_valid(_pole):
		_pole.queue_free()
	_ik = null
	_hand_orientation = null
	_target = null
	_pole = null
	_enemy_ref = null
	_player_ref = null
	_enemy_skeleton = null
	_player_skeleton = null
	_target_forearm = -1
	_target_wrist = -1
	_upper_arm = -1
	_elbow = -1
	_hand = -1
	_reach_m = 0.0
	_elapsed = 0.0
	last_hand_error_m = INF
	last_palm_alignment_error_degrees = INF
	last_finger_alignment_error_degrees = INF

func _exit_tree() -> void:
	end_contact("scene_exit")
