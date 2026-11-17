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
	_check(game.burning_horizon.get_child_count() == 1, "Zombie Fog Horizon uses one circular mesh, not four panels")
	var horizon_wall := game.burning_horizon.get_child(0) as MeshInstance3D
	var horizon_ring := horizon_wall.mesh as CylinderMesh if horizon_wall != null else null
	_check(horizon_ring != null and horizon_ring.radial_segments == 96, "horizon has 96 mesh segments")
	_check(horizon_ring != null and is_equal_approx(horizon_ring.top_radius, 10.0), "horizon uses the shared 10 m range")
	_check(horizon_wall != null and horizon_wall.material_override is ShaderMaterial, "ring uses a shared animated fog shader")
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
			_check(batch.custom_aabb.has_volume(), "city cells have nonempty culling bounds")
		elif child is MultiMeshInstance3D and child.is_in_group("nature_scenery_batch"):
			var nature := child as MultiMeshInstance3D
			nature_batches += 1
			nature_instances += nature.multimesh.instance_count
			_check(nature.multimesh.mesh != null and nature.multimesh.mesh.get_surface_count() > 0, "nature uses imported meshes")
			_check(nature.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "nature casts no shadows")
	_check(district_batches > 7 and district_boxes > 500, "expanded city adds spatially batched streets and ruins")
	_check(nature_batches == 9 and nature_instances == 62, "nine Zasoby nature models cover the wider district in batched instances")
	var obstacle_bounds: Array[AABB] = district.get("collision_bounds")
	_check(obstacle_bounds.size() == 32, "sixteen building cores and sixteen wrecks are physical cover")
	_check(game._spawn_blockers.size() == 67, "city cover is registered before zombie spawning")
	_check(game.get_tree().get_nodes_in_group("ruined_city_obstacle").size() == 32,
		"city cover has collision bodies")
	var space := game.get_world_3d().direct_space_state
	var building_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(44.0, 18.0, -48.0), Vector3(44.0, -2.0, -48.0), 1))
	var wreck_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(25.0, 10.0, -39.0), Vector3(25.0, -2.0, -39.0), 1))
	var street_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(
		Vector3(0.0, 10.0, 54.0), Vector3(0.0, -2.0, 54.0), 1))
	_check(not building_hit.is_empty() and building_hit.collider.is_in_group("ruined_city_obstacle"),
		"burned buildings physically block the player and enemies")
	_check(not wreck_hit.is_empty() and wreck_hit.collider.is_in_group("ruined_city_obstacle"),
		"wrecked vehicles physically block the player and enemies")
	_check(not street_hit.is_empty() and street_hit.collider == game.get_node("QuarantineCourtyardGround"),
		"the extended south street remains passable ground")
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
