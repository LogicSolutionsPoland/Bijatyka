extends Node
class_name PlayerExoMixamoOverlay

## Optional, Exo-only visual animations. The hidden Universal Base rig and all
## combat physics/timers keep running; these animations never move the player.
## Animations are pre-retargeted and quantized offline from the user's FBX files.
const DATA := preload("res://scripts/exo_mixamo_data.gd")
const LIBRARY_NAME := &"exo_mixamo"
const BLEND_SECONDS := 0.045
const STRIKE_LENGTH := 0.32
const STRIKE_CONTACT := 0.12
const ROLL_VISUAL_DURATION := 0.50
# Impact frames are selected from actual Exo Gray foot/knee geometry, not guessed
# percentages of the source animation. Computed once at model initialization.
const STRIKE_NAMES := ["mma_kick", "roundhouse", "fly_kick"]
const IMPACT_MIN_SECONDS := 0.18
const IMPACT_END_FRACTION := 0.92

var _animator: AnimationPlayer
var _driver: PlayerExoGrayRetarget
var _ready_to_play := false
var _skeleton: Skeleton3D
var _exo_model: Node3D
var _roll_actor: CharacterBody3D
var _roll_active := false
var _roll_lift := 0.0
var _impact_fractions: Dictionary = {}
var _original_sides: Dictionary = {}
var _contact_scores: Dictionary = {}

func configure(exo_model: Node3D, skeleton: Skeleton3D, driver: PlayerExoGrayRetarget) -> bool:
	if exo_model == null or skeleton == null or driver == null or DATA.CLIPS.is_empty():
		return false
	var skeleton_path := exo_model.get_path_to(skeleton)
	var bone_indices := PackedInt32Array()
	for name in DATA.BONES:
		var index := skeleton.find_bone(String(name))
		if index < 0:
			push_warning("Exo Mixamo: missing bone " + String(name))
			return false
		bone_indices.append(index)
	_skeleton = skeleton
	_exo_model = exo_model
	_roll_actor = exo_model.get_parent().get_parent() as CharacterBody3D
	var library := AnimationLibrary.new()
	for raw_name in DATA.CLIPS:
		var name := String(raw_name)
		var info: Dictionary = DATA.CLIPS[raw_name]
		var frame_count := int(info.get("frames", 0))
		var duration := float(info.get("length", 0.0))
		var bytes := Marshalls.base64_to_raw(String(info.get("data", "")))
		if frame_count < 2 or duration <= 0.0 or bytes.size() != frame_count * bone_indices.size() * 8:
			push_warning("Exo Mixamo: invalid clip data " + name)
			return false
		var animation := Animation.new()
		animation.length = duration
		animation.step = 1.0 / float(DATA.FPS)
		animation.loop_mode = Animation.LOOP_NONE
		for bone_no in range(bone_indices.size()):
			var track := animation.add_track(Animation.TYPE_ROTATION_3D)
			animation.track_set_path(track, NodePath("%s:%s" % [str(skeleton_path), String(DATA.BONES[bone_no])]))
			animation.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
			for frame in range(frame_count):
				var offset := (frame * bone_indices.size() + bone_no) * 8
				var q := Quaternion(
					float(bytes.decode_s16(offset)) / 32767.0,
					float(bytes.decode_s16(offset + 2)) / 32767.0,
					float(bytes.decode_s16(offset + 4)) / 32767.0,
					float(bytes.decode_s16(offset + 6)) / 32767.0
				).normalized()
				animation.rotation_track_insert_key(track, minf(duration, float(frame) / float(DATA.FPS)), q)
		if library.add_animation(StringName(name), animation) != OK:
			return false
	# Diagnose strike geometry using the visible 112-bone rig. Mirror in
	# rest-relative global space only when the source leg differs from input.
	# This never alters the physical CharacterBody3D or the hidden combat rig.
	for strike_name in STRIKE_NAMES:
		var original := library.get_animation(StringName(strike_name))
		var left := _find_contact(original, "left")
		var right := _find_contact(original, "right")
		var source_side := "left" if float(left["score"]) > float(right["score"]) else "right"
		var analysis: Dictionary = left if source_side == "left" else right
		_original_sides[strike_name] = source_side
		_impact_fractions[strike_name] = float(analysis["fraction"])
		_contact_scores[strike_name] = float(analysis["score"])
		print("EXO_KICK_ANALYSIS %s source=%s frame=%d impact=%.3fs score=%.3f" % [
			strike_name, source_side, int(analysis["frame"]),
			float(analysis["fraction"]) * original.length, float(analysis["score"])])
		print("EXO_KICK_HEIGHT %s left=%.3f (max %.3f) right=%.3f (max %.3f) selected=%.3f" % [
			strike_name, float(left["clearance"]), float(left["max_clearance"]),
			float(right["clearance"]), float(right["max_clearance"]),
			float(analysis["clearance"])])
		var reflected := _mirror_animation(original)
		if reflected == null or library.add_animation(StringName(strike_name + "_mirrored"), reflected) != OK:
			return false
		for side in ["left", "right"]:
			var selected := original if side == source_side else reflected
			var compact := _bake_strike(selected, float(analysis["fraction"]))
			if compact == null or library.add_animation(StringName(strike_name + "_" + side + "_combat"), compact) != OK:
				return false
		# Compatibility alias for existing preview/tests; explicit gameplay
		# calls always select the anatomically correct left/right variant.
		if library.add_animation(StringName(strike_name + "_combat"),
			library.get_animation(StringName(strike_name + "_right_combat"))) != OK:
			return false
	_animator = AnimationPlayer.new()
	_animator.name = "ExoMixamoAnimationPlayer"
	exo_model.add_child(_animator)
	_animator.root_node = _animator.get_path_to(exo_model)
	_animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	if _animator.add_animation_library(LIBRARY_NAME, library) != OK:
		_animator.queue_free()
		_animator = null
		return false
	_animator.animation_finished.connect(_on_animation_finished)
	_driver = driver
	_ready_to_play = true
	set_process(false)
	return true


# Sample the stored source rotations on Exo's *actual* skeleton. A bent torso
# or raised knee alone cannot win: the foot must travel forward, clear the
# support foot, and straighten beyond the knee. No runtime per-frame search.
func _find_contact(source: Animation, side: String) -> Dictionary:
	var foot_index := _skeleton.find_bone("LeftFoot" if side == "left" else "RightFoot")
	var knee_index := _skeleton.find_bone("LeftLeg" if side == "left" else "RightLeg")
	var hip_index := _skeleton.find_bone("LeftUpLeg" if side == "left" else "RightUpLeg")
	var support_index := _skeleton.find_bone("RightFoot" if side == "left" else "LeftFoot")
	var head_index := _skeleton.find_bone("Head")
	var pelvis_index := _skeleton.find_bone("Hips")
	var forward := -_roll_actor.global_transform.basis.z.normalized() if is_instance_valid(_roll_actor) else -_exo_model.global_transform.basis.z.normalized()
	var saved := _save_pose()
	_apply_source_pose(source, 0.0)
	var start_foot := _bone_position(foot_index)
	var start_support := _bone_position(support_index)
	var start_forward := (start_foot - start_support).dot(forward)
	var best_score := -INF
	var best_frame := 0
	var best_clearance := -INF
	var max_clearance := -INF
	var max_clearance_frame := -1
	var steps := maxi(2, ceili(source.length * float(DATA.FPS)))
	for frame in range(steps):
		var time := minf(source.length, float(frame) / float(DATA.FPS))
		if time < IMPACT_MIN_SECONDS or time > source.length * IMPACT_END_FRACTION:
			continue
		_apply_source_pose(source, time)
		var foot := _bone_position(foot_index)
		var knee := _bone_position(knee_index)
		var hip := _bone_position(hip_index)
		var planted := _bone_position(support_index)
		var torso := _bone_position(head_index) - _bone_position(pelvis_index)
		var leg_a := (hip - knee).normalized()
		var leg_b := (foot - knee).normalized()
		var straightness := -leg_a.dot(leg_b)  # 1 means a straight knee
		var reach := (foot - planted).dot(forward) - start_forward
		var travel := (foot - start_foot).dot(forward)
		var clearance := foot.y - planted.y
		if clearance > max_clearance:
			max_clearance = clearance
			max_clearance_frame = frame
		# A turning, planted support foot may travel forward during a spin.
		# It is not the kicking leg unless it actually leaves the ground.
		if clearance < 0.20:
			continue
		var foot_ahead_of_knee := (foot - knee).dot(forward)
		var support_drift := planted.distance_to(start_support)
		var upright := torso.normalized().dot(Vector3.UP)
		var score := 1.8 * reach + 0.9 * travel + 0.6 * maxf(0.0, clearance) \
			+ 0.55 * straightness + 0.40 * foot_ahead_of_knee \
			- 0.8 * support_drift - 1.0 * maxf(0.0, 0.40 - upright)
		# A convincing strike must also leave the floor; forward reach alone
		# would select low sweeping/crouching poses.
		score -= 4.0 * maxf(0.0, 0.18 - clearance)
		if score > best_score:
			best_score = score
			best_frame = frame
			best_clearance = clearance
	_restore_pose(saved)
	if best_score == -INF:
		best_score = -1000.0
	return {"fraction": minf(1.0, float(best_frame) / float(DATA.FPS) / source.length),
		"frame": best_frame, "score": best_score,
		"clearance": best_clearance, "max_clearance": max_clearance,
		"max_clearance_frame": max_clearance_frame}


func _save_pose() -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	for name in DATA.BONES:
		result.append(_skeleton.get_bone_pose_rotation(_skeleton.find_bone(String(name))))
	return result


func _restore_pose(rotations: Array[Quaternion]) -> void:
	for i in range(DATA.BONES.size()):
		_skeleton.set_bone_pose_rotation(_skeleton.find_bone(String(DATA.BONES[i])), rotations[i])
	_skeleton.force_update_all_bone_transforms()


func _apply_source_pose(clip: Animation, time: float) -> void:
	for i in range(DATA.BONES.size()):
		var idx := _skeleton.find_bone(String(DATA.BONES[i]))
		_skeleton.set_bone_pose_rotation(idx, clip.rotation_track_interpolate(i, time))
	_skeleton.force_update_all_bone_transforms()


func _bone_position(index: int) -> Vector3:
	return _skeleton.to_global(_skeleton.get_bone_global_pose(index).origin)


# True bilateral mirroring: swap left/right homologous joints and reflect each
# REST-RELATIVE GLOBAL rotation across the sagittal plane. Mirroring the
# quaternion's arbitrary components would corrupt the Mixamo joint axes.
func _mirror_animation(source: Animation) -> Animation:
	var mirrored := Animation.new()
	mirrored.length = source.length
	mirrored.step = source.step
	mirrored.loop_mode = Animation.LOOP_NONE
	var saved := _save_pose()
	var mirror_basis := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var track_indices: Dictionary = {}
	for name in DATA.BONES:
		var track := mirrored.add_track(Animation.TYPE_ROTATION_3D)
		mirrored.track_set_path(track, source.track_get_path(DATA.BONES.find(name)))
		mirrored.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		track_indices[String(name)] = track
	var frames := maxi(2, roundi(source.length * float(DATA.FPS)) + 1)
	for frame in range(frames):
		var time := minf(source.length, float(frame) / float(DATA.FPS))
		_apply_source_pose(source, time)
		var source_deltas: Dictionary = {}
		for raw_name in DATA.BONES:
			var name := String(raw_name)
			var bone := _skeleton.find_bone(name)
			var actual := _skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
			var rest := _skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
			source_deltas[name] = (actual * rest.inverse()).normalized()
		var output_globals: Dictionary = {}
		for raw_name in DATA.BONES:
			var name := String(raw_name)
			var opposite := _opposite_bone_name(name)
			var bone := _skeleton.find_bone(name)
			var delta := Basis(source_deltas[opposite] as Quaternion)
			var reflected := (mirror_basis * delta * mirror_basis).get_rotation_quaternion().normalized()
			var global_rest := _skeleton.get_bone_global_rest(bone).basis.get_rotation_quaternion()
			var wanted_global := (reflected * global_rest).normalized()
			var parent := _skeleton.get_bone_parent(bone)
			var parent_global := Quaternion.IDENTITY
			if parent >= 0:
				var parent_name := String(_skeleton.get_bone_name(parent))
				if output_globals.has(parent_name):
					parent_global = output_globals[parent_name] as Quaternion
				else:
					parent_global = _skeleton.get_bone_global_rest(parent).basis.get_rotation_quaternion()
			var local_rotation := (parent_global.inverse() * wanted_global).normalized()
			mirrored.rotation_track_insert_key(int(track_indices[name]), time, local_rotation)
			output_globals[name] = wanted_global
	_restore_pose(saved)
	return mirrored


func _opposite_bone_name(name: String) -> String:
	if name.begins_with("Left"):
		return "Right" + name.substr(4)
	if name.begins_with("Right"):
		return "Left" + name.substr(5)
	return name


func impact_fraction(name: String) -> float:
	return float(_impact_fractions.get(name, 0.0))


func authored_side(name: String) -> String:
	return String(_original_sides.get(name, ""))


func _bake_strike(source: Animation, peak_fraction: float) -> Animation:
	if source == null:
		return null
	var clip := Animation.new()
	clip.length = STRIKE_LENGTH
	clip.step = 1.0 / 60.0
	clip.loop_mode = Animation.LOOP_NONE
	# Impact is at the *actual* damage boundary, not at a late source-frame.
	# Fast follow-up attacks at 5 Hz still show the kick at t=0.12 s.
	# Chamber -> extension -> hit -> brief follow-through -> planted recovery.
	# Do not seek across the entire remaining 2-second spin in 0.15 seconds.
	var times := [0.0, 0.04, 0.08, STRIKE_CONTACT, 0.16, 0.20, 0.27, STRIKE_LENGTH]
	var fractions := [0.0, peak_fraction * 0.42, peak_fraction * 0.76, peak_fraction,
		minf(1.0, peak_fraction + 0.045), minf(1.0, peak_fraction + 0.09),
		minf(1.0, peak_fraction + 0.15), 0.0]
	for source_track in range(source.get_track_count()):
		if source.track_get_type(source_track) != Animation.TYPE_ROTATION_3D:
			continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, source.track_get_path(source_track))
		clip.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		for i in range(times.size()):
			var pose := source.rotation_track_interpolate(source_track, source.length * float(fractions[i]))
			clip.rotation_track_insert_key(track, float(times[i]), pose)
	return clip

func play_strike(name: String, side: String = "right") -> bool:
	if name not in STRIKE_NAMES or side not in ["left", "right"]:
		return false
	return play_clip(name + "_" + side + "_combat", STRIKE_LENGTH)

func play_ground_roll() -> bool:
	if not is_instance_valid(_roll_actor) or not _roll_actor.is_on_floor():
		return false
	if not play_clip("roll", ROLL_VISUAL_DURATION):
		return false
	_roll_active = true
	set_process(true)
	return true

func play_clip(name: String, requested_duration: float = 0.0) -> bool:
	if not _ready_to_play or not is_instance_valid(_animator):
		return false
	var key := StringName("%s/%s" % [String(LIBRARY_NAME), name])
	if not _animator.has_animation(key):
		return false
	_stop_roll_lift()
	var duration := _animator.get_animation(key).length
	var playback_speed := duration / requested_duration if requested_duration > 0.05 else 1.0
	_driver.set_process(false)
	_animator.play(key, BLEND_SECONDS, playback_speed)
	_animator.advance(0.0)
	return true

func _process(_delta: float) -> void:
	if not _roll_active or not is_instance_valid(_exo_model) or not is_instance_valid(_skeleton):
		set_process(false)
		return
	# Roll only adjusts the visible mesh, never CharacterBody3D/collision.
	# Keep head, pelvis, hands and feet from crossing the player's floor.
	var lower_y := INF
	for name in ["Head", "Hips", "LeftHand", "RightHand", "LeftFoot", "RightFoot"]:
		var bone := _skeleton.find_bone(name)
		if bone >= 0:
			var bone_position := _skeleton.to_global(_skeleton.get_bone_global_pose(bone).origin)
			lower_y = minf(lower_y, bone_position.y)
	if lower_y == INF:
		return
	# Subtract the previously applied visual lift to avoid feedback accumulation.
	var uncorrected_low := lower_y - _roll_lift
	var floor_y := _roll_actor.global_position.y if is_instance_valid(_roll_actor) else 0.0
	var progress := 0.0
	var clip := _animator.get_animation(StringName("exo_mixamo/roll"))
	if clip != null and clip.length > 0.0:
		progress = clampf(_animator.current_animation_position / clip.length, 0.0, 1.0)
	var fade := minf(1.0, minf(progress / 0.12, (1.0 - progress) / 0.12))
	var target_lift := clampf(floor_y + 0.075 - uncorrected_low, 0.0, 0.80) * maxf(0.0, fade)
	_roll_lift = lerpf(_roll_lift, target_lift, 0.55)
	_exo_model.position.y = _roll_lift

func stop_clip() -> void:
	if not _ready_to_play:
		return
	_animator.stop()
	_stop_roll_lift()
	_resume_driver()

func _stop_roll_lift() -> void:
	_roll_active = false
	set_process(false)
	_roll_lift = 0.0
	if is_instance_valid(_exo_model):
		_exo_model.position.y = 0.0

func _on_animation_finished(_name: StringName) -> void:
	_stop_roll_lift()
	_resume_driver()

func _resume_driver() -> void:
	if is_instance_valid(_driver):
		_driver.set_process(true)
		_driver.synchronize_pose()
