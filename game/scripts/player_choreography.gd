extends RefCounted
class_name PlayerCombatChoreography

## Optional ten-second motion study on the *existing* Universal Base male rig.
## Player-only: never install on an enemy or the boss. The actual fight keeps
## its short, contact-synchronised clips and two-hits-per-second gameplay.
const LIBRARY_NAME := &"player_choreography"
const SHOWCASE := &"ten_second_fight"
const DURATION := 10.0
const FPS := 30.0
const TRANSITION := 0.11
const RING := preload("res://scripts/player_ring_reference.gd")

# Timeline inspired by the twelve reference poses. Real imported locomotion,
# punches and kicks provide the joint micro-motion (instead of Euler pose swaps).
# In-place; real world displacement must still be driven by CharacterBody3D.
const PHRASES := [
	{"name": "guard", "clip": "Punch_Jab", "start": 0.00, "end": 0.48},
	{"name": "lunge", "clip": "Sprint", "start": 0.48, "end": 1.08},
	{"name": "jab", "clip": "left_jab", "start": 1.08, "end": 1.62},
	{"name": "cross", "clip": "right_cross", "start": 1.62, "end": 2.24},
	{"name": "hook", "clip": "right_hook", "start": 2.24, "end": 2.82},
	{"name": "duck", "clip": "duck", "start": 2.82, "end": 3.38},
	{"name": "uppercut", "clip": "left_uppercut", "start": 3.38, "end": 4.02},
	{"name": "pivot", "clip": "pivot_right", "start": 4.02, "end": 4.48},
	{"name": "approach", "clip": "Sprint", "start": 4.48, "end": 5.12},
	{"name": "airborne", "clip": "airborne_kick", "start": 5.12, "end": 5.87},
	{"name": "sweep", "clip": "left_sweep_kick", "start": 5.87, "end": 6.60},
	{"name": "slip", "clip": "slip_right", "start": 6.60, "end": 7.02},
	{"name": "counter", "clip": "right_uppercut", "start": 7.02, "end": 7.66},
	{"name": "kick", "clip": "left_high_kick", "start": 7.66, "end": 8.46},
	{"name": "finish", "clip": "right_cross", "start": 8.46, "end": 9.13},
	{"name": "recover", "clip": "Punch_Jab", "start": 9.13, "end": 10.0},
]
# Subtle, anatomically anchored weight shifts in model/world axes, not
# arbitrary rotations pasted from an unrelated rig.
const ACCENTS := {
	"lunge": {"pelvis": Vector3(0.06, 0.0, 0.0), "spine_02": Vector3(0.07, 0.0, 0.0)},
	"jab": {"pelvis": Vector3(0.0, -0.10, 0.0), "spine_03": Vector3(0.04, -0.08, 0.0)},
	"cross": {"pelvis": Vector3(0.0, 0.16, 0.0), "spine_03": Vector3(0.0, 0.14, 0.0)},
	"hook": {"pelvis": Vector3(0.0, 0.21, 0.0), "spine_02": Vector3(0.0, 0.11, 0.0)},
	"duck": {"pelvis": Vector3(0.12, 0.0, 0.0), "spine_03": Vector3(0.14, 0.0, 0.0)},
	"uppercut": {"pelvis": Vector3(-0.09, -0.10, 0.0), "spine_03": Vector3(-0.12, 0.0, 0.0)},
	"pivot": {"pelvis": Vector3(0.0, 0.24, 0.0), "spine_03": Vector3(0.0, -0.10, 0.0)},
	"approach": {"pelvis": Vector3(0.06, 0.0, 0.0), "spine_02": Vector3(0.07, 0.0, 0.0)},
	"airborne": {"spine_03": Vector3(0.10, 0.0, 0.0)},
	"sweep": {"pelvis": Vector3(-0.05, -0.18, 0.0), "spine_03": Vector3(0.04, 0.09, 0.0)},
	"slip": {"spine_03": Vector3(0.03, -0.06, 0.14)},
	"counter": {"pelvis": Vector3(-0.05, 0.10, 0.0), "spine_03": Vector3(-0.10, 0.0, 0.0)},
	"kick": {"spine_03": Vector3(-0.16, 0.0, 0.0)},
	"finish": {"pelvis": Vector3(0.0, 0.12, 0.0), "spine_03": Vector3(0.0, 0.10, 0.0)},
}

static func clip_path() -> StringName:
	return StringName("%s/%s" % [String(LIBRARY_NAME), String(SHOWCASE)])

static func install(animator: AnimationPlayer, skeleton: Skeleton3D) -> bool:
	if animator == null or skeleton == null:
		return false
	for bone_name in ["pelvis", "spine_02", "spine_03", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
		if skeleton.find_bone(bone_name) < 0:
			return false
	var source_clips: Array[Animation] = []
	for phrase in PHRASES:
		var clip_id := StringName(String(phrase.clip)) if String(phrase.clip) in ["Punch_Jab", "Sprint"] else RING.clip_path(String(phrase.clip))
		if not animator.has_animation(clip_id):
			return false
		source_clips.append(animator.get_animation(clip_id))
	var guard := source_clips[0]
	var result := Animation.new()
	result.length = DURATION
	result.step = 1.0 / FPS
	result.loop_mode = Animation.LOOP_NONE
	var source_tracks: Array[int] = []
	for src_track in range(guard.get_track_count()):
		var track_type := guard.track_get_type(src_track)
		if track_type not in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var output_track := result.add_track(track_type)
		var path := guard.track_get_path(src_track)
		result.track_set_path(output_track, path)
		result.track_set_interpolation_type(output_track, Animation.INTERPOLATION_LINEAR)
		source_tracks.append(src_track)
	for frame in range(int(DURATION * FPS) + 1):
		var time := float(frame) / FPS
		var segment := _segment_at(time)
		var phrase: Dictionary = PHRASES[segment]
		var progress := clampf((time - float(phrase.start)) / (float(phrase.end) - float(phrase.start)), 0.0, 1.0)
		var clip := source_clips[segment]
		var clip_t := progress * clip.length
		var fade := clampf((time - float(phrase.start)) / TRANSITION, 0.0, 1.0)
		fade = fade * fade * (3.0 - 2.0 * fade)
		var previous: Animation = source_clips[maxi(0, segment - 1)]
		var accent: Dictionary = ACCENTS.get(String(phrase.name), {})
		for output_track in range(source_tracks.size()):
			var guard_track := source_tracks[output_track]
			var path := guard.track_get_path(guard_track)
			var track_type := guard.track_get_type(guard_track)
			var value: Variant = _sample(clip, path, track_type, clip_t, guard, guard_track)
			if segment > 0 and fade < 1.0:
				var previous_value: Variant = _sample(previous, path, track_type, previous.length, guard, guard_track)
				value = _blend(previous_value, value, track_type, fade)
			if track_type == Animation.TYPE_ROTATION_3D and path.get_subname_count() == 1:
				var bone_name := String(path.get_subname(0))
				if accent.has(bone_name):
					var envelope := sin(PI * progress)
					value = _world_axis_offset(value as Quaternion, skeleton, bone_name, (accent[bone_name] as Vector3) * envelope)
			if track_type == Animation.TYPE_ROTATION_3D:
				result.rotation_track_insert_key(output_track, time, value)
			elif track_type == Animation.TYPE_POSITION_3D:
				result.position_track_insert_key(output_track, time, value)
			else:
				result.scale_track_insert_key(output_track, time, value)
	for phrase in PHRASES:
		var label := String(phrase.name)
		if label not in ["guard", "recover"]:
			result.add_marker(StringName(label), float(phrase.start) + (float(phrase.end) - float(phrase.start)) * 0.45)
	var library := AnimationLibrary.new()
	if library.add_animation(SHOWCASE, result) != OK:
		return false
	if animator.has_animation_library(LIBRARY_NAME):
		animator.remove_animation_library(LIBRARY_NAME)
	return animator.add_animation_library(LIBRARY_NAME, library) == OK

static func _segment_at(time: float) -> int:
	for index in range(PHRASES.size() - 1):
		if time < float(PHRASES[index].end):
			return index
	return PHRASES.size() - 1

static func _sample(clip: Animation, path: NodePath, track_type: int, t: float, fallback: Animation, fallback_track: int) -> Variant:
	var index := clip.find_track(path, track_type)
	if index < 0 or clip.track_get_key_count(index) == 0:
		clip = fallback
		index = fallback_track
		t = 0.0
	match track_type:
		Animation.TYPE_ROTATION_3D:
			return clip.rotation_track_interpolate(index, t)
		Animation.TYPE_POSITION_3D:
			return clip.position_track_interpolate(index, t)
		_:
			return clip.scale_track_interpolate(index, t)

static func _blend(a: Variant, b: Variant, track_type: int, weight: float) -> Variant:
	if track_type == Animation.TYPE_ROTATION_3D:
		return (a as Quaternion).slerp(b as Quaternion, weight)
	return (a as Vector3).lerp(b as Vector3, weight)

static func _world_axis_offset(base: Quaternion, skeleton: Skeleton3D, bone_name: String, euler: Vector3) -> Quaternion:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return base
	var world_rest := skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
	var inv := world_rest.inverse()
	return (base * Quaternion((inv * Vector3.RIGHT).normalized(), euler.x)
		* Quaternion((inv * Vector3.UP).normalized(), euler.y)
		* Quaternion((inv * Vector3.BACK).normalized(), euler.z)).normalized()
