extends RefCounted
class_name UniversalBaseCharacterMotion

## Routes Quaternius UAL clips onto the matching Universal Base Characters rig.

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
	"RightFoot": "foot_r",
}
const ACTIONS := {
	"Dash": 0.62,
	"Landing": 0.55,
	"Turn_Left": 0.28,
	"Turn_Right": 0.28,
	"Magic_Light": 0.84,
	"Magic_Judgment": 0.84,
	"Magic_Fire": 0.84,
	"Magic_Shadow": 0.84,
	"Hit": 0.72,
	"Hit_React": 0.72,
	"Defeat": 1.25,
	"Death_Forward": 1.25,
	"Death_Backward": 1.25,
}
const ACTION_SOURCE_CLIPS := {
	"Dash": "Roll",
	"Landing": "Jump_Land",
	"Magic_Light": "Spell_Simple_Shoot",
	"Magic_Judgment": "Spell_Simple_Shoot",
	"Magic_Fire": "Spell_Simple_Shoot",
	"Magic_Shadow": "Spell_Simple_Shoot",
	"Hit": "Hit_Chest",
	"Hit_React": "Hit_Chest",
	"Defeat": "Death01",
	"Death_Forward": "Death01",
	"Death_Backward": "Death01",
}
const DEFAULT_SOURCE_CLIPS := {
	"Idle": "Idle_Loop",
	"Walk": "Walk_Loop",
	"Sprint": "Sprint_Loop",
	"Jump": "Jump_Loop",
	"Hit_React": "Hit_Chest",
	"Death_Forward": "Death01",
	"Death_Backward": "Death01",
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
	for logical_bone: String in BONE_MAP:
		if skeleton.find_bone(String(BONE_MAP[logical_bone])) < 0:
			return false
	var default_library := animation_player.get_animation_library(&"")
	if default_library == null:
		return false
	for raw_target in DEFAULT_SOURCE_CLIPS:
		var target_name := String(raw_target)
		var source_name := String(DEFAULT_SOURCE_CLIPS[raw_target])
		if not _copy_animation(default_library, source_name, default_library, target_name):
			return false
	for loop_name in ["Idle", "Walk", "Sprint"]:
		if default_library.has_animation(StringName(loop_name)):
			default_library.get_animation(StringName(loop_name)).loop_mode = Animation.LOOP_LINEAR
	var action_library := AnimationLibrary.new()
	for raw_action in ACTIONS:
		var action_name := String(raw_action)
		var action: Animation
		if action_name == "Turn_Left" or action_name == "Turn_Right":
			action = _build_turn(skeleton, animation_root.get_path_to(skeleton), action_name == "Turn_Left", float(ACTIONS[raw_action]))
		else:
			var source_clip := String(ACTION_SOURCE_CLIPS[action_name])
			if not default_library.has_animation(StringName(source_clip)):
				return false
			action = default_library.get_animation(StringName(source_clip)).duplicate(true) as Animation
		if action == null:
			return false
		if action_library.add_animation(StringName(action_name), action) != OK:
			return false
	if animation_player.has_animation_library(LIBRARY_NAME):
		animation_player.remove_animation_library(LIBRARY_NAME)
	return animation_player.add_animation_library(LIBRARY_NAME, action_library) == OK

static func _copy_animation(source: AnimationLibrary, source_name: String, target: AnimationLibrary, target_name: String) -> bool:
	var source_key := StringName(source_name)
	var target_key := StringName(target_name)
	if not source.has_animation(source_key):
		return false
	if target.has_animation(target_key):
		target.remove_animation(target_key)
	var copied := source.get_animation(source_key).duplicate(true) as Animation
	return copied != null and target.add_animation(target_key, copied) == OK

static func _build_turn(skeleton: Skeleton3D, skeleton_path: NodePath, turn_left: bool, duration: float) -> Animation:
	var animation := Animation.new()
	animation.length = duration
	animation.step = 1.0 / 60.0
	animation.loop_mode = Animation.LOOP_NONE
	var direction := 1.0 if turn_left else -1.0
	_add_rotation_track(animation, skeleton, skeleton_path, "Spine", [0.0, duration * 0.5, duration], [Vector3.ZERO, Vector3(0.0, -0.10 * direction, 0.0), Vector3.ZERO])
	_add_rotation_track(animation, skeleton, skeleton_path, "Head", [0.0, duration * 0.5, duration], [Vector3.ZERO, Vector3(0.0, 0.14 * direction, 0.0), Vector3.ZERO])
	return animation

static func _add_rotation_track(animation: Animation, skeleton: Skeleton3D, skeleton_path: NodePath, source_bone: String, key_times: Array[float], poses: Array[Vector3]) -> void:
	var target_bone := String(BONE_MAP.get(source_bone, source_bone))
	var bone_index := skeleton.find_bone(target_bone)
	if bone_index < 0:
		return
	var rest_rotation := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
	var track := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track, NodePath("%s:%s" % [str(skeleton_path), target_bone]))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	for index in range(mini(key_times.size(), poses.size())):
		var local_rotation := (rest_rotation * Quaternion.from_euler(poses[index] * Vector3(FORWARD_AXIS_SIGN, 1.0, 1.0))).normalized()
		animation.rotation_track_insert_key(track, key_times[index], local_rotation)
