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
	_check(is_equal_approx(game.camera_arm.spring_length, Foundation.ROOFTOP_CAMERA_FOLLOW_DISTANCE), "rooftop camera uses the wider city-view distance")
	_check(game.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "camera keeps perspective projection instead of a 180-degree lens")
	_check(is_equal_approx(game.camera.fov, Foundation.CAMERA_VERTICAL_FOV), "camera keeps the existing 66-degree perspective")
	_check(game._camera_pitch < 0.0 and -game.camera.global_transform.basis.z.y < 0.0, "default camera looks down toward the lit ground")

	var manager = game.flashlight_visibility_manager
	manager.set_aim_yaw(0.0)
	_check(manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, -10)), "forward point is inside the 180-degree sector")
	_check(not manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, 10)), "rear point is outside the 180-degree sector")
	_check(not manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, 31)), "rear point remains outside the forward flashlight sector")
	_check(manager.is_point_in_sector(game.player.global_position + Vector3(0, 0, 0.3), 0.65), "sector hysteresis holds a recently visible actor near the boundary")
	_check(is_equal_approx(manager.get_radial_weight(VisibilityManager.BRIGHT_RADIUS), 1.0), "illumination stays bright through 7.33 m")
	_check(manager.get_radial_weight((VisibilityManager.BRIGHT_RADIUS + VisibilityManager.MAX_RADIUS) * 0.5) > 0.0 and manager.get_radial_weight((VisibilityManager.BRIGHT_RADIUS + VisibilityManager.MAX_RADIUS) * 0.5) < 1.0, "outer 7.33–10 m band fades smoothly")
	_check(is_zero_approx(manager.get_radial_weight(VisibilityManager.MAX_RADIUS)), "illumination reaches black at 10 m")
	# Rooftop glints stay off; ground-floor glints remain independent of beam aim and range.
	var base_position: Vector3 = game.player.global_position
	_check(is_zero_approx(manager.get_teeth_glow_weight(base_position + Vector3(0, 0, -15))), "rooftop keeps tooth glints off")
	game._set_rooftop_render_profile(false)
	_check(manager.get_teeth_glow_weight(base_position + Vector3(0, 0, -15)) > 0.99, "teeth remain visible beyond the new 10 m flashlight range")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(0, 0, -34)) > 0.99, "teeth remain visible outside the flashlight beam")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(0, 0, -35)) > 0.99, "teeth do not stop at the former forward boundary")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(0, 0, -100)) > 0.99, "teeth remain visible at long range")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(32, 0, -1)) > 0.99, "teeth remain visible to the right outside the beam")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(-32, 0, -1)) > 0.99, "teeth remain visible to the left outside the beam")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(33, 0, -1)) > 0.99, "teeth do not stop at the former right boundary")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(-33, 0, -1)) > 0.99, "teeth do not stop at the former left boundary")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(0, 0, 2)) > 0.99, "teeth are not clipped behind the player")
	_check(manager.get_teeth_glow_weight(base_position + Vector3(34, 0, -34)) > 0.99, "teeth are not clipped by the former diagonal boundary")
	_check(is_zero_approx(manager.get_radial_weight(11.0)), "ordinary environment light does not extend with teeth beyond 10 m")
	_check(manager.get_oval_weight(VisibilityManager.OVAL_CENTER_UV) > 0.999, "reference oval center is lit")
	_check(is_zero_approx(manager.get_oval_weight(Vector2(0.02, 0.60))), "left of the oval is black")
	_check(is_zero_approx(manager.get_oval_weight(Vector2(0.90, 0.60))), "right of the oval is black")
	_check(is_zero_approx(manager.get_oval_weight(Vector2(0.44, 0.10))), "above the oval is black")
	_check(is_zero_approx(manager.get_oval_weight(Vector2(0.44, 0.95))), "below the oval is black")
	var feather_uv := VisibilityManager.OVAL_CENTER_UV + Vector2(VisibilityManager.OVAL_RADIUS_UV.x * 0.97, 0.0)
	_check(manager.get_oval_weight(feather_uv) > 0.0 and manager.get_oval_weight(feather_uv) < 1.0, "oval has a short soft edge")
	_check(manager._material == null and manager._composite == null, "removed fullscreen mask is never allocated")
	_check(is_instance_valid(manager.spotlight), "3D flashlight beam remains independently active")

	manager.set_aim_yaw(PI * 0.5)
	_check(manager.is_point_in_sector(game.player.global_position + Vector3(-10, 0, 0)), "positive camera yaw lights the camera's leftward view")
	_check(not manager.is_point_in_sector(game.player.global_position + Vector3(10, 0, 0)), "rotated sector excludes the opposite half")
	_check(manager.aim_direction.distance_to(Vector3.LEFT) < 0.001, "aim direction has no rotation lag")
	_check(manager.get_teeth_glow_weight(game.player.global_position + Vector3(-34, 0, 0)) > 0.99, "teeth stay visible outside the rotated flashlight")
	_check(manager.get_teeth_glow_weight(game.player.global_position + Vector3(34, 0, 0)) > 0.99, "teeth are independent of rotated flashlight aim")
	game._camera_yaw = PI * 0.5
	game._process(1.0 / 60.0)
	_check((game._floor_material.get_shader_parameter("flashlight_forward") as Vector3).distance_to(manager.aim_direction) < 0.001, "ground beam direction follows camera yaw without a fullscreen mask")
	game._camera_yaw = 0.0
	manager.set_aim_yaw(-PI * 0.5)
	_check(manager.aim_direction.distance_to(Vector3.RIGHT) < 0.001, "negative camera yaw lights the camera's rightward view")
	manager.set_aim_yaw(0.0)

	# The right stick updates camera and flashlight aim in the same frame.
	var yaw_before_gamepad := game._camera_yaw
	Input.action_press("camera_right", 1.0)
	game._update_gamepad_camera(1.0 / 60.0)
	Input.action_release("camera_right")
	_check(not is_equal_approx(game._camera_yaw, yaw_before_gamepad), "gamepad camera action rotates the camera")
	var camera_forward := -game.camera.global_transform.basis.z
	camera_forward.y = 0.0
	_check(game.flashlight_visibility_manager.aim_direction.distance_to(camera_forward.normalized()) < 0.001, "gamepad aim points the flashlight along the camera")

	# Verify the light classifier feeds the shared MultiMesh queue independently
	# from AI and collision. The test scene is discarded after these placements.
	game._camera_yaw = 0.0
	game.camera_rig.rotation.y = 0.0
	manager.set_aim_yaw(0.0)
	# Rooftop residents are count-only now. Create two isolated classifier
	# fixtures without activating the ground-floor population or its director.
	var test_enemies: Array = game.horde_far_visuals._enemies.values()
	if test_enemies.size() < 2:
		_check(game.spawn_director.ordinary_population_count() == 4 and game.spawn_director._live.is_empty(), "rooftop holds four dormant ordinary entries without actors")
		for index in range(2):
			var fixture := game._spawn_enemy("shambler", game.player.global_position + Vector3(45.0 + index, 0.0, 0.0))
			game.horde_far_visuals.register_enemy(fixture)
		game.horde_far_visuals.visible = true
		test_enemies = game.horde_far_visuals._enemies.values()
	_check(test_enemies.size() >= 2, "classifier fixtures are registered with the shared visibility manager")
	if test_enemies.size() >= 2:
		for enemy_variant in test_enemies:
			var enemy := enemy_variant as FoundationEnemy
			enemy.global_position = game.player.global_position + Vector3(45.0, 0.0, 0.0)
		var visible_zombie := test_enemies[0] as FoundationEnemy
		var dark_zombie := test_enemies[1] as FoundationEnemy
		visible_zombie.global_position = game.player.global_position + Vector3(0.0, 0.0, -8.0)
		dark_zombie.global_position = game.player.global_position + Vector3(0.0, 0.0, 5.0)
		var dark_position := dark_zombie.global_position
		manager._classify_enemies()
		_check(manager.get_band(visible_zombie) == VisibilityManager.Band.VISIBLE_CLOSE, "zombie inside the 10 m light range is classified as visible")
		_check(manager.get_band(dark_zombie) == VisibilityManager.Band.DARK_CLOSE_COMBAT, "close zombie behind the light remains in the combat simulation but is visually dark")
		_check(not dark_zombie._visual_root.visible, "dark ordinary zombie detail model is visually hidden")
		game.horde_far_visuals._update_full_rig_selection()
		game.horde_far_visuals._process(0.21)
		_check(game.horde_far_visuals.multimesh.visible_instance_count == 0, "zombie inside the 10 m range uses the close render path")
		manager.set_aim_yaw(PI)
		manager._classify_enemies()
		_check(dark_zombie.global_position.distance_to(dark_position) < 0.001, "turning the flashlight never teleports a hidden zombie")
		_check(dark_zombie.is_physics_processing(), "hidden zombie physics and AI remain active")
		for enemy in test_enemies:
			(enemy as FoundationEnemy).queue_free()
		await process_frame
		game.horde_far_visuals.visible = false

	var old_rig_position := game.camera_rig.global_position
	game.player.global_position += Vector3.RIGHT * 2.0
	game._process(1.0 / 60.0)
	_check(game.camera_rig.global_position.distance_to(game.player.global_position + Vector3.UP * game._camera_pivot_height()) < old_rig_position.distance_to(game.player.global_position + Vector3.UP * game._camera_pivot_height()), "camera follows player movement with smoothing")
	game.player.velocity.y = 6.0
	game.player.global_position.y += 0.2
	game._process(1.0 / 60.0)
	_check(game.camera_rig.global_position.is_finite() and game.camera.global_position.is_finite(), "jump height changes do not destabilize the camera")

	game.player.global_position = Foundation.PLAYER_BASE_POSITION
	game.player.velocity = Vector3.ZERO
	game._camera_yaw = 0.0
	game._camera_pitch = deg_to_rad(Foundation.CAMERA_PITCH_DEGREES)
	game.camera_rig.rotation.y = 0.0
	game.camera_arm.rotation.x = game._effective_camera_pitch()
	game.flashlight_visibility_manager.set_aim_yaw(0.0)
	for frame in range(30):
		await physics_frame
		await process_frame
	_check(game.player.try_jump(), "jump input starts while grounded")
	for frame in range(90):
		await physics_frame
		await process_frame
		if frame > 3 and game.player.is_on_floor() and game.player.velocity.y <= 0.0:
			break
	_check(game.player.is_on_floor(), "ordinary Jump lands before the forward-jump check")
	_check(game.player.try_parabolic_jump(), "forward Jump starts separately after ordinary Jump lands")
	var player_facing := -game.player.global_transform.basis.z
	player_facing.y = 0.0
	_check(is_zero_approx(game.player._parabolic_jump_direction.y)
		and game.player._parabolic_jump_direction.dot(player_facing.normalized()) > 0.999,
		"forward Jump follows player facing horizontally under the downward camera")
	for frame in range(18):
		await physics_frame
		await process_frame
	_check(game.camera_rig.global_position.is_finite() and game.camera.global_position.is_finite(), "camera stays stable during the forward Jump")
	for frame in range(90):
		await physics_frame
		await process_frame
		if not game.player._parabolic_jump_active and game.player.is_on_floor():
			break
	_check(not game.player._parabolic_jump_active and game.player.is_on_floor(), "forward Jump lands before camera framing probes")
	game.player.global_position = Foundation.PLAYER_BASE_POSITION
	game.player.velocity = Vector3.ZERO
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * game._camera_pivot_height()
	game.camera_rig.rotation.y = 0.0
	for frame in range(30):
		await physics_frame
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
		_check(normalized.y >= 0.86 and normalized.y <= 0.91, "camera keeps combat area ahead at %s" % [viewport_size])
	root.size = saved_size

	game._set_rooftop_render_profile(true)
	_check(Foundation.ZOMBIE_HORDE_SIZE == 4 and Foundation.ZOMBIE_PERFORMANCE_CAPACITY == 20, "game stores four rooftop zombies and never profiles more than 20")
	_check(game.burning_horizon.get_child_count() == 4, "Burning Horizon remains present without the fullscreen mask")
	_check(game._boss_enemy != null and game._boss_enemy.hp > 0, "boss simulation remains independent from flashlight visibility")
	_check(manager._tracked.has(game._boss_enemy.get_instance_id()), "boss is registered for the same whole-body flashlight reveal")
	_check(is_equal_approx(Foundation.MOBILE_3D_RENDER_SCALE, 0.40), "Android 3D starts at 40 percent resolution with a native-resolution HUD")
	if OS.is_debug_build() and game.performance_diagnostics != null:
		var local_lights := game.find_children("*", "OmniLight3D", true, false)
		_check(local_lights.size() == 4, "four unshadowed local lights remain available for quality comparison")
		_check(game._local_lights_enabled != OS.has_feature("mobile"), "mobile starts without local light passes and desktop retains them")
		var player_meshes := game.player.visual_root.find_children("*", "GeometryInstance3D", true, false)
		_check(not game._key_light.shadow_enabled and player_meshes.all(func(node: Node) -> bool: return (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "character shadows stay disabled in the default mobile-friendly preset")
		game.performance_diagnostics.character_shadows_comparison_requested.emit(true)
		_check(game._key_light.shadow_enabled and player_meshes.any(func(node: Node) -> bool: return (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON), "profiler enables the key-light shadow and player shadow casters for visual A/B")
		game.performance_diagnostics.character_shadows_comparison_requested.emit(false)
		_check(not game._key_light.shadow_enabled and player_meshes.all(func(node: Node) -> bool: return (node as GeometryInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "profiler restores the shadow-free preset")
		game.performance_diagnostics.local_lights_comparison_requested.emit(false)
		_check(local_lights.all(func(light: Node) -> bool: return not (light as OmniLight3D).visible), "profiler disables all local lights without removing the bulbs")
		game.performance_diagnostics.local_lights_comparison_requested.emit(true)
		_check(local_lights.all(func(light: Node) -> bool: return (light as OmniLight3D).visible), "profiler restores all local lights")
		_check(bool(game._floor_material.get_shader_parameter("floor_fast_detail")) == OS.has_feature("mobile"), "phone defaults to lower-cost floor detail while desktop preserves full detail")
		game.performance_diagnostics.floor_detail_comparison_requested.emit(true)
		_check(bool(game._floor_material.get_shader_parameter("floor_fast_detail")), "profiler enables the fast floor for A/B comparison")
		game.performance_diagnostics.floor_detail_comparison_requested.emit(false)
		_check(not bool(game._floor_material.get_shader_parameter("floor_fast_detail")), "profiler restores the full floor for A/B comparison")
		_check(not bool(game._floor_material.get_shader_parameter("floor_skip_enabled")), "ground remains visible with the blackout removed")
		game._set_debug_floor_skip_enabled(true)
		game._set_debug_mask_visible(true)
		_check(not bool(game._floor_material.get_shader_parameter("floor_skip_enabled")), "debug switches cannot re-enable obsolete floor cutout")
		_check(manager._composite == null, "debug mask switch cannot recreate fullscreen pass")
		var original_scale := root.scaling_3d_scale
		game.performance_diagnostics.render_scale_requested.emit(0.40)
		_check(is_equal_approx(root.scaling_3d_scale, 0.40), "debug profiler can compare 40 percent 3D rendering")
		game.performance_diagnostics.render_scale_requested.emit(0.67)
		_check(is_equal_approx(root.scaling_3d_scale, 0.67), "debug profiler can compare the previous 0.67x rendering")
		game.performance_diagnostics.render_scale_requested.emit(1.0)
		_check(is_equal_approx(root.scaling_3d_scale, 1.0), "debug profiler can compare full-resolution 3D rendering")
		root.scaling_3d_scale = original_scale
		var active_enemies: int = game.horde_far_visuals._enemies.size()
		game.performance_diagnostics.mask_comparison_requested.emit(false)
		_check(manager._composite == null, "profiler mask OFF leaves no fullscreen overlay")
		_check(game.horde_far_visuals._enemies.size() == active_enemies, "mask comparison never alters zombie population")
		game.performance_diagnostics.mask_comparison_requested.emit(true)
		_check(manager._composite == null, "profiler mask ON cannot restore removed overlay")
		game._set_rooftop_render_profile(false)
		var pencil_manager := root.get_node_or_null("PencilSketchStyle")
		_check(pencil_manager != null and bool(pencil_manager.get("_gameplay_pencil_enabled")), "ground enables mesh-only character Sketch")
		_check(pencil_manager != null and bool(pencil_manager.get("_character_only")), "ground Sketch excludes environment meshes")
		game.performance_diagnostics.pencil_comparison_requested.emit(false)
		_check(pencil_manager != null and not bool(pencil_manager.get("_gameplay_pencil_enabled")), "profiler can disable character Sketch")
		game._set_rooftop_render_profile(true)
		game.performance_diagnostics.pencil_comparison_requested.emit(true)
		_check(pencil_manager != null and not bool(pencil_manager.get("_gameplay_pencil_enabled")), "rooftop keeps Sketch disabled")
		game._set_rooftop_render_profile(false)
		_check(pencil_manager != null and bool(pencil_manager.get("_gameplay_pencil_enabled")), "ground restores mesh-only Sketch after profiler toggle")
		game._set_rooftop_render_profile(true)
		_check(manager._composite == null and not manager.spotlight.visible, "rooftop leaves fullscreen mask absent and turns off 3D flashlight")
		game.performance_diagnostics.map_comparison_requested.emit(false)
		_check(not game.arena_map.visible, "debug profiler can isolate static map rendering")
		game.performance_diagnostics.map_comparison_requested.emit(true)
		_check(game.arena_map.visible, "debug profiler restores the map")

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
