extends RefCounted
class_name UniversalBaseCharacterMotion

## Runtime animation bridge for the 65-bone Universal Base Characters rig.

const LIBRARY_NAME := &"universal_base_actions"
const FORWARD_AXIS_SIGN := -1.0
const BONE_MAP := {
	"Hips": "pelvis",
	"Spine": "spine_02",
	"Chest": "spine_03",
	"Head": "Head",
	"LeftUpperArm": "upperarm_l",
	"LeftForearm": "lowerarm_l",
	"LeftHand": "hand_l",
	"LeftThigh": "thigh_l",
	"LeftShin": "calf_l",
	"LeftFoot": "foot_l",
	"RightUpperArm": "upperarm_r",
	"RightForearm": "lowerarm_r",
	"RightHand": "hand_r",
	"RightThigh": "thigh_r",
	"RightShin": "calf_r",
	"RightFoot": "foot_r"
}
const ACTIONS := {
	"Dash": 0.30,
	"Landing": 0.38,
	"Turn_Left": 0.28,
	"Turn_Right": 0.28,
	"Magic_Light": 0.62,
	"Magic_Judgment": 0.72,
	"Magic_Fire": 0.62,
	"Magic_Shadow": 0.68,
	"Hit": 0.34,
	"Defeat": 1.25
}

static func clip_path(action_name: String) -> StringName:
	return StringName("%s/%s" % [String(LIBRARY_NAME), action_name])

static func install(animation_player: AnimationPlayer, skeleton: Skeleton3D) -> bool:
	if animation_player == null or skeleton == null:
		return false
	var animation_root := animation_player.get_node_or_null(animation_player.root_node)
	if animation_root == null:
		animation_root = animation_player.get_parent()
	if animation_root == null or not animation_root.is_ancestor_of(skeleton):
		return false
	for source_bone: String in BONE_MAP:
		if skeleton.find_bone(String(BONE_MAP[source_bone])) < 0:
			return false

	var action_library := AnimationLibrary.new()
	for raw_action_name in ACTIONS:
		var action_name := String(raw_action_name)
		var action := _build_action(
			skeleton,
			animation_root.get_path_to(skeleton),
			action_name,
			float(ACTIONS[raw_action_name])
		)
		if action_library.add_animation(StringName(action_name), action) != OK:
			return false
	if animation_player.has_animation_library(LIBRARY_NAME):
		animation_player.remove_animation_library(LIBRARY_NAME)
	if animation_player.add_animation_library(LIBRARY_NAME, action_library) != OK:
		return false

	for animation_name in ["Idle", "Walk", "Sprint", "Jump"]:
		var animation := _build_locomotion(skeleton, animation_root.get_path_to(skeleton), animation_name)
		if animation_player.has_animation(StringName(animation_name)):
			animation_player.remove_animation(StringName(animation_name))
		if animation_player.add_animation(StringName(animation_name), animation) != OK:
			return false
	return true

static func _build_locomotion(skeleton: Skeleton3D, skeleton_path: NodePath, animation_name: String) -> Animation:
	var duration := 1.0
	var key_times: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
	var animation := Animation.new()
	match animation_name:
		"Walk":
			duration = 0.64
		"Sprint":
			duration = 0.46
		"Jump":
			duration = 0.58
		_:
			duration = 1.2
	animation.length = duration
	animation.step = 1.0 / 60.0
	animation.loop_mode = Animation.LOOP_LINEAR if animation_name != "Jump" else Animation.LOOP_NONE
	var zero := Vector3.ZERO
	match animation_name:
		"Idle":
			_add_rotation_track(animation, skeleton, skeleton_path, "Spine", key_times, [zero, Vector3(-0.018, 0.0, 0.0), zero, Vector3(-0.018, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "Chest", key_times, [zero, Vector3(-0.025, 0.0, 0.0), zero, Vector3(-0.025, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "Head", key_times, [zero, Vector3(0.015, 0.0, 0.0), zero, Vector3(0.015, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "LeftUpperArm", key_times, [zero, Vector3(0.0, 0.0, -0.025), zero, Vector3(0.0, 0.0, -0.025), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "RightUpperArm", key_times, [zero, Vector3(0.0, 0.0, 0.025), zero, Vector3(0.0, 0.0, 0.025), zero])
		"Walk", "Sprint":
			var stride := 0.48 if animation_name == "Walk" else 0.78
			var knee := 0.24 if animation_name == "Walk" else 0.42
			var arm_swing := 0.28 if animation_name == "Walk" else 0.48
			_add_rotation_track(animation, skeleton, skeleton_path, "LeftThigh", key_times, [Vector3(stride, 0.0, 0.0), zero, Vector3(-stride, 0.0, 0.0), zero, Vector3(stride, 0.0, 0.0)])
			_add_rotation_track(animation, skeleton, skeleton_path, "RightThigh", key_times, [Vector3(-stride, 0.0, 0.0), zero, Vector3(stride, 0.0, 0.0), zero, Vector3(-stride, 0.0, 0.0)])
			_add_rotation_track(animation, skeleton, skeleton_path, "LeftShin", key_times, [Vector3(knee, 0.0, 0.0), Vector3(knee * 0.4, 0.0, 0.0), zero, Vector3(knee * 0.4, 0.0, 0.0), Vector3(knee, 0.0, 0.0)])
			_add_rotation_track(animation, skeleton, skeleton_path, "RightShin", key_times, [zero, Vector3(knee * 0.4, 0.0, 0.0), Vector3(knee, 0.0, 0.0), Vector3(knee * 0.4, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "LeftUpperArm", key_times, [Vector3(-arm_swing, 0.0, 0.0), zero, Vector3(arm_swing, 0.0, 0.0), zero, Vector3(-arm_swing, 0.0, 0.0)])
			_add_rotation_track(animation, skeleton, skeleton_path, "RightUpperArm", key_times, [Vector3(arm_swing, 0.0, 0.0), zero, Vector3(-arm_swing, 0.0, 0.0), zero, Vector3(arm_swing, 0.0, 0.0)])
			_add_rotation_track(animation, skeleton, skeleton_path, "Spine", key_times, [Vector3(0.02, 0.0, 0.0), zero, Vector3(-0.02, 0.0, 0.0), zero, Vector3(0.02, 0.0, 0.0)])
		"Jump":
			var jump_times: Array[float] = [0.0, 0.22, 0.72, 1.0]
			_add_rotation_track(animation, skeleton, skeleton_path, "LeftThigh", jump_times, [zero, Vector3(-0.28, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "RightThigh", jump_times, [zero, Vector3(-0.28, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "LeftShin", jump_times, [zero, Vector3(0.38, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "RightShin", jump_times, [zero, Vector3(0.38, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "LeftUpperArm", jump_times, [zero, Vector3(-0.35, 0.0, -0.16), Vector3(-0.20, 0.0, -0.10), zero])
			_add_rotation_track(animation, skeleton, skeleton_path, "RightUpperArm", jump_times, [zero, Vector3(-0.35, 0.0, 0.16), Vector3(-0.20, 0.0, 0.10), zero])
	return animation

static func _build_action(skeleton: Skeleton3D, skeleton_path: NodePath, action_name: String, duration: float) -> Animation:
	var animation := Animation.new()
	animation.length = duration
	animation.step = 1.0 / 60.0
	animation.loop_mode = Animation.LOOP_NONE
	var key_times := [0.0, duration * 0.22, duration * 0.68, duration]
	var poses := _action_poses(action_name)
	for raw_bone_name in poses:
		_add_rotation_track(
			animation,
			skeleton,
			skeleton_path,
			String(raw_bone_name),
			key_times,
			poses[raw_bone_name]
		)
	return animation

static func _add_rotation_track(
	animation: Animation,
	skeleton: Skeleton3D,
	skeleton_path: NodePath,
	source_bone: String,
	key_times: Array,
	poses: Array
) -> void:
	var target_bone := String(BONE_MAP.get(source_bone, source_bone))
	var bone_index := skeleton.find_bone(target_bone)
	if bone_index < 0:
		return
	var rest_rotation := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [str(skeleton_path), target_bone]))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for index in range(mini(key_times.size(), poses.size())):
		var local_pose: Vector3 = poses[index]
		local_pose.x *= FORWARD_AXIS_SIGN
		var local_rotation := (rest_rotation * Quaternion.from_euler(local_pose)).normalized()
		animation.rotation_track_insert_key(track, float(key_times[index]), local_rotation)

static func _action_poses(action_name: String) -> Dictionary:
	var zero := Vector3.ZERO
	match action_name:
		"Dash":
			return {
				"Spine": [zero, Vector3(-0.18, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), zero],
				"Chest": [zero, Vector3(-0.24, 0.0, 0.0), Vector3(-0.16, 0.0, 0.0), zero],
				"LeftUpperArm": [zero, Vector3(0.28, 0.0, -0.12), Vector3(0.20, 0.0, -0.08), zero],
				"RightUpperArm": [zero, Vector3(0.28, 0.0, 0.12), Vector3(0.20, 0.0, 0.08), zero]
			}
		"Landing":
			return {
				"Hips": [zero, Vector3(0.12, 0.0, 0.0), Vector3(0.07, 0.0, 0.0), zero],
				"Spine": [zero, Vector3(0.14, 0.0, 0.0), Vector3(0.06, 0.0, 0.0), zero],
				"LeftThigh": [zero, Vector3(-0.22, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), zero],
				"RightThigh": [zero, Vector3(-0.22, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), zero],
				"LeftShin": [zero, Vector3(0.30, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), zero],
				"RightShin": [zero, Vector3(0.30, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), zero]
			}
		"Turn_Left", "Turn_Right":
			var direction := 1.0 if action_name == "Turn_Left" else -1.0
			return {
				"Hips": [zero, Vector3(0.0, 0.10 * direction, 0.0), Vector3(0.0, 0.06 * direction, 0.0), zero],
				"Spine": [zero, Vector3(0.0, -0.12 * direction, 0.0), Vector3(0.0, -0.06 * direction, 0.0), zero],
				"Head": [zero, Vector3(0.0, 0.12 * direction, 0.0), Vector3(0.0, 0.06 * direction, 0.0), zero]
			}
		"Magic_Light", "Magic_Judgment", "Magic_Fire", "Magic_Shadow":
			var lift := 0.58
			if action_name == "Magic_Judgment":
				lift = 0.82
			elif action_name == "Magic_Fire":
				lift = 0.46
			elif action_name == "Magic_Shadow":
				lift = 0.66
			return {
				"Spine": [zero, Vector3(-0.14, 0.0, 0.0), Vector3(-0.10, 0.0, 0.0), zero],
				"Chest": [zero, Vector3(-0.08, 0.0, 0.0), Vector3(-0.04, 0.0, 0.0), zero],
				"RightUpperArm": [zero, Vector3(-lift, 0.0, -0.18), Vector3(-0.18, 0.0, -0.08), zero],
				"RightForearm": [zero, Vector3(0.42, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), zero],
				"LeftUpperArm": [zero, Vector3(0.18, 0.0, 0.10), Vector3(0.12, 0.0, 0.05), zero]
			}
		"Hit":
			return {
				"Hips": [zero, Vector3(0.0, 0.0, 0.10), Vector3(0.0, 0.0, 0.06), zero],
				"Spine": [zero, Vector3(0.12, 0.0, 0.10), Vector3(0.06, 0.0, 0.04), zero],
				"Chest": [zero, Vector3(0.14, 0.0, 0.06), Vector3(0.06, 0.0, 0.03), zero],
				"LeftUpperArm": [zero, Vector3(0.20, 0.0, 0.14), Vector3(0.10, 0.0, 0.06), zero],
				"RightUpperArm": [zero, Vector3(0.20, 0.0, -0.14), Vector3(0.10, 0.0, -0.06), zero]
			}
		"Defeat":
			return {
				"Hips": [zero, Vector3(0.14, 0.0, 0.0), Vector3(0.42, 0.0, 0.0), Vector3(0.48, 0.0, 0.0)],
				"Spine": [zero, Vector3(0.12, 0.0, 0.0), Vector3(0.38, 0.0, 0.0), Vector3(0.48, 0.0, 0.0)],
				"Chest": [zero, Vector3(-0.10, 0.0, 0.0), Vector3(0.26, 0.0, 0.0), Vector3(0.32, 0.0, 0.0)],
				"LeftThigh": [zero, Vector3(-0.14, 0.0, -0.08), Vector3(-0.35, 0.0, -0.10), Vector3(-0.35, 0.0, -0.10)],
				"RightThigh": [zero, Vector3(-0.14, 0.0, 0.08), Vector3(-0.35, 0.0, 0.10), Vector3(-0.35, 0.0, 0.10)],
				"LeftShin": [zero, Vector3(0.20, 0.0, 0.0), Vector3(0.40, 0.0, 0.0), Vector3(0.40, 0.0, 0.0)],
				"RightShin": [zero, Vector3(0.20, 0.0, 0.0), Vector3(0.40, 0.0, 0.0), Vector3(0.40, 0.0, 0.0)],
				"LeftUpperArm": [zero, Vector3(0.32, 0.0, 0.18), Vector3(0.66, 0.0, 0.28), Vector3(0.66, 0.0, 0.28)],
				"RightUpperArm": [zero, Vector3(0.32, 0.0, -0.18), Vector3(0.66, 0.0, -0.28), Vector3(0.66, 0.0, -0.28)]
			}
	return {}
