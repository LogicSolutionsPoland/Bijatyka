extends RefCounted
class_name PlayerRingReferenceCombat

## Player-only ring-fight vocabulary. The sixteen clips are baked once at
## model initialization onto the imported 65-bone Universal Base male rig.
## Enemy and boss AnimationPlayers never receive this library.
##
## The original UniversalBaseCombat clips remain installed as safe fallbacks.
## Source punches and planted front kicks retain their validated contact frames.
## Additive changes are expressed in the skeleton's global rest axes, not
## copied Euler angles from a different skeleton.

const BASE := preload("res://scripts/universal_base_combat.gd")
const LIBRARY_NAME := &"player_ring_reference"
const PUNCH_VARIANTS := {
	"left": ["left_jab", "left_hook", "left_uppercut"],
	"right": ["right_cross", "right_hook", "right_uppercut"],
}
const KICK_VARIANTS := {
	"left": ["left_front_kick", "left_high_kick", "left_sweep_kick"],
	"right": ["right_front_kick", "right_high_kick", "right_sweep_kick"],
}
const MOVEMENT_DURATIONS := {
	"duck": 0.36,
	"slip_left": 0.27,
	"slip_right": 0.27,
	"pivot_left": 0.28,
	"pivot_right": 0.28,
}
const CLIP_NAMES := [
	"left_jab", "right_cross",
	"left_hook", "right_hook",
	"left_uppercut", "right_uppercut",
	"left_front_kick", "right_front_kick",
	"left_high_kick", "right_high_kick",
	"left_sweep_kick", "right_sweep_kick",
	"duck", "slip_left", "slip_right",
	"pivot_left", "pivot_right", "airborne_kick",
	"left_airborne_punch", "right_airborne_punch",
]

static func clip_path(clip_name: String) -> StringName:
	return StringName("%s/%s" % [String(LIBRARY_NAME), clip_name])

static func attack_name(kind: String, side: String, repetition: int, airborne: bool = false) -> String:
	if kind == "punch" and airborne:
		return side + "_airborne_punch"
	if kind == "kick" and airborne:
		return "airborne_kick"
	var variants: Dictionary = PUNCH_VARIANTS if kind == "punch" else KICK_VARIANTS
	var side_variants: Array = variants.get(side, [])
	if side_variants.is_empty():
		return ""
	return String(side_variants[posmod(repetition, side_variants.size())])

static func install(animator: AnimationPlayer, skeleton: Skeleton3D, profiles: Dictionary) -> bool:
	if animator == null or skeleton == null or not animator.has_animation(&"Punch_Jab"):
		return false
	for kind in ["punch", "kick"]:
		if not profiles.has(kind):
			return false
		for side in ["left", "right"]:
			if not animator.has_animation(BASE.clip_path(kind, side)):
				return false
	var guard := animator.get_animation(&"Punch_Jab")
	var library := AnimationLibrary.new()
	for kind in ["punch", "kick"]:
		for side in ["left", "right"]:
			var variants: Array = PUNCH_VARIANTS[side] if kind == "punch" else KICK_VARIANTS[side]
			var source := animator.get_animation(BASE.clip_path(kind, side))
			for raw_name in variants:
				var name := String(raw_name)
				var clip := source.duplicate(true) as Animation
				if clip == null:
					return false
				_overlay(clip, skeleton, _attack_offsets(name), float(profiles[kind].windup))
				if library.add_animation(StringName(name), clip) != OK:
					return false
	for raw_name in MOVEMENT_DURATIONS:
		var name := String(raw_name)
		var clip := _pose_action(guard, skeleton, _movement_offsets(name), float(MOVEMENT_DURATIONS[name]))
		if clip == null or library.add_animation(StringName(name), clip) != OK:
			return false
	# Airborne leg strike reuses the right kick's exact gameplay hit time.
	var flying := animator.get_animation(BASE.clip_path("kick", "right")).duplicate(true) as Animation
	if flying == null:
		return false
	_overlay(flying, skeleton, _attack_offsets("airborne_kick"), float(profiles["kick"].windup))
	if library.add_animation(&"airborne_kick", flying) != OK:
		return false
	for side in ["left", "right"]:
		var airborne_punch := animator.get_animation(BASE.clip_path("punch", side)).duplicate(true) as Animation
		if airborne_punch == null:
			return false
		var punch_name: String = String(side) + "_airborne_punch"
		_overlay(airborne_punch, skeleton, _attack_offsets(punch_name), float(profiles["punch"].windup))
		if library.add_animation(StringName(punch_name), airborne_punch) != OK:
			return false
	var reach := _pose_action(guard, skeleton, _movement_offsets("grapple_reach"), 0.16)
	if reach == null or library.add_animation(&"grapple_reach", reach) != OK:
		return false
	if library.get_animation_list().size() != CLIP_NAMES.size() + 1:
		return false
	if animator.has_animation_library(LIBRARY_NAME):
		animator.remove_animation_library(LIBRARY_NAME)
	return animator.add_animation_library(LIBRARY_NAME, library) == OK

static func _attack_offsets(name: String) -> Dictionary:
	var left := name.begins_with("left_")
	var side := -1.0 if left else 1.0
	var limb := "l" if left else "r"
	if name in ["left_jab", "right_cross"]:
		# Make the imported source strike distinguishable from the legacy clip.
		return {
			"pelvis": Vector3(0.0, 0.10 * side, 0.0),
			"spine_03": Vector3(0.06, 0.16 * side, 0.0),
			"upperarm_" + limb: Vector3(-0.13, -0.10 * side, 0.03 * side),
			"lowerarm_" + limb: Vector3(0.12, 0.0, 0.0),
		}
	if name in ["left_front_kick", "right_front_kick"]:
		return {
			"pelvis": Vector3(-0.10, 0.06 * side, 0.0),
			"spine_03": Vector3(-0.11, 0.0, 0.0),
			"thigh_" + limb: Vector3(-0.18, 0.0, 0.0),
			"calf_" + limb: Vector3(-0.12, 0.0, 0.0),
		}
	if name.ends_with("_hook"):
		return {
			"pelvis": Vector3(0.0, 0.09 * side, 0.0),
			"spine_02": Vector3(0.0, 0.16 * side, 0.0),
			"spine_03": Vector3(0.02, 0.20 * side, 0.0),
			"upperarm_" + limb: Vector3(-0.06, -0.22 * side, 0.05 * side),
			"lowerarm_" + limb: Vector3(0.22, 0.0, 0.0),
		}
	if name.ends_with("_uppercut"):
		return {
			"pelvis": Vector3(-0.06, 0.08 * side, 0.0),
			"spine_02": Vector3(0.09, 0.10 * side, 0.0),
			"spine_03": Vector3(0.11, 0.04 * side, 0.0),
			"upperarm_" + limb: Vector3(0.25, 0.0, 0.0),
			"lowerarm_" + limb: Vector3(0.18, 0.0, 0.0),
		}
	if name.ends_with("_high_kick"):
		return {
			"pelvis": Vector3(-0.07, 0.04 * side, 0.03 * side),
			"spine_03": Vector3(-0.18, 0.0, -0.06 * side),
			"thigh_" + limb: Vector3(-0.44, 0.0, 0.0),
			"calf_" + limb: Vector3(-0.16, 0.0, 0.0),
		}
	if name.ends_with("_sweep_kick"):
		# A turning body kick: chamber from the source kick, rotate the hips
		# through contact and counter-rotate the chest to keep balance.
		return {
			"pelvis": Vector3(-0.12, 0.36 * side, 0.08 * side),
			"spine_02": Vector3(-0.10, -0.16 * side, -0.08 * side),
			"spine_03": Vector3(-0.14, -0.12 * side, -0.08 * side),
			"thigh_" + limb: Vector3(-0.24, 0.18 * side, 0.16 * side),
			"calf_" + limb: Vector3(-0.11, 0.0, 0.0),
		}
	if name.ends_with("_airborne_punch"):
		return {
			"pelvis": Vector3(0.10, 0.12 * side, 0.0),
			"spine_02": Vector3(0.15, 0.08 * side, 0.0),
			"spine_03": Vector3(0.12, 0.10 * side, 0.0),
			"upperarm_" + limb: Vector3(0.20, -0.08 * side, 0.0),
			"thigh_l": Vector3(0.22, 0.0, 0.0),
			"thigh_r": Vector3(0.16, 0.0, 0.0),
			"calf_l": Vector3(0.28, 0.0, 0.0),
			"calf_r": Vector3(0.22, 0.0, 0.0),
		}
	if name == "airborne_kick":
		return {
			"spine_02": Vector3(0.10, 0.0, 0.0),
			"spine_03": Vector3(0.12, 0.0, 0.0),
			"thigh_r": Vector3(-0.12, 0.0, 0.0),
			"thigh_l": Vector3(0.32, 0.0, 0.0),
			"calf_l": Vector3(0.58, 0.0, 0.0),
		}
	return {}

static func _movement_offsets(name: String) -> Dictionary:
	if name == "grapple_reach":
		# Two extended arms and a forward chest brace precede a controlled strike.
		return {
			"pelvis": Vector3(0.11, 0.0, 0.0),
			"spine_02": Vector3(0.16, 0.0, 0.0),
			"spine_03": Vector3(0.16, 0.0, 0.0),
			"upperarm_l": Vector3(0.32, 0.0, -0.18),
			"upperarm_r": Vector3(0.32, 0.0, 0.18),
			"lowerarm_l": Vector3(-0.18, 0.0, 0.0),
			"lowerarm_r": Vector3(-0.18, 0.0, 0.0),
		}
	if name == "duck":
		return {
			"pelvis": Vector3(0.14, 0.0, 0.0),
			"spine_02": Vector3(0.23, 0.0, 0.0),
			"spine_03": Vector3(0.13, 0.0, 0.0),
			"thigh_l": Vector3(0.28, 0.0, 0.0),
			"thigh_r": Vector3(0.28, 0.0, 0.0),
			"calf_l": Vector3(-0.36, 0.0, 0.0),
			"calf_r": Vector3(-0.36, 0.0, 0.0),
		}
	var sign := -1.0 if name.ends_with("_left") else 1.0
	if name.begins_with("slip"):
		return {
			"pelvis": Vector3(0.02, 0.0, 0.07 * sign),
			"spine_02": Vector3(0.09, -0.08 * sign, 0.19 * sign),
			"spine_03": Vector3(0.09, -0.06 * sign, 0.15 * sign),
			"Head": Vector3(0.0, 0.06 * sign, -0.08 * sign),
		}
	if name.begins_with("pivot"):
		return {
			"pelvis": Vector3(0.0, 0.22 * sign, 0.0),
			"spine_02": Vector3(0.0, -0.07 * sign, 0.0),
			"spine_03": Vector3(0.0, -0.12 * sign, 0.0),
			"Head": Vector3(0.0, -0.10 * sign, 0.0),
			"thigh_l": Vector3(0.07, 0.05 * sign, 0.0),
			"thigh_r": Vector3(-0.04, 0.05 * sign, 0.0),
		}
	return {}

static func _pose_action(guard: Animation, skeleton: Skeleton3D, offsets: Dictionary, duration: float) -> Animation:
	var clip := Animation.new()
	clip.length = duration
	clip.step = 1.0 / 60.0
	clip.loop_mode = Animation.LOOP_NONE
	var fractions := [0.0, 0.24, 0.55, 0.80, 1.0]
	var weights := [0.0, 0.68, 1.0, 0.54, 0.0]
	for src_track in range(guard.get_track_count()):
		var type := guard.track_get_type(src_track)
		if type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var target_track := clip.add_track(type)
		var path := guard.track_get_path(src_track)
		clip.track_set_path(target_track, path)
		clip.track_set_interpolation_type(target_track, Animation.INTERPOLATION_CUBIC)
		var bone_name := String(path.get_subname(0)) if path.get_subname_count() == 1 else ""
		var delta: Vector3 = offsets.get(bone_name, Vector3.ZERO)
		for key in range(fractions.size()):
			var value: Variant
			if type == Animation.TYPE_ROTATION_3D:
				value = guard.rotation_track_interpolate(src_track, 0.0)
				if delta != Vector3.ZERO:
					value = _offset_rotation(value as Quaternion, skeleton, bone_name, delta * float(weights[key]))
			elif type == Animation.TYPE_POSITION_3D:
				value = guard.position_track_interpolate(src_track, 0.0)
			else:
				value = guard.scale_track_interpolate(src_track, 0.0)
			clip.track_insert_key(target_track, float(fractions[key]) * duration, value)
	return clip

static func _overlay(clip: Animation, skeleton: Skeleton3D, offsets: Dictionary, contact_time: float) -> void:
	if offsets.is_empty():
		return
	for track in range(clip.get_track_count()):
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := clip.track_get_path(track)
		if path.get_subname_count() != 1:
			continue
		var bone_name := String(path.get_subname(0))
		if not offsets.has(bone_name):
			continue
		for key in range(clip.track_get_key_count(track)):
			var t := clip.track_get_key_time(track, key)
			var window := contact_time if t <= contact_time else maxf(0.10, (clip.length - contact_time) * 0.52)
			var weight := maxf(0.0, 1.0 - absf(t - contact_time) / window)
			if weight <= 0.0:
				continue
			var base := clip.track_get_key_value(track, key) as Quaternion
			var delta: Vector3 = offsets[bone_name]
			clip.track_set_key_value(track, key, _offset_rotation(base, skeleton, bone_name, delta * weight))

static func _offset_rotation(base: Quaternion, skeleton: Skeleton3D, bone_name: String, delta: Vector3) -> Quaternion:
	var index := skeleton.find_bone(bone_name)
	if index < 0:
		return base
	var global_rest := skeleton.get_bone_global_rest(index).basis.get_rotation_quaternion()
	var inverse_rest := global_rest.inverse()
	var x_axis := (inverse_rest * Vector3.RIGHT).normalized()
	var y_axis := (inverse_rest * Vector3.UP).normalized()
	var z_axis := (inverse_rest * Vector3.BACK).normalized()
	return (base * Quaternion(x_axis, delta.x) * Quaternion(y_axis, delta.y) * Quaternion(z_axis, delta.z)).normalized()
