extends SceneTree
## Software OpenGL pixel probe for the Compatibility flashlight mask.

const Foundation := preload("res://scripts/foundation.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Foundation.new()
	root.add_child(game)
	for frame in range(12):
		await process_frame
	var player_position: Vector3 = game.player.global_position
	game._boss_enemy.global_position = player_position + Vector3(3.0, 0.05, 5.0)
	game._update_boss_locator()
	var lit_probe := _add_probe(game, player_position + Vector3(0.0, 1.4, -8.0), Color(1.0, 0.05, 0.03))
	# The close shoulder camera no longer shows the old probe behind the
	# character. Place it in view beyond the 30 m flashlight radius instead.
	var dark_probe := _add_probe(game, player_position + Vector3(0.0, 1.2, -34.0), Color(0.02, 1.0, 0.04))
	for scale in [1.0, Foundation.MOBILE_BALANCED_RENDER_SCALE, Foundation.MOBILE_3D_RENDER_SCALE]:
		root.scaling_3d_scale = scale
		for frame in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty(), "Compatibility frame readback is available at %.2fx" % scale)
		if image != null and not image.is_empty():
			var lit_point := game.camera.unproject_position(lit_probe.global_position)
			var dark_point := game.camera.unproject_position(dark_probe.global_position)
			var player_point := game.camera.unproject_position(game.player.global_position + Vector3.UP * 1.15)
			var visible_rect := game.camera.get_viewport().get_visible_rect()
			_check(visible_rect.has_point(lit_point) and visible_rect.has_point(dark_point) and visible_rect.has_point(player_point), "color probes and player remain on screen at %.2fx" % scale)
			var lit_pixel := _sample(image, lit_point)
			var dark_pixel := _sample(image, dark_point)
			var player_pixel := _sample(image, player_point)
			print("FLASHLIGHT_RENDER_SAMPLE " + JSON.stringify({"renderer": "GL Compatibility software desktop", "render_scale": scale, "lit_pixel": lit_pixel, "dark_pixel": dark_pixel, "player_pixel": player_pixel, "lit_uv": lit_point / Vector2(image.get_width(), image.get_height()), "dark_uv": dark_point / Vector2(image.get_width(), image.get_height()), "player_uv": player_point / Vector2(image.get_width(), image.get_height())}))
			_check(lit_pixel.r > 0.45 and lit_pixel.g < 0.35, "red object is visible inside the semicircle at %.2fx" % scale)
			_check(dark_pixel.g < 0.12, "green object is black outside the semicircle at %.2fx" % scale)
			_check(maxf(player_pixel.r, maxf(player_pixel.g, player_pixel.b)) > 0.04, "player remains readable at %.2fx" % scale)
	_check(game.hud._root != null and game.hud._root.visible, "HUD remains visible above the 3D darkness mask")
	_check(game.hud._boss_marker != null and game.hud._boss_marker.visible, "red boss locator remains visible when the boss is outside the flashlight semicircle")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: flashlight Compatibility render mask (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: flashlight Compatibility render mask (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _add_probe(parent: Node, at: Vector3, color: Color) -> MeshInstance3D:
	var probe := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	probe.mesh = sphere
	probe.position = at
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	probe.material_override = material
	probe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(probe)
	return probe

func _sample(image: Image, screen_point: Vector2) -> Color:
	var x := clampi(int(screen_point.x), 0, image.get_width() - 1)
	var y := clampi(int(screen_point.y), 0, image.get_height() - 1)
	return image.get_pixel(x, y)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
