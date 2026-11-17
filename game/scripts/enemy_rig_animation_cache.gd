extends RefCounted
class_name EnemyRigAnimationCache
## Owned by the pooled model, so prepared clips survive actor replacement and
## are freed with that model. Never shares clips between different skeletons.

const MOTION := preload("res://scripts/universal_base_motion.gd")
const COMBAT := preload("res://scripts/universal_base_enemy_combat.gd")
const CACHE_META := &"enemy_rig_animation_cache_v1"
const MAX_PROFILES := 4 # Three ordinary variants plus one custom timing profile.
static var motion_builds := 0
static var combat_builds := 0
static var combat_reuses := 0

static func install(model: Node3D, animator: AnimationPlayer, skeleton: Skeleton3D,
		profiles: Dictionary) -> bool:
	if model == null or animator == null or skeleton == null:
		return false
	var animation_root := animator.get_node_or_null(animator.root_node)
	if animation_root == null or not animation_root.is_ancestor_of(skeleton):
		return false
	var signature := _signature(animator, skeleton, animation_root)
	var cache: Dictionary = model.get_meta(CACHE_META, {})
	var motion: AnimationLibrary = cache.get("motion")
	if cache.get("signature") != signature or motion == null or not animator.has_animation_library(MOTION.LIBRARY_NAME) or animator.get_animation_library(MOTION.LIBRARY_NAME) != motion:
		# Imported source clips are immutable. Give each model its own alias table
		# before MOTION replaces Idle/Walk/death aliases; the player and other rigs
		# may still use the imported default library.
		if not animator.has_animation_library(&""):
			return false
		var source := animator.get_animation_library(&"")
		var local := AnimationLibrary.new()
		for clip_name in source.get_animation_list():
			local.add_animation(clip_name, source.get_animation(clip_name))
		animator.remove_animation_library(&"")
		animator.add_animation_library(&"", local)
		if not MOTION.install(animator, skeleton):
			model.remove_meta(CACHE_META)
			return false
		motion_builds += 1
		cache = {"signature": _signature(animator, skeleton, animation_root),
			"motion": animator.get_animation_library(MOTION.LIBRARY_NAME), "profiles": []}
		model.set_meta(CACHE_META, cache)
	var entries: Array = cache.profiles
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		if entry.profiles != profiles:
			continue
		var library := entry.library as AnimationLibrary
		if animator.has_animation_library(COMBAT.LIBRARY_NAME):
			if animator.get_animation_library(COMBAT.LIBRARY_NAME) != library:
				animator.remove_animation_library(COMBAT.LIBRARY_NAME)
		if not animator.has_animation_library(COMBAT.LIBRARY_NAME):
			if animator.add_animation_library(COMBAT.LIBRARY_NAME, library) != OK:
				return false
		entries.remove_at(index)
		entries.append(entry)
		combat_reuses += 1
		return true
	if not COMBAT.install(animator, skeleton, profiles):
		return false
	combat_builds += 1
	if entries.size() >= MAX_PROFILES:
		entries.pop_front()
	entries.append({"profiles": profiles.duplicate(true),
		"library": animator.get_animation_library(COMBAT.LIBRARY_NAME)})
	return true

static func _signature(animator: AnimationPlayer, skeleton: Skeleton3D, animation_root: Node) -> Array:
	# Exact values, not rounded timing strings or a collision-prone hash. Includes
	# rig identity, track paths, source resources and rest configuration. Pose and
	# model scale are deliberately absent: they change per actor, not per clip.
	var signature: Array = [animator.get_instance_id(), skeleton.get_instance_id(),
		animator.root_node, animation_root.get_path_to(skeleton)]
	if animator.has_animation_library(&""):
		signature.append(animator.get_animation_library(&""))
	var sources: Array = MOTION.DEFAULT_SOURCE_CLIPS.values() + MOTION.ACTION_SOURCE_CLIPS.values() + COMBAT.BASE_COMBAT.PUNCH_SOURCES.values()
	for source in sources:
		signature.append(animator.get_animation(source) if animator.has_animation(source) else null)
	for bone in range(skeleton.get_bone_count()):
		signature.append(skeleton.get_bone_name(bone))
		signature.append(skeleton.get_bone_parent(bone))
		signature.append(skeleton.get_bone_rest(bone))
	return signature

static func get_stats() -> Dictionary:
	return {"motion_builds": motion_builds, "combat_builds": combat_builds,
		"combat_reuses": combat_reuses}
