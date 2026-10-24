extends RefCounted
class_name FightAnimationBuilder

const LIBRARY_NAME := &"thornbound_combat"
const ATTACK_SIDES := ["left", "right"]
const ATTACK_KINDS := ["punch", "kick"]

static func clip_path(kind: String, side: String) -> StringName:
    return StringName("%s/%s_%s" % [String(LIBRARY_NAME), side, kind])

static func install(animation_player: AnimationPlayer, skeleton: Skeleton3D, attack_profiles: Dictionary) -> bool:
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

    var library := AnimationLibrary.new()
    for kind: String in ATTACK_KINDS:
        var profile: Dictionary = attack_profiles.get(kind, {})
        if profile.is_empty():
            return false
        for side: String in ATTACK_SIDES:
            var animation := _build_animation(skeleton, animation_root.get_path_to(skeleton), kind, side, profile)
            if animation.get_track_count() < 3:
                return false
            var animation_name := StringName("%s_%s" % [side, kind])
            if library.add_animation(animation_name, animation) != OK:
                return false

    if animation_player.has_animation_library(LIBRARY_NAME):
        animation_player.remove_animation_library(LIBRARY_NAME)
    if animation_player.add_animation_library(LIBRARY_NAME, library) != OK:
        return false
    for kind: String in ATTACK_KINDS:
        for side: String in ATTACK_SIDES:
            if not animation_player.has_animation(clip_path(kind, side)):
                return false
    return true

static func _build_animation(skeleton: Skeleton3D, skeleton_path: NodePath, kind: String, side: String, profile: Dictionary) -> Animation:
    var windup := float(profile.get("windup", 0.18))
    var active := float(profile.get("active", 0.14))
    var recovery := float(profile.get("recovery", 0.38))
    var impact_time := windup
    var total := windup + active + recovery
    var key_times := [
        0.0,
        windup * 0.34,
        windup * 0.72,
        impact_time,
        impact_time + active * 0.72,
        impact_time + active + recovery * 0.30,
        impact_time + active + recovery * 0.72,
        total
    ]
    var animation := Animation.new()
    animation.length = total
    animation.step = 1.0 / 60.0
    animation.loop_mode = Animation.LOOP_NONE
    animation.add_marker(&"contact", impact_time)

    var poses := _pose_frames(kind, side)
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
        for key_index in range(mini(key_times.size(), eulers.size())):
            var local_rotation := (rest_rotation * Quaternion.from_euler(eulers[key_index])).normalized()
            animation.rotation_track_insert_key(track, float(key_times[key_index]), local_rotation)
    return animation

static func _pose_frames(kind: String, side: String) -> Dictionary:
    var side_sign := 1.0 if side == "right" else -1.0
    if kind == "punch":
        return _punch_frames(side_sign)
    return _kick_frames(side_sign)

static func _punch_frames(side_sign: float) -> Dictionary:
    # Thornbound faces -Z. Positive local X lifts an arm toward -Z; the
    # previous negative contact rotations sent both fists behind the rig.
    var active_arm := "Right" if side_sign > 0.0 else "Left"
    var guard_arm := "Left" if side_sign > 0.0 else "Right"
    var active_leg := active_arm
    var support_leg := guard_arm
    var poses: Dictionary = {
        "Hips": [
            Vector3.ZERO,
            Vector3(0.0, 0.025 * side_sign, 0.008 * side_sign),
            Vector3(0.0, 0.055 * side_sign, 0.012 * side_sign),
            Vector3(0.0, -0.035 * side_sign, -0.010 * side_sign),
            Vector3(0.0, -0.050 * side_sign, -0.012 * side_sign),
            Vector3(0.0, -0.025 * side_sign, -0.004 * side_sign),
            Vector3.ZERO,
            Vector3.ZERO
        ],
        "Spine": [
            Vector3.ZERO,
            Vector3(-0.015, 0.025 * side_sign, 0.0),
            Vector3(-0.025, 0.065 * side_sign, 0.0),
            Vector3(-0.045, -0.080 * side_sign, 0.0),
            Vector3(-0.050, -0.100 * side_sign, 0.0),
            Vector3(-0.030, -0.055 * side_sign, 0.0),
            Vector3(-0.010, -0.015 * side_sign, 0.0),
            Vector3.ZERO
        ],
        "Chest": [
            Vector3.ZERO,
            Vector3(-0.020, 0.075 * side_sign, 0.025 * side_sign),
            Vector3(-0.040, 0.140 * side_sign, 0.040 * side_sign),
            Vector3(-0.080, -0.180 * side_sign, 0.030 * side_sign),
            Vector3(-0.090, -0.220 * side_sign, 0.025 * side_sign),
            Vector3(-0.055, -0.120 * side_sign, 0.015 * side_sign),
            Vector3(-0.015, -0.025 * side_sign, 0.0),
            Vector3.ZERO
        ]
    }
    poses["%sUpperArm" % active_arm] = [
        Vector3.ZERO,
        Vector3(-0.16, 0.0, -0.07 * side_sign),
        Vector3(0.30, 0.0, -0.12 * side_sign),
        Vector3(1.24, 0.0, -0.15 * side_sign),
        Vector3(1.18, 0.0, -0.13 * side_sign),
        Vector3(0.68, 0.0, -0.08 * side_sign),
        Vector3(0.20, 0.0, -0.03 * side_sign),
        Vector3.ZERO
    ]
    poses["%sForearm" % active_arm] = [
        Vector3.ZERO,
        Vector3(1.05, 0.0, 0.0),
        Vector3(0.88, 0.0, 0.0),
        Vector3(0.30, 0.0, 0.0),
        Vector3(0.24, 0.0, 0.0),
        Vector3(0.40, 0.0, 0.0),
        Vector3(0.20, 0.0, 0.0),
        Vector3.ZERO
    ]
    poses["%sHand" % active_arm] = [
        Vector3.ZERO,
        Vector3(0.0, 0.0, 0.02 * side_sign),
        Vector3(0.0, 0.0, 0.04 * side_sign),
        Vector3(0.0, 0.0, 0.08 * side_sign),
        Vector3(0.0, 0.0, 0.06 * side_sign),
        Vector3(0.0, 0.0, 0.035 * side_sign),
        Vector3(0.0, 0.0, 0.01 * side_sign),
        Vector3.ZERO
    ]
    poses["%sUpperArm" % guard_arm] = [
        Vector3.ZERO,
        Vector3(0.22, 0.0, 0.035 * side_sign),
        Vector3(0.30, 0.0, 0.06 * side_sign),
        Vector3(0.36, 0.0, 0.08 * side_sign),
        Vector3(0.34, 0.0, 0.07 * side_sign),
        Vector3(0.25, 0.0, 0.05 * side_sign),
        Vector3(0.10, 0.0, 0.02 * side_sign),
        Vector3.ZERO
    ]
    poses["%sForearm" % guard_arm] = [
        Vector3.ZERO,
        Vector3(1.10, 0.0, 0.0),
        Vector3(1.16, 0.0, 0.0),
        Vector3(1.16, 0.0, 0.0),
        Vector3(1.10, 0.0, 0.0),
        Vector3(0.90, 0.0, 0.0),
        Vector3(0.40, 0.0, 0.0),
        Vector3.ZERO
    ]
    poses["%sHand" % guard_arm] = [
        Vector3.ZERO,
        Vector3(0.0, 0.0, 0.015 * side_sign),
        Vector3(0.0, 0.0, 0.025 * side_sign),
        Vector3(0.0, 0.0, 0.035 * side_sign),
        Vector3(0.0, 0.0, 0.030 * side_sign),
        Vector3(0.0, 0.0, 0.020 * side_sign),
        Vector3(0.0, 0.0, 0.005 * side_sign),
        Vector3.ZERO
    ]
    poses["%sThigh" % active_leg] = [
        Vector3.ZERO, Vector3(-0.015, 0.0, 0.0), Vector3(-0.035, 0.0, 0.0),
        Vector3(-0.075, 0.0, 0.0), Vector3(-0.090, 0.0, 0.0), Vector3(-0.050, 0.0, 0.0),
        Vector3(-0.010, 0.0, 0.0), Vector3.ZERO
    ]
    poses["%sThigh" % support_leg] = [
        Vector3.ZERO, Vector3(0.020, 0.0, 0.0), Vector3(0.030, 0.0, 0.0),
        Vector3(0.045, 0.0, 0.0), Vector3(0.035, 0.0, 0.0), Vector3(0.015, 0.0, 0.0),
        Vector3.ZERO, Vector3.ZERO
    ]
    return poses

static func _kick_frames(side_sign: float) -> Dictionary:
    var active_arm := "Right" if side_sign > 0.0 else "Left"
    var guard_arm := "Left" if side_sign > 0.0 else "Right"
    var active_leg := active_arm
    var support_leg := guard_arm
    var poses: Dictionary = {
        "Hips": [
            Vector3.ZERO,
            Vector3(0.0, 0.025 * side_sign, 0.015 * side_sign),
            Vector3(0.0, 0.055 * side_sign, 0.045 * side_sign),
            Vector3(0.0, -0.075 * side_sign, 0.055 * side_sign),
            Vector3(0.0, -0.095 * side_sign, 0.065 * side_sign),
            Vector3(0.0, -0.045 * side_sign, 0.025 * side_sign),
            Vector3.ZERO,
            Vector3.ZERO
        ],
        "Spine": [
            Vector3.ZERO,
            Vector3(0.025, 0.020 * side_sign, 0.0),
            Vector3(0.045, 0.045 * side_sign, 0.0),
            Vector3(0.020, -0.070 * side_sign, 0.0),
            Vector3(-0.020, -0.095 * side_sign, 0.0),
            Vector3(-0.015, -0.045 * side_sign, 0.0),
            Vector3.ZERO,
            Vector3.ZERO
        ],
        "Chest": [
            Vector3.ZERO,
            Vector3(0.040, 0.035 * side_sign, 0.025 * side_sign),
            Vector3(0.085, 0.075 * side_sign, 0.050 * side_sign),
            Vector3(0.035, -0.105 * side_sign, 0.045 * side_sign),
            Vector3(-0.075, -0.125 * side_sign, 0.040 * side_sign),
            Vector3(-0.055, -0.070 * side_sign, 0.020 * side_sign),
            Vector3(-0.015, -0.020 * side_sign, 0.0),
            Vector3.ZERO
        ]
    }
    poses["%sThigh" % active_leg] = [
        Vector3.ZERO,
        Vector3(-0.22, 0.0, 0.0),
        Vector3(-0.68, 0.0, 0.0),
        Vector3(-1.02, 0.0, 0.0),
        Vector3(-1.42, 0.0, 0.0),
        Vector3(-1.50, 0.0, 0.0),
        Vector3(-0.82, 0.0, 0.0),
        Vector3.ZERO
    ]
    poses["%sShin" % active_leg] = [
        Vector3.ZERO,
        Vector3(0.25, 0.0, 0.0),
        Vector3(0.62, 0.0, 0.0),
        Vector3(0.82, 0.0, 0.0),
        Vector3(0.12, 0.0, 0.0),
        Vector3(0.08, 0.0, 0.0),
        Vector3(0.58, 0.0, 0.0),
        Vector3.ZERO
    ]
    poses["%sThigh" % support_leg] = [
        Vector3.ZERO,
        Vector3(0.045, 0.0, 0.0),
        Vector3(0.085, 0.0, 0.0),
        Vector3(0.11, 0.0, 0.0),
        Vector3(0.085, 0.0, 0.0),
        Vector3(0.04, 0.0, 0.0),
        Vector3.ZERO,
        Vector3.ZERO
    ]
    poses["%sShin" % support_leg] = [
        Vector3.ZERO,
        Vector3(0.05, 0.0, 0.0),
        Vector3(0.10, 0.0, 0.0),
        Vector3(0.14, 0.0, 0.0),
        Vector3(0.12, 0.0, 0.0),
        Vector3(0.07, 0.0, 0.0),
        Vector3(0.02, 0.0, 0.0),
        Vector3.ZERO
    ]
    poses["%sUpperArm" % active_arm] = [
        Vector3.ZERO,
        Vector3(-0.06, 0.0, -0.08 * side_sign),
        Vector3(-0.12, 0.0, -0.14 * side_sign),
        Vector3(-0.18, 0.0, -0.18 * side_sign),
        Vector3(-0.12, 0.0, -0.13 * side_sign),
        Vector3(-0.07, 0.0, -0.08 * side_sign),
        Vector3(-0.02, 0.0, -0.03 * side_sign),
        Vector3.ZERO
    ]
    poses["%sForearm" % active_arm] = [
        Vector3.ZERO,
        Vector3(-0.10, 0.0, 0.0),
        Vector3(-0.18, 0.0, 0.0),
        Vector3(-0.25, 0.0, 0.0),
        Vector3(-0.20, 0.0, 0.0),
        Vector3(-0.11, 0.0, 0.0),
        Vector3(-0.03, 0.0, 0.0),
        Vector3.ZERO
    ]
    poses["%sUpperArm" % guard_arm] = [
        Vector3.ZERO,
        Vector3(-0.12, 0.0, 0.045 * side_sign),
        Vector3(-0.23, 0.0, 0.07 * side_sign),
        Vector3(-0.31, 0.0, 0.09 * side_sign),
        Vector3(-0.25, 0.0, 0.07 * side_sign),
        Vector3(-0.15, 0.0, 0.045 * side_sign),
        Vector3(-0.05, 0.0, 0.015 * side_sign),
        Vector3.ZERO
    ]
    poses["%sForearm" % guard_arm] = [
        Vector3.ZERO,
        Vector3(-0.18, 0.0, 0.0),
        Vector3(-0.30, 0.0, 0.0),
        Vector3(-0.37, 0.0, 0.0),
        Vector3(-0.29, 0.0, 0.0),
        Vector3(-0.16, 0.0, 0.0),
        Vector3(-0.05, 0.0, 0.0),
        Vector3.ZERO
    ]
    return poses
