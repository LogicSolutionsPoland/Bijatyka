extends Node
class_name PlayerExoGrayRetarget

## The combat rig is deliberately left unchanged (Universal Base, 65 bones).
## Copy its *rest-relative global* rotations to the Exo Gray Mixamo mesh rig.
## Copying local rotations directly would twist limbs because the two rigs have
## different rest axes. The copy happens after physics-driven AnimationPlayer
## updates, on the render frame. No second animation library is installed.
##
## Exo Gray's GLB is preprocessed to remove the "mixamorig:" prefixes: Godot
## Skeleton3D bone names cannot contain ':'.

const BONE_PAIRS := [
	["pelvis", "Hips"],
	["spine_01", "Spine"],
	["spine_02", "Spine1"],
	["spine_03", "Spine2"],
	["neck_01", "Neck"],
	["Head", "Head"],
	["clavicle_l", "LeftShoulder"],
	["upperarm_l", "LeftArm"],
	["lowerarm_l", "LeftForeArm"],
	["hand_l", "LeftHand"],
	["clavicle_r", "RightShoulder"],
	["upperarm_r", "RightArm"],
	["lowerarm_r", "RightForeArm"],
	["hand_r", "RightHand"],
	["thigh_l", "LeftUpLeg"],
	["calf_l", "LeftLeg"],
	["foot_l", "LeftFoot"],
	["thigh_r", "RightUpLeg"],
	["calf_r", "RightLeg"],
	["foot_r", "RightFoot"],
]

var source_skeleton: Skeleton3D
var target_skeleton: Skeleton3D
var _bone_pairs: Array[Vector2i] = []
var _root_translation_scale := 1.0

func configure(source: Skeleton3D, target: Skeleton3D) -> bool:
	set_process(false)
	source_skeleton = source
	target_skeleton = target
	_bone_pairs.clear()
	if source_skeleton == null or target_skeleton == null:
		return false
	for pair in BONE_PAIRS:
		var source_index := source_skeleton.find_bone(String(pair[0]))
		var target_index := target_skeleton.find_bone(String(pair[1]))
		if source_index < 0 or target_index < 0:
			push_warning("Exo Gray retarget missing bone %s -> %s" % [pair[0], pair[1]])
			return false
		_bone_pairs.append(Vector2i(source_index, target_index))
	# Scene nodes have a 0.01 root scale in the original centimeter-based GLB.
	# Convert pelvis translations from the 65-bone rig into target rig units.
	var source_scale := source_skeleton.global_transform.basis.get_scale().y
	var target_scale := target_skeleton.global_transform.basis.get_scale().y
	if target_scale > 0.00001:
		_root_translation_scale = source_scale / target_scale
	set_process_priority(100)
	set_process(true)
	synchronize_pose()
	return true

func _process(_delta: float) -> void:
	synchronize_pose()

func synchronize_pose() -> void:
	if not is_instance_valid(source_skeleton) or not is_instance_valid(target_skeleton):
		set_process(false)
		return
	for pair in _bone_pairs:
		var from_bone := pair.x
		var to_bone := pair.y
		var source_pose := source_skeleton.get_bone_global_pose(from_bone)
		var source_rest := source_skeleton.get_bone_global_rest(from_bone)
		var target_rest := target_skeleton.get_bone_global_rest(to_bone)
		var source_rotation := source_pose.basis.get_rotation_quaternion()
		var rest_rotation := source_rest.basis.get_rotation_quaternion()
		var target_rest_rotation := target_rest.basis.get_rotation_quaternion()
		var wanted_global_rotation := (source_rotation * rest_rotation.inverse() * target_rest_rotation).normalized()
		var parent_bone := target_skeleton.get_bone_parent(to_bone)
		var parent_rotation := Quaternion.IDENTITY
		if parent_bone >= 0:
			parent_rotation = target_skeleton.get_bone_global_pose(parent_bone).basis.get_rotation_quaternion()
		target_skeleton.set_bone_pose_rotation(to_bone, (parent_rotation.inverse() * wanted_global_rotation).normalized())
		if from_bone == _bone_pairs[0].x:
			var pelvis_delta := source_pose.origin - source_rest.origin
			target_skeleton.set_bone_pose_position(
				to_bone,
				target_skeleton.get_bone_rest(to_bone).origin + pelvis_delta * _root_translation_scale
			)
