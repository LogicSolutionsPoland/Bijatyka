extends RefCounted
class_name UniversalBaseEnemyCombat

## Enemy-only clips built from the imported Universal Base animation tracks.
## Both the male and female GLBs carry their own UAL poses and bone bases.
const LIBRARY_NAME := &"enemy_combat"
const BASE_COMBAT := preload("res://scripts/universal_base_combat.gd")

static func clip_path(kind: String, side: String, _library_name: StringName = LIBRARY_NAME) -> StringName:
	return StringName("%s/%s_%s" % [LIBRARY_NAME, side, kind])

static func install(animator: AnimationPlayer, skeleton: Skeleton3D, profiles: Dictionary) -> bool:
	if animator == null or skeleton == null:
		return false
	var animation_root := animator.get_node_or_null(animator.root_node)
	if animation_root == null or not animation_root.is_ancestor_of(skeleton):
		return false
	for source: StringName in BASE_COMBAT.PUNCH_SOURCES.values():
		if not animator.has_animation(source):
			return false
	var ring_ready := BASE_COMBAT.RING.install(animator, skeleton)
	var library := AnimationLibrary.new()
	for kind in ["punch", "kick"]:
		if not profiles.has(kind):
			return false
		var profile: Dictionary = profiles[kind]
		for side in ["left", "right"]:
			var clip: Animation
			if ring_ready:
				clip = BASE_COMBAT.RING.build_attack(animator, kind, side, profile)
			elif kind == "punch":
				var source := animator.get_animation(BASE_COMBAT.PUNCH_SOURCES[side])
				clip = BASE_COMBAT._retime_punch(source, float(BASE_COMBAT.PUNCH_CONTACTS[side]), profile)
			else:
				clip = BASE_COMBAT._build_kick(animator.get_animation(&"Punch_Jab"), skeleton, side, profile)
			if clip == null or clip.get_track_count() < 3:
				return false
			if library.add_animation(StringName("%s_%s" % [side, kind]), clip) != OK:
				return false
	if animator.has_animation_library(LIBRARY_NAME):
		animator.remove_animation_library(LIBRARY_NAME)
	return animator.add_animation_library(LIBRARY_NAME, library) == OK
