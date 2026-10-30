extends SceneTree
## Pixel check for the actual 3D flashlight shaft in the Compatibility renderer.

const VisibilityManager := preload("res://scripts/flashlight_visibility.gd")

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 720)
	var world := Node3D.new()
	world.name = "FlashlightBeamPixelWorld"
	root.add_child(world)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)

	var player := Node3D.new()
	player.name = "BeamTestPlayer"
	world.add_child(player)

	var camera := Camera3D.new()
	camera.name = "BeamTestCamera"
	camera.fov = 66.0
	world.add_child(camera)
	camera.global_position = Vector3(0.0, 4.0, 9.0)
	camera.look_at(Vector3(0.0, 1.55, -7.0), Vector3.UP)
	camera.current = true

	var manager := VisibilityManager.new()
	world.add_child(manager)
	manager.configure(player, camera, true)
	manager.set_rooftop_sky_visible(false)
	# Measure the cross-sections themselves, independent of the screen overlay.
	manager._composite.visible = false
	for node in manager.spotlight.find_children("PlayerFlashlightBeamSheet*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = false

	var sections := manager.spotlight.get_node_or_null("PlayerFlashlightBeamSections") as MeshInstance3D
	_check(sections != null and sections.mesh != null, "flashlight creates the depth-tested shaft cross-sections")
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	var axis_point := manager.beam_origin + manager.beam_direction * 14.0
	# The project viewport can differ from the captured root image when the
	# test sets root.size (notably on software Compatibility rendering).
	var beam_screen := camera.unproject_position(axis_point) * Vector2(image.get_size()) / camera.get_viewport().get_visible_rect().size
	_check(Rect2(Vector2.ZERO, Vector2(image.get_width(), image.get_height())).has_point(beam_screen), "beam axis projects inside the view")
	var visible_blue := _sample_blue_max(image, beam_screen, 4)
	print("FLASHLIGHT_AIR_BEAM_PIXEL " + JSON.stringify({"blue": visible_blue, "screen": beam_screen, "size": image.get_size()}))
	_check(visible_blue > 0.12, "a blue shaft is visible in air along the camera aim")

	# A black wall before the far sections should leave only the near sections
	# visible. The beam must not draw through the opaque depth buffer.
	var wall := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(30.0, 30.0, 0.15)
	wall.mesh = wall_box
	var wall_material := StandardMaterial3D.new()
	wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_material.albedo_color = Color.BLACK
	wall.material_override = wall_material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(wall)
	wall.global_position = manager.beam_origin + manager.beam_direction * 8.5
	wall.global_basis = Basis.looking_at(manager.beam_direction, Vector3.UP)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var blocked_image := root.get_texture().get_image()
	var blocked_blue := _sample_blue_max(blocked_image, beam_screen, 4)
	print("FLASHLIGHT_WALL_CUTOFF_PIXEL " + JSON.stringify({"before": visible_blue, "after": blocked_blue}))
	_check(blocked_blue < visible_blue * 0.70, "opaque wall cuts off the far flashlight shaft")

	# The real rooftop has a bright, warm city panorama. Probe the live
	# composite and the entire beam against warm sky with the geometry off/on:
	# a black-background probe alone cannot catch additive glow washing out.
	wall.queue_free()
	await process_frame
	sections.visible = false
	environment.background_color = Color(0.72, 0.46, 0.34)
	manager.set_rooftop_sky_visible(true)
	manager._composite.visible = true
	var off_axis := Vector2(image.get_width() * 0.85, image.get_height() * 0.3)
	var near_axis := camera.unproject_position(manager.beam_origin + manager.beam_direction * 4.5) * Vector2(image.get_size()) / camera.get_viewport().get_visible_rect().size
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var warm_image := root.get_texture().get_image()
	var warm_axis := warm_image.get_pixelv(Vector2i(beam_screen))
	var warm_near := warm_image.get_pixelv(Vector2i(near_axis))
	var warm_off_axis := warm_image.get_pixelv(Vector2i(off_axis))
	sections.visible = true
	for node in manager.spotlight.find_children("PlayerFlashlightBeamSheet*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).visible = true
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var roof_image := root.get_texture().get_image()
	var roof_axis := roof_image.get_pixelv(Vector2i(beam_screen))
	var roof_near := roof_image.get_pixelv(Vector2i(near_axis))
	var roof_off_axis := roof_image.get_pixelv(Vector2i(off_axis))
	print("FLASHLIGHT_ROOF_AIR_PIXEL " + JSON.stringify({"beam": roof_axis, "sky_only": warm_axis, "near": roof_near, "near_sky_only": warm_near, "outside": roof_off_axis}))
	_check(roof_axis.b > warm_axis.b + 0.07, "the shaft is visible above the floor against a bright rooftop sky")
	_check(roof_near.b > warm_near.b + 0.07, "the air shaft is visible near the player, before the rooftop rail")
	_check(absf(roof_off_axis.b - warm_off_axis.b) < 0.025, "rooftop sky outside the shaft is unchanged")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: visible flashlight air beam (%d checks)" % 7)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: visible flashlight air beam (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _sample_blue_max(image: Image, screen_point: Vector2, radius: int) -> float:
	var center := Vector2i(roundi(screen_point.x), roundi(screen_point.y))
	var maximum := 0.0
	for y in range(maxi(0, center.y - radius), mini(image.get_height(), center.y + radius + 1)):
		for x in range(maxi(0, center.x - radius), mini(image.get_width(), center.x + radius + 1)):
			maximum = maxf(maximum, image.get_pixel(x, y).b)
	return maximum

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
