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
	var artwork := effect.material.get_shader_parameter("tip_artwork") as Texture2D
	_check(artwork != null and artwork.resource_path.ends_with("flashlight_tip_zombie_fog.webp"),
		"real PR #70 art image is bound into the active GPU shader")
	_check(artwork != null and artwork.get_width() == 768 and artwork.get_height() == 512,
		"original 768x512 WebP imports at correct dimensions")
	_check(effect.material.shader.code.contains("floor(effect_time * 13.0)") and
		effect.material.shader.code.contains("line_index < 5"),
		"five short horizontal glitch slices take 13 discrete steps per second")
	_check(game.burning_horizon.visible and game.burning_horizon.get_child_count() == 1,
		"circular Zombie Fog Horizon is retained in ground scene")

	# Freeze time for paired on/off and 0%/40% silhouettes comparisons.
	# The fog layer retains its own configured 72% density.
	for scale in [1.0, 0.67, 0.40]:
		root.scaling_3d_scale = scale
		effect.material.set_shader_parameter("animation_time_scale", 0.0)
		effect.set_effect_visible(false)
		await process_frame
		var hidden_frame := await _capture_frame()
		_save_capture(hidden_frame, "tip-hidden-%.2f.png" % scale)
		effect.update_beam(manager.beam_origin, render_direction,
			VisibilityManager.MAX_RADIUS, VisibilityManager.BEAM_TANGENT, true)
		for frame in range(4):
			await process_frame
		var visible_frame := await _capture_frame()
		_save_capture(visible_frame, "tip-visible-%.2f.png" % scale)
		var visible_delta := _region_delta(hidden_frame, visible_frame, sample_point, effect.projected_size)
		_check(visible_delta > 0.01,
			"PR #70 tip fog renders genuinely different pixels at %.2fx" % scale)
		var off_beam := _sample(visible_frame,
			Vector2(float(visible_frame.get_width()) * 0.02, float(visible_frame.get_height()) * 0.42))
		_check(maxf(off_beam.r, maxf(off_beam.g, off_beam.b)) < 0.06,
			"fullscreen blackout remains dark outside beam footprint at %.2fx" % scale)

		effect.material.set_shader_parameter("silhouette_opacity", 0.0)
		await process_frame
		var fog_only := await _capture_frame()
		effect.material.set_shader_parameter("silhouette_opacity", 0.40)
		await process_frame
		var artwork_frame := await _capture_frame()
		_save_capture(artwork_frame, "tip-artwork-40pct-%.2f.png" % scale)
		var artwork_delta := _region_delta(fog_only, artwork_frame, sample_point, effect.projected_size)
		_check(artwork_delta > 0.002,
			"original artwork changes actual framebuffer when silhouette alpha rises from 0 to 40 percent at %.2fx" % scale)
		print("FLASHLIGHT_TIP_ALPHA " + JSON.stringify({
			"scale": scale, "tip_on_off_delta": visible_delta,
			"artwork_0_to_40_delta": artwork_delta, "off_beam_pixel": off_beam
		}))

	# The shader uses actual TIME for continuous fog plus 13 Hz stepped glitch.
	# Screenshots and paired pixels confirm motion; the shader-code assertion
	# verifies the exact 13 Hz calculation (not a claimed measured clock).
	root.scaling_3d_scale = 1.0
	effect.material.set_shader_parameter("animation_time_scale", 1.0)
	await process_frame
	var motion_start_frame := await _capture_frame()
	_save_capture(motion_start_frame, "tip-animation-start.png")
	var glitch_frame := await _capture_after_motion(0.12)
	_save_capture(glitch_frame, "tip-animation-after-120ms.png")
	var glitch_delta := _region_delta(motion_start_frame, glitch_frame, sample_point, effect.projected_size)
	var motion_end_frame := await _capture_after_motion(0.8)
	_save_capture(motion_end_frame, "tip-animation-after-920ms.png")
	var motion_delta := _region_delta(motion_start_frame, motion_end_frame, sample_point, effect.projected_size)
	_check(glitch_delta > 0.003, "short-window flashlight-tip glitch/fog changes actual pixels")
	_check(motion_delta > 0.006, "PR #70 zombie silhouettes and fog animate in real OpenGL pixels")
	print("FLASHLIGHT_TIP_MOTION " + JSON.stringify({
		"after_120ms_max_delta": glitch_delta, "after_920ms_max_delta": motion_delta,
		"glitch_steps_per_second_from_shader": 13.0
	}))
	game._set_rooftop_render_profile(true)
	await process_frame
	_check(not effect.overlay.visible and not manager._composite.visible and not game.burning_horizon.visible,
		"rooftop hides tip, fullscreen blackout and circular horizon together")
	var rooftop_frame := await _capture_frame()
	_save_capture(rooftop_frame, "tip-rooftop-profile.png")
	game._set_rooftop_render_profile(false)
	_check(effect.overlay.visible and manager._composite.visible and game.burning_horizon.visible,
		"ground return restores tip, fullscreen blackout and circular horizon")

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

func _save_capture(image: Image, name: String) -> void:
	var folder := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	if folder.is_empty() or image == null or image.is_empty():
		return
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		failures.append("Cannot create tip capture directory")
		return
	if image.save_png(folder.path_join(name)) != OK:
		failures.append("Cannot save tip frame " + name)

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
