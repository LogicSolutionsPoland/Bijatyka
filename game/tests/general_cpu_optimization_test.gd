extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Horde := preload("res://scripts/horde_far_visuals.gd")
const Cache := preload("res://scripts/enemy_rig_animation_cache.gd")
const Visibility := preload("res://scripts/flashlight_visibility.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_rig_transfers()
	_test_flashlight_updates()
	await process_frame
	if failures.is_empty():
		print("PASS: general CPU optimization (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _test_rig_transfers() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var pool := Horde.new()
	pool.configure(20)
	fixture.add_child(pool)
	pool.set_process(false)
	var actors: Array[FoundationEnemy] = []
	for kind in ["shambler", "brute", "stalker"]:
		var enemy := Enemy.new()
		enemy.configure(kind)
		fixture.add_child(enemy)
		enemy.set_physics_process(false)
		pool.register_enemy(enemy)
		actors.append(enemy)
	var before := Cache.get_stats()
	var libraries: Dictionary = {}
	var motion: AnimationLibrary
	var model: Node3D
	for cycle in range(12):
		var enemy := actors[cycle % actors.size()]
		enemy._set_full_animation_selected(true)
		_check(enemy._model != null and enemy._fight_animations_ready, "transfer %d prepares attacks" % cycle)
		var animator := enemy._animation_player
		var library := animator.get_animation_library(&"enemy_combat")
		if cycle == 0:
			model = enemy._model
			motion = animator.get_animation_library(&"universal_base_actions")
		_check(enemy._model == model, "transfers keep the same pooled model")
		_check(animator.get_animation_library(&"universal_base_actions") == motion, "transfers retain locomotion and death resources")
		if libraries.has(enemy.enemy_variant):
			_check(libraries[enemy.enemy_variant] == library, "returning variant retains its exact combat library")
		else:
			libraries[enemy.enemy_variant] = library
		var profile: Dictionary = enemy._fight_attack_profiles().punch
		for side in ["left", "right"]:
			for kind in ["punch", "kick"]:
				var clip := library.get_animation(StringName(side + "_" + kind))
				_check(is_equal_approx(clip.get_marker_time(&"contact"), profile.windup), "cached %s %s %s preserves contact" % [enemy.enemy_variant, side, kind])
				_check(is_equal_approx(clip.length, profile.windup + profile.active + profile.recovery), "cached clip preserves total duration")
		var connections := animator.animation_finished.get_connections()
		_check(connections.size() == 1 and connections[0].callable.get_object() == enemy, "completion belongs only to the current actor")
		enemy._set_full_animation_selected(false)
		_check(animator.animation_finished.get_connections().is_empty() and not animator.is_playing(), "release clears playback and old completion handler")
	var after := Cache.get_stats()
	_check(after.motion_builds - before.motion_builds == 1, "one motion build across 12 model transfers")
	_check(after.combat_builds - before.combat_builds == 3, "one combat build per ordinary timing variant")
	_check(after.combat_reuses - before.combat_reuses == 9, "all warmed transfers reuse prepared clips")
	_check(pool.get_rig_pool_stats().created == 1, "cache does not increase the resident model count")
	_check(libraries.shambler != libraries.brute and libraries.brute != libraries.stalker, "different timing variants retain separate libraries")

	var actor := actors[0]
	actor._set_full_animation_selected(true)
	var skeleton := actor._skeleton
	var animator := actor._animation_player
	var bone := skeleton.find_bone("spine_02")
	var changed_rest := skeleton.get_bone_rest(bone)
	changed_rest.origin.y += 0.01
	skeleton.set_bone_rest(bone, changed_rest)
	actor._set_full_animation_selected(false)
	actor._set_full_animation_selected(true)
	_check(animator.get_animation_library(&"universal_base_actions") != motion, "rest edit invalidates motion and combat cache")
	var previous_combat := animator.get_animation_library(&"enemy_combat")
	var default_library := animator.get_animation_library(&"")
	var replacement := default_library.get_animation(&"Punch_Jab").duplicate(true) as Animation
	default_library.remove_animation(&"Punch_Jab")
	default_library.add_animation(&"Punch_Jab", replacement)
	actor._set_full_animation_selected(false)
	actor._set_full_animation_selected(true)
	_check(animator.get_animation_library(&"enemy_combat") != previous_combat, "replacing a source animation invalidates prepared attacks")
	actor._set_full_animation_selected(false)
	for index in range(6):
		actor.telegraph_duration = 0.8 + float(index) * 0.1
		actor._set_full_animation_selected(true)
		var cache: Dictionary = model.get_meta(Cache.CACHE_META)
		_check(cache.profiles.size() <= Cache.MAX_PROFILES, "custom timing profiles have a bounded cache")
		var clip := actor._animation_player.get_animation(&"enemy_combat/left_punch")
		_check(is_equal_approx(clip.get_marker_time(&"contact"), actor.telegraph_duration * 0.55), "custom timing uses its own contact marker")
		actor._set_full_animation_selected(false)
	fixture.queue_free()

func _test_flashlight_updates() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Node3D.new()
	fixture.add_child(player)
	var camera := Camera3D.new()
	fixture.add_child(camera)
	var manager := Visibility.new()
	manager.configure(player, camera, true)
	fixture.add_child(manager)
	manager.set_process(false)
	var before := manager.get_parameter_update_stats()
	for index in range(120):
		manager.set_aim_yaw(0.0)
		manager._process(1.0 / 60.0)
	var after := manager.get_parameter_update_stats()
	_check(after == before, "stationary camera submits no duplicate transforms or uniforms")
	for index in range(1, 61):
		player.position.x = float(index) * 0.05
		var yaw := float(index) * 0.01
		manager.set_aim_yaw(yaw)
		manager.set_aim_yaw(yaw)
		manager._process(1.0 / 60.0)
		_check(manager.beam_origin.is_equal_approx(player.global_position + Vector3.UP * Visibility.BEAM_HEIGHT), "movement updates the physical 3D beam in the same frame")
		_check((-manager.spotlight.global_basis.z).is_equal_approx(manager.beam_direction), "yaw rotates the physical 3D beam in the same frame")
	after = manager.get_parameter_update_stats()
	_check(after.updates - before.updates == 60, "three callers submit only 60 distinct moving states")
	_check(after.uniform_writes == before.uniform_writes and manager._material == null, "moving 3D beam never submits deleted screen-mask shader uniforms")
	before = after
	camera.rotation.x = -0.3
	manager.set_aim_yaw(0.6)
	_check(manager.beam_direction.y < -0.2, "pitch updates even when yaw is unchanged")
	_check(manager.get_parameter_update_stats().uniform_writes == before.uniform_writes, "pitch-only change cannot introduce fullscreen mask uniforms")
	player.rotation.y = 1.2
	manager._process(1.0 / 60.0)
	_check((-manager.spotlight.global_basis.z).is_equal_approx(manager.beam_direction), "parent rotation cannot turn spotlight away from camera")
	manager.set_rooftop_sky_visible(true)
	_check(not manager.spotlight.visible and manager._composite == null, "rooftop hides the 3D flashlight without reintroducing blackout")
	player.position.z = 2.0
	manager.set_rooftop_sky_visible(false)
	_check(manager.spotlight.visible and manager._composite == null, "ground restores 3D flashlight only; no fullscreen composite")
	_check(manager.beam_origin.is_equal_approx(player.global_position + Vector3.UP * Visibility.BEAM_HEIGHT), "ground restores current beam position immediately")
	fixture.queue_free()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
