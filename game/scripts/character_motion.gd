extends RefCounted
class_name ThornboundMotion

## Short responsive upper-body action clips for the imported 21-bone player rig.
## Source locomotion clips and hit-synchronized fight clips remain authoritative.

const LIBRARY_NAME := &"thornbound_actions"
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
	for bone_name in ["Hips", "Spine", "Chest", "Head", "Cape", "LeftUpperArm", "LeftForearm", "RightUpperArm", "RightForearm", "LeftThigh", "LeftShin", "RightThigh", "RightShin"]:
		if skeleton.find_bone(bone_name) < 0:
			return false
	var library := AnimationLibrary.new()
	for action_name in ACTIONS:
		var animation := _build_animation(animation_root.get_path_to(skeleton), skeleton, action_name, float(ACTIONS[action_name]))
		if library.add_animation(StringName(action_name), animation) != OK:
			return false
	if animation_player.has_animation_library(LIBRARY_NAME):
		animation_player.remove_animation_library(LIBRARY_NAME)
	return animation_player.add_animation_library(LIBRARY_NAME, library) == OK

static func _build_animation(skeleton_path: NodePath, skeleton: Skeleton3D, action_name: String, duration: float) -> Animation:
	var animation := Animation.new()
	animation.length = duration
	animation.step = 1.0 / 60.0
	animation.loop_mode = Animation.LOOP_NONE
	var key_times := [0.0, duration * 0.30, duration * 0.68, duration]
	var pose_data: Dictionary = _poses(action_name)
	for raw_bone_name in pose_data:
		var bone_name := String(raw_bone_name)
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var rest_rotation := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [str(skeleton_path), bone_name]))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		var frames: Array = pose_data[raw_bone_name]
		for index in range(mini(key_times.size(), frames.size())):
			var local_rotation := (rest_rotation * Quaternion.from_euler(frames[index] as Vector3)).normalized()
			animation.rotation_track_insert_key(track, float(key_times[index]), local_rotation)
	return animation

static func _poses(action_name: String) -> Dictionary:
	var zero := Vector3.ZERO
	match action_name:
		"Dash":
			return {
				"Spine": [zero, Vector3(-0.20, 0.0, 0.0), Vector3(-0.16, 0.0, 0.0), zero],
				"Chest": [zero, Vector3(-0.25, 0.0, 0.0), Vector3(-0.22, 0.0, 0.0), zero],
				"LeftUpperArm": [zero, Vector3(0.30, 0.0, -0.12), Vector3(0.25, 0.0, -0.08), zero],
				"RightUpperArm": [zero, Vector3(0.30, 0.0, 0.12), Vector3(0.25, 0.0, 0.08), zero],
				"Cape": [zero, Vector3(-0.20, 0.0, 0.0), Vector3(-0.28, 0.0, 0.0), zero]
			}
		"Landing":
			return {
				"Hips": [zero, Vector3(0.13, 0.0, 0.0), Vector3(0.09, 0.0, 0.0), zero],
				"Spine": [zero, Vector3(0.16, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), zero],
				"LeftThigh": [zero, Vector3(-0.24, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), zero],
				"RightThigh": [zero, Vector3(-0.24, 0.0, 0.0), Vector3(-0.15, 0.0, 0.0), zero],
				"LeftShin": [zero, Vector3(0.35, 0.0, 0.0), Vector3(0.20, 0.0, 0.0), zero],
				"RightShin": [zero, Vector3(0.35, 0.0, 0.0), Vector3(0.20, 0.0, 0.0), zero],
				"LeftUpperArm": [zero, Vector3(0.20, 0.0, 0.10), Vector3(0.14, 0.0, 0.06), zero],
				"RightUpperArm": [zero, Vector3(0.20, 0.0, -0.10), Vector3(0.14, 0.0, -0.06), zero],
				"Cape": [zero, Vector3(0.23, 0.0, 0.0), Vector3(0.10, 0.0, 0.0), zero]
			}
		"Turn_Left", "Turn_Right":
			var sign := 1.0 if action_name == "Turn_Left" else -1.0
			return {
				"Hips": [zero, Vector3(0.0, 0.10 * sign, 0.0), Vector3(0.0, 0.06 * sign, 0.0), zero],
				"Spine": [zero, Vector3(0.0, -0.16 * sign, 0.0), Vector3(0.0, -0.08 * sign, 0.0), zero],
				"Chest": [zero, Vector3(0.0, -0.18 * sign, 0.0), Vector3(0.0, -0.08 * sign, 0.0), zero],
				"Head": [zero, Vector3(0.0, 0.12 * sign, 0.0), Vector3(0.0, 0.06 * sign, 0.0), zero],
				"Cape": [zero, Vector3(0.0, 0.13 * sign, 0.0), Vector3(0.0, 0.06 * sign, 0.0), zero]
			}
		"Magic_Light":
			return _magic_pose(Vector3(-0.12, 0.0, 0.0), Vector3(-0.58, 0.0, -0.14), Vector3(-0.14, 0.0, -0.10))
		"Magic_Judgment":
			return _magic_pose(Vector3(-0.22, 0.0, 0.0), Vector3(-0.82, 0.0, -0.18), Vector3(-0.26, 0.0, -0.14))
		"Magic_Fire":
			return _magic_pose(Vector3(-0.14, 0.0, 0.0), Vector3(-0.45, 0.0, -0.12), Vector3(-0.08, 0.0, -0.12))
		"Magic_Shadow":
			return _magic_pose(Vector3(-0.18, 0.0, 0.0), Vector3(-0.62, 0.0, -0.22), Vector3(-0.20, 0.0, -0.16))
		"Hit":
			return {
				"Hips": [zero, Vector3(0.0, 0.0, 0.12), Vector3(0.0, 0.0, 0.07), zero],
				"Spine": [zero, Vector3(0.12, 0.0, 0.10), Vector3(0.06, 0.0, 0.05), zero],
				"Chest": [zero, Vector3(0.16, 0.0, 0.08), Vector3(0.07, 0.0, 0.03), zero],
				"LeftUpperArm": [zero, Vector3(0.20, 0.0, 0.18), Vector3(0.11, 0.0, 0.08), zero],
				"RightUpperArm": [zero, Vector3(0.20, 0.0, -0.18), Vector3(0.11, 0.0, -0.08), zero],
				"Cape": [zero, Vector3(0.18, 0.0, 0.0), Vector3(0.08, 0.0, 0.0), zero]
			}
		"Defeat":
			return {
				"Hips": [zero, Vector3(0.15, 0.0, 0.0), Vector3(0.46, 0.0, 0.0), Vector3(0.50, 0.0, 0.0)],
				"Spine": [zero, Vector3(0.12, 0.0, 0.0), Vector3(0.45, 0.0, 0.0), Vector3(0.52, 0.0, 0.0)],
				"Chest": [zero, Vector3(-0.12, 0.0, 0.0), Vector3(0.30, 0.0, 0.0), Vector3(0.34, 0.0, 0.0)],
				"LeftThigh": [zero, Vector3(-0.18, 0.0, -0.08), Vector3(-0.42, 0.0, -0.10), Vector3(-0.42, 0.0, -0.10)],
				"RightThigh": [zero, Vector3(-0.18, 0.0, 0.08), Vector3(-0.42, 0.0, 0.10), Vector3(-0.42, 0.0, 0.10)],
				"LeftShin": [zero, Vector3(0.25, 0.0, 0.0), Vector3(0.48, 0.0, 0.0), Vector3(0.48, 0.0, 0.0)],
				"RightShin": [zero, Vector3(0.25, 0.0, 0.0), Vector3(0.48, 0.0, 0.0), Vector3(0.48, 0.0, 0.0)],
				"LeftUpperArm": [zero, Vector3(0.35, 0.0, 0.20), Vector3(0.72, 0.0, 0.30), Vector3(0.72, 0.0, 0.30)],
				"RightUpperArm": [zero, Vector3(0.35, 0.0, -0.20), Vector3(0.72, 0.0, -0.30), Vector3(0.72, 0.0, -0.30)],
				"Cape": [zero, Vector3(0.22, 0.0, 0.0), Vector3(0.38, 0.0, 0.0), Vector3(0.38, 0.0, 0.0)]
			}
	return {}

static func _magic_pose(lean: Vector3, arm_lift: Vector3, follow_through: Vector3) -> Dictionary:
	var zero := Vector3.ZERO
	return {
		"Spine": [zero, lean, lean * 0.8, zero],
		"Chest": [zero, lean + Vector3(-0.06, 0.0, 0.0), lean * 0.65, zero],
		"LeftUpperArm": [zero, arm_lift, follow_through, zero],
		"LeftForearm": [zero, Vector3(0.48, 0.0, 0.0), Vector3(0.22, 0.0, 0.0), zero],
		"RightUpperArm": [zero, Vector3(0.18, 0.0, -0.10), Vector3(0.12, 0.0, -0.05), zero],
		"RightForearm": [zero, Vector3(0.40, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), zero],
		"Head": [zero, Vector3(-0.05, 0.0, 0.0), Vector3(-0.02, 0.0, 0.0), zero],
		"Cape": [zero, Vector3(-0.14, 0.0, 0.0), Vector3(-0.10, 0.0, 0.0), zero]
	}
