extends SceneTree
## Render the actual skinned, pencil-styled boss across the flashlight edge.
## The simple box probe cannot detect a clipped head on an imported GLB.

const Visibility := preload("res://scripts/flashlight_visibility.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := Node3D.new()
	root.add_child(scene)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	scene.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(20.0), 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = false
	scene.add_child(sun)
	var player := Node3D.new()
	scene.add_child(player)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.0, 6.0)
	scene.add_child(camera)
	camera.current = true
	var manager := Visibility.new()
	manager.configure(player, camera, true)
	scene.add_child(manager)
	manager.set_process(false)
	manager.set_aim_yaw(0.0)
	var viewport_size := camera.get_viewport().get_visible_rect().size
	var boss := FoundationEnemy.new()
	boss.configure("boss", true)
	# Put the torso in the oval and the head above its top edge.
	boss.position = camera.project_position(viewport_size * Vector2(0.44, 0.45), 8.0) - Vector3.UP * 1.40
	scene.add_child(boss)
	boss.set_physics_process(false)
	manager.track_enemy(boss)
	var probe := MeshInstance3D.new()
	var probe_mesh := BoxMesh.new()
	probe_mesh.size = Vector3.ONE * 0.4
	probe.mesh = probe_mesh
	probe.position = camera.project_position(viewport_size * Vector2(0.80, 0.30), 7.0)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color.GREEN
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	probe.material_override = green
	scene.add_child(probe)
	await physics_frame
	manager._classify_enemies()
	_check(boss._flashlight_full_body_visible, "actual boss is selected when its projected body touches the beam")
	_check(not boss._base_visual_meshes.is_empty(), "actual skinned GLB is loaded")
	if not boss._base_visual_meshes.is_empty():
		_check(boss._base_visual_meshes[0].get_active_material(0).render_priority > manager._material.render_priority, "boss material is ordered above the darkness pass")
		for body_mesh in boss._base_visual_meshes:
			for surface_index in range(body_mesh.mesh.get_surface_count()):
				var surface_material := body_mesh.get_active_material(surface_index)
				print("BOSS_REVEAL_SURFACE " + JSON.stringify({"mesh": body_mesh.name, "surface": surface_index, "material": surface_material.get_class(), "priority": surface_material.render_priority, "variant": surface_material.has_meta(&"_flashlight_reveal_source"), "shader_head": (surface_material as ShaderMaterial).shader.code.substr(0, 150) if surface_material is ShaderMaterial else "standard"}))
	manager.set_composite_visible_for_comparison(false)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var unmasked := root.get_texture().get_image()
	manager.set_composite_visible_for_comparison(true)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var masked := root.get_texture().get_image()
	_check(not unmasked.is_empty() and not masked.is_empty(), "Compatibility frame readback is available")
	var head_brightness := 0.0
	var retained_brightness := 0.0
	var head_point := Vector2.ZERO
	if not unmasked.is_empty() and not masked.is_empty():
		# The pale head/shoulders cross above the top of the oval, while the
		# torso remains inside it. Search only their horizontal band so the
		# feet, boss ring and the separate green scenery cannot satisfy this.
		for y in range(int(viewport_size.y * 0.15), int(viewport_size.y * 0.39), 2):
			for x in range(int(viewport_size.x * 0.34), int(viewport_size.x * 0.54), 2):
				var uv := Vector2(x, y) / viewport_size
				if manager.get_oval_weight(uv) > 0.01:
					continue
				var brightness := _brightness(unmasked.get_pixel(x, y))
				if brightness > head_brightness:
					head_brightness = brightness
					retained_brightness = _brightness(masked.get_pixel(x, y))
					head_point = Vector2(x, y)
		_check(head_brightness > 0.14, "actual boss head is present above the oval with the mask off")
		if head_brightness > 0.14:
			_check(retained_brightness > head_brightness * 0.60, "the real boss head remains visible after the mask is restored")
		var scenery := masked.get_pixel(int(viewport_size.x * 0.80), int(viewport_size.y * 0.30))
		_check(scenery.g < 0.06, "nearby scenery outside the flashlight stays black")
		manager._material.render_priority = -128
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var early_mask := _brightness(root.get_texture().get_image().get_pixelv(Vector2i(head_point)))
		manager._material.render_priority = 126
		for body_mesh in boss._base_visual_meshes:
			for surface_index in range(body_mesh.mesh.get_surface_count()):
				var pencil := body_mesh.get_active_material(surface_index) as ShaderMaterial
				var standard := StandardMaterial3D.new()
				standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				standard.albedo_color = pencil.get_shader_parameter(&"albedo") as Color
				standard.albedo_texture = pencil.get_shader_parameter(&"albedo_texture") as Texture2D
				standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				standard.render_priority = 127
				body_mesh.set_surface_override_material(surface_index, standard)
		for frame in range(3):
			await process_frame
			await RenderingServer.frame_post_draw
		var standard_masked := _brightness(root.get_texture().get_image().get_pixelv(Vector2i(head_point)))
		print("BOSS_REVEAL_DIAGNOSTIC " + JSON.stringify({"early_mask_head": early_mask, "standard_head": standard_masked}))
	print("BOSS_WHOLE_BODY_RENDER " + JSON.stringify({"boss_lit": boss._flashlight_full_body_visible, "head_pixel": head_point, "head_without_mask": head_brightness, "head_with_mask": retained_brightness}))
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: skinned boss flashlight silhouette (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _brightness(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
