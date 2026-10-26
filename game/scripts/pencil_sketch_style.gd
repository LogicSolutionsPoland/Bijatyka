extends Node

const SINGLE_SIDED_SHADER: Shader = preload("res://shaders/pencil_sketch.gdshader")
const DOUBLE_SIDED_SHADER: Shader = preload("res://shaders/pencil_sketch_double_sided.gdshader")
const STYLE_META := &"_pencil_sketch_materials_processed"
const OPAQUE_META := &"_pencil_sketch_opaque_material"

var _material_cache: Dictionary = {}
var _pending_mesh_ids: Dictionary = {}
var _styled_surface_count := 0
var _styled_mesh_count := 0

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan_tree(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		_queue_mesh(node as MeshInstance3D)

func _scan_tree(node: Node) -> void:
	if node is MeshInstance3D:
		_queue_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_scan_tree(child)

func _queue_mesh(mesh: MeshInstance3D) -> void:
	var instance_id := mesh.get_instance_id()
	if _pending_mesh_ids.has(instance_id):
		return
	_pending_mesh_ids[instance_id] = true
	# Defer only the ID so a scene freed before the callback does not pass a
	# stale MeshInstance3D argument through Godot's deferred-call type check.
	call_deferred("_apply_to_mesh", instance_id)

func _apply_to_mesh(instance_id: int) -> void:
	_pending_mesh_ids.erase(instance_id)
	var object: Object = instance_from_id(instance_id)
	if not is_instance_valid(object) or not object is MeshInstance3D:
		return
	var mesh := object as MeshInstance3D
	if mesh.mesh == null or mesh.has_meta(STYLE_META):
		return

	var changed := false
	if mesh.material_override != null:
		var override_replacement := _styled_material(mesh.material_override)
		if override_replacement != null:
			mesh.material_override = override_replacement
			_styled_surface_count += 1
			changed = true
	else:
		for surface_index in range(mesh.mesh.get_surface_count()):
			var source := mesh.get_active_material(surface_index)
			var surface_replacement := _styled_material(source)
			if surface_replacement == null:
				continue
			mesh.set_surface_override_material(surface_index, surface_replacement)
			_styled_surface_count += 1
			changed = true

	if changed:
		mesh.set_meta(STYLE_META, true)
		_styled_mesh_count += 1

func _styled_material(source: Material) -> ShaderMaterial:
	if not source is StandardMaterial3D:
		return null

	var base := source as StandardMaterial3D
	if base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return null
	if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or base.emission_enabled:
		return null
	if base.next_pass != null:
		return null

	var is_double_sided := base.cull_mode == BaseMaterial3D.CULL_DISABLED
	var cache_key := "%d:%d" % [base.get_instance_id(), int(is_double_sided)]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as ShaderMaterial

	var styled := ShaderMaterial.new()
	styled.shader = DOUBLE_SIDED_SHADER if is_double_sided else SINGLE_SIDED_SHADER
	styled.set_meta(OPAQUE_META, true)
	styled.set_shader_parameter("albedo_tint", base.albedo_color)
	styled.set_shader_parameter("use_albedo_texture", base.albedo_texture != null)
	if base.albedo_texture != null:
		styled.set_shader_parameter("albedo_texture", base.albedo_texture)
	styled.set_shader_parameter("use_vertex_color", base.vertex_color_use_as_albedo)
	_material_cache[cache_key] = styled
	return styled

func is_enabled() -> bool:
	return true

func get_style_stats() -> Dictionary:
	return {
		"enabled": true,
		"styled_meshes": _styled_mesh_count,
		"styled_surfaces": _styled_surface_count,
		"shared_materials": _material_cache.size()
	}
