extends RefCounted
class_name UniversalBaseCombat

## Player attacks for the UAL rig. Never apply the old character's local bone
## rotations to this skeleton: its arms have different rest axes and a T-pose.
const LIBRARY_NAME := &"universal_base_combat"
const PUNCH_SOURCES := {"left": &"Punch_Jab", "right": &"Punch_Cross"}
# Full extension in the supplied clips, before their recovery begins.
const PUNCH_CONTACTS := {"left": 0.2333333333, "right": 0.30}

static func clip_path(kind: String, side: String) -> StringName:
	return StringName("%s/%s_%s" % [LIBRARY_NAME, side, kind])

static func install(animator: AnimationPlayer, skeleton: Skeleton3D, profiles: Dictionary) -> bool:
	if animator == null or skeleton == null:
		return false
	for source: StringName in PUNCH_SOURCES.values():
		if not animator.has_animation(source):
			return false
	var library := AnimationLibrary.new()
	for side: String in ["left", "right"]:
		var source := animator.get_animation(PUNCH_SOURCES[side])
		var punch := _retime_punch(source, float(PUNCH_CONTACTS[side]), profiles["punch"])
		var kick := _build_kick(animator.get_animation(&"Punch_Jab"), skeleton, side, profiles["kick"])
		if kick == null:
			return false
		library.add_animation(StringName(side + "_punch"), punch)
		library.add_animation(StringName(side + "_kick"), kick)
	if animator.has_animation_library(LIBRARY_NAME):
		animator.remove_animation_library(LIBRARY_NAME)
	return animator.add_animation_library(LIBRARY_NAME, library) == OK

static func _empty_copy(source: Animation, profile: Dictionary) -> Animation:
	var animation := source.duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_NONE
	animation.length = float(profile.windup) + float(profile.active) + float(profile.recovery)
	animation.step = 1.0 / 60.0
	for track in range(animation.get_track_count()):
		for key in range(animation.track_get_key_count(track) - 1, -1, -1):
			animation.track_remove_key(track, key)
	animation.add_marker(&"contact", float(profile.windup))
	return animation

static func _sample(source: Animation, track: int, time: float) -> Variant:
	match source.track_get_type(track):
		Animation.TYPE_ROTATION_3D:
			return source.rotation_track_interpolate(track, time)
		Animation.TYPE_POSITION_3D:
			return source.position_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D:
			return source.scale_track_interpolate(track, time)
	return null

static func _retime_punch(source: Animation, contact: float, profile: Dictionary) -> Animation:
	var animation := _empty_copy(source, profile)
	var windup := float(profile.windup)
	# Resample both sides of contact separately so there is always an exact key
	# at the gameplay damage boundary, regardless of the source clip's length.
	for segment in range(2):
		var start := 0.0 if segment == 0 else windup
		var end := windup if segment == 0 else animation.length
		var source_start := 0.0 if segment == 0 else contact
		var source_end := contact if segment == 0 else source.length
		var steps := maxi(1, ceili((end - start) * 60.0))
		for key in range(steps + 1):
			var weight := float(key) / steps
			var time := lerpf(start, end, weight)
			var source_time := lerpf(source_start, source_end, weight)
			for track in range(animation.get_track_count()):
				animation.track_insert_key(track, time, _sample(source, track, source_time))
	return animation

static func _build_kick(guard: Animation, skeleton: Skeleton3D, side: String, profile: Dictionary) -> Animation:
	var animation := _empty_copy(guard, profile)
	var suffix := "l" if side == "left" else "r"
	var windup := float(profile.windup)
	var active_end := windup + float(profile.active)
	var recovery := float(profile.recovery)
	var times := [0.0, windup * 0.35, windup * 0.72, windup,
		active_end, active_end + recovery * 0.30, active_end + recovery * 0.72, animation.length]
	# Chamber, extend at contact, rechamber, then plant the foot. The other leg
	# and closed-fist guard retain the supplied animation's complete pose.
	var angles := {
		"thigh_" + suffix: [0.0, -0.35, -1.10, -1.45, -1.30, -0.95, -0.40, 0.0],
		"calf_" + suffix: [0.0, 0.70, 1.50, 0.18, 0.18, 1.30, 0.60, 0.0],
		"foot_" + suffix: [0.0, -0.10, -0.15, 0.20, 0.20, -0.10, -0.05, 0.0],
		"spine_02": [0.0, -0.02, -0.06, -0.09, -0.08, -0.05, -0.02, 0.0],
	}
	# The library's right leg starts behind the body in an orthodox stance.
	# It needs more hip travel than the leading leg to reach the same height.
	if side == "right":
		angles["thigh_r"] = [0.0, -0.55, -1.45, -1.90, -1.75, -1.20, -0.50, 0.0]
	var guard_rotations: Dictionary = {}
	for track in range(guard.get_track_count()):
		var path := guard.track_get_path(track)
		if guard.track_get_type(track) == Animation.TYPE_ROTATION_3D and path.get_subname_count() == 1:
			guard_rotations[String(path.get_subname(0))] = guard.rotation_track_interpolate(track, 0.0)
	for bone_name: String in angles:
		if skeleton.find_bone(bone_name) < 0 or not guard_rotations.has(bone_name):
			return null
	for track in range(animation.get_track_count()):
		var base: Variant = _sample(guard, track, 0.0)
		var path := animation.track_get_path(track)
		var bone_name := String(path.get_subname(0)) if path.get_subname_count() == 1 else ""
		var local_axis := Vector3.RIGHT
		var rotates := animation.track_get_type(track) == Animation.TYPE_ROTATION_3D and angles.has(bone_name)
		if rotates:
			# Convert the model-space kick axis to this bone's guard basis. Name
			# substitution or a single Euler sign cannot retarget different rigs.
			var global_rotation := Quaternion.IDENTITY
			var bone := skeleton.find_bone(bone_name)
			while bone >= 0:
				var rotation: Quaternion = guard_rotations.get(skeleton.get_bone_name(bone), skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
				global_rotation = rotation * global_rotation
				bone = skeleton.get_bone_parent(bone)
			local_axis = global_rotation.inverse() * Vector3.RIGHT
		for key in range(times.size()):
			var value: Variant = base
			if rotates:
				value = (base * Quaternion(local_axis.normalized(), float(angles[bone_name][key]))).normalized()
			animation.track_insert_key(track, float(times[key]), value)
	return animation
