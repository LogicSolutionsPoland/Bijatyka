extends SceneTree
## Regression: visual-only floating teeth are removed while real enemy glints work.
## Run: godot --headless --path game --script res://tests/darkness_teeth_crowd_test.gd

const TEETH_OVERLAY := preload("res://scripts/distant_zombie_teeth.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var overlay := TEETH_OVERLAY.new()
	root.add_child(overlay)
	overlay.configure(null, null, null)

	var property_names := {}
	for entry in overlay.get_property_list():
		property_names[String(entry["name"])] = true
	_check(not property_names.has("_synthetic_mouths"), "no synthetic mouth population")
	_check(not property_names.has("_mouth_texture"), "no generated teeth-mask texture")
	_check(not property_names.has("_active_charge_index"), "no scheduled charging mouth")

	var method_names := {}
	for entry in overlay.get_method_list():
		method_names[String(entry["name"])] = true
	_check(not method_names.has("_build_synthetic_mouths"), "no synthetic-mouth generator")
	_check(not method_names.has("_build_mouth_texture"), "no teeth texture generator")
	_check(not method_names.has("_draw_synthetic_horde"), "no synthetic overlay renderer")

	var real_points: Array[Dictionary] = [
		{"center": Vector2(100.0, 100.0), "strength": 1.0, "scale": 1.0}
	]
	overlay.set_glints(real_points)
	var glints: Array = overlay.get("_glints")
	_check(glints.size() == 1 and glints[0]["center"] == Vector2(100.0, 100.0),
		"glints from real tracked zombies remain supported")
	var empty_points: Array[Dictionary] = []
	overlay.set_glints(empty_points)
	_check((overlay.get("_glints") as Array).is_empty(), "clearing real glints removes all overlay content")

	overlay.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	print("%s: darkness teeth removal (%d checks)" % ["PASS" if _failures.is_empty() else "FAIL", _checks])
	quit(0 if _failures.is_empty() else 1)

func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(description)
