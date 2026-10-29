extends SceneTree
## Deterministic silhouette/cover pixel checks on the Android Compatibility path.

const Visibility := preload("res://scripts/flashlight_visibility.gd")
const Reveal := preload("res://scripts/flashlight_enemy_reveal.gd")

class EnemyProbe extends Node3D:
	var meshes: Array[MeshInstance3D] = []
	func set_flashlight_render_visible(value: bool) -> void:
		for mesh in meshes:
			mesh.visible = value
	func set_flashlight_full_body_visible(value: bool) -> void:
		for mesh in meshes:
			Reveal.set_mesh_revealed(mesh, value)

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
	scene.add_child(camera)
	camera.position = Vector3(0.0, 1.0, 6.0)
	camera.current = true
	var manager := Visibility.new()
	manager.configure(player, camera, true)
	scene.add_child(manager)
	manager.set_process(false)
	var enemy := EnemyProbe.new()
	scene.add_child(enemy)
	var size := camera.get_viewport().get_visible_rect().size
	enemy.position = camera.project_position(size * Vector2(0.735, 0.60), 14.0) - Vector3.UP * 1.1
	for part in [
		[Vector3(0, 1.25, 0), Vector3(0.7, 0.9, 0.4)],
		[Vector3(0, 1.95, 0), Vector3(0.46, 0.5, 0.46)],
		[Vector3(-0.68, 1.25, 0), Vector3(0.5, 0.24, 0.24)],
		[Vector3(0.68, 1.25, 0), Vector3(0.5, 0.24, 0.24)],
		[Vector3(-0.20, 0.44, 0), Vector3(0.22, 0.85, 0.22)],
		[Vector3(0.20, 0.44, 0), Vector3(0.22, 0.85, 0.22)],
	]:
		enemy.meshes.append(_box(enemy, part[0], part[1], Color(1.0, 0.03, 0.02)))
	manager.track_enemy(enemy)
	var environment_probe := _box(scene, camera.project_position(size * Vector2(0.80, 0.60), 14.0), Vector3.ONE * 0.25, Color.GREEN)
	await physics_frame
	manager._classify_enemies()
	_check(manager.is_visible_to_flashlight(enemy), "only a side of the body needs to enter the beam")
	for scale in [1.0, 0.67, 0.50]:
		root.scaling_3d_scale = scale
		for frame in range(6):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		for part in [enemy.meshes[3], enemy.meshes[5]]:
			var screen_point := camera.unproject_position(part.global_position)
			_check(manager.get_oval_weight(screen_point / size) <= 0.01, "sampled limb is outside the oval at %.2fx" % scale)
			var color := _sample(image, screen_point)
			_check(color.r > 0.75 and color.g < 0.15, "entire arm/leg stays visible beyond the oval at %.2fx" % scale)
		var ground_color := _sample(image, camera.unproject_position(environment_probe.global_position))
		_check(ground_color.g < 0.03, "nearby environment stays black at %.2fx" % scale)
		print("WHOLE_ENEMY_RENDER_SAMPLE " + JSON.stringify({"scale": scale, "arm": _sample(image, camera.unproject_position(enemy.meshes[3].global_position)), "environment": ground_color}))
	# A narrow wall covers the unlit arm while another part remains in the beam.
	var cover := StaticBody3D.new()
	cover.collision_layer = 1
	cover.position = camera.position.lerp(enemy.meshes[3].global_position, 0.5)
	scene.add_child(cover)
	_box(cover, Vector3.ZERO, Vector3(0.32, 0.32, 0.3), Color.BLUE)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.32, 0.32, 0.3)
	collider.shape = shape
	cover.add_child(collider)
	await physics_frame
	manager._classify_enemies()
	_check(manager.is_visible_to_flashlight(enemy), "partially covered enemy still touches the beam")
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var covered := _sample(root.get_texture().get_image(), camera.unproject_position(enemy.meshes[3].global_position))
	_check(covered.r < 0.03 and covered.b < 0.03, "a wall occludes the revealed limb and stays dark itself")
	enemy.position.x += 8.0
	manager._classify_enemies()
	_check(not manager.is_visible_to_flashlight(enemy), "leaving the light disables the whole-body reveal")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: flashlight whole enemy Compatibility pixels (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func _sample(image: Image, at: Vector2) -> Color:
	return image.get_pixel(clampi(int(at.x), 0, image.get_width() - 1), clampi(int(at.y), 0, image.get_height() - 1))

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
