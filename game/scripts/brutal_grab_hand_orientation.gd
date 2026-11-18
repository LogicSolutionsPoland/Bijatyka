extends SkeletonModifier3D
class_name BrutalGrabHandOrientation
## Session-scoped palm orientation, chained after the active arm TwoBoneIK3D.
## The imported rigs have mirrored side-specific palm frames, so derive each
## frame from the actual hand and finger rest hierarchy instead of assuming a
## common local axis.

const EXO_BONES := {
	"left": {"hand": "LeftHand", "index": "LeftHandIndex1", "middle_tip": "LeftHandMiddle4", "pinky": "LeftHandPinky1"},
	"right": {"hand": "RightHand", "index": "RightHandIndex1", "middle_tip": "RightHandMiddle4", "pinky": "RightHandPinky1"},
}
const UNIVERSAL_BONES := {
	"left": {"hand": "hand_l", "index": "index_01_l", "middle_tip": "middle_04_leaf_l", "pinky": "pinky_01_l"},
	"right": {"hand": "hand_r", "index": "index_01_r", "middle_tip": "middle_04_leaf_r", "pinky": "pinky_01_r"},
}

var _enemy_skeleton: Skeleton3D
var _player_skeleton: Skeleton3D
var _enemy_hand := -1
var _player_forearm := -1
var _player_hand := -1
var _enemy_side := ""
var _player_side := ""
var _enemy_frame: Dictionary = {}
var _player_frame: Dictionary = {}
var _configured := false
var _last_target_finger_world := Vector3.ZERO
var _last_target_palm_world := Vector3.ZERO
var _has_target_frame := false

static func _is_descendant_of(skeleton: Skeleton3D, bone: int, ancestor: int) -> bool:
	var cursor := bone
	while cursor >= 0:
		if cursor == ancestor:
			return true
		cursor = skeleton.get_bone_parent(cursor)
	return false

## Returns the measured frame in hand-local rest space. `finger` points out
## through the middle finger; `lateral` points from index to pinky; their cross
## product gives the palm normal. The left/right result is deliberately
## resolved separately because the GLBs mirror their thumb and wrist axes.
static func resolve_hand_frame(skeleton: Skeleton3D, side: String, exo: bool) -> Dictionary:
	if not is_instance_valid(skeleton) or not (EXO_BONES if exo else UNIVERSAL_BONES).has(side):
		return {}
	var names: Dictionary = (EXO_BONES if exo else UNIVERSAL_BONES)[side]
	var hand := skeleton.find_bone(String(names.hand))
	var index := skeleton.find_bone(String(names.index))
	var middle_tip := skeleton.find_bone(String(names.middle_tip))
	var pinky := skeleton.find_bone(String(names.pinky))
	if hand < 0 or index < 0 or middle_tip < 0 or pinky < 0:
		return {}
	if skeleton.get_bone_parent(index) != hand or skeleton.get_bone_parent(pinky) != hand:
		return {}
	if not _is_descendant_of(skeleton, middle_tip, hand):
		return {}
	var hand_rest := skeleton.get_bone_global_rest(hand)
	var hand_inverse := hand_rest.affine_inverse()
	var finger_tip_local: Vector3 = hand_inverse * skeleton.get_bone_global_rest(middle_tip).origin
	var index_local: Vector3 = hand_inverse * skeleton.get_bone_global_rest(index).origin
	var pinky_local: Vector3 = hand_inverse * skeleton.get_bone_global_rest(pinky).origin
	if finger_tip_local.length_squared() < 0.000001:
		return {}
	var finger_axis := finger_tip_local.normalized()
	var lateral_axis := pinky_local - index_local
	lateral_axis -= finger_axis * lateral_axis.dot(finger_axis)
	if lateral_axis.length_squared() < 0.000001:
		return {}
	lateral_axis = lateral_axis.normalized()
	var palm_axis := finger_axis.cross(lateral_axis).normalized()
	if palm_axis.length_squared() < 0.99:
		return {}
	return {
		"hand": hand,
		"finger": finger_axis,
		"lateral": lateral_axis,
		"palm": palm_axis,
		"index": index,
		"middle_tip": middle_tip,
		"pinky": pinky,
	}

func configure(enemy_skeleton: Skeleton3D, enemy_hand: int, enemy_side: String,
		player_skeleton: Skeleton3D, player_forearm: int, player_hand: int,
		player_side: String, player_is_exo: bool) -> bool:
	_configured = false
	_has_target_frame = false
	_enemy_skeleton = enemy_skeleton
	_player_skeleton = player_skeleton
	_enemy_hand = enemy_hand
	_player_forearm = player_forearm
	_player_hand = player_hand
	_enemy_side = enemy_side
	_player_side = player_side
	if not is_instance_valid(_enemy_skeleton) or not is_instance_valid(_player_skeleton):
		return false
	if _enemy_hand < 0 or _enemy_hand >= _enemy_skeleton.get_bone_count():
		return false
	if _player_forearm < 0 or _player_hand < 0 or _player_hand >= _player_skeleton.get_bone_count():
		return false
	if _player_skeleton.get_bone_parent(_player_hand) != _player_forearm:
		return false
	_enemy_frame = resolve_hand_frame(_enemy_skeleton, _enemy_side, false)
	_player_frame = resolve_hand_frame(_player_skeleton, _player_side, player_is_exo)
	if _enemy_frame.is_empty() or _player_frame.is_empty():
		return false
	if int(_enemy_frame.hand) != _enemy_hand or int(_player_frame.hand) != _player_hand:
		return false
	_configured = true
	return true

func _resolve_target_frame() -> Dictionary:
	if not _configured or not is_instance_valid(_player_skeleton):
		return {}
	var forearm := _player_skeleton.get_bone_global_pose(_player_forearm).origin
	var wrist := _player_skeleton.get_bone_global_pose(_player_hand).origin
	var finger_world := (_player_skeleton.global_transform.basis.orthonormalized() * (wrist - forearm)).normalized()
	if finger_world.length_squared() < 0.99:
		return {}
	var player_hand_basis := _player_skeleton.global_transform.basis.orthonormalized() * _player_skeleton.get_bone_global_pose(_player_hand).basis.orthonormalized()
	var player_lateral: Vector3 = player_hand_basis * _player_frame.lateral
	var lateral_world := player_lateral - finger_world * player_lateral.dot(finger_world)
	var expected_palm: Vector3 = player_hand_basis * _player_frame.palm
	if lateral_world.length_squared() < 0.0001:
		var palm_projected := expected_palm - finger_world * expected_palm.dot(finger_world)
		if palm_projected.length_squared() < 0.0001:
			return {}
		lateral_world = palm_projected.normalized().cross(finger_world)
	else:
		lateral_world = lateral_world.normalized()
	var palm_world := finger_world.cross(lateral_world).normalized()
	if palm_world.dot(expected_palm) < 0.0:
		lateral_world = -lateral_world
		palm_world = -palm_world
	if palm_world.length_squared() < 0.99 or lateral_world.length_squared() < 0.99:
		return {}
	return {"finger": finger_world, "palm": palm_world, "lateral": lateral_world}

func _process_modification_with_delta(_delta: float) -> void:
	_has_target_frame = false
	var skeleton := get_skeleton()
	if not _configured or not is_instance_valid(skeleton) or skeleton != _enemy_skeleton:
		return
	var target := _resolve_target_frame()
	if target.is_empty():
		return
	var source_basis := Basis(_enemy_frame.palm, _enemy_frame.finger, _enemy_frame.lateral).orthonormalized()
	var target_basis := Basis(target.palm, target.finger, target.lateral).orthonormalized()
	var desired_world_basis := target_basis * source_basis.inverse()
	var skeleton_world_basis := skeleton.global_transform.basis.orthonormalized()
	var desired_skeleton_basis := (skeleton_world_basis.inverse() * desired_world_basis).orthonormalized()
	var hand_pose := skeleton.get_bone_global_pose(_enemy_hand)
	var hand_scale := hand_pose.basis.get_scale()
	hand_pose.basis = desired_skeleton_basis.scaled(hand_scale)
	skeleton.set_bone_global_pose(_enemy_hand, hand_pose)
	_last_target_finger_world = target.finger
	_last_target_palm_world = target.palm
	_has_target_frame = true

func get_alignment_errors_degrees() -> Dictionary:
	if not _has_target_frame or _enemy_frame.is_empty() or not is_instance_valid(_enemy_skeleton):
		return {}
	var hand_world_basis := _enemy_skeleton.global_transform.basis.orthonormalized() * _enemy_skeleton.get_bone_global_pose(_enemy_hand).basis.orthonormalized()
	var actual_finger: Vector3 = (hand_world_basis * _enemy_frame.finger).normalized()
	var actual_palm: Vector3 = (hand_world_basis * _enemy_frame.palm).normalized()
	return {
		"finger": rad_to_deg(actual_finger.angle_to(_last_target_finger_world)),
		"palm": rad_to_deg(actual_palm.angle_to(_last_target_palm_world)),
		"actual_finger": actual_finger,
		"actual_palm": actual_palm,
		"target_finger": _last_target_finger_world,
		"target_palm": _last_target_palm_world,
	}
