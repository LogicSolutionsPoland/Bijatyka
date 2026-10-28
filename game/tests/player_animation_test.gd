extends SceneTree

const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const EXPECTED_SOURCE_CLIPS := ["Idle_Loop", "Walk_Loop", "Sprint_Loop", "Jump_Loop", "Spell_Simple_Shoot"]

var failures: Array[String] = []
var checks := 0
var connected_hits: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := Player.new() as FoundationPlayer
	root.add_child(player)
	player.set_physics_process(false)
	_check(player._animation_player.current_animation == "Idle", "player starts its idle animation immediately")
	var ready_skeleton := player._skeleton as Skeleton3D
	_check(_bone_world(ready_skeleton, "hand_l").y < _bone_world(ready_skeleton, "upperarm_l").y - 0.20
		and _bone_world(ready_skeleton, "hand_r").y < _bone_world(ready_skeleton, "upperarm_r").y - 0.20,
		"player is not displayed in the imported T-pose")
	await process_frame
	_check(player._fight_animations_ready, "player combat clips install on the imported rig")
	_check(player._ring_animations_ready, "all ring reference clips install exclusively on the player rig")
	if not player._fight_animations_ready:
		_finish(player, null)
		return

	var animator := player._animation_player as AnimationPlayer
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skeleton := player._skeleton as Skeleton3D
	_check(skeleton.get_bone_count() == 65, "imported player rig contains 65 bones")
	for clip_name in EXPECTED_SOURCE_CLIPS:
		_check(animator.has_animation(clip_name), "imported player clip exists: %s" % clip_name)
	_check_ring_bank(player)
	for kind in ["punch", "kick"]:
		for side in ["left", "right"]:
			_check_contact_pose(player, kind, side)
			await _check_hit_timing(player, kind, side)
			_check_repeated_strikes(player, kind, side)

	_check_attack_priority(player)
	_check_cinematic_chain(player)
	_check_airborne_strikes(player)

	_check_locomotion_does_not_restart(animator, player)
	for action in ["jump", "dash", "attack_punch", "attack_kick", "pad_jump", "pad_dash", "pad_punch_left", "pad_blast", "pad_kick_left", "pad_kick_right"]:
		_check(InputMap.has_action(action), "existing input action remains present: %s" % action)

	_finish(player, null)

func _check_ring_bank(player: FoundationPlayer) -> void:
	var animator := player._animation_player as AnimationPlayer
	var all_names: Array = Player.PLAYER_RING_REFERENCE.CLIP_NAMES
	_check(all_names.size() == 20, "reference animation bank includes 20 reusable player clips")
	_check(animator.has_animation(Player.PLAYER_RING_REFERENCE.clip_path("grapple_reach")), "grapple reach player clip installed")
	_check(is_equal_approx(Player.TARGET_MELEE_CYCLE_SECONDS, 0.5), "maximum attack cadence is two strikes per second")
	for raw_name in all_names:
		var name := String(raw_name)
		var path := Player.PLAYER_RING_REFERENCE.clip_path(name)
		_check(animator.has_animation(path), "player ring library includes %s" % name)
		if not animator.has_animation(path):
			continue
		var clip := animator.get_animation(path)
		_check(clip.get_track_count() >= 3, "ring clip %s drives an actual skeleton" % name)
		if name not in ["duck", "slip_left", "slip_right", "pivot_left", "pivot_right"]:
			var kind := "kick" if "kick" in name else "punch"
			_check(is_equal_approx(clip.get_marker_time(&"contact"), float(Player.ATTACKS[kind].windup)), "ring clip %s contact matches damage timing" % name)
	# Enemy visuals must never have the player-only library.
	var enemy := Enemy.new() as FoundationEnemy
	root.add_child(enemy)
	enemy.set_physics_process(false)
	_check(enemy._animation_player == null or not enemy._animation_player.has_animation(Player.PLAYER_RING_REFERENCE.clip_path("left_hook")), "ordinary zombie never gets player reference clips")
	enemy.queue_free()


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
	animator.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	var suffix := "l" if side == "left" else "r"
	var support_suffix := "r" if side == "left" else "l"
	var planted_foot := _bone_world(skeleton, "foot_" + support_suffix)
	_check_guard(skeleton, "%s %s start" % [side, kind])
	animator.seek(contact_time, true)
	skeleton.force_update_all_bone_transforms()
	var forward := -player.global_transform.basis.z
	if kind == "punch":
		var strike_vector := _bone_world(skeleton, "hand_" + suffix) - _bone_world(skeleton, "upperarm_" + suffix)
		_check(strike_vector.dot(forward) > 0.40, "%s punch fist extends in front of the player at contact" % side)
	else:
		var active_foot := _bone_world(skeleton, "foot_" + suffix)
		var support_foot := _bone_world(skeleton, "foot_" + support_suffix)
		_check((active_foot - support_foot).dot(forward) > 0.50, "%s kick extends forward at contact" % side)
		_check(active_foot.y - player.global_position.y > 0.60, "%s kick reaches the opponent's body" % side)
		_check(support_foot.distance_to(planted_foot) < 0.01, "%s kick keeps the supporting foot planted" % side)
	animator.seek(animation.length, true)
	skeleton.force_update_all_bone_transforms()
	_check_guard(skeleton, "%s %s recovery" % [side, kind])

func _bone_world(skeleton: Skeleton3D, bone_name: String) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(bone_name)).origin)

func _check_guard(skeleton: Skeleton3D, label: String) -> void:
	var left := _bone_world(skeleton, "hand_l")
	var right := _bone_world(skeleton, "hand_r")
	_check(left.distance_to(right) < 0.65, "%s holds a guard instead of the old T-pose" % label)

func _check_hit_timing(player: FoundationPlayer, kind: String, side: String) -> void:
	var animator := player._animation_player as AnimationPlayer
	var enemy := Enemy.new() as FoundationEnemy
	enemy.starting_health = 100
	root.add_child(enemy)
	enemy.set_physics_process(false)
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	enemy.global_position = Vector3(0.0, 0.0, -1.0)
	await process_frame
	connected_hits.clear()
	if not player.attack_connected.is_connected(_on_attack_connected):
		player.attack_connected.connect(_on_attack_connected)
	var starting_health := enemy.hp
	var hit_time := float(Player.ATTACKS[kind].windup)
	player._finish_attack()
	_check(player.request_attack(kind, side), "%s %s attack starts through its existing input path" % [side, kind])
	if player.attack_phase == "grapple":
		_check(player._engagement_target == enemy, "cinematic grapple picks the nearest ordinary zombie")
		_check(enemy._player_grapple_owner == player, "victim is held while player reaches for a grab")
		animator.advance(Player.CHAIN_GRAB_SECONDS)
		player._update_attack(Player.CHAIN_GRAB_SECONDS)
	var active_clip := player._active_attack_clip
	_check(String(active_clip).begins_with("player_ring_reference/") and player._animation_player.current_animation == active_clip, "%s %s selects a player-only ring clip" % [side, kind])
	_check(is_equal_approx(player._animation_player.get_animation(active_clip).get_marker_time(&"contact"), hit_time), "%s %s variant retains gameplay contact marker" % [side, kind])
	player._animation_player.advance(hit_time - 0.01)
	player._update_attack(hit_time - 0.01)
	_check(enemy.hp == starting_health, "%s %s cannot damage before visual contact" % [side, kind])
	player._animation_player.advance(0.01)
	player._update_attack(0.01)
	_check(player.attack_phase == "active", "%s %s enters active state on the existing windup boundary" % [side, kind])
	_check(enemy.hp == starting_health - int(Player.ATTACKS[kind].damage), "%s %s gameplay damage resolves on that boundary" % [side, kind])
	_check(connected_hits.has(kind), "%s %s hit event is emitted on the visual contact marker" % [side, kind])
	_check(is_equal_approx(player._animation_player.current_animation_position, hit_time), "%s %s playback reaches contact with damage" % [side, kind])
	player._update_attack(float(Player.ATTACKS[kind].active))
	_check(connected_hits.size() == 1, "%s %s applies damage only once" % [side, kind])
	player._finish_attack()
	enemy.queue_free()
	await process_frame

func _check_repeated_strikes(player: FoundationPlayer, kind: String, side: String) -> void:
	var animator := player._animation_player
	var count_before := player.attack_count
	var observed: Dictionary = {}
	for strike in range(5):
		_check(player.request_attack(kind, side), "%s %s repeat %d starts" % [side, kind, strike])
		observed[String(animator.current_animation)] = true
		_check(is_zero_approx(animator.current_animation_position), "%s %s repeat %d restarts its windup" % [side, kind, strike])
		animator.advance(float(Player.ATTACKS[kind].windup))
		player._update_attack(float(Player.ATTACKS[kind].windup))
		animator.advance(float(Player.ATTACKS[kind].active))
		player._update_attack(float(Player.ATTACKS[kind].active))
	_check(player.attack_count == count_before + 5, "%s %s retains five sequential strikes at a two-per-second cadence" % [side, kind])
	_check(observed.size() == 3, "%s %s cycles distinct ring variants" % [side, kind])
	player._finish_attack()
	# Buffered repeats also need a new animation, even without a ready frame.
	player.request_attack(kind, side)
	player.request_attack(kind, side)
	animator.advance(float(Player.ATTACKS[kind].windup))
	player._update_attack(float(Player.ATTACKS[kind].windup))
	animator.advance(float(Player.ATTACKS[kind].active))
	player._update_attack(float(Player.ATTACKS[kind].active))
	_check(player.attack_phase == "windup" and is_zero_approx(animator.current_animation_position), "%s %s buffered repeat restarts visibly" % [side, kind])
	player._finish_attack()

func _check_attack_priority(player: FoundationPlayer) -> void:
	player._play_character_action("Landing", 0.55)
	player.request_attack("punch", "right")
	var clip := player._active_attack_clip
	_check(is_zero_approx(player._character_action_time), "accepted melee clears the old action's locomotion lock")
	player._animation_player.advance(0.04)
	Input.action_press("move_left")
	player._update_movement(1.0 / 60.0)
	Input.action_release("move_left")
	_check(player._animation_player.current_animation == clip, "turning while attacking cannot replace the punch")
	player._play_character_action("Landing", 0.55)
	_check(player._animation_player.current_animation == clip, "landing while attacking cannot replace the punch")
	player.interrupt_by_zombie()
	_check(player._animation_player.current_animation == Player.CHARACTER_MOTION.clip_path("Hit"), "real enemy interruption still plays a hit reaction")
	player._finish_attack()
	player._character_action_time = 0.0

func _check_cinematic_chain(player: FoundationPlayer) -> void:
	var first := Enemy.new() as FoundationEnemy
	var second := Enemy.new() as FoundationEnemy
	first.starting_health = 100
	second.starting_health = 100
	root.add_child(first)
	root.add_child(second)
	first.set_physics_process(false)
	second.set_physics_process(false)
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	first.global_position = Vector3(0.0, 0.0, -1.1)
	second.global_position = Vector3(0.0, 0.0, -3.5)
	player._previous_engagement_target = null
	player._finish_attack()
	_check(player.request_attack("punch", "right"), "chain first strike accepted")
	_check(player.attack_phase == "grapple" and player._engagement_target == first, "first nearby zombie is grabbed before hitting")
	_check(first._player_grapple_owner == player and second._player_grapple_owner == null, "only the first victim is held")
	player._animation_player.advance(Player.CHAIN_GRAB_SECONDS)
	player._update_attack(Player.CHAIN_GRAB_SECONDS)
	_check(player.attack_phase == "windup", "reaching motion transitions into strike")
	player._animation_player.advance(float(Player.ATTACKS["punch"].windup))
	player._update_attack(float(Player.ATTACKS["punch"].windup))
	_check(first.hp == first.starting_health - int(Player.ATTACKS["punch"].damage), "grabbed zombie receives damage at animated contact")
	player.request_attack("punch", "left")
	player._animation_player.advance(float(Player.ATTACKS["punch"].active))
	player._update_attack(float(Player.ATTACKS["punch"].active))
	_check(player.attack_phase == "approach" and player._engagement_target == second, "buffered attack chooses another zombie")
	_check(player._animation_player.current_animation == Player.PLAYER_RING_REFERENCE.clip_path("slip_left"), "approach uses a dedicated ring dodge pose")
	var before := player.global_position
	player._update_movement(1.0 / 60.0)
	_check(player.velocity.z < 0.0 and player.global_position == before, "chain hop uses collision-aware velocity, not a teleport")
	player.global_position = Vector3(0.0, 0.0, -2.2)
	player._update_attack(1.0 / 60.0)
	_check(player.attack_phase == "grapple" and player._engagement_target == second, "reaching the next zombie starts another grapple")
	player._finish_attack()
	player.velocity = Vector3.ZERO
	player._previous_engagement_target = null
	first.queue_free()
	second.queue_free()

func _check_airborne_strikes(player: FoundationPlayer) -> void:
	for kind in ["punch", "kick"]:
		player._finish_attack()
		player.velocity = Vector3(0.0, 4.0, 0.0)
		_check(player.request_attack(kind, "left"), "%s accepted during jump" % kind)
		_check(player.attack_phase == "windup" and player._engagement_target == null,
			"%s starts without a ground grapple during jump" % kind)
		var expected := "left_airborne_punch" if kind == "punch" else "airborne_kick"
		_check(player._active_attack_clip == Player.PLAYER_RING_REFERENCE.clip_path(expected),
			"%s selects its airborne animation" % kind)
	player._finish_attack()
	player.velocity = Vector3.ZERO


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
