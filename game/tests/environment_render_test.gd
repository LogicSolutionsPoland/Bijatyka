extends SceneTree

const Foundation := preload("res://scripts/foundation.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Foundation.new()
	root.add_child(game)
	await process_frame
	var concrete := game._material(Color(0.24, 0.255, 0.27), 0.93)
	_check(concrete == game._material(Color(0.24, 0.255, 0.27), 0.93), "matching ruin materials are shared")
	_check(concrete != game._material(Color(0.075, 0.085, 0.10), 0.98), "different ruin surfaces retain their colors")
	var fire := Color(1.0, 0.29, 0.08)
	_check(game._emissive_material(fire) == game._emissive_material(fire), "matching fire emissive materials are shared")
	_check(game._emissive_material(fire) != game._emissive_material(Color(0.23, 0.60, 0.78)), "different light colors remain separate")
	# Both installed brazier flame meshes should use the exact same resource.
	var flames: Array[MeshInstance3D] = []
	for node in game.find_children("*", "MeshInstance3D", true, false):
		if node is MeshInstance3D and node.position.y > 1.0:
			if node.material_override == game._emissive_material(fire):
				flames.append(node)
	_check(flames.size() == 2, "both brazier flames use one prepared material")
	# The starting tower adds two shared finishes to the original arena set.
	_check(game._ruin_materials.size() <= 10, "arena and rooftop tower use a small set of shared ruin materials")
	_check(game.burning_horizon.get_child_count() == 4, "Burning Horizon retains four panels")
	_check(game.burning_horizon.get_child(0).material_override == game.burning_horizon.get_child(1).material_override, "horizon panels share their material")
	_check(game.get_node("QuarantineCourtyardGround") != null, "ground and collision remain")
	var district := game.get_node("AshenQuarantineMap")
	var district_batches := 0
	var district_boxes := 0
	var nature_batches := 0
	var nature_instances := 0
	for child in district.get_children():
		if child is MultiMeshInstance3D and child.is_in_group("static_map_batch"):
			var batch := child as MultiMeshInstance3D
			district_batches += 1
			district_boxes += batch.multimesh.instance_count
			_check(batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "district batches cast no shadows")
		elif child is MultiMeshInstance3D and child.is_in_group("nature_scenery_batch"):
			var nature := child as MultiMeshInstance3D
			nature_batches += 1
			nature_instances += nature.multimesh.instance_count
			_check(nature.multimesh.mesh != null and nature.multimesh.mesh.get_surface_count() > 0, "nature uses imported meshes")
			_check(nature.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "nature casts no shadows")
	_check(district_batches == 7 and district_boxes == 103, "all 103 district boxes share seven material draws")
	_check(nature_batches == 4 and nature_instances == 20, "six trees, eight rocks, six shrubs share four mesh batches")
	_check(Foundation.VISIBILITY_RADIUS == 30.0, "visual edge stays at 30 m")
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: environment materials and visual invariants")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
