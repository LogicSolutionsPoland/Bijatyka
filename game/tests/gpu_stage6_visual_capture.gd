extends SceneTree
## Captures the Stage 5 roof/ground views, compares them with the validated
## Stage 5 artifact, then checks and captures the ground beam across a wall.

const SCENE := preload("res://scenes/foundation.tscn")
const Foundation := preload("res://scripts/foundation.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	var baseline_dir := OS.get_environment("BIJATYKA_STAGE5_CAPTURE_DIR")
	if output_dir.is_empty() or baseline_dir.is_empty():
		_fail("Capture and Stage 5 baseline directories are required")
		return
	root.scaling_3d_scale = 0.40
	Engine.max_fps = 60
	var game := SCENE.instantiate()
	root.add_child(game)
	for frame in range(12):
		await process_frame
	var manager: Node = game.flashlight_visibility_manager
	if game._pencil_screen_pass.visible or manager._composite.visible or manager.spotlight.visible:
		_fail("Rooftop unexpectedly enables Pencil, mask, or flashlight beam")
		return
	var roof_path := output_dir.path_join("roof.png")
	if not await _capture(roof_path):
		quit(1)
		return
	if not _compare_to_stage5(roof_path, baseline_dir.path_join("roof.png"), game, "roof"):
		quit(1)
		return

	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0.0, 0.05, -5.2)
	for visual in game._ground_map_visuals:
		visual.visible = true
	game._ground_map_ready = true
	game._set_rooftop_render_profile(false)
	game._rooftop_camera_blend = 0.0
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.camera_arm.spring_length = Foundation.CAMERA_FOLLOW_DISTANCE
	game.camera_arm.rotation.x = game._effective_camera_pitch()
	game._update_camera_framing()
	manager._upload_shader_parameters()
	game.set_process(false)
	manager.set_process(false)
	if game._boss_enemy._animation_player != null:
		game._boss_enemy._animation_player.pause()
	for frame in range(6):
		await process_frame
	if not game._pencil_screen_pass.visible or not manager._composite.visible or not manager.spotlight.visible:
		_fail("Ground floor unexpectedly hides Pencil, mask, or flashlight beam")
		return

	var ground_path := output_dir.path_join("ground.png")
	if not await _capture(ground_path):
		quit(1)
		return
	if not _compare_to_stage5(ground_path, baseline_dir.path_join("ground.png"), game, "ground"):
		quit(1)
		return
	var before_path := output_dir.path_join("beam-before-wall.png")
	if not await _capture(before_path):
		quit(1)
		return
	var camera := game.camera as Camera3D
	var axis_world := manager.beam_origin + manager.beam_direction * 14.0
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var expected_before := camera.unproject_position(axis_world) * Vector2(root.size) / viewport_size
	var before_image := root.get_texture().get_image()
	var before_blue := _sample_blue_max(before_image, expected_before, 5)
	_check(before_blue > 0.12, "blue beam is visible in front of the wall")

	var wall := MeshInstance3D.new()
	wall.name = "Stage6OpaqueBeamOccluder"
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(30.0, 30.0, 0.15)
	wall.mesh = wall_box
	var wall_material := StandardMaterial3D.new()
	wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_material.albedo_color = Color.BLACK
	wall.material_override = wall_material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(wall)
	wall.global_position = manager.beam_origin + manager.beam_direction * 8.5
	wall.global_basis = Basis.looking_at(manager.beam_direction, Vector3.UP)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var after_image := root.get_texture().get_image()
	var after_blue := _sample_blue_max(after_image, expected_before, 5)
	var behind_path := output_dir.path_join("beam-behind-wall.png")
	if not _save_image(after_image, behind_path):
		quit(1)
		return
	print("STAGE6_WALL_PIXEL " + JSON.stringify({
		"before_blue_max": before_blue, "behind_blue_max": after_blue,
		"screen": expected_before, "size": after_image.get_size(),
	}))
	_check(after_blue < before_blue * 0.70, "opaque wall removes the far beam behind it")

	if _failures.is_empty():
		print("PASS: Stage 6 roof/ground comparison and beam wall occlusion")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: Stage 6 visual comparison (%d failures)" % _failures.size())
		quit(1)

func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("No Compatibility frame to capture: " + path)
		return false
	return _save_image(image, path)

func _save_image(image: Image, path: String) -> bool:
	var error := image.save_png(path)
	if error != OK:
		push_error("Cannot save Compatibility frame %s: %s" % [path, error_string(error)])
		return false
	print("STAGE6_VISUAL_CAPTURE " + JSON.stringify({"path": path, "size": image.get_size()}))
	return true

func _compare_to_stage5(current_path: String, baseline_path: String, game: Node, label: String) -> bool:
	var current := Image.load_from_file(current_path)
	var baseline := Image.load_from_file(baseline_path)
	if current == null or current.is_empty() or baseline == null or baseline.is_empty():
		_fail("Cannot load %s or its Stage 5 baseline capture" % label)
		return false
	if current.get_size() != baseline.get_size():
		_fail("%s size differs from Stage 5 baseline: %s vs %s" % [label, current.get_size(), baseline.get_size()])
		return false
	var camera := game.camera as Camera3D
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var excluded: Array[Rect2] = []
	for actor in [game.player, game._boss_enemy]:
		if not is_instance_valid(actor):
			continue
		var screen := camera.unproject_position(actor.global_position + Vector3.UP * 1.05)
		screen *= Vector2(current.get_size()) / viewport_size
		excluded.append(Rect2(screen - Vector2(105.0, 155.0), Vector2(210.0, 310.0)))
	var compared := 0
	var changed_over_one_lsb := 0
	var changed_over_two_lsb := 0
	var max_delta_lsb := 0
	for y in range(current.get_height()):
		for x in range(current.get_width()):
			var point := Vector2(x, y)
			var skip := false
			for rect in excluded:
				if rect.has_point(point):
					skip = true
					break
			if skip:
				continue
			compared += 1
			var a := current.get_pixel(x, y)
			var b := baseline.get_pixel(x, y)
			var delta := maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
			var lsb_delta := roundi(delta * 255.0)
			max_delta_lsb = maxi(max_delta_lsb, lsb_delta)
			if lsb_delta > 1:
				changed_over_one_lsb += 1
			if lsb_delta > 2:
				changed_over_two_lsb += 1
	var ratio := float(changed_over_one_lsb) / maxf(float(compared), 1.0)
	print("STAGE6_BASELINE_IMAGE_COMPARE " + JSON.stringify({
		"view": label, "compared_static_pixels": compared,
		"changed_over_1_lsb": changed_over_one_lsb,
		"changed_over_2_lsb": changed_over_two_lsb,
		"max_delta_lsb": max_delta_lsb,
		"changed_ratio": snappedf(ratio, 0.000001),
	}))
	_check(ratio <= 0.001, "%s remains within 0.1 percent changed static pixels vs Stage 5" % label)
	return _failures.is_empty()

func _sample_blue_max(image: Image, screen_point: Vector2, radius: int) -> float:
	var center := Vector2i(roundi(screen_point.x), roundi(screen_point.y))
	var maximum := 0.0
	for y in range(maxi(0, center.y - radius), mini(image.get_height(), center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(image.get_width(), center.x + radius + 1)):
			maximum = maxf(maximum, image.get_pixel(x, y).b)
	return maximum

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _fail(message: String) -> void:
	_failures.append(message)
	for failure in _failures:
		push_error(failure)
	print("FAIL: Stage 6 visual comparison (%d failures)" % _failures.size())
	quit(1)
