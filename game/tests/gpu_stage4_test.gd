extends SceneTree
## Stage 4 resource, culling and full-scene rendering invariants.

const WORLD := preload("res://scenes/foundation.tscn")
const BEAM_SECTIONS := preload("res://shaders/flashlight_beam_sections.gdshader")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error("Stage 4: " + message)

func _run() -> void:
	var world := WORLD.instantiate()
	root.add_child(world)
	await process_frame
	var batches := get_nodes_in_group("courtyard_static_batch")
	var instances := 0
	var shared_mesh: Mesh
	var skyline_found := false
	var skyline_bounds_found := false
	for node in batches:
		var visual := node as MultiMeshInstance3D
		check(visual != null and visual.multimesh != null and visual.custom_aabb.has_volume(),
			"courtyard cells have renderable bounds")
		if visual == null or visual.multimesh == null:
			continue
		instances += visual.multimesh.instance_count
		if shared_mesh == null:
			shared_mesh = visual.multimesh.mesh
		check(visual.multimesh.mesh == shared_mesh, "cells reuse one unit box mesh")
		check(visual.material_override in world._ruin_materials.values(), "cells reuse original ruin materials")
		if (visual.global_transform * visual.custom_aabb).has_point(Vector3(-12.5, 7.0, -37.0)):
			skyline_bounds_found = true
		# The headless dummy RenderingServer does not read back MultiMesh
		# transforms. Exercise their exact positions in rendered CI instead.
		if Engine.get_frames_drawn() > 0:
			for index in range(visual.multimesh.instance_count):
				var position := (visual.global_transform * visual.multimesh.get_instance_transform(index)).origin
				if position.distance_to(Vector3(-12.5, 7.0, -37.0)) < 0.001:
					skyline_found = true
	check(instances == 62, "all 62 decorative boxes remain present")
	check(batches.size() < instances and batches.size() > 1, "nearby cells batch boxes without merging the whole map")
	check(skyline_bounds_found and (Engine.get_frames_drawn() == 0 or skyline_found),
		"distant skyline retains its world transform and culling bounds")
	check(world.get_node_or_null("BrokenPillarA") is StaticBody3D and
		(world.get_node("BrokenPillarA") as StaticBody3D).get_child(0) is CollisionShape3D,
		"collidable cover is still physical")
	check(world._spawn_blockers.size() == 35, "concealed spawn blockers include the unchanged skyline and tower")
	if not batches.is_empty():
		var near := batches[0] as MultiMeshInstance3D
		var at := (near.global_transform * near.multimesh.get_instance_transform(0)).origin
		world.player.global_position = at
		world._apply_distance_visibility(near)
		check(near.visible, "batch stays visible when a player is next to one of its boxes")
		world.player.global_position = Vector3(500.0, 0.0, 500.0)
		world._apply_distance_visibility(near)
		check(not near.visible, "offscreen cell is distance culled")
	world.player.global_position = world.PLAYER_BASE_POSITION
	check(not world._pencil_screen_pass.visible and not world.flashlight_visibility_manager.spotlight.visible,
		"roof has neither Pencil Sketch nor flashlight")
	world._set_rooftop_render_profile(false)
	check(world._pencil_screen_pass.visible and world.flashlight_visibility_manager.spotlight.visible,
		"ground restores both Pencil Sketch and the full 3D flashlight")
	var sheets := world.flashlight_visibility_manager.spotlight.get_node_or_null("PlayerFlashlightBeamSheets") as MultiMeshInstance3D
	check(sheets != null and sheets.multimesh.instance_count == 3, "all crossed 3D beam sheets remain")
	check(BEAM_SECTIONS.code.contains("if (radial >= 1.0)") and BEAM_SECTIONS.code.contains("ALPHA = section_opacity"),
		"only zero-opacity section corners skip blending")
	check(world.horde_far_visuals.rig_budget == 7 and world.spawn_director.ordinary_population_count() == 4,
		"seven-rig budget and four rooftop data records remain")
	for name in ["Bark_DeadTree.png", "Bark_DeadTree_Normal.png", "Rocks_Diffuse.png"]:
		var texture_path: String = "res://assets/environment/nature/" + name
		var texture := load(texture_path) as Texture2D
		var config := ConfigFile.new()
		check(config.load(texture_path + ".import") == OK, name + " has tracked import settings")
		check(texture != null and texture.get_image().has_mipmaps(), name + " has distance mipmaps")
		check(int(config.get_value("params", "compress/mode", -1)) == 2, name + " has VRAM compression")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: GPU stage 4 resources and geometry (%d checks; %d boxes in %d cells)" % [checks, instances, batches.size()])
	else:
		print("FAIL: GPU stage 4 resources and geometry (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
