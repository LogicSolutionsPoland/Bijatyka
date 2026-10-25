extends SceneTree

const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const EXPECTED_SOURCE_CLIPS := ["Idle", "Walk", "Sprint", "Jump", "Sword_Slash"]
const FORWARD := Vector3(0.0, 0.0, -1.0)

var failures: Array[String] = []
var checks := 0
var connected_hits: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := Player.new() as FoundationPlayer
	root.add_child(player)
	await process_frame
	_check(player._fight_animations_ready, "player combat clips install on the imported rig")
	if not player._fight_animations_ready:
		_finish(player, null)
		return

	var animator := player._animation_player as AnimationPlayer
	var skeleton := player._skeleton as Skeleton3D
	_check(skeleton.get_bone_count() == 21, "imported player rig contains 21 bones")
	for clip_name in EXPECTED_SOURCE_CLIPS:
		_check(animator.has_animation(clip_name), "imported player clip exists: %s" % clip_name)
	for kind in ["punch", "kick"]:
		for side in ["left", "right"]:
			_check_contact_pose(player, kind, side)
			_check_hit_timing(player, kind, side)

	_check_locomotion_does_not_restart(animator, player)
	for action in ["jump", "dash", "attack_punch", "attack_kick", "pad_jump", "pad_dash", "pad_punch_left", "pad_blast", "pad_kick_left", "pad_kick_right"]:
		_check(InputMap.has_action(action), "existing input action remains present: %s" % action)

	_finish(player, null)

func _check_contact_pose(player: FoundationPlayer, kind: String, side: String) -> void:
	var animator := player._animation_player as AnimationPlayer
	var skeleton := player._skeleton as Skeleton3D
	var animation_path := Player.FIGHT_ANIMATION_BUILDER.clip_path(kind, side)
	_check(animator.has_animation(animation_path), "generated clip exists: %s" % animation_path)
	if not animator.has_animation(animation_path):
		return
	var animation := animator.get_animation(animation_path)
	var profile: Dictionary = Player.ATTACKS[kind]
	var contact_time := float(profile.windup)
	_check(is_equal_approx(animation.length, contact_time + float(profile.active) + float(profile.recovery)), "%s %s clip duration matches gameplay phases" % [side, kind])
	_check(is_equal_approx(animation.get_marker_time(&"contact"), contact_time), "%s %s visual contact marker matches gameplay hit time" % [side, kind])
	animator.play(animation_path, 0.0)
	animator.seek(contact_time, true)
	skeleton.force_update_all_bone_transforms()
	var limb := "Left" if side == "left" else "Right"
	if kind == "punch":
		var shoulder := skeleton.find_bone(limb + "UpperArm")
		var hand := skeleton.find_bone(limb + "Hand")
		var strike_vector := skeleton.get_bone_global_pose(hand).origin - skeleton.get_bone_global_pose(shoulder).origin
		_check(strike_vector.dot(FORWARD) > 0.18, "%s punch hand extends toward the imported -Z facing direction" % side)
	else:
		var active_foot := skeleton.find_bone(limb + "Foot")
		var support_foot := skeleton.find_bone(("Right" if side == "left" else "Left") + "Foot")
		var foot_delta := skeleton.get_bone_global_pose(active_foot).origin - skeleton.get_bone_global_pose(support_foot).origin
		_check(foot_delta.dot(FORWARD) > 0.25, "%s kick foot extends forward of the planted foot" % side)

func _check_hit_timing(player: FoundationPlayer, kind: String, side: String) -> void:
	var enemy := Enemy.new() as FoundationEnemy
	enemy.starting_health = 100
	root.add_child(enemy)
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	enemy.global_position = Vector3(0.0, 0.0, -1.0)
	await process_frame
	connected_hits.clear()
	if not player.attack_connected.is_connected(_on_attack_connected):
		player.attack_connected.connect(_on_attack_connected)
	var starting_health := enemy.hp
	var hit_time := float(Player.ATTACKS[kind].windup)
	_check(player.request_attack(kind, side), "%s %s attack starts through its existing input path" % [side, kind])
	_check(player._animation_player.current_animation == Player.FIGHT_ANIMATION_BUILDER.clip_path(kind, side), "%s %s selects its matching visual clip" % [side, kind])
	player._update_attack(hit_time)
	_check(player.attack_phase == "active", "%s %s enters active state on the existing windup boundary" % [side, kind])
	_check(enemy.hp == starting_health - int(Player.ATTACKS[kind].damage), "%s %s gameplay damage resolves on that boundary" % [side, kind])
	_check(connected_hits.has(kind), "%s %s hit event is emitted on the visual contact marker" % [side, kind])
	player._finish_attack()
	enemy.queue_free()
	await process_frame

func _check_locomotion_does_not_restart(animator: AnimationPlayer, player: FoundationPlayer) -> void:
	player._set_locomotion_animation("Idle")
	_check(animator.current_animation == "Idle", "Idle locomotion transition selects the imported clip")
	animator.advance(0.20)
	player._set_locomotion_animation("Idle")
	_check(animator.current_animation_position > 0.15, "same-state locomotion does not restart its animation each frame")
	player._set_locomotion_animation("Walk")
	_check(animator.current_animation == "Walk", "Walk transition selects the imported clip")
	animator.advance(0.05)
	var walk_position := animator.current_animation_position
	player._set_locomotion_animation("Walk")
	_check(is_equal_approx(animator.current_animation_position, walk_position), "same-state Walk request preserves playback position")
	player._set_locomotion_animation("Jump")
	_check(animator.current_animation == "Jump", "Jump transition selects the imported clip")

func _on_attack_connected(kind: String, _target: Node) -> void:
	connected_hits.append(kind)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish(player: Node, enemy: Node) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()
	if is_instance_valid(player):
		player.queue_free()
	if failures.is_empty():
		print("PASS: player martial animation (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d player animation checks failed" % [failures.size(), checks])
		quit(1)
