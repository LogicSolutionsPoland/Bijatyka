extends SceneTree

const PLAYER_SCRIPT := preload("res://scripts/player_controller.gd")
const ENEMY_SCRIPT := preload("res://scripts/enemy.gd")
const STYLE_SCRIPT := preload("res://scripts/pencil_sketch_style.gd")
const PENCIL_SHADER := preload("res://shaders/pencil_sketch.gdshader")
const PENCIL_DOUBLE_SIDED_SHADER := preload("res://shaders/pencil_sketch_double_sided.gdshader")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(String(ProjectSettings.get_setting("autoload/PencilSketchStyle", "")) == "*res://scripts/pencil_sketch_style.gd", "Pencil Sketch is enabled by its project autoload")
	_check(ResourceLoader.exists("res://shaders/pencil_sketch_double_sided.gdshader"), "double-sided animated fabric shader is present")
	var style_manager := root.get_node_or_null("PencilSketchStyle")
	if style_manager == null:
		style_manager = STYLE_SCRIPT.new()
		style_manager.name = "PencilSketchStyle"
		root.add_child(style_manager)
	await process_frame

	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := PLAYER_SCRIPT.new() as FoundationPlayer
	player.set_physics_process(false)
	fixture.add_child(player)
	await process_frame
	await process_frame
	_check(player._skeleton != null and player._animation_player != null, "the detailed playable character keeps its animated skeleton")
	_check(player._character_motion_ready and player._fight_animations_ready, "existing movement and combat animation libraries remain installed")

	var player_counts := _count_sketch_surfaces(player)
	_check(player_counts.x > 0, "the skinned player surfaces use the pencil shader")
	_check(player_counts.y > 0, "player albedo textures remain bound to shared pencil materials")

	var enemy := ENEMY_SCRIPT.new() as FoundationEnemy
	enemy.configure("shambler", false, true)
	enemy._player = player
	enemy.set_physics_process(false)
	fixture.add_child(enemy)
	await process_frame
	enemy._set_distance_detail(5.0)
	enemy._set_full_animation_selected(true)
	await process_frame
	await process_frame
	_check(enemy._high_detail_visual_ready and enemy._high_detail_visual_active, "the close animated high-detail zombie remains available")
	var enemy_counts := _count_sketch_surfaces(enemy)
	_check(enemy_counts.x > 0, "the animated high-detail zombie uses the pencil shader")
	_check(enemy_counts.y > 0, "zombie albedo textures remain bound to shared pencil materials")
	_check(enemy._fight_animations_ready, "pencil materials do not disrupt zombie fight animation retargeting")

	var stats: Dictionary = style_manager.call("get_style_stats")
	_check(int(stats.get("styled_meshes", 0)) > 0, "runtime style manager caches processed mesh materials")
	_check(int(stats.get("shared_materials", 0)) > 0, "pencil variants are shared instead of duplicated per actor")

	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: optimized Pencil Sketch materials (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: optimized Pencil Sketch materials (%d/%d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _count_sketch_surfaces(node: Node) -> Vector2i:
	var styled := 0
	var textured := 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index) as ShaderMaterial
			if material == null or not [PENCIL_SHADER, PENCIL_DOUBLE_SIDED_SHADER].has(material.shader):
				continue
			styled += 1
			_check(material.has_meta(&"_pencil_sketch_opaque_material"), "styled opaque surface retains its spawn-occluder material marker")
			var sketch_material := material
			if bool(sketch_material.get_shader_parameter("use_albedo_texture")) \
					and sketch_material.get_shader_parameter("albedo_texture") is Texture2D:
				textured += 1
	return Vector2i(styled, textured)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
