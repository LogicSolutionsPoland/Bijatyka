extends RefCounted
class_name RingReferenceCombat

## Baked manual reference reconstructions. Source UAL clips stay untouched.
const LIBRARY_NAME := &"ring_reference"
const ACTION_CLIPS := {
	"left_punch": "lead_straight", "right_punch": "rear_hook",
	"left_kick": "left_high_kick", "right_kick": "right_high_kick",
}
static var _cache: Dictionary = {}

static func install(animator: AnimationPlayer, skeleton: Skeleton3D) -> bool:
	if animator == null or skeleton == null: return false
	var model := animator.get_node_or_null(animator.root_node)
	if model == null or not model.is_ancestor_of(skeleton): return false
	var rig := "female" if String(model.scene_file_path).contains("_Female") else "male"
	var source := load("res://animations/ring_reference/%s/library.tres" % rig) as AnimationLibrary
	if source == null: return false
	var path := model.get_path_to(skeleton)
	# Validate every binding before replacing any installed library.
	for clip_name in source.get_animation_list():
		var animation := source.get_animation(clip_name)
		for track in range(animation.get_track_count()):
			var binding := animation.track_get_path(track)
			if binding.get_subname_count() != 1 or skeleton.find_bone(binding.get_subname(0)) < 0: return false
	var library := source
	if str(path) != "Armature/Skeleton3D":
		library = source.duplicate(true)
		for clip_name in library.get_animation_list():
			var animation := library.get_animation(clip_name)
			for track in range(animation.get_track_count()):
				var bone := animation.track_get_path(track).get_subname(0)
				animation.track_set_path(track, NodePath("%s:%s" % [path, bone]))
	if animator.has_animation_library(LIBRARY_NAME): animator.remove_animation_library(LIBRARY_NAME)
	return animator.add_animation_library(LIBRARY_NAME, library) == OK

static func build_attack(animator: AnimationPlayer, kind: String, side: String, profile: Dictionary) -> Animation:
	var name := String(ACTION_CLIPS.get(side + "_" + kind, ""))
	var path := StringName("%s/%s" % [LIBRARY_NAME, name])
	if not animator.has_animation(path): return null
	var source := animator.get_animation(path)
	var cache_key := "%s:%.8f:%.8f:%.8f" % [source.resource_path, float(profile.windup), float(profile.active), float(profile.recovery)]
	if _cache.has(cache_key): return _cache[cache_key]
	var clip := source.duplicate(true) as Animation
	var contact := source.get_marker_time(&"contact")
	var windup := float(profile.windup)
	clip.length = windup + float(profile.active) + float(profile.recovery)
	clip.loop_mode = Animation.LOOP_NONE
	clip.remove_marker(&"contact")
	clip.add_marker(&"contact", windup)
	for track in range(clip.get_track_count()):
		# Preserve sparse static finger and guard tracks.
		if clip.track_get_key_count(track) == 1: continue
		for key in range(clip.track_get_key_count(track) - 1, -1, -1): clip.track_remove_key(track, key)
		for segment in range(2):
			var start := 0.0 if segment == 0 else windup
			var end := windup if segment == 0 else clip.length
			var source_start := 0.0 if segment == 0 else contact
			var source_end := contact if segment == 0 else source.length
			var steps := maxi(1, ceili((end - start) * 30.0))
			for key in range(steps + 1):
				var w := float(key) / steps
				var time := lerpf(start, end, w)
				var sample_time := lerpf(source_start, source_end, w)
				var value: Variant
				if source.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					value = source.rotation_track_interpolate(track, sample_time)
				else:
					value = source.position_track_interpolate(track, sample_time)
				clip.track_insert_key(track, time, value)
	_cache[cache_key] = clip
	return clip
