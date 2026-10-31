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
const PEAK_FRACTIONS := {"mma_kick": 0.37, "roundhouse": 0.65, "fly_kick": 0.50}

var _animator: AnimationPlayer
var _driver: PlayerExoGrayRetarget
var _ready_to_play := false
var _skeleton: Skeleton3D
var _exo_model: Node3D
var _roll_actor: CharacterBody3D
var _roll_active := false
var _roll_lift := 0.0

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
	# Bake short, impact-aligned previews once. Gameplay hit markers stay on
	# the hidden source rig and are never driven by this visible animation.
	for strike_name in PEAK_FRACTIONS:
		var original := library.get_animation(StringName(strike_name))
		var strike := _bake_strike(original, float(PEAK_FRACTIONS[strike_name]))
		if strike == null or library.add_animation(StringName(strike_name + "_combat"), strike) != OK:
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
	_skeleton = skeleton
	_exo_model = exo_model
	_roll_actor = exo_model.get_parent().get_parent() as CharacterBody3D
	_ready_to_play = true
	set_process(false)
	return true

func _bake_strike(source: Animation, peak_fraction: float) -> Animation:
	if source == null:
		return null
	var clip := Animation.new()
	clip.length = STRIKE_LENGTH
	clip.step = 1.0 / 60.0
	clip.loop_mode = Animation.LOOP_NONE
	# Impact is at the *actual* damage boundary, not at a late source-frame.
	# Fast follow-up attacks at 5 Hz still show the kick at t=0.12 s.
	var times := [0.0, 0.04, 0.08, STRIKE_CONTACT, 0.20, 0.27, STRIKE_LENGTH]
	var fractions := [0.0, 0.09, peak_fraction * 0.55, peak_fraction,
		lerpf(peak_fraction, 1.0, 0.55), 1.0, 0.0]
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

func play_strike(name: String) -> bool:
	if not PEAK_FRACTIONS.has(name):
		return false
	return play_clip(name + "_combat", STRIKE_LENGTH)

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
