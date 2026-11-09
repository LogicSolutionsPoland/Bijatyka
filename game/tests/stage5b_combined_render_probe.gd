extends SceneTree
## Stage 5B Step 4: combined full-scene Mesa/OpenGL readback regression.
## Host software-OpenGL pixels, not Android GPU performance evidence.

const Foundation := preload("res://scripts/foundation.gd")
const Visibility := preload("res://scripts/flashlight_visibility.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Foundation.new()
	root.add_child(game)
	for frame in range(14):
		await process_frame
	var manager = game.flashlight_visibility_manager
	var tip = manager._tip_silhouettes
	if not _check(manager._composite != null and game.burning_horizon != null and tip != null,
		"all three independently integrated layers are instantiated"):
		_finish()
		return
	_check(manager._material.render_priority == 126, "fullscreen blackout has render priority 126")
	_check(game.burning_horizon.get_child(0).material_override.render_priority == 127,
		"10m fog horizon is layered after blackout")
	_check(tip.material.render_priority == 127, "tip art is layered after blackout")
	var ring := game.burning_horizon.get_child(0).mesh as CylinderMesh
	_check(ring != null and ring.radial_segments == 96 and is_equal_approx(ring.top_radius, 10.0),
		"actual 96-segment circular fog horizon still has 10m radius")

	var roof_before := await _capture()
	_save(roof_before, "step4-roof-before.png")
	_check(not manager._composite.visible and not game.burning_horizon.visible and not tip.overlay.visible,
		"initial rooftop has no ground-floor blackout, ring or tip")
	_check(_peak(roof_before, Vector2(0.50, 0.56)) > 0.04,
		"original rooftop panorama remains visible in an actual framebuffer")

	game.set_process(false)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	manager.set_process(false)
	game.player.global_position = Vector3(0.0, 0.05, -5.2)
	game._rooftop_camera_blend = 0.0
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.camera_arm.spring_length = Foundation.CAMERA_FOLLOW_DISTANCE
	game._update_camera_framing()
	game._set_rooftop_render_profile(false)
	game.hud._root.visible = true
	if is_instance_valid(game._boss_enemy):
		game._boss_enemy.global_position = game.player.global_position + Vector3(3.0, 0.05, 5.0)
		game._update_boss_locator()
	_check(manager._composite.visible and game.burning_horizon.visible and manager.spotlight.visible,
		"ground floor restores blackout, fog ring and real spotlight")
	_check(game.hud._root.visible and is_instance_valid(game.hud._status_panel),
		"native canvas HUD stays present above the world")

	tip.material.set_shader_parameter("animation_time_scale", 0.0)
	for scale in [1.0, 0.67, 0.40]:
		root.scaling_3d_scale = scale
		for angle in range(3):
			var yaw: float = [-0.38, 0.0, 0.38][angle]
			var pitch: float = [-0.14, -0.06, 0.05][angle]
			game.camera_rig.rotation.y = yaw
			game.camera_arm.rotation.x = pitch
			await process_frame
			manager.set_aim_yaw(yaw)
			manager._upload_shader_parameters()
			manager._sync_tip_silhouettes()
			for frame in range(4):
				await process_frame
			var frame_image := await _capture()
			var label := "step4-ground-s%.2f-angle%d.png" % [scale, angle]
			_save(frame_image, label)
			_check(not frame_image.is_empty(), "actual combined viewport exists: " + label)
			_check(manager._composite.visible and game.burning_horizon.visible and manager.spotlight.visible,
				"all ground layers survive yaw, pitch and render scale: " + label)
			var left_dark := _peak(frame_image, Vector2(0.02, 0.42))
			var right_dark := _peak(frame_image, Vector2(0.98, 0.42))
			_check(left_dark < 0.08 and right_dark < 0.08,
				"two off-beam scene edges remain black with all effects on: " + label)
			_check(game.burning_horizon.global_position.distance_to(game.player.global_position) < 0.02,
				"moving horizon is player centered: " + label)
			print("STAGE5B_COMBINED_FRAME " + JSON.stringify({
				"scale": scale, "yaw": yaw, "pitch": pitch,
				"dark_left": left_dark, "dark_right": right_dark,
				"tip_visible": tip.overlay.visible, "beam_visible": manager.spotlight.visible,
				"mask": manager._composite.visible, "horizon": game.burning_horizon.visible
			}))
	# Return to level beam for a stable projected tip in the depth and HUD A/B probes.
	root.scaling_3d_scale = 1.0
	game.camera_rig.rotation.y = 0.0
	game.camera_arm.rotation.x = -0.06
	await process_frame
	manager.set_aim_yaw(0.0)
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	for frame in range(4):
		await process_frame
	_check(tip.overlay.visible and root.get_visible_rect().has_point(tip.projected_center),
		"combined real-game tip is projected onto the viewport")
	# CanvasLayer A/B: the HUD must be visibly present in the framebuffer.
	var hud_on := await _capture()
	_save(hud_on, "step4-hud-on.png")
	game.hud._root.visible = false
	for frame in range(2):
		await process_frame
	var hud_off := await _capture()
	_save(hud_off, "step4-hud-off.png")
	var hud_delta := _region_delta(hud_on, hud_off, Vector2(220.0, 110.0), Vector2(410.0, 200.0))
	_check(hud_delta > 0.10, "real HUD pixels survive the fullscreen black mask")
	print("STAGE5B_HUD_AB " + JSON.stringify({"max_rgb_delta": hud_delta, "boss_marker_visible": game.hud._boss_marker.visible}))
	game.hud._root.visible = false

	# Player translation must move the ring, camera and projected flashlight together.
	var previous_ring := game.burning_horizon.global_position
	game.player.global_position += Vector3(1.8, 0.0, -1.4)
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.burning_horizon.follow_player(game.player.global_position)
	await process_frame
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	for frame in range(4):
		await process_frame
	_save(await _capture(), "step4-player-moved.png")
	_check(game.burning_horizon.global_position.distance_to(game.player.global_position) < 0.02 and
		game.burning_horizon.global_position.distance_to(previous_ring) > 1.5,
		"circular fog travels with the player without rebuilding the cylinder")
	_check(manager.beam_origin.distance_to(game.player.global_position + Vector3.UP * 1.55) < 0.03,
		"3D beam follows actual translated player")

	# Explicit floor interception: the displayed tip must not sink below the arena.
	tip.update_beam(manager.beam_origin, Vector3(0.0, -0.3, -1.0).normalized(),
		Visibility.MAX_RADIUS, Visibility.BEAM_TANGENT, true)
	_check(tip.overlay.visible and tip.overlay.global_position.y > 0.05,
		"downward-pointing flashlight silhouette is relocated above ground intersection")
	_save(await _capture(), "step4-floor-intersection.png")
	manager._sync_tip_silhouettes()
	for frame in range(3):
		await process_frame

	# Opaque foreground wall between camera and tip: compare the SAME pixels.
	# A disabled depth test on the tip makes it incorrectly paint through this wall.
	_check(tip.overlay.visible, "tip is present before wall depth comparison")
	var center: Vector2 = tip.projected_center
	var wall := MeshInstance3D.new()
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(8.0, 7.0, 0.30)
	wall.mesh = wall_mesh
	var wall_mat := StandardMaterial3D.new()
	wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_mat.albedo_color = Color(0.06, 0.75, 0.12)
	wall.material_override = wall_mat
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(wall)
	wall.global_transform = Transform3D(game.camera.global_basis,
		game.camera.global_position.lerp(tip.overlay.global_position, 0.55))
	tip.set_effect_visible(false)
	for frame in range(4):
		await process_frame
	var behind_wall := await _capture()
	_save(behind_wall, "step4-wall-tip-off.png")
	tip.update_beam(manager.beam_origin, manager.beam_direction,
		Visibility.MAX_RADIUS, Visibility.BEAM_TANGENT, true)
	for frame in range(4):
		await process_frame
	var through_wall := await _capture()
	_save(through_wall, "step4-wall-tip-on.png")
	var wall_green := _sample(behind_wall, center).g
	var wall_delta := _region_delta(behind_wall, through_wall, center, Vector2(36.0, 36.0))
	print("STAGE5B_WALL_DEPTH_AB " + JSON.stringify({
		"wall_green": wall_green, "tip_on_vs_off_max_rgb_delta": wall_delta,
		"tip_shader_depth_disabled": tip.material.shader.code.contains("depth_test_disabled")
	}))
	_check(wall_green > 0.12, "the opaque wall actually covers the tested projected beam tip")
	_check(wall_delta < 0.045, "foreground wall occludes tip artwork in real scene depth buffer")
	wall.queue_free()
	for frame in range(3):
		await process_frame

	# Verify roof/ground transitions after moving the character and camera.
	game._set_rooftop_render_profile(true)
	for frame in range(3):
		await process_frame
	var roof_after := await _capture()
	_save(roof_after, "step4-roof-after.png")
	_check(not manager._composite.visible and not game.burning_horizon.visible and not tip.overlay.visible,
		"roof transition disables blackout, fog horizon and tip together")
	game._set_rooftop_render_profile(false)
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	for frame in range(4):
		await process_frame
	_save(await _capture(), "step4-ground-return.png")
	_check(manager._composite.visible and game.burning_horizon.visible and manager.spotlight.visible,
		"ground return restores core 3D lighting and fullscreen darkness")
	_check(tip.overlay.visible, "ground return restores live tip projection")
	game.queue_free()
	await process_frame
	_finish()

func _capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _sample(image: Image, point: Vector2) -> Color:
	return image.get_pixel(clampi(int(point.x), 0, image.get_width() - 1),
		clampi(int(point.y), 0, image.get_height() - 1))

func _peak(image: Image, uv: Vector2) -> float:
	var c := _sample(image, Vector2(image.get_size()) * uv)
	return maxf(c.r, maxf(c.g, c.b))

func _region_delta(first: Image, second: Image, center: Vector2, footprint: Vector2) -> float:
	var extent := footprint * 0.5
	var peak_delta := 0.0
	for y in range(-int(extent.y), int(extent.y) + 1, 4):
		for x in range(-int(extent.x), int(extent.x) + 1, 4):
			var p := center + Vector2(x, y)
			var a := _sample(first, p)
			var b := _sample(second, p)
			peak_delta = maxf(peak_delta,
				Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length())
	return peak_delta

func _save(image: Image, filename: String) -> void:
	var folder := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	if folder.is_empty() or image == null or image.is_empty():
		failures.append("missing capture directory or empty frame " + filename)
		return
	if DirAccess.make_dir_recursive_absolute(folder) != OK or image.save_png(folder.path_join(filename)) != OK:
		failures.append("failed to save PNG " + filename)

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
	return condition

func _finish() -> void:
	if failures.is_empty():
		print("PASS: Stage5B Step4 combined real-render matrix (%d checks)" % checks)
	else:
		for error in failures:
			push_error(error)
		print("FAIL: Stage5B Step4 combined real-render matrix (%d failures, %d checks)" %
			[failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
