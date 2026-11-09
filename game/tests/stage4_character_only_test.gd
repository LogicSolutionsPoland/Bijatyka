extends SceneTree
## Stage 4: character-only Sketch, restoration and no environment conversion.
const STYLE_META := &"_pencil_sketch_materials_processed"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("Stage4 Sketch: " + label)

func _make_mesh(label: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = BoxMesh.new()
	instance.material_override = StandardMaterial3D.new()
	return instance

func _run() -> void:
	var style := root.get_node_or_null("PencilSketchStyle")
	_check(style != null, "PencilSketchStyle autoload exists")
	if style == null:
		_finish()
		return
	style.set_gameplay_pencil_enabled(false)
	style.set_character_only(true)
	var environment := Node3D.new()
	environment.name = "Environment"
	var ground := _make_mesh("Ground")
	environment.add_child(ground)
	root.add_child(environment)
	var actor := Node3D.new()
	actor.name = "TestPlayer"
	actor.add_to_group("player")
	var actor_visual := Node3D.new()
	actor_visual.name = "VisualRoot"
	var actor_mesh := _make_mesh("PlayerMesh")
	actor_visual.add_child(actor_mesh)
	actor.add_child(actor_visual)
	root.add_child(actor)
	var enemy := Node3D.new()
	enemy.name = "TestEnemy"
	enemy.add_to_group("enemies")
	var enemy_visual := Node3D.new()
	enemy_visual.name = "VisualRoot"
	var enemy_mesh := _make_mesh("EnemyMesh")
	enemy_visual.add_child(enemy_mesh)
	enemy.add_child(enemy_visual)
	root.add_child(enemy)
	var base_ground := ground.material_override
	var base_actor := actor_mesh.material_override
	var base_enemy := enemy_mesh.material_override
	style.set_gameplay_pencil_enabled(true)
	for frame in range(12):
		await process_frame
	_check(actor_mesh.has_meta(STYLE_META), "player visual receives Sketch")
	_check(enemy_mesh.has_meta(STYLE_META), "zombie visual receives Sketch")
	_check(not ground.has_meta(STYLE_META), "ground does not receive Sketch")
	_check(ground.material_override == base_ground, "ground material is not replaced")
	_check(actor_mesh.material_override != base_actor, "player material is converted")
	_check(enemy_mesh.material_override != base_enemy, "zombie material is converted")
	style.set_gameplay_pencil_enabled(false)
	_check(actor_mesh.material_override == base_actor, "player material restored on rooftop")
	_check(enemy_mesh.material_override == base_enemy, "zombie material restored on rooftop")
	_check(not actor_mesh.has_meta(STYLE_META) and not enemy_mesh.has_meta(STYLE_META), "style metadata cleared on rooftop")
	_check(not root.has_node("PencilScreenPass"), "no root-level fullscreen Pencil pass")
	actor.queue_free()
	enemy.queue_free()
	environment.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("PASS: stage4 character-only Sketch (%d checks)" % checks)
		quit(0)
	else:
		print("FAIL: stage4 character-only Sketch (%d of %d failed)" % [failures.size(), checks])
		quit(1)
