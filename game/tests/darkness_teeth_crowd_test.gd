extends SceneTree
## Headless structural regression for the visual-only synthetic teeth horde.
## Run: godot --headless --path game --script res://tests/darkness_teeth_crowd_test.gd

const TEETH_OVERLAY := preload("res://scripts/distant_zombie_teeth.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var camera := Camera3D.new()
	var player := Node3D.new()
	root.add_child(player)
	root.add_child(camera)
	var overlay := TEETH_OVERLAY.new()
	root.add_child(overlay)
	overlay.configure(camera, player, null)

	_check(overlay.get_synthetic_mouth_count() == 420,
		"visual teeth population does not depend on real enemy or spawn count")
	var synthetic: Array = overlay.get("_synthetic_mouths")
	var offsets_before: Array[Vector3] = []
	var inside_minimum := false
	for entry_variant in synthetic:
		var entry: Dictionary = entry_variant
		var offset: Vector3 = entry["offset"]
		offsets_before.append(offset)
		var distance := Vector2(offset.x, offset.z).length()
		if distance < 14.0 - 0.001 or distance > 68.0 + 0.001:
			inside_minimum = true
	_check(not inside_minimum, "all synthetic teeth stay beyond 10 m flashlight range")

	var texture: Texture2D = overlay.get("_mouth_texture")
	_check(texture != null and texture.get_width() == 96 and texture.get_height() == 48,
		"all masks share one 96x48 texture")
	if texture != null:
		var image := texture.get_image()
		var visible_pixels := 0
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				if image.get_pixel(x, y).a > 0.5:
					visible_pixels += 1
		_check(visible_pixels > 100, "teeth texture contains visible tooth-shaped pixels")

	var real_points: Array[Dictionary] = []
	overlay.set_glints(real_points)
	overlay._process(1.0)
	var bright_points: Array[Dictionary] = [{"center": Vector2(100.0, 100.0), "strength": 1.0, "scale": 1.0}]
	overlay.set_glints(bright_points)
	overlay._process(1.0)
	overlay.set_glints(real_points)
	_check(overlay.get_synthetic_mouth_count() == 420,
		"clearing real enemy glints never clears the synthetic crowd")
	var unchanged := true
	var after: Array = overlay.get("_synthetic_mouths")
	for index in range(after.size()):
		var at: Dictionary = after[index]
		if at["offset"] != offsets_before[index]:
			unchanged = false
			break
	_check(unchanged, "synthetic positions remain stable across redraws and animation")

	overlay.queue_free()
	camera.queue_free()
	player.queue_free()
	await process_frame
	for message in _failures:
		push_error(message)
	print("%s: darkness teeth crowd (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(description)
