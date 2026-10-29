extends SceneTree
## Whole-body entry/exit, opaque cover, pooled rigs, boss and crowd regression.

const Visibility := preload("res://scripts/flashlight_visibility.gd")
const Reveal := preload("res://scripts/flashlight_enemy_reveal.gd")
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
	var enemy := FoundationEnemy.new()
	scene.add_child(enemy)
	enemy.set_physics_process(false)
	enemy._set_full_animation_selected(true)
	manager.track_enemy(enemy)
	_place(camera, enemy, Vector2(0.44, 0.60), 14.0)
	await physics_frame
	manager._classify_enemies()
	_check(manager.is_visible_to_flashlight(enemy) and enemy._flashlight_full_body_visible, "enemy in the beam reveals its whole body")
	_check(not enemy._base_visual_meshes.is_empty(), "test uses the actual skinned enemy model")
	for mesh in enemy._base_visual_meshes:
		for surface in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(surface)
			_check(material.render_priority > manager._material.render_priority, "enemy surface draws after the black mask")
			_check(material.has_meta(Reveal.SOURCE_META), "revealed surface retains its original textured material")
			_check((material as ShaderMaterial).shader.code.contains("depth_draw_always"), "revealed skin writes depth while drawing after the mask")
	var reused_material := enemy._base_visual_meshes[0].get_active_material(0)
	# Torso lies just outside the oval; one side still touches the light.
	_place(camera, enemy, Vector2(0.735, 0.60), 14.0)
	manager._classify_enemies()
	_check(manager.is_visible_to_flashlight(enemy), "a partially lit side reveals the entire enemy")
	_place(camera, enemy, Vector2(0.94, 0.60), 14.0)
	manager._classify_enemies()
	_check(not manager.is_visible_to_flashlight(enemy) and not enemy._flashlight_full_body_visible, "enemy completely outside the oval is hidden")
	_check(not enemy._visual_root.visible, "leaving the beam hides the detailed rig")
	_check(not enemy._base_visual_meshes[0].get_active_material(0).has_meta(Reveal.SOURCE_META), "leaving the beam restores normal materials")
	_place(camera, enemy, Vector2(0.44, 0.60), 14.0)
	manager._classify_enemies()
	_check(enemy._base_visual_meshes[0].get_active_material(0) == reused_material, "beam re-entry reuses material variants")
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 12.0, 0.5)
	shape.shape = box
	wall.add_child(shape)
	wall.position = (camera.position + enemy.position + Vector3.UP) * 0.5
	scene.add_child(wall)
	await physics_frame
	manager._classify_enemies()
	_check(manager.is_visible_to_flashlight(enemy) and enemy._flashlight_full_body_visible, "cover does not suppress a body whose projection touches the beam")
	wall.queue_free()
	await physics_frame
	await process_frame
	manager._classify_enemies()
	_check(enemy._flashlight_full_body_visible, "removing cover keeps the whole-body reveal")
	enemy.position = Vector3(0.0, 0.0, 8.0)
	manager._classify_enemies()
	_check(not enemy._flashlight_full_body_visible, "enemies behind the player stay dark")
	enemy.position = Vector3(0.0, 0.0, -31.0)
	manager._classify_enemies()
	_check(manager.get_band(enemy) == Visibility.Band.BEYOND_RENDER and not enemy._flashlight_full_body_visible, "whole-body reveal respects the 30 m range")
	_place(camera, enemy, Vector2(0.44, 0.60), 14.0)
	manager._classify_enemies()
	enemy._release_detailed_model()
	enemy._set_full_animation_selected(true)
	_check(enemy._base_visual_meshes[0].get_active_material(0).has_meta(Reveal.SOURCE_META), "newly acquired rig inherits the current reveal state")
	var boss := FoundationEnemy.new()
	boss.configure("boss", true)
	scene.add_child(boss)
	boss.set_physics_process(false)
	manager.track_enemy(boss)
	_place(camera, boss, Vector2(0.44, 0.60), 14.0)
	manager._classify_enemies()
	_check(boss._flashlight_full_body_visible, "boss uses the same whole-body reveal")
	_place(camera, boss, Vector2(0.96, 0.60), 14.0)
	manager._classify_enemies()
	_check(not boss._flashlight_full_body_visible, "boss loses its reveal outside the beam")
	var crowd := HordeFarVisuals.new()
	crowd.configure(5)
	scene.add_child(crowd)
	var crowd_material := crowd.multimesh.mesh.surface_get_material(0) as ShaderMaterial
	_check(crowd_material.render_priority > manager._material.render_priority and crowd_material.shader.code.contains("depth_draw_always"), "distant MultiMesh bodies also cross the mask edge with depth testing")
	manager.enabled = false
	manager._classify_enemies()
	_check(not enemy._flashlight_full_body_visible and manager.is_visible_to_flashlight(enemy), "disabling the flashlight returns normal unmasked rendering")
	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: flashlight whole enemy reveal (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _place(camera: Camera3D, enemy: Node3D, uv: Vector2, depth: float) -> void:
	enemy.global_position = camera.project_position(camera.get_viewport().get_visible_rect().size * uv, depth) - Vector3.UP

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
