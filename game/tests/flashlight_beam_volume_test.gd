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
	var beam_screen := camera.unproject_position(axis_point)
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
	wall.global_position = manager.beam_origin + manager.beam_direction * 8.5
	wall.global_basis = Basis.looking_at(manager.beam_direction, Vector3.UP)
	world.add_child(wall)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var blocked_image := root.get_texture().get_image()
	var blocked_blue := _sample_blue_max(blocked_image, beam_screen, 4)
	print("FLASHLIGHT_WALL_CUTOFF_PIXEL " + JSON.stringify({"before": visible_blue, "after": blocked_blue}))
	_check(blocked_blue < visible_blue * 0.70, "opaque wall cuts off the far flashlight shaft")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: visible flashlight air beam (%d checks)" % 4)
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
