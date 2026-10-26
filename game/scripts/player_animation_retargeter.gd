extends RefCounted

const ATTACK_LIBRARY_NAME := &"thornbound_combat"
const PREVIEW_LIBRARY_NAME := &"player_animation_preview"
const KAYKIT_COMBAT := preload("res://assets/animations/kaykit/Rig_Medium_CombatMelee.glb")
const KAYKIT_MOVEMENT := preload("res://assets/animations/kaykit/Rig_Medium_MovementBasic.glb")
const UNIVERSAL_ANIMATIONS := preload("res://assets/animations/universal/UAL1_Standard.glb")
const FORWARD := Vector3(0.0, 0.0, -1.0)

const SOURCE_SCENES := {
	"kaykit_combat": KAYKIT_COMBAT,
	"kaykit_movement": KAYKIT_MOVEMENT,
	"ual": UNIVERSAL_ANIMATIONS
}

const BONE_MAP := {
	"root": "Root",
	"hips": "Hips",
	"pelvis": "Hips",
	"spine": "Spine",
	"spine_01": "Spine",
	"spine_03": "Chest",
	"chest": "Chest",
	"neck": "Neck",
	"neck_01": "Neck",
	"head": "Head",
	"upperarm.l": "LeftUpperArm",
	"upperarm.r": "RightUpperArm",
	"upperarm_l": "LeftUpperArm",
	"upperarm_r": "RightUpperArm",
	"lowerarm.l": "LeftForearm",
	"lowerarm.r": "RightForearm",
	"lowerarm_l": "LeftForearm",
	"lowerarm_r": "RightForearm",
	"wrist.l": "LeftHand",
	"wrist.r": "RightHand",
	"hand_l": "LeftHand",
	"hand_r": "RightHand",
	"upperleg.l": "LeftThigh",
	"upperleg.r": "RightThigh",
	"thigh_l": "LeftThigh",
	"thigh_r": "RightThigh",
	"lowerleg.l": "LeftShin",
	"lowerleg.r": "RightShin",
	"calf_l": "LeftShin",
	"calf_r": "RightShin",
	"foot.l": "LeftFoot",
	"foot.r": "RightFoot",
	"foot_l": "LeftFoot",
	"foot_r": "RightFoot"
}

static func install(animation_player: AnimationPlayer, target_skeleton: Skeleton3D, attack_profiles: Dictionary) -> bool:
	if animation_player == null or target_skeleton == null:
		return false
	var target_root := animation_player.get_node_or_null(animation_player.root_node)
	if target_root == null:
		target_root = animation_player.get_parent()
	if target_root == null or not target_root.is_ancestor_of(target_skeleton):
		return false
	for required_bone: String in [
		"Root", "Hips", "Spine", "Chest", "Head",
		"LeftUpperArm", "LeftForearm", "LeftHand",
		"RightUpperArm", "RightForearm", "RightHand",
		"LeftThigh", "LeftShin", "LeftFoot",
		"RightThigh", "RightShin", "RightFoot"
	]:
		if target_skeleton.find_bone(required_bone) < 0:
			return false

	var source_contexts: Dictionary = {}
	for source_id in SOURCE_SCENES.keys():
		var source_scene: Node = SOURCE_SCENES[source_id].instantiate()
		if source_scene == null:
			_release_sources(source_contexts)
			return false
		target_root.add_child(source_scene)
		_disable_rendering(source_scene)
		var source_player := source_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var source_skeleton := source_scene.find_child("Skeleton3D", true, false) as Skeleton3D
		if source_player == null or source_skeleton == null:
			source_scene.queue_free()
			_release_sources(source_contexts)
			return false
		source_contexts[source_id] = {
			"scene": source_scene,
			"player": source_player,
			"skeleton": source_skeleton
		}

	var target_skeleton_path := target_root.get_path_to(target_skeleton)
	var default_animations: Dictionary = {}
	var locomotion_specs := [
		{"name": "Idle", "source": "kaykit_combat", "clip": "Melee_Unarmed_Idle", "loop": true},
		{"name": "Walk", "source": "ual", "clip": "Walk_Loop", "loop": true},
		{"name": "Sprint", "source": "ual", "clip": "Sprint_Loop", "loop": true},
		{"name": "Jump", "source": "kaykit_movement", "clip": "Jump_Full_Short", "loop": false, "duration": 0.6833},
		{"name": "Cast", "source": "ual", "clip": "Spell_Simple_Shoot", "loop": false}
	]
	for spec: Dictionary in locomotion_specs:
		var context: Dictionary = source_contexts[spec.source]
		var source_animation := _find_animation(context.player, StringName(spec.clip))
		if source_animation == null:
			_release_sources(source_contexts)
			return false
		var duration := float(spec.get("duration", source_animation.length))
		var converted := _retarget_animation(
			source_animation,
			context.skeleton,
			target_skeleton,
			target_skeleton_path,
			duration,
			0.0,
			false,
			bool(spec.loop)
		)
		if converted == null:
			_release_sources(source_contexts)
			return false
		default_animations[StringName(spec.name)] = converted

	var attack_specs := {
		"left_punch": {"source": "ual", "clip": "Punch_Jab", "contact": 0.23, "mirror": false},
		"right_punch": {"source": "ual", "clip": "Punch_Cross", "contact": 0.30, "mirror": false},
		"left_kick": {"source": "kaykit_combat", "clip": "Melee_Unarmed_Attack_Kick", "contact": 0.45, "mirror": true},
		"right_kick": {"source": "kaykit_combat", "clip": "Melee_Unarmed_Attack_Kick", "contact": 0.45, "mirror": false}
	}
	var combat_library := AnimationLibrary.new()
	for clip_key in attack_specs.keys():
		var side := "left" if String(clip_key).begins_with("left_") else "right"
		var kind := "punch" if String(clip_key).ends_with("_punch") else "kick"
		var profile: Dictionary = attack_profiles.get(kind, {})
		if profile.is_empty():
			_release_sources(source_contexts)
			return false
		var spec: Dictionary = attack_specs[clip_key]
		var context: Dictionary = source_contexts[spec.source]
		var source_animation := _find_animation(context.player, StringName(spec.clip))
		if source_animation == null:
			_release_sources(source_contexts)
			return false
		var duration := float(profile.windup) + float(profile.active) + float(profile.recovery)
		var converted := _retarget_animation(
			source_animation,
			context.skeleton,
			target_skeleton,
			target_skeleton_path,
			duration,
			float(spec.contact),
			bool(spec.mirror),
			false,
			float(profile.windup)
		)
		if converted == null or converted.get_track_count() < 3:
			_release_sources(source_contexts)
			return false
		if combat_library.add_animation(StringName(clip_key), converted) != OK:
			_release_sources(source_contexts)
			return false

	if not _validate_attack_poses(animation_player, target_skeleton, combat_library, attack_profiles):
		_release_sources(source_contexts)
		return false

	var default_library := animation_player.get_animation_library(&"")
	if default_library == null:
		default_library = AnimationLibrary.new()
	for name: StringName in default_animations.keys():
		if default_library.has_animation(name):
			default_library.remove_animation(name)
		if default_library.add_animation(name, default_animations[name]) != OK:
			_release_sources(source_contexts)
			return false

	if animation_player.has_animation_library(ATTACK_LIBRARY_NAME):
		animation_player.remove_animation_library(ATTACK_LIBRARY_NAME)
	if animation_player.add_animation_library(ATTACK_LIBRARY_NAME, combat_library) != OK:
		_release_sources(source_contexts)
		return false
	if not animation_player.has_animation_library(&""):
		if animation_player.add_animation_library(&"", default_library) != OK:
			_release_sources(source_contexts)
			return false
	for name: StringName in default_animations.keys():
		if not animation_player.has_animation(name):
			_release_sources(source_contexts)
			return false
	for clip_key in attack_specs.keys():
		if not animation_player.has_animation(StringName("%s/%s" % [String(ATTACK_LIBRARY_NAME), String(clip_key)])):
			_release_sources(source_contexts)
			return false
	_release_sources(source_contexts)
	return true

static func _retarget_animation(
	source_animation: Animation,
	source_skeleton: Skeleton3D,
	target_skeleton: Skeleton3D,
	target_skeleton_path: NodePath,
	target_duration: float,
	contact_fraction: float,
	mirror: bool,
	loop: bool,
	contact_target_time: float = -1.0
) -> Animation:
	if source_animation == null or source_skeleton == null or target_duration <= 0.0:
		return null
	var output := Animation.new()
	output.length = target_duration
	output.step = source_animation.step
	output.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	if contact_fraction > 0.0 and contact_target_time >= 0.0:
		output.add_marker(&"contact", contact_target_time)
	var source_contact_time := source_animation.length * contact_fraction
	var created_tracks := 0
	for source_track in range(source_animation.get_track_count()):
		var source_type := source_animation.track_get_type(source_track)
		if source_type != Animation.TYPE_ROTATION_3D and source_type != Animation.TYPE_POSITION_3D:
			continue
		var source_path := source_animation.track_get_path(source_track)
		if source_path.get_subname_count() == 0:
			continue
		var source_bone_name := String(source_path.get_subname(source_path.get_subname_count() - 1)).to_lower()
		var target_bone_name := String(BONE_MAP.get(source_bone_name, ""))
		if target_bone_name.is_empty():
			continue
		if mirror:
			target_bone_name = _swap_side(target_bone_name)
		var source_bone_index := source_skeleton.find_bone(String(source_path.get_subname(source_path.get_subname_count() - 1)))
		var target_bone_index := target_skeleton.find_bone(target_bone_name)
		if source_bone_index < 0 or target_bone_index < 0:
			continue
		if source_type == Animation.TYPE_POSITION_3D and target_bone_name == "Root":
			continue
		var source_rest := source_skeleton.get_bone_rest(source_bone_index)
		var target_rest := target_skeleton.get_bone_rest(target_bone_index)
		var output_track := output.add_track(source_type)
		output.track_set_path(output_track, NodePath("%s:%s" % [String(target_skeleton_path), target_bone_name]))
		output.track_set_interpolation_type(output_track, source_animation.track_get_interpolation_type(source_track))
		var sample_times: Array[float] = []
		for key_index in range(source_animation.track_get_key_count(source_track)):
			sample_times.append(source_animation.track_get_key_time(source_track, key_index))
		if contact_fraction > 0.0:
			sample_times.append(source_contact_time)
		sample_times.sort()
		var previous_source_time := -1.0
		for source_time in sample_times:
			if source_time <= previous_source_time + 0.00001:
				continue
			previous_source_time = source_time
			var source_value: Variant = _sample_track_value(source_animation, source_track, source_time)
			var target_value: Variant
			if source_type == Animation.TYPE_ROTATION_3D:
				var source_rest_rotation := source_rest.basis.get_rotation_quaternion()
				var target_rest_rotation := target_rest.basis.get_rotation_quaternion()
				var source_pose_rotation: Quaternion = source_value
				var delta_rotation := (source_rest_rotation.inverse() * source_pose_rotation).normalized()
				if mirror:
					delta_rotation = Quaternion(delta_rotation.x, -delta_rotation.y, -delta_rotation.z, delta_rotation.w).normalized()
				target_value = (target_rest_rotation * delta_rotation).normalized()
			else:
				var source_position: Vector3 = source_value
				var position_delta := source_position - source_rest.origin
				if mirror:
					position_delta.x = -position_delta.x
				target_value = target_rest.origin + position_delta
			output.track_insert_key(output_track, _map_time(source_time, source_animation.length, source_contact_time, contact_target_time, target_duration, contact_fraction), target_value)
		created_tracks += 1
	if created_tracks == 0:
		return null
	return output

static func _sample_track_value(animation: Animation, track_index: int, time: float) -> Variant:
	var key_count := animation.track_get_key_count(track_index)
	if key_count <= 0:
		return null
	if key_count == 1 or time <= animation.track_get_key_time(track_index, 0):
		return animation.track_get_key_value(track_index, 0)
	if time >= animation.track_get_key_time(track_index, key_count - 1):
		return animation.track_get_key_value(track_index, key_count - 1)
	var left_index := 0
	for key_index in range(key_count - 1):
		if time <= animation.track_get_key_time(track_index, key_index + 1):
			left_index = key_index
			break
		left_index = key_index + 1
	var left_time := animation.track_get_key_time(track_index, left_index)
	var right_time := animation.track_get_key_time(track_index, left_index + 1)
	var weight := 0.0 if is_equal_approx(left_time, right_time) else (time - left_time) / (right_time - left_time)
	if animation.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:
		var left_rotation: Quaternion = animation.track_get_key_value(track_index, left_index)
		var right_rotation: Quaternion = animation.track_get_key_value(track_index, left_index + 1)
		return left_rotation.slerp(right_rotation, weight)
	var left_position: Vector3 = animation.track_get_key_value(track_index, left_index)
	var right_position: Vector3 = animation.track_get_key_value(track_index, left_index + 1)
	return left_position.lerp(right_position, weight)

static func _map_time(source_time: float, source_length: float, contact_time: float, target_contact: float, target_length: float, contact_fraction: float) -> float:
	if contact_fraction <= 0.0 or target_contact < 0.0 or source_length <= 0.0:
		return clampf(source_time / source_length * target_length, 0.0, target_length)
	if source_time <= contact_time:
		return clampf(source_time / maxf(contact_time, 0.0001) * target_contact, 0.0, target_contact)
	var post_contact_duration := maxf(source_length - contact_time, 0.0001)
	return clampf(target_contact + (source_time - contact_time) / post_contact_duration * (target_length - target_contact), target_contact, target_length)

static func _find_animation(animation_player: AnimationPlayer, clip_name: StringName) -> Animation:
	if animation_player.has_animation(clip_name):
		return animation_player.get_animation(clip_name)
	for library_name: StringName in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(library_name)
		if library != null and library.has_animation(clip_name):
			return library.get_animation(clip_name)
	return null

static func _validate_attack_poses(animation_player: AnimationPlayer, skeleton: Skeleton3D, combat_library: AnimationLibrary, attack_profiles: Dictionary) -> bool:
	if animation_player.has_animation_library(PREVIEW_LIBRARY_NAME):
		animation_player.remove_animation_library(PREVIEW_LIBRARY_NAME)
	animation_player.add_animation_library(PREVIEW_LIBRARY_NAME, combat_library)
	for kind in ["punch", "kick"]:
		var profile: Dictionary = attack_profiles[kind]
		for side in ["left", "right"]:
			var clip_name := StringName("%s_%s" % [side, kind])
			var clip_path := StringName("%s/%s" % [String(PREVIEW_LIBRARY_NAME), String(clip_name)])
			animation_player.play(clip_path, 0.0)
			animation_player.seek(float(profile.windup), true)
			skeleton.force_update_all_bone_transforms()
			var limb := "Left" if side == "left" else "Right"
			var forward_reach := 0.0
			if kind == "punch":
				var shoulder := skeleton.find_bone(limb + "UpperArm")
				var hand := skeleton.find_bone(limb + "Hand")
				if shoulder < 0 or hand < 0:
					animation_player.remove_animation_library(PREVIEW_LIBRARY_NAME)
					animation_player.stop()
					skeleton.reset_bone_poses()
					return false
				var strike_vector: Vector3 = skeleton.get_bone_global_pose(hand).origin - skeleton.get_bone_global_pose(shoulder).origin
				forward_reach = strike_vector.dot(FORWARD)
				if forward_reach <= 0.18:
					animation_player.remove_animation_library(PREVIEW_LIBRARY_NAME)
					animation_player.stop()
					skeleton.reset_bone_poses()
					return false
			else:
				var active_foot := skeleton.find_bone(limb + "Foot")
				var support_foot := skeleton.find_bone(("Right" if side == "left" else "Left") + "Foot")
				if active_foot < 0 or support_foot < 0:
					animation_player.remove_animation_library(PREVIEW_LIBRARY_NAME)
					animation_player.stop()
					skeleton.reset_bone_poses()
					return false
				var foot_delta: Vector3 = skeleton.get_bone_global_pose(active_foot).origin - skeleton.get_bone_global_pose(support_foot).origin
				forward_reach = foot_delta.dot(FORWARD)
				if forward_reach <= 0.25:
					animation_player.remove_animation_library(PREVIEW_LIBRARY_NAME)
					animation_player.stop()
					skeleton.reset_bone_poses()
					return false
	animation_player.remove_animation_library(PREVIEW_LIBRARY_NAME)
	animation_player.stop()
	skeleton.reset_bone_poses()
	return true

static func _swap_side(bone_name: String) -> String:
	if bone_name.begins_with("Left"):
		return "Right" + bone_name.substr(4)
	if bone_name.begins_with("Right"):
		return "Left" + bone_name.substr(5)
	return bone_name

static func _disable_rendering(root: Node) -> void:
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).visible = false
	for child in root.get_children():
		_disable_rendering(child)

static func _release_sources(source_contexts: Dictionary) -> void:
	for context in source_contexts.values():
		var source_scene: Node = context.scene
		if is_instance_valid(source_scene):
			source_scene.queue_free()
