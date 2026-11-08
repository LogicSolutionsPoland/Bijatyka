extends RefCounted
class_name PlayerMmaKick

## Player-only animation sampled from the uploaded Mixamo Mma Kick (1).fbx.
## Includes authored spinning body and leg rotations, baked into 17 frames.
## Translation is omitted; the player CharacterBody3D controls collision.

const SAMPLE_COUNT := 17
const BONES := ["pelvis","spine_01","spine_02","spine_03","neck_01","Head","clavicle_l","upperarm_l","lowerarm_l","hand_l","clavicle_r","upperarm_r","lowerarm_r","hand_r","thigh_l","calf_l","foot_l","thigh_r","calf_r","foot_r"]
const QUATS_BASE64 := "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"

static func bake(base: Animation, skeleton: Skeleton3D, side: String, profile: Dictionary) -> Animation:
	if base == null or skeleton == null or side not in ["left", "right"]:
		return null
	var duration := float(profile.windup) + float(profile.active) + float(profile.recovery)
	var data := Marshalls.base64_to_raw(QUATS_BASE64)
	if data.size() != SAMPLE_COUNT * BONES.size() * 8:
		push_error("MMA kick sample data is invalid")
		return null

	var guard_pose: Array[Quaternion] = []
	guard_pose.resize(skeleton.get_bone_count())
	var guard_track := {}
	for bone in range(skeleton.get_bone_count()):
		guard_pose[bone] = skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	for track in range(base.get_track_count()):
		if base.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := base.track_get_path(track)
		if path.get_subname_count() != 1:
			continue
		var bone := skeleton.find_bone(String(path.get_subname(0)))
		if bone >= 0:
			guard_pose[bone] = base.rotation_track_interpolate(track, 0.0)
			guard_track[bone] = true

	var guard_global: Array[Quaternion] = []
	guard_global.resize(guard_pose.size())
	for bone in range(guard_pose.size()):
		var p := skeleton.get_bone_parent(bone)
		guard_global[bone] = (guard_global[p] * guard_pose[bone]).normalized() if p >= 0 else guard_pose[bone]

	var source_by_bone := {}
	for i in range(BONES.size()):
		var name := String(BONES[i])
		if side == "left":
			if name.ends_with("_l"):
				name = name.substr(0, name.length() - 2) + "_r"
			elif name.ends_with("_r"):
				name = name.substr(0, name.length() - 2) + "_l"
		var bone := skeleton.find_bone(name)
		if bone >= 0 and guard_track.has(bone):
			source_by_bone[bone] = i
	var kicking_leg := skeleton.find_bone("thigh_" + ("l" if side == "left" else "r"))
	if not source_by_bone.has(skeleton.find_bone("pelvis")) or not source_by_bone.has(kicking_leg):
		push_error("MMA kick could not find player pelvis/leg animation tracks")
		return null

	var clip := base.duplicate(true) as Animation
	clip.length = duration
	clip.loop_mode = Animation.LOOP_NONE
	clip.step = 1.0 / 60.0
	for track in range(clip.get_track_count()):
		for k in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, k)

	for sample in range(SAMPLE_COUNT):
		var time := duration * float(sample) / float(SAMPLE_COUNT - 1)
		var offset0 := sample * BONES.size() * 8
		var deltas: Array[Quaternion] = []
		deltas.resize(BONES.size())
		for i in range(BONES.size()):
			var o := offset0 + i * 8
			var q := Quaternion(
				float(data.decode_s16(o)) / 32767.0,
				float(data.decode_s16(o + 2)) / 32767.0,
				float(data.decode_s16(o + 4)) / 32767.0,
				float(data.decode_s16(o + 6)) / 32767.0
			).normalized()
			deltas[i] = Quaternion(q.x, -q.y, -q.z, q.w) if side == "left" else q

		var world: Array[Quaternion] = []
		world.resize(guard_pose.size())
		for bone in range(guard_pose.size()):
			var p := skeleton.get_bone_parent(bone)
			if source_by_bone.has(bone):
				world[bone] = (deltas[int(source_by_bone[bone])] * guard_global[bone]).normalized()
			else:
				world[bone] = (world[p] * guard_pose[bone]).normalized() if p >= 0 else guard_pose[bone]
		for track in range(clip.get_track_count()):
			var kind := clip.track_get_type(track)
			if kind == Animation.TYPE_ROTATION_3D:
				var path := clip.track_get_path(track)
				if path.get_subname_count() != 1:
					continue
				var bone := skeleton.find_bone(String(path.get_subname(0)))
				if bone < 0:
					continue
				var p := skeleton.get_bone_parent(bone)
				var pose := (world[p].inverse() * world[bone]).normalized() if p >= 0 else world[bone]
				clip.rotation_track_insert_key(track, time, pose)
			elif kind == Animation.TYPE_POSITION_3D:
				clip.position_track_insert_key(track, time, base.position_track_interpolate(track, 0.0))
			elif kind == Animation.TYPE_SCALE_3D:
				clip.scale_track_insert_key(track, time, base.scale_track_interpolate(track, 0.0))
	return clip
