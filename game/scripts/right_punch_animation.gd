extends RefCounted
class_name RightPunchAnimationBuilder

const LIBRARY_NAME := &"bijatyka"
const ANIMATION_NAME := &"right_punch"
const CLIP_PATH := "bijatyka/right_punch"

static func install(animation_player: AnimationPlayer, skeleton: Skeleton3D, attack_profile: Dictionary) -> bool:
	if animation_player == null or skeleton == null:
		return false
	var animation_root := animation_player.get_node_or_null(animation_player.root_node)
	if animation_root == null:
		animation_root = animation_player.get_parent()
	if animation_root == null or not animation_root.is_ancestor_of(skeleton):
		return false
	for required_bone: String in ["Chest", "RightUpperArm", "RightForearm"]:
		if skeleton.find_bone(required_bone) < 0:
			return false

	var animation := _build_animation(skeleton, animation_root.get_path_to(skeleton), attack_profile)
	if animation.get_track_count() < 3:
		return false
	var library := AnimationLibrary.new()
	if library.add_animation(ANIMATION_NAME, animation) != OK:
		return false
	if animation_player.has_animation_library(LIBRARY_NAME):
		animation_player.remove_animation_library(LIBRARY_NAME)
	if animation_player.add_animation_library(LIBRARY_NAME, library) != OK:
		return false
	return animation_player.has_animation(CLIP_PATH)

static func _build_animation(skeleton: Skeleton3D, skeleton_path: NodePath, attack_profile: Dictionary) -> Animation:
	var windup := float(attack_profile.get("windup", 0.14))
	var active := float(attack_profile.get("active", 0.12))
	var recovery := float(attack_profile.get("recovery", 0.34))
	var total := windup + active + recovery
	var key_times := [
		0.0,
		windup * 0.34,
		windup * 0.72,
		windup,
		windup + active * 0.72,
		windup + active + recovery * 0.30,
		windup + active + recovery * 0.72,
		total
	]
	var animation := Animation.new()
	animation.length = total
	animation.step = 1.0 / 60.0
	animation.loop_mode = Animation.LOOP_NONE
	animation.add_marker(&"contact", windup)
	var poses := _bone_eulers()
	for raw_bone_name in poses.keys():
		var bone_name := String(raw_bone_name)
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			continue
		var rest_rotation := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [str(skeleton_path), bone_name]))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
		var eulers: Array = poses[bone_name]
		for key_index in range(key_times.size()):
			var euler: Vector3 = eulers[key_index]
			var rotation := (rest_rotation * Quaternion.from_euler(euler)).normalized()
			animation.rotation_track_insert_key(track, float(key_times[key_index]), rotation)
	return animation

static func _bone_eulers() -> Dictionary:
	return {
		"Hips": [
			Vector3.ZERO, Vector3(0.0, 0.025, 0.0), Vector3(0.0, 0.045, 0.0), Vector3(0.0, -0.035, 0.0),
			Vector3(0.0, -0.055, 0.0), Vector3(0.0, -0.025, 0.0), Vector3(0.0, 0.0, 0.0), Vector3.ZERO
		],
		"Spine": [
			Vector3.ZERO, Vector3(-0.015, 0.035, 0.0), Vector3(-0.025, 0.075, 0.0), Vector3(-0.04, -0.11, 0.0),
			Vector3(-0.05, -0.14, 0.0), Vector3(-0.025, -0.07, 0.0), Vector3.ZERO, Vector3.ZERO
		],
		"Chest": [
			Vector3.ZERO, Vector3(-0.025, 0.075, 0.025), Vector3(-0.045, 0.14, 0.035), Vector3(-0.08, -0.18, 0.03),
			Vector3(-0.09, -0.22, 0.025), Vector3(-0.055, -0.12, 0.015), Vector3(-0.015, -0.025, 0.0), Vector3.ZERO
		],
		"RightUpperArm": [
			Vector3.ZERO, Vector3(-0.34, 0.0, -0.08), Vector3(-0.58, 0.0, -0.12), Vector3(-1.15, 0.0, -0.15),
			Vector3(-1.06, 0.0, -0.13), Vector3(-0.62, 0.0, -0.08), Vector3(-0.18, 0.0, -0.03), Vector3.ZERO
		],
		"RightForearm": [
			Vector3.ZERO, Vector3(-0.42, 0.0, 0.0), Vector3(-0.60, 0.0, 0.0), Vector3(-0.70, 0.0, 0.0),
			Vector3(-0.48, 0.0, 0.0), Vector3(-0.32, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3.ZERO
		],
		"RightHand": [
			Vector3.ZERO, Vector3(0.0, 0.0, 0.025), Vector3(0.0, 0.0, 0.04), Vector3(0.0, 0.0, 0.09),
			Vector3(0.0, 0.0, 0.06), Vector3(0.0, 0.0, 0.035), Vector3(0.0, 0.0, 0.01), Vector3.ZERO
		],
		"LeftUpperArm": [
			Vector3.ZERO, Vector3(-0.08, 0.0, 0.035), Vector3(-0.14, 0.0, 0.06), Vector3(-0.19, 0.0, 0.08),
			Vector3(-0.17, 0.0, 0.07), Vector3(-0.12, 0.0, 0.05), Vector3(-0.05, 0.0, 0.02), Vector3.ZERO
		],
		"LeftForearm": [
			Vector3.ZERO, Vector3(-0.08, 0.0, 0.0), Vector3(-0.12, 0.0, 0.0), Vector3(-0.16, 0.0, 0.0),
			Vector3(-0.15, 0.0, 0.0), Vector3(-0.10, 0.0, 0.0), Vector3(-0.04, 0.0, 0.0), Vector3.ZERO
		]
	}
