extends RefCounted
class_name KickAnimationBuilder

const LIBRARY_NAME := &"bijatyka_kicks"
const LEFT_ANIMATION_NAME := &"left_kick"
const RIGHT_ANIMATION_NAME := &"right_kick"

const BONE_ALIASES := {
    "Hips": ["Hips", "Pelvis"],
    "Spine": ["Spine", "Spine1"],
    "Chest": ["Chest", "Spine2", "UpperChest"],
    "LeftThigh": ["LeftThigh", "LeftUpperLeg", "LeftUpLeg"],
    "LeftShin": ["LeftShin", "LeftLowerLeg", "LeftLeg"],
    "LeftFoot": ["LeftFoot", "LeftAnkle"],
    "RightThigh": ["RightThigh", "RightUpperLeg", "RightUpLeg"],
    "RightShin": ["RightShin", "RightLowerLeg", "RightLeg"],
    "RightFoot": ["RightFoot", "RightAnkle"],
    "LeftUpperArm": ["LeftUpperArm", "LeftArm"],
    "LeftForearm": ["LeftForearm", "LeftLowerArm"],
    "RightUpperArm": ["RightUpperArm", "RightArm"],
    "RightForearm": ["RightForearm", "RightLowerArm"]
}

static func clip_path(side: String) -> String:
    return "bijatyka_kicks/%s" % String(_animation_name(side))

static func install(animation_player: AnimationPlayer, skeleton: Skeleton3D, attack_profile: Dictionary) -> Dictionary:
    var readiness := {"left": false, "right": false}
    if animation_player == null or skeleton == null:
        return readiness
    var animation_root := animation_player.get_node_or_null(animation_player.root_node)
    if animation_root == null:
        animation_root = animation_player.get_parent()
    if animation_root == null or not animation_root.is_ancestor_of(skeleton):
        return readiness

    var library := AnimationLibrary.new()
    for side in ["left", "right"]:
        var animation := _build_animation(skeleton, animation_root.get_path_to(skeleton), side, attack_profile)
        if animation == null:
            continue
        if library.add_animation(_animation_name(side), animation) == OK:
            readiness[side] = true
    if library.get_animation_list().is_empty():
        return {"left": false, "right": false}
    if animation_player.has_animation_library(LIBRARY_NAME):
        animation_player.remove_animation_library(LIBRARY_NAME)
    if animation_player.add_animation_library(LIBRARY_NAME, library) != OK:
        return {"left": false, "right": false}
    for side in ["left", "right"]:
        readiness[side] = animation_player.has_animation(clip_path(side))
    return readiness

static func _animation_name(side: String) -> StringName:
    return LEFT_ANIMATION_NAME if side == "left" else RIGHT_ANIMATION_NAME

static func _build_animation(skeleton: Skeleton3D, skeleton_path: NodePath, side: String, attack_profile: Dictionary) -> Animation:
    var kicking_leg := "Left" if side == "left" else "Right"
    var support_leg := "Right" if side == "left" else "Left"
    var required_bones := ["Chest", kicking_leg + "Thigh", kicking_leg + "Shin"]
    for required_bone in required_bones:
        if _resolve_bone_name(skeleton, required_bone).is_empty():
            return null

    var windup := float(attack_profile.get("windup", 0.23))
    var active := float(attack_profile.get("active", 0.16))
    var recovery := float(attack_profile.get("recovery", 0.48))
    var total := windup + active + recovery
    var key_times := [
        0.0,
        windup * 0.28,
        windup * 0.72,
        windup,
        windup + active * 0.35,
        windup + active,
        windup + active + recovery * 0.28,
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
    var poses := _bone_eulers(kicking_leg, support_leg)
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
    return animation

static func _resolve_bone_name(skeleton: Skeleton3D, requested_name: String) -> String:
    var candidates: Array = BONE_ALIASES.get(requested_name, [requested_name])
    for candidate in candidates:
        if skeleton.find_bone(String(candidate)) >= 0:
            return String(candidate)
    return ""

static func _bone_eulers(kicking_leg: String, support_leg: String) -> Dictionary:
    var mirror := 1.0 if kicking_leg == "Right" else -1.0
    var guarding_arm := "Left" if kicking_leg == "Right" else "Right"
    var poses := {
        "Hips": [
            Vector3.ZERO, Vector3(0.0, 0.025 * mirror, 0.0), Vector3(0.0, 0.07 * mirror, 0.0),
            Vector3(0.0, 0.12 * mirror, 0.0), Vector3(0.0, 0.10 * mirror, 0.0),
            Vector3(0.0, 0.055 * mirror, 0.0), Vector3(0.0, 0.025 * mirror, 0.0),
            Vector3(0.0, 0.01 * mirror, 0.0), Vector3.ZERO
        ],
        "Spine": [
            Vector3.ZERO, Vector3(0.025, 0.0, 0.0), Vector3(0.075, 0.0, 0.0),
            Vector3(0.12, 0.0, 0.0), Vector3(0.10, 0.0, 0.0), Vector3(0.075, 0.0, 0.0),
            Vector3(0.045, 0.0, 0.0), Vector3(0.015, 0.0, 0.0), Vector3.ZERO
        ],
        "Chest": [
            Vector3.ZERO, Vector3(0.025, -0.025 * mirror, 0.01 * mirror), Vector3(0.065, -0.06 * mirror, 0.035 * mirror),
            Vector3(0.105, -0.11 * mirror, 0.06 * mirror), Vector3(0.09, -0.085 * mirror, 0.045 * mirror),
            Vector3(0.07, -0.05 * mirror, 0.025 * mirror), Vector3(0.04, -0.025 * mirror, 0.01 * mirror),
            Vector3(0.012, 0.0, 0.0), Vector3.ZERO
        ],
        kicking_leg + "Thigh": [
            Vector3.ZERO, Vector3(0.30, 0.01 * mirror, -0.025 * mirror), Vector3(0.86, 0.035 * mirror, -0.055 * mirror),
            Vector3(1.42, 0.06 * mirror, -0.075 * mirror), Vector3(1.55, 0.055 * mirror, -0.07 * mirror),
            Vector3(1.35, 0.04 * mirror, -0.05 * mirror), Vector3(0.98, 0.025 * mirror, -0.035 * mirror),
            Vector3(0.40, 0.01 * mirror, -0.015 * mirror), Vector3.ZERO
        ],
        kicking_leg + "Shin": [
            Vector3.ZERO, Vector3(0.30, 0.0, 0.0), Vector3(0.72, 0.0, 0.0),
            Vector3(0.10, 0.0, 0.0), Vector3(0.04, 0.0, 0.0), Vector3(0.08, 0.0, 0.0),
            Vector3(0.68, 0.0, 0.0), Vector3(0.32, 0.0, 0.0), Vector3.ZERO
        ],
        kicking_leg + "Foot": [
            Vector3.ZERO, Vector3(-0.04, 0.0, 0.0), Vector3(-0.10, 0.0, 0.0),
            Vector3(0.13, 0.0, 0.0), Vector3(0.18, 0.0, 0.0), Vector3(0.12, 0.0, 0.0),
            Vector3(-0.08, 0.0, 0.0), Vector3(-0.035, 0.0, 0.0), Vector3.ZERO
        ],
        support_leg + "Thigh": [
            Vector3.ZERO, Vector3(0.025, 0.0, -0.015 * mirror), Vector3(0.075, 0.0, -0.035 * mirror),
            Vector3(0.11, 0.0, -0.05 * mirror), Vector3(0.10, 0.0, -0.04 * mirror),
            Vector3(0.075, 0.0, -0.03 * mirror), Vector3(0.045, 0.0, -0.02 * mirror),
            Vector3(0.012, 0.0, 0.0), Vector3.ZERO
        ],
        support_leg + "Shin": [
            Vector3.ZERO, Vector3(0.035, 0.0, 0.0), Vector3(0.12, 0.0, 0.0),
            Vector3(0.17, 0.0, 0.0), Vector3(0.15, 0.0, 0.0), Vector3(0.11, 0.0, 0.0),
            Vector3(0.07, 0.0, 0.0), Vector3(0.025, 0.0, 0.0), Vector3.ZERO
        ],
        support_leg + "Foot": [
            Vector3.ZERO, Vector3(0.01, 0.0, 0.0), Vector3(0.025, 0.0, 0.0),
            Vector3(0.04, 0.0, 0.0), Vector3(0.035, 0.0, 0.0), Vector3(0.025, 0.0, 0.0),
            Vector3(0.015, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO
        ],
        guarding_arm + "UpperArm": [
            Vector3(-0.14, 0.0, -0.025 * mirror), Vector3(-0.18, 0.0, -0.045 * mirror),
            Vector3(-0.24, 0.0, -0.07 * mirror), Vector3(-0.29, 0.0, -0.09 * mirror),
            Vector3(-0.27, 0.0, -0.08 * mirror), Vector3(-0.23, 0.0, -0.06 * mirror),
            Vector3(-0.20, 0.0, -0.045 * mirror), Vector3(-0.16, 0.0, -0.03 * mirror),
            Vector3(-0.14, 0.0, -0.025 * mirror)
        ],
        guarding_arm + "Forearm": [
            Vector3(-0.52, 0.0, 0.0), Vector3(-0.56, 0.0, 0.0), Vector3(-0.63, 0.0, 0.0),
            Vector3(-0.68, 0.0, 0.0), Vector3(-0.66, 0.0, 0.0), Vector3(-0.62, 0.0, 0.0),
            Vector3(-0.58, 0.0, 0.0), Vector3(-0.54, 0.0, 0.0), Vector3(-0.52, 0.0, 0.0)
        ],
        kicking_leg + "UpperArm": [
            Vector3(-0.12, 0.0, 0.025 * mirror), Vector3(-0.10, 0.0, 0.06 * mirror),
            Vector3(-0.06, 0.0, 0.12 * mirror), Vector3(-0.02, 0.0, 0.17 * mirror),
            Vector3(-0.01, 0.0, 0.18 * mirror), Vector3(-0.04, 0.0, 0.12 * mirror),
            Vector3(-0.08, 0.0, 0.07 * mirror), Vector3(-0.11, 0.0, 0.035 * mirror),
            Vector3(-0.12, 0.0, 0.025 * mirror)
        ],
        kicking_leg + "Forearm": [
            Vector3(-0.34, 0.0, 0.0), Vector3(-0.36, 0.0, 0.0), Vector3(-0.40, 0.0, 0.0),
            Vector3(-0.42, 0.0, 0.0), Vector3(-0.40, 0.0, 0.0), Vector3(-0.38, 0.0, 0.0),
            Vector3(-0.36, 0.0, 0.0), Vector3(-0.34, 0.0, 0.0), Vector3(-0.34, 0.0, 0.0)
        ]
    }
    return poses
