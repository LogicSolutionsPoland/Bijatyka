extends SceneTree
## Software OpenGL pixel probe for the moving flashlight-tip overlay.

const Foundation := preload("res://scripts/foundation.gd")
const VisibilityManager := preload("res://scripts/flashlight_visibility.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Foundation.new()
	root.add_child(game)
	for frame in range(12):
		await process_frame

	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud._root.visible = false
	game.player.global_position = Vector3(0.0, 0.05, -5.2)
	game._rooftop_camera_blend = 0.0
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.camera_rig.rotation.y = 0.0
	game.camera_arm.spring_length = Foundation.CAMERA_FOLLOW_DISTANCE
	game.camera_arm.rotation.x = game._effective_camera_pitch()
	game._update_camera_framing()
	game._set_rooftop_render_profile(false)

	var manager = game.flashlight_visibility_manager
	manager.set_process(false)
	manager.set_aim_yaw(0.0)
	manager._upload_shader_parameters()
	var effect = manager._tip_silhouettes
	if effect == null or effect.overlay == null:
		_finish()
		return
	# Hold the probe beam level so the depth-tested quad sits above the floor.
	# The focused test separately covers tracking the game's live pitch.
	var render_direction := Vector3.FORWARD
	effect.call("update_beam", manager.beam_origin, render_direction,
		VisibilityManager.MAX_RADIUS, VisibilityManager.BEAM_TANGENT, true)
	_check(effect.overlay.visible, "ground profile displays one projected silhouette cluster")
	_check(manager._composite.visible, "the real ground-floor flashlight darkness pass is active")
	var viewport_rect := game.camera.get_viewport().get_visible_rect()
	_check(viewport_rect.has_point(effect.projected_center), "beam-tip cluster projects inside the viewport")
	var sample_point: Vector2 = effect.projected_center
	var opacity := float(effect.material.get_shader_parameter("silhouette_opacity"))
	_check(is_equal_approx(opacity, 0.40), "rendered shader is configured for 40 percent silhouette opacity")

	# Freeze the shader phase while capturing the paired opacity frames so the
	# animation cannot change the sampled silhouette between comparisons.
	effect.material.set_shader_parameter("animation_time_scale", 0.0)
	effect.set_effect_visible(false)
	var hidden_frame := await _capture_frame()
	effect.call("update_beam", manager.beam_origin, render_direction,
		VisibilityManager.MAX_RADIUS, VisibilityManager.BEAM_TANGENT, true)
	for frame in range(4):
		await process_frame
	var visible_frame := await _capture_frame()
	var hidden_pixel := _sample(hidden_frame, sample_point)
	var visible_pixel := _sample(visible_frame, sample_point)
	var overlay_delta := Vector3(
		visible_pixel.r - hidden_pixel.r,
		visible_pixel.g - hidden_pixel.g,
		visible_pixel.b - hidden_pixel.b
	).length()
	# Render the same spatial shader over black, then compare its composited
	# linear-light RGB against an opaque reference. The Compatibility viewport
	# keeps the clear-color alpha opaque, so its alpha channel is not a useful
	# measure of spatial transparency.
	var alpha_probe := SubViewport.new()
	alpha_probe.name = "FlashlightTipOpacityProbe"
	alpha_probe.size = Vector2i(128, 128)
	alpha_probe.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var probe_world := Node3D.new()
	var probe_camera := Camera3D.new()
	probe_world.add_child(probe_camera)
	probe_camera.current = true
	var probe_environment := Environment.new()
	probe_environment.background_mode = Environment.BG_COLOR
	probe_environment.background_color = Color.BLACK
	var probe_world_environment := WorldEnvironment.new()
	probe_world_environment.environment = probe_environment
	probe_world.add_child(probe_world_environment)
	var alpha_quad := MeshInstance3D.new()
	var alpha_mesh := QuadMesh.new()
	alpha_mesh.size = Vector2(2.0, 2.0)
	alpha_quad.mesh = alpha_mesh
	alpha_quad.position = Vector3(0.0, 0.0, -2.0)
	var alpha_material := effect.material.duplicate() as ShaderMaterial
	alpha_quad.material_override = alpha_material
	probe_world.add_child(alpha_quad)
	alpha_probe.add_child(probe_world)
	root.add_child(alpha_probe)
	await process_frame
	await RenderingServer.frame_post_draw
	var low_opacity_pixel := alpha_probe.get_texture().get_image().get_pixel(64, 64)
	alpha_material.set_shader_parameter("silhouette_opacity", 1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var opaque_pixel := alpha_probe.get_texture().get_image().get_pixel(64, 64)
	var low_linear := low_opacity_pixel.srgb_to_linear()
	var opaque_linear := opaque_pixel.srgb_to_linear()
	var measured_opacity := (
		low_linear.r / maxf(opaque_linear.r, 0.001)
		+ low_linear.g / maxf(opaque_linear.g, 0.001)
		+ low_linear.b / maxf(opaque_linear.b, 0.001)
	) / 3.0
	alpha_probe.queue_free()
	print("FLASHLIGHT_TIP_PIXEL " + JSON.stringify({
		"renderer": "GL Compatibility software desktop",
		"opacity_uniform": opacity,
		"measured_opacity_vs_opaque_reference": measured_opacity,
		"rendered_color_at_40_percent": low_opacity_pixel,
		"rendered_color_at_full_opacity": opaque_pixel,
		"hidden_pixel": hidden_pixel,
		"visible_pixel": visible_pixel,
		"overlay_delta": overlay_delta,
		"screen_rect": Rect2(effect.projected_center - effect.projected_size * 0.5,
			effect.projected_size),
		"world_tip": effect.beam_tip
	}))
	_check(maxf(hidden_pixel.r, maxf(hidden_pixel.g, hidden_pixel.b)) < 0.25,
		"beam-tip sample remains in the dark outer edge before the overlay")
	_check(overlay_delta > 0.08,
		"silhouettes are visible over the darkness mask")
	_check(measured_opacity >= 0.30 and measured_opacity <= 0.50,
		"rendered silhouette opacity is approximately 40 percent")

	effect.material.set_shader_parameter("animation_time_scale", 1.0)
	await process_frame
	var motion_start_frame := await _capture_frame()
	var moving_frame := await _capture_after_motion(0.8)
	var motion_delta := _region_delta(motion_start_frame, moving_frame, sample_point, effect.projected_size)
	_check(motion_delta > 0.006, "zombie silhouettes and fog visibly move over time")
	print("FLASHLIGHT_TIP_MOTION " + JSON.stringify({"max_pixel_delta": motion_delta, "wait_seconds": 0.8}))

	game.queue_free()
	await process_frame
	_finish()

func _capture_frame() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _capture_after_motion(seconds: float) -> Image:
	await create_timer(seconds).timeout
	return await _capture_frame()

func _region_delta(first: Image, second: Image, center: Vector2, footprint: Vector2) -> float:
	var radius := Vector2i(
		maxi(8, int(footprint.x * 0.45)),
		maxi(8, int(footprint.y * 0.45))
	)
	var maximum := 0.0
	for y in range(-radius.y, radius.y + 1, 3):
		for x in range(-radius.x, radius.x + 1, 3):
			var point := Vector2(center.x + x, center.y + y)
			var a := _sample(first, point)
			var b := _sample(second, point)
			maximum = maxf(maximum, Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	return maximum

func _sample(image: Image, point: Vector2) -> Color:
	var x := clampi(int(point.x), 0, image.get_width() - 1)
	var y := clampi(int(point.y), 0, image.get_height() - 1)
	return image.get_pixel(x, y)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: flashlight tip silhouette Compatibility render (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: flashlight tip silhouette Compatibility render (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
