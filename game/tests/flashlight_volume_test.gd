extends SceneTree
## The beam must have height and depth, follow camera pitch/yaw, and stop
## accumulating visible air when an opaque wall interrupts the view ray.

const Visibility := preload("res://scripts/flashlight_visibility.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player := Node3D.new()
	scene.add_child(player)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.55, 4.0)
	camera.current = true
	scene.add_child(camera)
	var manager := Visibility.new()
	manager.configure(player, camera, true)
	scene.add_child(manager)
	manager.set_aim_yaw(0.0)
	_check(manager.spotlight != null and manager.spotlight.visible, "one player-owned 3D spotlight is active")
	_check(is_equal_approx(manager.spotlight.spot_range, Visibility.MAX_RADIUS), "the surface light shares the 30 m beam range")
	_check(manager.get_beam_density(Vector3(0.0, 1.55, -10.0)) > 0.9, "air above the ground lies inside the 3D beam")
	_check(manager.get_beam_density(Vector3(7.0, 1.55, -10.0)) < 0.01, "air well outside the cone remains dark")
	_check(manager.get_beam_density(Vector3(0.0, 1.55, 3.0)) < 0.01, "no beam shines behind the player")
	manager.set_aim_yaw(PI * 0.5)
	_check(manager.get_beam_density(Vector3(-10.0, 1.55, 0.0)) > 0.9, "beam turns with camera yaw")
	manager.set_aim_yaw(0.0)
	camera.rotation.x = deg_to_rad(-16.0)
	manager.set_aim_yaw(0.0)
	_check(manager.beam_direction.y < -0.25, "beam follows camera pitch in three dimensions")
	_check((-manager.spotlight.global_basis.z).distance_to(manager.beam_direction) < 0.001, "light and visible air share an axis")
	camera.rotation.x = 0.0
	manager.set_aim_yaw(0.0)
	# Isolate the scattered air from the old screen oval in this pixel probe.
	manager._material.set_shader_parameter("oval_center_uv", Vector2(-10.0, -10.0))
	manager._material.set_shader_parameter("player_keep_radius", 0.1)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var center := Vector2i(image.get_width() / 2, image.get_height() / 2)
	var sky_light := image.get_pixelv(center)
	var outside := image.get_pixel(int(image.get_width() * 0.06), int(image.get_height() * 0.06))
	_check(sky_light.b > 0.045, "visible shaft glows in empty air without a floor surface")
	_check(outside.b < 0.02, "air outside the beam stays black")
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(8.0, 8.0, 0.3)
	wall.mesh = box
	wall.position = Vector3(0.0, 1.55, -1.5)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color.BLACK
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall.material_override = dark
	scene.add_child(wall)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var behind_wall := root.get_texture().get_image().get_pixelv(center)
	_check(behind_wall.b < sky_light.b * 0.6, "depth stops the air beam behind an opaque wall")
	print("FLASHLIGHT_VOLUME_SAMPLE " + JSON.stringify({"open_air": sky_light, "off_axis": outside, "wall": behind_wall}))
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: 3D flashlight volume (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: 3D flashlight volume (%d/%d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
