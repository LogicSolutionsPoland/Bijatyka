extends SceneTree
## Camera and flashlight math regression checks; render-only pixels are covered
## by flashlight_render_probe.gd under Compatibility software rendering.

const Foundation := preload("res://scripts/foundation.gd")
const VisibilityManager := preload("res://scripts/flashlight_visibility.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Foundation.new()
	root.add_child(game)
	for frame in range(8):
		await process_frame
	_check(game.flashlight_visibility_enabled, "project config enables the reversible flashlight mode")
	_check(game.flashlight_visibility_manager.enabled, "shared flashlight visibility manager is active")
	_check(game.player.global_position.distance_to(Foundation.PLAYER_BASE_POSITION) < 0.1, "player stays at the existing protected base position")
	_check(is_equal_approx(game.camera_arm.spring_length, Foundation.CAMERA_FOLLOW_DISTANCE), "raised over-shoulder follow distance remains intact")
	_check(game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "camera keeps perspective projection instead of a 180-degree lens")
	_check(is_equal_approx(game.camera.fov, Foundation.CAMERA_VERTICAL_FOV), "camera keeps the existing 66-degree perspective")

	var manager = game.flashlight_visibility_manager
	manager.set_aim_yaw(0.0)
	_check(manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, -10)), "forward point is inside the 180-degree sector")
	_check(not manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, 10)), "rear point is outside the 180-degree sector")
	_check(not manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, 31)), "visibility never extends beyond the 30 m radius")
	_check(manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, 0.3), 0.65), "sector hysteresis holds a recently visible actor near the boundary")
	_check(is_equal_approx(manager.get_radial_weight(22.0), 1.0), "illumination stays bright through 22 m")
	_check(manager.get_radial_weight(26.0) > 0.0 and manager.get_radial_weight(26.0) < 1.0, "outer 22–30 m band fades smoothly")
	_check(is_zero_approx(manager.get_radial_weight(30.0)), "illumination reaches black at 30 m")

	manager.set_aim_yaw(PI * 0.5)
	_check(manager.is_point_in_sector(game.player.global_position + Vector3(10, 0, 0)), "sector rotates immediately with camera aim yaw")
	_check(not manager.is_point_in_sector(game.player.global_position + Vector3(-10, 0, 0)), "rotated sector excludes its rear half")
	_check(manager.aim_direction.distance_to(Vector3.RIGHT) < 0.001, "aim direction has no rotation lag")
	manager.set_aim_yaw(0.0)

	# Touch camera gestures flow through the same callback used by the HUD.
	var yaw_before_touch := game._camera_yaw
	game.hud.camera_dragged.emit(Vector2(18.0, -7.0))
	_check(not is_equal_approx(game._camera_yaw, yaw_before_touch), "touch drag rotates the camera")
	_check(game.flashlight_visibility_manager.aim_direction.distance_to(Vector3(sin(game._camera_yaw), 0.0, -cos(game._camera_yaw))) < 0.001, "touch aim updates the flashlight in the same frame")

	# The same input actions used by the right stick update the camera and aim.
	var yaw_before_gamepad := game._camera_yaw
	Input.action_press("camera_right", 1.0)
	game._update_gamepad_camera(1.0 / 60.0)
	Input.action_release("camera_right")
	_check(not is_equal_approx(game._camera_yaw, yaw_before_gamepad), "gamepad camera action rotates the camera")
	_check(game.flashlight_visibility_manager.aim_direction.distance_to(Vector3(sin(game._camera_yaw), 0.0, -cos(game._camera_yaw))) < 0.001, "gamepad aim updates the flashlight")

	# Verify the light classifier feeds the shared MultiMesh queue independently
	# from AI and collision. The test scene is discarded after these placements.
	game._camera_yaw = 0.0
	game.camera_rig.rotation.y = 0.0
	manager.set_aim_yaw(0.0)
	var test_enemies: Array = game.horde_far_visuals._enemies.values()
	_check(test_enemies.size() >= 2, "ordinary zombie population is registered with the shared visibility manager")
	if test_enemies.size() >= 2:
		for enemy_variant in test_enemies:
			var enemy := enemy_variant as FoundationEnemy
			enemy.global_position = game.player.global_position + Vector3(45.0, 0.0, 0.0)
		var visible_zombie := test_enemies[0] as FoundationEnemy
		var dark_zombie := test_enemies[1] as FoundationEnemy
		visible_zombie.global_position = game.player.global_position + Vector3(0.0, 0.0, -20.0)
		dark_zombie.global_position = game.player.global_position + Vector3(0.0, 0.0, 5.0)
		var dark_position := dark_zombie.global_position
		manager._classify_enemies()
		_check(manager.get_band(visible_zombie) == VisibilityManager.Band.VISIBLE_DISTANT, "distant zombie inside the light is classified as visible")
		_check(manager.get_band(dark_zombie) == VisibilityManager.Band.DARK_CLOSE_COMBAT, "close zombie behind the light remains in the combat simulation but is visually dark")
		_check(not dark_zombie._visual_root.visible, "dark ordinary zombie detail model is visually hidden")
		game.horde_far_visuals._update_full_rig_selection()
		game.horde_far_visuals._process(0.21)
		_check(game.horde_far_visuals.multimesh.visible_instance_count == 1, "shared MultiMesh compacts the horde to the one visible distant zombie")
		manager.set_aim_yaw(PI)
		manager._classify_enemies()
		_check(dark_zombie.global_position.distance_to(dark_position) < 0.001, "turning the flashlight never teleports a hidden zombie")
		_check(dark_zombie.is_physics_processing(), "hidden zombie physics and AI remain active")

	var old_rig_position := game.camera_rig.global_position
	game.player.global_position += Vector3.RIGHT * 2.0
	game._process(1.0 / 60.0)
	_check(game.camera_rig.global_position.distance_to(game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT) < old_rig_position.distance_to(game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT), "camera follows player movement with smoothing")
	game.player.velocity.y = 6.0
	game.player.global_position.y += 0.2
	game._process(1.0 / 60.0)
	_check(game.camera_rig.global_position.is_finite() and game.camera.global_position.is_finite(), "jump and dash height changes do not destabilize the camera")

	game.player.global_position = Foundation.PLAYER_BASE_POSITION
	game.player.velocity = Vector3.ZERO
	game._camera_yaw = 0.0
	game._camera_pitch = deg_to_rad(Foundation.CAMERA_PITCH_DEGREES)
	game.camera_rig.rotation.y = 0.0
	game.camera_arm.rotation.x = game._camera_pitch
	game.flashlight_visibility_manager.set_aim_yaw(0.0)
	for frame in range(30):
		await process_frame
	_check(game.player.try_jump(), "jump input starts while grounded")
	_check(game.player.try_dash(), "dash input starts without replacing the jump state")
	for frame in range(18):
		await physics_frame
		await process_frame
	_check(game.camera_rig.global_position.is_finite() and game.camera.global_position.is_finite(), "camera stays stable while jump and dash move the player")
	game.player.global_position = Foundation.PLAYER_BASE_POSITION
	game.player.velocity = Vector3.ZERO
	game.player.dash_time = 0.0
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.camera_rig.rotation.y = 0.0
	for frame in range(30):
		await process_frame

	var saved_size := root.size
	for viewport_size in [Vector2i(960, 720), Vector2i(1280, 720), Vector2i(2240, 960)]:
		root.size = viewport_size
		for frame in range(3):
			await process_frame
		game._update_camera_framing()
		await process_frame
		var actual_viewport_size := game.camera.get_viewport().get_visible_rect().size
		var feet_screen := game.camera.unproject_position(game.player.global_position)
		var normalized := Vector2(feet_screen.x / actual_viewport_size.x, feet_screen.y / actual_viewport_size.y)
		print("FLASHLIGHT_CAMERA_FRAME " + JSON.stringify({"window": viewport_size, "viewport": actual_viewport_size, "shoulder_offset": game.camera_arm.position.x, "player_feet": normalized}))
		_check(normalized.x >= 0.34 and normalized.x <= 0.42, "camera keeps player in the lower-left horizontal band at %s" % [viewport_size])
		_check(normalized.y >= 0.75 and normalized.y <= 0.86, "camera keeps combat area ahead at %s" % [viewport_size])
	root.size = saved_size

	_check(Foundation.ZOMBIE_HORDE_SIZE == 15 and Foundation.ZOMBIE_PERFORMANCE_CAPACITY == 200, "game population remains 15 with 200-zombie debug-only stress capacity")
	_check(game.burning_horizon.get_child_count() == 4, "Burning Horizon remains present while masked")
	_check(game._boss_enemy != null and game._boss_enemy.hp > 0, "boss simulation remains independent from flashlight visibility")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: flashlight visibility and camera (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: flashlight visibility and camera (%d/%d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
