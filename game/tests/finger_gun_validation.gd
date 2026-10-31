extends SceneTree

## Validates the serialized animation against the real Exo Gray GLB at runtime.
const PLAYER := preload("res://scripts/player_controller.gd")
const ANIM := &"finger_gun/Finger_Gun_Shoot"
const RESOURCE := "res://assets/characters/exo_gray/animations/Finger_Gun_Shoot.res"
const EVENT := 0.30
var checks := 0
var failures: Array[String] = []
var fire_events := 0
var emitted_transform := Transform3D.IDENTITY

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PLAYER.new() as FoundationPlayer
	root.add_child(player)
	player.set_physics_process(false)
	var model := player._exo_visual_model as Node3D
	var target := player._exo_retarget.target_skeleton as Skeleton3D if player._exo_retarget != null else null
	var overlay := player._exo_overlay as PlayerExoMixamoOverlay
	_check(model != null and target != null and overlay != null, "real Exo player, skeleton and animator exist")
	if target == null or overlay == null:
		_finish(player)
		return
	var animator := overlay._animator as AnimationPlayer
	_check(ResourceLoader.exists(RESOURCE), "dedicated binary .res exists")
	_check(animator != null and animator.has_animation(ANIM), "animation is registered in the existing Exo AnimationPlayer")
	if animator == null or not animator.has_animation(ANIM):
		_finish(player)
		return
	var clip := animator.get_animation(ANIM)
	var source := player._animation_player.get_animation(&"Punch_Cross")
	_check(is_equal_approx(clip.length, source.length), "source punch playback duration is unchanged")
	_check(clip.loop_mode == Animation.LOOP_NONE and clip.length > EVENT, "animation has natural one-shot timing")
	_check(clip.has_marker(&"fire") and is_equal_approx(clip.get_marker_time(&"fire"), EVENT), "precise fire frame marked")
	var seen: Dictionary = {}
	var method_track := -1
	for t in range(clip.get_track_count()):
		var path := clip.track_get_path(t)
		if clip.track_get_type(t) == Animation.TYPE_METHOD:
			method_track = t
			_check(str(path) == "FingerGunFireEvent", "method event points at real relay")
			continue
		if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			_check(false, "unexpected track type")
			continue
		var bone := String(path.get_subname(0)) if path.get_subname_count() == 1 else ""
		_check(target.find_bone(bone) >= 0, "animated Exo bone exists: " + bone)
		_check(model.get_node_or_null(NodePath(path.get_concatenated_names())) == target,
			"track targets active Exo Skeleton3D: " + bone)
		seen[bone] = t
		_check(clip.track_get_key_count(t) > 8, "baked motion includes interpolation keys for " + bone)
	for name in ["RightHandIndex1", "RightHandIndex2", "RightHandIndex3",
		"RightHandThumb1", "RightHandThumb2", "RightHandThumb3",
		"RightHandMiddle1", "RightHandRing1", "RightHandPinky1",
		"RightArm", "RightForeArm", "RightHand", "Spine2"]:
		_check(seen.has(name), "explicit fingertip/arm/body track: " + name)
	_check(method_track >= 0 and clip.track_get_key_count(method_track) == 1, "single fire method event")
	if method_track >= 0:
		_check(is_equal_approx(clip.track_get_key_time(method_track, 0), EVENT), "event occurs at authored fire time")
		_check(String((clip.track_get_key_value(method_track, 0) as Dictionary).get("method", "")) == "emit_fire", "event method is named correctly")
	var marker := target.get_node_or_null("FingerGunIndexTip/FingerGunMuzzle") as Marker3D
	var attachment := target.get_node_or_null("FingerGunIndexTip") as BoneAttachment3D
	_check(marker != null and attachment != null and attachment.bone_name == "RightHandIndex3",
		"muzzle follows the real index fingertip bone")
	var relay := model.get_node_or_null("FingerGunFireEvent") as FingerGunFireEvent
	_check(relay != null, "future spell event relay is available")
	if relay != null:
		relay.fired.connect(_on_fired)
	# Compare baked motion: the curled middle finger must be distinct at firing.
	if seen.has("RightHandMiddle2") and seen.has("RightHandIndex2"):
		var middle := int(seen["RightHandMiddle2"])
		var index := int(seen["RightHandIndex2"])
		_check(clip.rotation_track_interpolate(middle, EVENT).angle_to(
			clip.rotation_track_interpolate(middle, 0.0)) > 0.40, "middle finger curls while firing")
		_check(clip.rotation_track_interpolate(index, EVENT).angle_to(
			clip.rotation_track_interpolate(index, 0.0)) < 0.35, "index remains approximately straight")
	_check(clip.rotation_track_interpolate(int(seen.get("RightArm", 0)), EVENT).angle_to(
		clip.rotation_track_interpolate(int(seen.get("RightArm", 0)), 0.0)) > 0.08,
		"original punch arm extension survives conversion")
	var actor_transform := player.global_transform
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	player._exo_retarget.set_process(false)
	animator.play(ANIM, 0.0, 1.0)
	animator.seek(0.0, true)
	animator.advance(EVENT + 0.012)
	await process_frame
	_check(fire_events == 1, "exactly one firing signal emitted on forward playback")
	if marker != null and fire_events == 1:
		_check(emitted_transform.origin.distance_to(marker.global_position) < 0.15,
			"firing world origin matches animated index fingertip")
	animator.seek(clip.length, true)
	animator.stop()
	player._exo_retarget.set_process(true)
	_check(player.global_transform.is_equal_approx(actor_transform), "no player root motion or physics change")
	for side in ["left", "right"]:
		_check(player._animation_player.has_animation(player.FIGHT_ANIMATION_BUILDER.clip_path("punch", side)),
			"original physical punch remains intact: " + side)
	_finish(player)

func _on_fired(transform: Transform3D) -> void:
	fire_events += 1
	emitted_transform = transform

func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures.append(detail)

func _finish(player: Node) -> void:
	player.queue_free()
	if failures.is_empty():
		print("PASS: Finger Gun Shoot Exo rig, event and punch regression (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("FINGER_GUN_VALIDATION_FAILED: " + failure)
		print("FAIL: Finger Gun Shoot (%d/%d checks failed)" % [failures.size(), checks])
		quit(1)
