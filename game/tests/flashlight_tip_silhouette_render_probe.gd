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
	manager._sync_tip_silhouettes()
	var effect = manager._tip_silhouettes
	_check(effect != null and effect.overlay != null and effect.overlay.visible,
		"ground profile displays one projected silhouette cluster")
	if effect == null or effect.overlay == null:
		_finish()
		return
	_check(manager._composite.visible, "the real ground-floor flashlight darkness pass is active")
	var viewport_rect := game.camera.get_viewport().get_visible_rect()
	_check(viewport_rect.has_point(effect.projected_center), "beam-tip cluster projects inside the viewport")
	var sample_point: Vector2 = effect.projected_center
	var opacity := float(effect.material.get_shader_parameter("silhouette_opacity"))
	_check(is_equal_approx(opacity, 0.40), "rendered shader is configured for 40 percent silhouette opacity")
	var original_silhouette_color = effect.material.get_shader_parameter("silhouette_color")
	var original_fog_color = effect.material.get_shader_parameter("fog_color")

	# Freeze the shader phase while capturing the paired opacity frames so the
	# animation cannot change the sampled silhouette between comparisons. Use
	# white source colors so the linear readback directly measures alpha rather
	# than the silhouette tint.
	effect.material.set_shader_parameter("animation_time_scale", 0.0)
	effect.material.set_shader_parameter("silhouette_color", Vector3.ONE)
	effect.material.set_shader_parameter("fog_color", Vector3.ONE)
	effect.set_effect_visible(false)
	var hidden_frame := await _capture_frame()
	effect.call("update_beam", manager.beam_origin, manager.beam_direction,
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
	# Compare the 40% render with the same silhouette drawn at full opacity.
	# Read back through the same Compatibility renderer and linearize its
	# sRGB pixel values before estimating the blend alpha over the black mask.
	effect.material.set_shader_parameter("silhouette_opacity", 1.0)
	await process_frame
	var opaque_frame := await _capture_frame()
	var opaque_pixel := _sample(opaque_frame, sample_point)
	var measured_opacity := _estimate_blend_opacity(hidden_pixel, visible_pixel, opaque_pixel)
	effect.material.set_shader_parameter("silhouette_opacity", opacity)
	print("FLASHLIGHT_TIP_PIXEL " + JSON.stringify({
		"renderer": "GL Compatibility software desktop",
		"opacity_uniform": opacity,
		"measured_opacity_vs_opaque_reference": measured_opacity,
		"hidden_pixel": hidden_pixel,
		"visible_pixel": visible_pixel,
		"opaque_reference_pixel": opaque_pixel,
		"overlay_delta": overlay_delta,
		"screen_rect": Rect2(effect.overlay.position, effect.overlay.size)
	}))
	_check(maxf(hidden_pixel.r, maxf(hidden_pixel.g, hidden_pixel.b)) < 0.25,
		"beam-tip sample remains in the dark outer edge before the overlay")
	_check(overlay_delta > 0.08,
		"silhouettes are visible over the darkness mask")
	_check(measured_opacity >= 0.30 and measured_opacity <= 0.50,
		"rendered silhouette opacity is approximately 40 percent")

	effect.material.set_shader_parameter("animation_time_scale", 1.0)
	effect.material.set_shader_parameter("silhouette_color", original_silhouette_color)
	effect.material.set_shader_parameter("fog_color", original_fog_color)
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

func _estimate_blend_opacity(background: Color, blended: Color, opaque: Color) -> float:
	var background_linear := background.srgb_to_linear()
	var blended_linear := blended.srgb_to_linear()
	var opaque_linear := opaque.srgb_to_linear()
	var total := 0.0
	var channels := 0
	for values in [
		[background_linear.r, blended_linear.r, opaque_linear.r],
		[background_linear.g, blended_linear.g, opaque_linear.g],
		[background_linear.b, blended_linear.b, opaque_linear.b],
	]:
		var opaque_delta: float = values[2] - values[0]
		if absf(opaque_delta) <= 0.01:
			continue
		total += (values[1] - values[0]) / opaque_delta
		channels += 1
	return total / float(channels) if channels > 0 else 0.0

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
