extends SceneTree

## One-time editor/headless baker: samples the original, unmodified Punch_Cross
## on Universal Base, retargets each pose to the ACTUAL imported Exo Gray rig,
## then authors an independent binary Godot Animation resource.
const PLAYER := preload("res://scripts/player_controller.gd")
const EXO_DATA := preload("res://scripts/exo_mixamo_data.gd")
const OUTPUT := "res://assets/characters/exo_gray/animations/Finger_Gun_Shoot.res"
const SOURCE := &"Punch_Cross"
const FRAME_RATE := 30.0
const CONTACT := 0.30
const REQUIRED := [
	"RightHand", "RightHandIndex1", "RightHandIndex2", "RightHandIndex3",
	"RightHandThumb1", "RightHandThumb2", "RightHandThumb3",
	"RightHandMiddle1", "RightHandMiddle2", "RightHandMiddle3",
	"RightHandRing1", "RightHandRing2", "RightHandRing3",
	"RightHandPinky1", "RightHandPinky2", "RightHandPinky3"
]
const CURLS := {
	"Index": [0.0, 0.0, 0.0],
	"Thumb": [0.42, 0.18, 0.05],
	"Middle": [0.80, 1.05, 0.65],
	"Ring": [0.88, 1.05, 0.70],
	"Pinky": [0.85, 0.98, 0.65]
}

func _initialize() -> void:
	call_deferred("_bake")

func _bake() -> void:
	var player := PLAYER.new()
	root.add_child(player)
	player.set_physics_process(false)
	var source_anim := player._animation_player as AnimationPlayer
	var source_rig := player._skeleton as Skeleton3D
	var exo := player._exo_visual_model as Node3D
	var retarget := player._exo_retarget as PlayerExoGrayRetarget
	if source_anim == null or source_rig == null or exo == null or retarget == null:
		_fail("Active source and Exo Gray animation rigs are required", player)
		return
	var target := retarget.target_skeleton as Skeleton3D
	if target == null or target.get_bone_count() != 112:
		_fail("Exo Gray's actual 112-bone skeleton is missing", player)
		return
	for name in REQUIRED:
		if target.find_bone(name) < 0:
			_fail("Exo Gray lacks a required finger bone: " + name, player)
			return
	for name in EXO_DATA.BONES:
		if target.find_bone(String(name)) < 0:
			_fail("Retargeted body bone not present: " + String(name), player)
			return
	if not source_anim.has_animation(SOURCE):
		_fail("Original punch missing: " + String(SOURCE), player)
		return
	var original := source_anim.get_animation(SOURCE)
	if original.length <= CONTACT + 0.12:
		_fail("Original punch ends before meaningful casting recovery", player)
		return
	var initial_length := original.length
	var initial_track_count := original.get_track_count()
	print("FINGER_GUN_SOURCE=%s DURATION=%.6f TRACKS=%d EXO_BONES=%d" % [
		String(SOURCE), original.length, initial_track_count, target.get_bone_count()
	])
	# Source animation is sampled only. It is not duplicated/edited or saved.
	retarget.set_process(false)
	source_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	source_anim.play(SOURCE)
	source_anim.seek(0.0, true)
	var clip := Animation.new()
	clip.resource_name = "Finger_Gun_Shoot"
	clip.length = original.length
	clip.step = 1.0 / FRAME_RATE
	clip.loop_mode = Animation.LOOP_NONE
	clip.set_meta("source_animation", String(SOURCE))
	clip.set_meta("authoring_model", "Exo_Gray_Player.glb")
	clip.set_meta("fire_time", CONTACT)
	var targets := []
	for raw_name in EXO_DATA.BONES:
		targets.append(String(raw_name))
	for finger in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
		for part in range(1, 4):
			var name := "RightHand%s%d" % [finger, part]
			if name not in targets:
				targets.append(name)
	var skeleton_path := str(exo.get_path_to(target))
	var tracks := {}
	for name in targets:
		var index := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(index, NodePath("%s:%s" % [skeleton_path, name]))
		clip.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
		tracks[name] = index
	var axes := {}
	for finger in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
		for part in range(1, 4):
			var name := "RightHand%s%d" % [finger, part]
			axes[name] = _curl_axis(target, name, finger == "Thumb")
	var count := ceili(original.length * FRAME_RATE)
	for frame in range(count + 1):
		var at := minf(original.length, float(frame) / FRAME_RATE)
		# Never retime the punch: preserve its natural source cadence and full length.
		source_anim.seek(at, true)
		retarget.synchronize_pose()
		var grip := smoothstep(0.0, CONTACT * 0.90, at) * (1.0 - smoothstep(
			maxf(CONTACT + 0.075, original.length - 0.19), original.length, at))
		var recoil := 0.0
		if at >= CONTACT and at <= CONTACT + 0.13:
			recoil = sin((at - CONTACT) / 0.13 * PI)
		for name in targets:
			var idx := target.find_bone(name)
			var pose := target.get_bone_pose_rotation(idx)
			if name.begins_with("RightHand") and name != "RightHand":
				var finger := name.substr("RightHand".length())
				var part := int(finger.substr(finger.length() - 1))
				finger = finger.substr(0, finger.length() - 1)
				var bend := float(CURLS[finger][part - 1]) * grip
				pose = (pose * Quaternion(axes[name], bend)).normalized()
			elif name == "RightHand":
				# Small upward wrist recoil, not a punch-sized arm kick.
				pose = (pose * Quaternion(Vector3.RIGHT, recoil * 0.10)).normalized()
			elif name == "Spine2":
				pose = (pose * Quaternion(Vector3.UP, recoil * 0.025)).normalized()
			clip.rotation_track_insert_key(int(tracks[name]), at, pose)
	clip.add_marker(&"fire", CONTACT)
	var event_track := clip.add_track(Animation.TYPE_METHOD)
	clip.track_set_path(event_track, NodePath("FingerGunFireEvent"))
	clip.method_track_insert_key(event_track, CONTACT, &"emit_fire", [])
	if original.length != initial_length or original.get_track_count() != initial_track_count:
		_fail("Source punch was unexpectedly changed", player)
		return
	var folder := ProjectSettings.globalize_path(OUTPUT.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_fail("Cannot create output folder: " + folder, player)
		return
	var status := ResourceSaver.save(clip, OUTPUT)
	if status != OK:
		_fail("ResourceSaver failed: " + str(status), player)
		return
	# Reload the actual serialized binary resource instead of trusting the in-memory bake.
	var saved := load(OUTPUT) as Animation
	if saved == null or saved.get_track_count() != targets.size() + 1:
		_fail("Saved animation cannot be loaded correctly", player)
		return
	print("FINGER_GUN_BAKED path=%s source=%s duration=%.6f fire=%.3f tracks=%d finger_bones=%d" % [
		OUTPUT, String(SOURCE), saved.length, CONTACT, saved.get_track_count(), 15
	])
	player.queue_free()
	quit(0)

func _curl_axis(skeleton: Skeleton3D, name: String, thumb: bool) -> Vector3:
	var index := skeleton.find_bone(name)
	var rest := skeleton.get_bone_global_rest(index)
	var child := -1
	for j in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(j) == index:
			child = j
			break
	var start := rest.origin
	var forward := Vector3.FORWARD
	if child >= 0:
		forward = (skeleton.get_bone_global_rest(child).origin - start).normalized()
	else:
		var parent := skeleton.get_bone_parent(index)
		if parent >= 0:
			forward = (start - skeleton.get_bone_global_rest(parent).origin).normalized()
	var wanted := Vector3.UP if thumb else skeleton.get_bone_global_rest(
		skeleton.find_bone("RightHand")).origin - start
	wanted -= forward * wanted.dot(forward)
	if wanted.length_squared() < 0.00001:
		wanted = rest.basis.y - forward * rest.basis.y.dot(forward)
	if wanted.length_squared() < 0.00001:
		wanted = rest.basis.x - forward * rest.basis.x.dot(forward)
	var world_axis := forward.cross(wanted.normalized()).normalized()
	return (rest.basis.inverse() * world_axis).normalized()

func _fail(message: String, player: Node) -> void:
	push_error("FINGER_GUN_BAKE_FAILED: " + message)
	player.queue_free()
	quit(1)
