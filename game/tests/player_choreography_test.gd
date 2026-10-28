extends SceneTree

const PLAYER := preload("res://scripts/player_controller.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const CHOREOGRAPHY := preload("res://scripts/player_choreography.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PLAYER.new() as FoundationPlayer
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame

	_check(player._skeleton != null and player._skeleton.get_bone_count() == 65, "using the existing 65-bone player, not a substitute rig")
	_check(player._ring_animations_ready, "player ring clips are ready before the rehearsal")
	_check(not player._choreography_ready, "large preview is baked lazily, not on Android gameplay startup")
	_check(player.play_choreography_preview(), "the existing player can start its choreography")
	var animator := player._animation_player as AnimationPlayer
	var path := CHOREOGRAPHY.clip_path()
	_check(animator.has_animation(path), "rehearsal installed on the real player's AnimationPlayer")
	_check(animator.current_animation == path, "ten-second choreography is visibly selected for playback")
	if not animator.has_animation(path):
		_finish(player)
		return
	var clip := animator.get_animation(path)
	_check(is_equal_approx(clip.length, 10.0), "rehearsal lasts exactly ten seconds")
	_check(clip.get_track_count() >= 30, "clip contains actual imported skeleton tracks")
	_check(clip.track_get_key_count(0) >= 300, "baked 30fps keyframes cover the full timeline")
	_check(CHOREOGRAPHY.PHRASES.size() >= 12, "reference pose sheet is expanded into a full combat sequence")
	var bones_seen: Dictionary = {}
	for track in range(clip.get_track_count()):
		var track_path := clip.track_get_path(track)
		if track_path.get_subname_count() == 1:
			bones_seen[String(track_path.get_subname(0))] = true
	for bone_name in ["pelvis", "spine_03", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r"]:
		_check(bones_seen.has(bone_name), "choreography animates the real %s bone" % bone_name)

	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var pose_signatures: Dictionary = {}
	for time in [0.2, 1.38, 2.40, 3.05, 3.69, 4.25, 5.50, 6.16, 7.39, 8.04, 8.91, 9.72]:
		animator.seek(float(time), true)
		player._skeleton.force_update_all_bone_transforms()
		var skeleton := player._skeleton as Skeleton3D
		var l := skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin
		var r := skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin
		var foot := skeleton.get_bone_global_pose(skeleton.find_bone("foot_l")).origin
		var signature := "%d|%d|%d|%d|%d" % [roundi(l.x * 10.0), roundi(l.y * 10.0), roundi(r.x * 10.0), roundi(r.y * 10.0), roundi(foot.y * 10.0)]
		pose_signatures[signature] = true
		print("CHOREOGRAPHY_DIAG t=%.2f sig=%s hand_l=%s hand_r=%s playing=%s" % [time, signature, l, r, animator.current_animation])
	_check(pose_signatures.size() >= 6, "time samples produce distinct combat poses rather than a static rig")
	_check(player.attack_phase == "ready" and player.attack_count == 0, "preview does not apply game damage or alter melee cadence")

	var enemy := ENEMY.new() as FoundationEnemy
	root.add_child(enemy)
	enemy.set_physics_process(false)
	_check(enemy._animation_player == null or not enemy._animation_player.has_animation(path), "enemy and boss never get this player-only clip")
	enemy.queue_free()
	_finish(player)

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func _finish(player: Node) -> void:
	if is_instance_valid(player):
		player.queue_free()
	if failures.is_empty():
		print("PASS: ten-second player choreography (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d player choreography checks" % [failures.size(), checks])
		quit(1)
