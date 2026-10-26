extends SceneTree
## Compatibility software-rendered probe of the actual playable foundation.

const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")
const PENCIL := preload("res://scripts/pencil.gd")
const OUTPUT := "res://../build/pencil_visual_qa/gameplay.png"

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := FOUNDATION_SCENE.instantiate()
	root.add_child(game)
	await create_timer(0.7).timeout
	_check(RenderingServer.get_current_rendering_method() == "gl_compatibility", "GL Compatibility renderer")
	var enemies: Array[FoundationEnemy] = []
	for child in game.get_children():
		if child is FoundationEnemy and not child.is_boss:
			enemies.append(child)
	_check(enemies.size() == 5, "exactly five active ordinary zombies")
	if enemies.size() != 5:
		_finish(game)
		return
	game._boss_enemy.visible = false
	game._boss_enemy.set_physics_process(false)
	for index in range(5):
		var enemy := enemies[index]
		enemy.set_physics_process(false)
		enemy.global_position = game.player.global_position + Vector3((index - 2) * 2.25, 0.0, -8.0 - float(index % 2) * 1.7)
		# The normal horde scheduler promotes these actors as they enter 16 m.
		# Promote synchronously so this frozen screenshot exercises the same rigs.
		enemy.set_flashlight_render_visible(true)
		enemy._set_distance_detail(enemy.global_position.distance_to(game.player.global_position))
		enemy._set_full_animation_selected(true)
	for frame in range(3):
		await process_frame
	for index in range(5):
		var enemy := enemies[index]
		var styled := false
		for visual in enemy.find_children("*", "MeshInstance3D", true, false):
			var mesh := visual as MeshInstance3D
			if mesh.mesh != null and PENCIL.is_pencil(mesh.get_active_material(0)):
				styled = true
				break
		_check(styled, "ordinary zombie %d has the source graphite material" % index)
	game._update_distance_visibility()
	game.flashlight_visibility_manager._classify_enemies()
	var screen_pass := game.camera.get_node_or_null("PencilScreenPass") as MeshInstance3D
	_check(screen_pass != null and screen_pass.visible, "pencil screen pass is attached to the active camera")
	if screen_pass == null:
		_finish(game)
		return
	_check(PENCIL.add_screen_pass(game.camera) == screen_pass.material_override, "screen pass is idempotent")
	_check(get_nodes_in_group("pencil_screen_pass").size() == 1, "only one pencil screen pass")
	_check((screen_pass.material_override as ShaderMaterial).shader.resource_path == "res://shaders/pencil_screen.gdshader", "Compatibility screen shader selected")
	game.player.request_attack("punch", "right")
	await create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	var with_pencil := root.get_texture().get_image()
	_check(with_pencil != null and not with_pencil.is_empty(), "rendered gameplay image exists")
	if with_pencil == null or with_pencil.is_empty():
		_finish(game)
		return
	var output := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	_check(with_pencil.save_png(output) == OK, "gameplay evidence saved")
	screen_pass.visible = false
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var without_pencil := root.get_texture().get_image()
	screen_pass.visible = true
	var changed := 0
	var sampled := 0
	for y in range(80, min(620, with_pencil.get_height()), 6):
		for x in range(70, min(1150, with_pencil.get_width()), 6):
			var a := with_pencil.get_pixel(x, y)
			var b := without_pencil.get_pixel(x, y)
			if abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b) > 0.075:
				changed += 1
			sampled += 1
	print("PENCIL_RENDER_EVIDENCE " + JSON.stringify({"path": output, "changed_pixels": changed, "sampled_pixels": sampled, "ordinary_zombies": enemies.size(), "renderer": RenderingServer.get_current_rendering_method()}))
	_check(changed > sampled * 0.05, "pencil pass visibly changes more than five percent of the gameplay region")
	_finish(game)

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)

func _finish(game: Node) -> void:
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: visible Pencil Sketch Compatibility gameplay")
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: Pencil Sketch gameplay (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
