extends SceneTree
## Isolated GL Compatibility pixel check of the teeth-only screen overlay.
## The existing flashlight/character test checks the world-space range.
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
	var manager := game.flashlight_visibility_manager
	_check(manager != null and is_instance_valid(manager._teeth_overlay), "tooth overlay exists in gameplay")
	_check(manager._teeth_canvas.layer == 0, "tooth overlay draws on its own CanvasLayer")
	manager.set_process(false)
	game.hud._root.visible = false
	var viewport_size := root.get_visible_rect().size
	var center := viewport_size * Vector2(0.78, 0.18)
	_check(manager.get_oval_weight(center / viewport_size) < 0.001, "render test point is outside the flashlight oval")

	var empty_points: Array[Dictionary] = []
	manager._teeth_overlay.call("set_glints", empty_points)
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var dark := root.get_texture().get_image()
	_check(dark != null and not dark.is_empty(), "Compatibility dark frame readback succeeded")
	var baseline := _max_brightness(dark, center, 12)

	var bright_points: Array[Dictionary] = [{"center": center, "strength": 1.0, "scale": 3.0}]
	manager._teeth_overlay.call("set_glints", bright_points)
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var glint := root.get_texture().get_image()
	_check(glint != null and not glint.is_empty(), "Compatibility glint frame readback succeeded")
	var illuminated := _max_brightness(glint, center, 12)
	print("TEETH_GLINT_RENDER_SAMPLE " + JSON.stringify({"baseline": baseline, "glint": illuminated, "uv": center / viewport_size}))
	_check(illuminated > baseline + 0.20, "visible tooth strokes render above the oval blackout")

	manager._teeth_overlay.call("set_glints", empty_points)
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var cleared := _max_brightness(root.get_texture().get_image(), center, 12)
	_check(cleared < illuminated - 0.20, "tooth overlay fully disappears when glints are cleared")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: zombie teeth Compatibility glint overlay (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: zombie teeth Compatibility glint overlay (%d of %d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _max_brightness(img: Image, center: Vector2, radius: int) -> float:
	if img == null or img.is_empty():
		return 0.0
	var brightest := 0.0
	var x0 := maxi(int(center.x) - radius, 0)
	var x1 := mini(int(center.x) + radius, img.get_width() - 1)
	var y0 := maxi(int(center.y) - radius, 0)
	var y1 := mini(int(center.y) + radius, img.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var pixel := img.get_pixel(x, y)
			brightest = maxf(brightest, maxf(pixel.r, maxf(pixel.g, pixel.b)))
	return brightest

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
