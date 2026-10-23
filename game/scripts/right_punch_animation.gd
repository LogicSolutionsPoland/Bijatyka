extends RefCounted
class_name RightPunchAnimationBuilder

const LIBRARY_NAME := &"bijatyka"
const LEFT_ANIMATION_NAME := &"left_punch"
const RIGHT_ANIMATION_NAME := &"right_punch"
const CLIP_PATH := "bijatyka/right_punch"

static func clip_path(side: String) -> String:
    return "bijatyka/%s" % String(_animation_name(side))

static func _animation_name(side: String) -> StringName:
    return LEFT_ANIMATION_NAME if side == "left" else RIGHT_ANIMATION_NAME

static func install(animation_player: AnimationPlayer, skeleton: Skeleton3D, attack_profile: Dictionary) -> bool:
    if animation_player == null or skeleton == null:
        return false
    var animation_root := animation_player.get_node_or_null(animation_player.root_node)
    if animation_root == null:
        animation_root = animation_player.get_parent()
    if animation_root == null or not animation_root.is_ancestor_of(skeleton):
        return false
    if _resolve_bone_name(skeleton, "Chest").is_empty():
        return false

    var library := AnimationLibrary.new()
    for side in ["left", "right"]:
        var animation := _build_animation(skeleton, animation_root.get_path_to(skeleton), side, attack_profile)
        if animation == null:
            continue
        if library.add_animation(_animation_name(side), animation) != OK:
            continue
    if library.get_animation_list().is_empty():
        return false
    if animation_player.has_animation_library(LIBRARY_NAME):
        animation_player.remove_animation_library(LIBRARY_NAME)
    if animation_player.add_animation_library(LIBRARY_NAME, library) != OK:
        return false
    return animation_player.has_animation(CLIP_PATH)

static func _build_animation(skeleton: Skeleton3D, skeleton_path: NodePath, side: String, attack_profile: Dictionary) -> Animation:
    var arm := "Left" if side == "left" else "Right"
    if _resolve_bone_name(skeleton, arm + "UpperArm").is_empty():
        return null
    if _resolve_bone_name(skeleton, arm + "Forearm").is_empty():
        return null

    var windup := float(attack_profile.get("windup", 0.14))
    var active := float(attack_profile.get("active", 0.12))
    var recovery := float(attack_profile.get("recovery", 0.34))
    var total := windup + active + recovery
    var key_times := [
        0.0,
        windup * 0.28,
        windup * 0.70,
        windup,
        windup + active * 0.35,
        windup + active,
        windup + active + recovery * 0.30,
        windup + active + recovery * 0.72,
        total
    ]
    var animation := Animation.new()
    animation.length = total
    animation.step = 1.0 / 60.0
    animation.loop_mode = Animation.LOOP_NONE
    animation.add_marker(&"chamber", key_times[2])
    animation.add_marker(&"contact", windup)
    animation.add_marker(&"follow_through", key_times[4])

    var poses := _bone_eulers(side)
    for raw_bone_name in poses.keys():
        var bone_name := String(raw_bone_name)
        var resolved_name := _resolve_bone_name(skeleton, bone_name)
        if resolved_name.is_empty():
            continue
        var bone_index := skeleton.find_bone(resolved_name)
        var rest_rotation := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()
        var track := animation.add_track(Animation.TYPE_ROTATION_3D)
        animation.track_set_path(track, NodePath("%s:%s" % [str(skeleton_path), resolved_name]))
        animation.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
        var eulers: Array = poses[bone_name]
        for key_index in range(key_times.size()):
            var rotation := (rest_rotation * Quaternion.from_euler(eulers[key_index])).normalized()
            animation.rotation_track_insert_key(track, float(key_times[key_index]), rotation)
    return animation if animation.get_track_count() >= 3 else null

static func _resolve_bone_name(skeleton: Skeleton3D, requested_name: String) -> String:
    var aliases := {
        "Hips": ["Hips", "Pelvis"],
        "Spine": ["Spine", "Spine1"],
        "Chest": ["Chest", "Spine2", "UpperChest"],
        "Neck": ["Neck", "Neck1"],
        "Head": ["Head"],
        "LeftUpperArm": ["LeftUpperArm", "LeftArm"],
        "RightUpperArm": ["RightUpperArm", "RightArm"],
        "LeftForearm": ["LeftForearm", "LeftLowerArm"],
        "RightForearm": ["RightForearm", "RightLowerArm"],
        "LeftHand": ["LeftHand", "LeftWrist"],
        "RightHand": ["RightHand", "RightWrist"]
    }
    var candidates: Array = aliases.get(requested_name, [requested_name])
    for candidate in candidates:
        if skeleton.find_bone(String(candidate)) >= 0:
            return String(candidate)
    return ""

static func _bone_eulers(side: String) -> Dictionary:
    var arm := "Left" if side == "left" else "Right"
    var guard := "Right" if side == "left" else "Left"
    var mirror := -1.0 if side == "left" else 1.0
    return {
        "Hips": [
            Vector3.ZERO, Vector3(0.0, 0.025 * mirror, 0.0), Vector3(0.0, 0.085 * mirror, 0.0),
            Vector3(0.0, -0.035 * mirror, 0.0), Vector3(0.0, -0.075 * mirror, 0.0),
            Vector3(0.0, -0.05 * mirror, 0.0), Vector3(0.0, -0.025 * mirror, 0.0),
            Vector3(0.0, 0.0, 0.0), Vector3.ZERO
        ],
        "Spine": [
            Vector3.ZERO, Vector3(-0.015, 0.025 * mirror, 0.0), Vector3(-0.025, 0.065 * mirror, 0.0),
            Vector3(-0.035, -0.08 * mirror, 0.0), Vector3(-0.055, -0.12 * mirror, 0.0),
            Vector3(-0.035, -0.09 * mirror, 0.0), Vector3(-0.02, -0.035 * mirror, 0.0),
            Vector3.ZERO, Vector3.ZERO
        ],
        "Chest": [
            Vector3.ZERO, Vector3(-0.025, 0.035 * mirror, 0.02 * mirror), Vector3(-0.045, 0.12 * mirror, 0.045 * mirror),
            Vector3(-0.075, -0.17 * mirror, 0.035 * mirror), Vector3(-0.09, -0.24 * mirror, 0.025 * mirror),
            Vector3(-0.07, -0.18 * mirror, 0.02 * mirror), Vector3(-0.045, -0.08 * mirror, 0.01 * mirror),
            Vector3(-0.015, -0.02 * mirror, 0.0), Vector3.ZERO
        ],
        "Neck": [
            Vector3.ZERO, Vector3(0.0, -0.015 * mirror, 0.0), Vector3(0.015, -0.035 * mirror, 0.0),
            Vector3(0.025, 0.04 * mirror, 0.0), Vector3(0.02, 0.055 * mirror, 0.0),
            Vector3(0.015, 0.035 * mirror, 0.0), Vector3(0.005, 0.015 * mirror, 0.0),
            Vector3.ZERO, Vector3.ZERO
        ],
        arm + "UpperArm": [
            Vector3.ZERO, Vector3(0.18, 0.0, 0.035 * mirror), Vector3(0.82, 0.0, 0.10 * mirror),
            Vector3(1.36, 0.0, 0.12 * mirror), Vector3(1.48, 0.0, 0.10 * mirror),
            Vector3(1.30, 0.0, 0.08 * mirror), Vector3(0.82, 0.0, 0.04 * mirror),
            Vector3(0.30, 0.0, 0.02 * mirror), Vector3.ZERO
        ],
        arm + "Forearm": [
            Vector3.ZERO, Vector3(0.30, 0.0, 0.0), Vector3(0.92, 0.0, 0.0),
            Vector3(0.18, 0.0, 0.0), Vector3(0.08, 0.0, 0.0),
            Vector3(0.16, 0.0, 0.0), Vector3(0.45, 0.0, 0.0),
            Vector3(0.72, 0.0, 0.0), Vector3.ZERO
        ],
        arm + "Hand": [
            Vector3.ZERO, Vector3(0.0, 0.0, 0.02 * mirror), Vector3(0.0, 0.0, 0.04 * mirror),
            Vector3(0.0, 0.0, 0.08 * mirror), Vector3(0.0, 0.0, 0.10 * mirror),
            Vector3(0.0, 0.0, 0.06 * mirror), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO
        ],
        guard + "UpperArm": [
            Vector3(-0.12, 0.0, -0.025 * mirror), Vector3(-0.16, 0.0, -0.045 * mirror),
            Vector3(-0.20, 0.0, -0.06 * mirror), Vector3(-0.22, 0.0, -0.07 * mirror),
            Vector3(-0.24, 0.0, -0.08 * mirror), Vector3(-0.22, 0.0, -0.07 * mirror),
            Vector3(-0.18, 0.0, -0.05 * mirror), Vector3(-0.14, 0.0, -0.035 * mirror), Vector3(-0.12, 0.0, -0.025 * mirror)
        ],
        guard + "Forearm": [
            Vector3(-0.52, 0.0, 0.0), Vector3(-0.56, 0.0, 0.0), Vector3(-0.60, 0.0, 0.0),
            Vector3(-0.62, 0.0, 0.0), Vector3(-0.64, 0.0, 0.0), Vector3(-0.62, 0.0, 0.0),
            Vector3(-0.58, 0.0, 0.0), Vector3(-0.54, 0.0, 0.0), Vector3(-0.52, 0.0, 0.0)
        ]
    }
