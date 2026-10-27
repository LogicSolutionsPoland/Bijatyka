extends SceneTree

## Offline two-bone fitting only. Runtime receives baked Animation tracks.
const DATA := "res://../tools/ring_reference/motions.json"
const OUT := "res://animations/ring_reference"
var s: Skeleton3D
var animator: AnimationPlayer
var base_rot: Array[Quaternion] = []
var base_pos: Array[Vector3] = []
var anchors: Dictionary = {}
var globals: Dictionary = {}
var scale_ratio := 1.0
var max_foot_error := 0.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	for rig in ["Male", "Female"]:
		var model: Node3D = load("res://assets/characters/universal_base/Universal_Base_Characters_%s.glb" % rig).instantiate()
		root.add_child(model)
		s = model.find_child("Skeleton3D", true, false)
		animator = model.find_child("AnimationPlayer", true, false)
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animator.play("Punch_Jab", 0.0)
		animator.seek(0.0, true)
		s.force_update_all_bone_transforms()
		base_rot.clear(); base_pos.clear(); anchors.clear(); globals.clear()
		for bone in range(s.get_bone_count()):
			base_rot.append(s.get_bone_pose_rotation(bone))
			base_pos.append(s.get_bone_pose_position(bone))
			var bone_name := s.get_bone_name(bone)
			anchors[bone_name] = s.get_bone_global_pose(bone).origin
			globals[bone_name] = s.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		scale_ratio = float(anchors["Head"].y) / 1.498429
		var dir := OUT.path_join(rig.to_lower())
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var library := AnimationLibrary.new()
		for clip_name: String in data.clips:
			var clip := _bake(data.clips[clip_name])
			clip.resource_name = clip_name
			clip.set_meta("source_seconds", data.clips[clip_name].source)
			clip.set_meta("reconstruction", "manual; inferred depth; not mocap")
			if ResourceSaver.save(clip, dir.path_join(clip_name + ".tres")) != OK:
				quit(1); return
			library.add_animation(clip_name, clip)
		if _save_library(data.clips.keys(), dir) != OK:
			quit(1); return
		model.free()
	print("BAKED_RING_CLIPS=32 MAX_PLANTED_FOOT_ERROR_METRES=", max_foot_error)
	quit(0 if max_foot_error < 0.025 else 1)

func _reset() -> void:
	for bone in range(s.get_bone_count()):
		s.set_bone_pose_rotation(bone, base_rot[bone])
		s.set_bone_pose_position(bone, base_pos[bone])
	s.force_update_all_bone_transforms()

func _vec(frame: Dictionary, key: String) -> Vector3:
	var v: Array = frame.get(key, [0, 0, 0])
	return Vector3(float(v[0]), float(v[1]), float(v[2]))

func _frame_at(frames: Array, time: float) -> Dictionary:
	for i in range(1, frames.size()):
		if time <= float(frames[i].t) + 0.00001:
			var a: Dictionary = frames[i - 1]
			var b: Dictionary = frames[i]
			var w := clampf((time - float(a.t)) / (float(b.t) - float(a.t)), 0.0, 1.0)
			w = w * w * (3.0 - 2.0 * w)
			var result: Dictionary = {}
			for key in a.keys() + b.keys():
				if key != "t":
					var v := _vec(a, key).lerp(_vec(b, key), w)
					result[key] = [v.x, v.y, v.z]
			return result
	return frames.back()

func _global_rotate(bone_name: String, delta: Quaternion) -> void:
	var bone := s.find_bone(bone_name)
	var parent := s.get_bone_parent(bone)
	var parent_q := s.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var current := s.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	s.set_bone_pose_rotation(bone, (parent_q.inverse() * delta * current).normalized())
	s.force_update_all_bone_transforms()

func _point(bone: int) -> Vector3:
	return s.get_bone_global_pose(bone).origin

func _aim_plane(bone: int, child: int, target: Vector3, source_normal: Vector3, target_normal: Vector3) -> void:
	var bone_name := s.get_bone_name(bone)
	var child_name := s.get_bone_name(child)
	var original_dir: Vector3 = (anchors[child_name] - anchors[bone_name]).normalized()
	var desired_dir := (target - _point(bone)).normalized()
	var original_basis := Basis(original_dir, source_normal.cross(original_dir).normalized(), source_normal).orthonormalized()
	var desired_basis := Basis(desired_dir, target_normal.cross(desired_dir).normalized(), target_normal).orthonormalized()
	var desired_q := (desired_basis * original_basis.inverse()).get_rotation_quaternion() * (globals[bone_name] as Quaternion)
	var parent := s.get_bone_parent(bone)
	var parent_q := s.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	s.set_bone_pose_rotation(bone, (parent_q.inverse() * desired_q).normalized())
	s.force_update_all_bone_transforms()

func _limb(upper_name: String, lower_name: String, end_name: String, target: Vector3, pole: Vector3) -> void:
	var upper := s.find_bone(upper_name)
	var lower := s.find_bone(lower_name)
	var end := s.find_bone(end_name)
	var origin := _point(upper)
	var a := origin.distance_to(_point(lower))
	var b := _point(lower).distance_to(_point(end))
	var distance := clampf(origin.distance_to(target), absf(a - b) + 0.001, a + b - 0.001)
	var dir := (target - origin).normalized()
	var perpendicular := pole - dir * pole.dot(dir)
	if perpendicular.length() < 0.001:
		perpendicular = Vector3.RIGHT.cross(dir)
	perpendicular = perpendicular.normalized()
	var along := (a * a + distance * distance - b * b) / (2.0 * distance)
	var height := sqrt(maxf(0.0, a * a - along * along))
	var elbow := origin + dir * along + perpendicular * height
	var effective_target := origin + dir * distance
	var original_normal: Vector3 = (anchors[lower_name] - anchors[upper_name]).cross(anchors[end_name] - anchors[lower_name]).normalized()
	var desired_normal := (elbow - origin).cross(effective_target - elbow).normalized()
	_aim_plane(upper, lower, elbow, original_normal, desired_normal)
	_aim_plane(lower, end, effective_target, original_normal, desired_normal)
	# Restore the guard's end-effector orientation after the limb swing.
	var parent := s.get_bone_parent(end)
	var parent_q := s.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	s.set_bone_pose_rotation(end, (parent_q.inverse() * (globals[end_name] as Quaternion)).normalized())
	s.force_update_all_bone_transforms()

func _apply(frame: Dictionary) -> void:
	_reset()
	var pelvis := s.find_bone("pelvis")
	var offset := _vec(frame, "root") * scale_ratio
	var parent := s.get_bone_parent(pelvis)
	var basis := s.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	s.set_bone_pose_position(pelvis, base_pos[pelvis] + basis.inverse() * offset)
	s.force_update_all_bone_transforms()
	for bone_name in ["pelvis", "spine_02", "spine_03", "Head"]:
		var angles := _vec(frame, "head" if bone_name == "Head" else bone_name) * (PI / 180.0)
		_global_rotate(bone_name, Quaternion.from_euler(angles))
	# Lower the authored pelvis only when a planted leg would exceed its reach.
	# This is an offline constraint correction, never a runtime IK operation.
	for pass_index in range(2):
		for suffix: String in ["l", "r"]:
			if not _vec(frame, "foot_" + suffix).is_zero_approx(): continue
			var hip := _point(s.find_bone("thigh_" + suffix))
			var knee := _point(s.find_bone("calf_" + suffix))
			var foot := _point(s.find_bone("foot_" + suffix))
			var target: Vector3 = anchors["foot_" + suffix]
			var reach := hip.distance_to(knee) + knee.distance_to(foot) - 0.002
			var horizontal := Vector2(hip.x - target.x, hip.z - target.z).length_squared()
			var allowed_height := sqrt(maxf(0.0, reach * reach - horizontal))
			var drop := minf(0.0, allowed_height - (hip.y - target.y))
			if drop < 0.0:
				s.set_bone_pose_position(pelvis, s.get_bone_pose_position(pelvis) + basis.inverse() * Vector3(0, drop, 0))
				s.force_update_all_bone_transforms()
	var yaw := Quaternion(Vector3.UP, deg_to_rad(_vec(frame, "pelvis").y))
	for suffix: String in ["l", "r"]:
		var hand_name := "hand_" + suffix
		var hand_target: Vector3 = anchors["pelvis"] + offset + yaw * (anchors[hand_name] - anchors["pelvis"]) + _vec(frame, hand_name) * scale_ratio
		var side := 1.0 if suffix == "l" else -1.0
		_limb("upperarm_" + suffix, "lowerarm_" + suffix, hand_name, hand_target, Vector3(side * 0.65, -1.0, -0.15))
		var foot_name := "foot_" + suffix
		var target: Vector3 = anchors[foot_name] + _vec(frame, foot_name) * scale_ratio
		_limb("thigh_" + suffix, "calf_" + suffix, foot_name, target, Vector3(side * 0.45, 0.8, 1.0))
		if _vec(frame, foot_name).is_zero_approx() and offset.y <= 0.001:
			max_foot_error = maxf(max_foot_error, _point(s.find_bone(foot_name)).distance_to(target))

func _bake(info: Dictionary) -> Animation:
	var animation := Animation.new()
	animation.length = float(info.frames.back().t)
	animation.loop_mode = Animation.LOOP_LINEAR if info.get("loop", false) else Animation.LOOP_NONE
	animation.step = 1.0 / 30.0
	if info.has("contact"):
		animation.add_marker(&"contact", float(info.contact))
	# Sparse per-bone tracks; closed-fist fingers retained from the imported guard.
	var times: Array[float] = [0.0, animation.length]
	for i in range(1, ceili(animation.length * 30.0)):
		times.append(float(i) / 30.0)
	for frame: Dictionary in info.frames:
		times.append(float(frame.t))
	if info.has("contact"):
		times.append(float(info.contact))
	times.sort()
	var last_time := -1.0
	var tracks: Dictionary = {}
	for bone in range(s.get_bone_count()):
		var name := s.get_bone_name(bone)
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("Armature/Skeleton3D:" + name))
		animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		tracks[bone] = track
	var pos_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(pos_track, NodePath("Armature/Skeleton3D:pelvis"))
	for time in times:
		if absf(time - last_time) < 0.00001: continue
		last_time = time
		_apply(_frame_at(info.frames, time))
		for bone in range(s.get_bone_count()):
			animation.rotation_track_insert_key(tracks[bone], time, s.get_bone_pose_rotation(bone))
		animation.position_track_insert_key(pos_track, time, s.get_bone_pose_position(s.find_bone("pelvis")))
	# Collapse static tracks without removing the guard/finger pose.
	for track in range(animation.get_track_count()):
		var same := true
		var initial: Variant = animation.track_get_key_value(track, 0)
		for key in range(1, animation.track_get_key_count(track)):
			var value: Variant = animation.track_get_key_value(track, key)
			if not initial.is_equal_approx(value):
				same = false; break
		if same:
			for key in range(animation.track_get_key_count(track) - 1, 0, -1):
				animation.track_remove_key(track, key)
	return animation

func _save_library(names: Array, dir: String) -> Error:
	var text := '[gd_resource type="AnimationLibrary" load_steps=%d format=3]\n\n' % (names.size() + 1)
	for i in range(names.size()):
		text += '[ext_resource type="Animation" path="%s/%s.tres" id="%d"]\n' % [dir, names[i], i + 1]
	text += '\n[resource]\n_data = {\n'
	for i in range(names.size()):
		text += '&"%s": ExtResource("%d")%s\n' % [names[i], i + 1, "," if i < names.size() - 1 else ""]
	text += '}\n'
	var file := FileAccess.open(dir.path_join("library.tres"), FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(text)
	return OK
