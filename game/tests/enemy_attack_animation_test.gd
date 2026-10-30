extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Foundation := preload("res://scripts/foundation.gd")
const VARIANTS := ["shambler", "brute", "stalker", "boss"]
const HEADINGS := [0.0, PI * 0.5, PI]

var failures: Array[String] = []
var checks := 0
var resolved_hits := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(Foundation.ZOMBIE_HORDE_SIZE == 4, "rooftop ordinary population contains four dormant entries")
	for variant in VARIANTS:
		var enemy := Enemy.new() as FoundationEnemy
		enemy.configure(variant)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy._set_full_animation_selected(true)
		_check(enemy._model != null and enemy._skeleton != null and enemy._fight_animations_ready, "%s imports a detailed combat rig" % variant)
		if not enemy._fight_animations_ready:
			enemy.queue_free()
			continue
		_check(enemy._animation_player.current_animation == "Idle", "%s starts its idle pose immediately" % variant)
		var skeleton := enemy._skeleton as Skeleton3D
		_check(_bone(skeleton, "hand_l").y < _bone(skeleton, "upperarm_l").y - 0.20
			and _bone(skeleton, "hand_r").y < _bone(skeleton, "upperarm_r").y - 0.20,
			"%s is not displayed in the imported T-pose" % variant)
		for child in enemy._visual_root.get_children():
			if child is MeshInstance3D:
				_check(not (child as MeshInstance3D).mesh is BoxMesh, "%s has no box over the animated torso" % variant)
		var expected_path := Enemy.BOSS_MODEL_PATH if variant == "boss" else Enemy.ENEMY_MODEL_PATH
		_check(enemy._model.scene_file_path == expected_path, "%s uses the specified male/female model" % variant)
		var animator := enemy._animation_player as AnimationPlayer
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var side_target := Node3D.new()
		root.add_child(side_target)
		for yaw in HEADINGS:
			enemy.rotation.y = yaw
			for side in ["left", "right"]:
				var side_offset := -0.5 if side == "left" else 0.5
				side_target.global_position = enemy.global_position + enemy.global_basis * Vector3(side_offset, 0.0, -enemy.attack_range * 0.82)
				_check(enemy._select_attack_animation(side_target, enemy.attack_range * 0.82).begins_with("enemy_combat/" + side + "_"), "%s yaw %.2f selects target's %s side" % [variant, yaw, side])
			for kind in ["punch", "kick"]:
				for side in ["left", "right"]:
					_check_pose(enemy, kind, side, yaw)
		await _check_playback(enemy)
		side_target.queue_free()
		enemy.queue_free()
		await process_frame
	if failures.is_empty():
		print("PASS: enemy attack animation (%d checks; male variants, female boss)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d enemy attack animation checks failed" % [failures.size(), checks])
		quit(1)

func _check_pose(enemy: FoundationEnemy, kind: String, side: String, yaw: float) -> void:
	var animator := enemy._animation_player as AnimationPlayer
	var skeleton := enemy._skeleton as Skeleton3D
	var label := "%s %s %s yaw %.2f" % [enemy.enemy_variant, side, kind, yaw]
	var path := Enemy.FIGHT_ANIMATION_BUILDER.clip_path(kind, side)
	_check(animator.has_animation(path), "%s clip is installed" % label)
	if not animator.has_animation(path):
		return
	var animation := animator.get_animation(path)
	var profile: Dictionary = enemy._fight_attack_profiles()[kind]
	var contact := float(profile.windup)
	_check(is_equal_approx(animation.get_marker_time(&"contact"), contact), "%s marker matches gameplay contact" % label)
	_check(is_equal_approx(animation.length, contact + float(profile.active) + float(profile.recovery)), "%s duration matches existing timing" % label)
	animator.play(path, 0.0)
	animator.seek(0.0, true)
	skeleton.force_update_all_bone_transforms()
	var start_hand := _bone(skeleton, "hand_l" if side == "left" else "hand_r")
	var support_name := "foot_r" if side == "left" else "foot_l"
	var support_start := _bone(skeleton, support_name)
	_check(_guarded(skeleton), "%s begins from combat guard" % label)
	animator.seek(contact, true)
	skeleton.force_update_all_bone_transforms()
	var forward := -enemy.global_basis.z
	var suffix := "l" if side == "left" else "r"
	if kind == "punch":
		var hand := _bone(skeleton, "hand_" + suffix)
		var upperarm := _bone(skeleton, "upperarm_" + suffix)
		_check((hand - upperarm).dot(forward) > 0.35, "%s fist extends toward target" % label)
		_check((hand - start_hand).dot(forward) > 0.28, "%s fist visibly travels toward contact" % label)
	else:
		var foot := _bone(skeleton, "foot_" + suffix)
		var support := _bone(skeleton, support_name)
		_check((foot - support).dot(forward) > 0.50, "%s foot reaches target" % label)
		_check(foot.y - enemy.global_position.y > 0.56, "%s kick rises above ground" % label)
		_check(support.distance_to(support_start) < 0.02, "%s supporting foot stays planted" % label)
	animator.seek(animation.length, true)
	skeleton.force_update_all_bone_transforms()
	_check(_guarded(skeleton), "%s recovers to combat guard" % label)
	_check(_bone(skeleton, support_name).distance_to(support_start) < 0.02, "%s recovers support foot position" % label)

func _check_playback(enemy: FoundationEnemy) -> void:
	var animator := enemy._animation_player as AnimationPlayer
	var victim := Enemy.new() as FoundationEnemy
	victim.configure("shambler")
	root.add_child(victim)
	victim.set_physics_process(false)
	enemy.rotation.y = 0.0
	enemy.global_position = Vector3.ZERO
	victim.global_position = Vector3(0.0, 0.0, -enemy.attack_range * 0.80)
	await physics_frame
	enemy.combat_target = victim
	enemy._player = null
	enemy.state = "windup"
	enemy.state_time = float(enemy._fight_attack_profiles()["punch"].windup)
	enemy._attack_sequence = 0
	enemy._begin_attack_animation(victim, enemy.attack_range * 0.80, enemy.state_time)
	var selected := enemy._attack_animation
	_check(selected.begins_with("enemy_combat/") and animator.current_animation == selected, "%s starts an enemy clip" % enemy.enemy_variant)
	_check(is_zero_approx(animator.current_animation_position), "%s begins at its guard frame" % enemy.enemy_variant)
	var first_time := enemy.state_time
	var health := victim.hp
	resolved_hits = 0
	enemy.attack_resolved.connect(_on_resolved)
	animator.advance(first_time - 0.01)
	enemy._update_ai(first_time - 0.01, enemy.attack_range * 0.80)
	_check(victim.hp == health and resolved_hits == 0, "%s cannot damage before visual contact" % enemy.enemy_variant)
	animator.advance(0.0101)
	enemy._update_ai(0.0101, enemy.attack_range * 0.80)
	_check(victim.hp == health - 12 and resolved_hits == 1, "%s resolves existing damage once at contact" % enemy.enemy_variant)
	_check(enemy.state == "recovery" and absf(animator.current_animation_position - enemy._attack_contact_time) < 0.01, "%s recovery begins on contact frame" % enemy.enemy_variant)
	victim.global_position = Vector3(0.0, 0.0, -enemy.attack_range - 3.0)
	enemy._update_ai(enemy.state_time + 0.001, enemy.attack_range + 3.0)
	enemy._update_ai(0.05, enemy.attack_range + 3.0)
	_check(animator.current_animation in ["Idle", "Walk", "Sprint"], "%s returns to idle or locomotion when target leaves reach" % enemy.enemy_variant)
	victim.global_position = Vector3(0.0, 0.0, -enemy.attack_range * 0.80)
	# Replaying the same clip during a second windup must reset its pose.
	# Wandering may turn the enemy randomly while the victim is out of reach.
	enemy.rotation.y = 0.0
	enemy._attack_sequence = 0
	enemy._begin_attack_animation(victim, enemy.attack_range * 0.80, first_time)
	animator.advance(0.10)
	enemy._begin_attack_animation(victim, enemy.attack_range * 0.80, first_time)
	_check(animator.current_animation == selected and is_zero_approx(animator.current_animation_position), "%s repeats same strike from frame zero" % enemy.enemy_variant)
	enemy.receive_hit(5)
	_check(animator.current_animation == "Hit_React", "%s hit interrupts its attack" % enemy.enemy_variant)
	animator.advance(0.10)
	enemy.receive_hit(5)
	_check(is_zero_approx(animator.current_animation_position), "%s repeated hit restarts reaction" % enemy.enemy_variant)
	enemy.state = "approach"
	enemy._play_animation("Walk")
	_check(animator.current_animation == "Walk", "%s returns to locomotion after hit" % enemy.enemy_variant)
	enemy.receive_hit(1000)
	_check(enemy._death_started and animator.current_animation.begins_with("Death_"), "%s death overrides locomotion" % enemy.enemy_variant)
	victim.queue_free()
	await process_frame

func _bone(skeleton: Skeleton3D, name: String) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin)

func _guarded(skeleton: Skeleton3D) -> bool:
	return _bone(skeleton, "hand_l").distance_to(_bone(skeleton, "hand_r")) < 0.65

func _on_resolved(_enemy: Node, hit: bool) -> void:
	if hit:
		resolved_hits += 1

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
