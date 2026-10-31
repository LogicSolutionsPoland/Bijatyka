extends Node
class_name PlayerExoMixamoOverlay

## Optional, Exo-only visual animations. The hidden Universal Base rig and all
## combat physics/timers keep running; these animations never move the player.
## Animations are pre-retargeted and quantized offline from the user's FBX files.
const DATA := preload("res://scripts/exo_mixamo_data.gd")
const LIBRARY_NAME := &"exo_mixamo"
const BLEND_SECONDS := 0.06

var _animator: AnimationPlayer
var _driver: PlayerExoGrayRetarget
var _ready_to_play := false

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
	return true

func play_clip(name: String, requested_duration: float = 0.0) -> bool:
	if not _ready_to_play or not is_instance_valid(_animator):
		return false
	var key := StringName("%s/%s" % [String(LIBRARY_NAME), name])
	if not _animator.has_animation(key):
		return false
	var duration := _animator.get_animation(key).length
	var playback_speed := duration / requested_duration if requested_duration > 0.05 else 1.0
	_driver.set_process(false)
	_animator.play(key, BLEND_SECONDS, playback_speed)
	_animator.advance(0.0)
	return true

func stop_clip() -> void:
	if not _ready_to_play:
		return
	_animator.stop()
	_resume_driver()

func _on_animation_finished(_name: StringName) -> void:
	_resume_driver()

func _resume_driver() -> void:
	if is_instance_valid(_driver):
		_driver.set_process(true)
		_driver.synchronize_pose()
