extends Node

const PENCIL := preload("res://scripts/pencil.gd")
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
	apply_mesh(object as MeshInstance3D)

func apply_mesh(mesh: MeshInstance3D) -> void:
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
	if base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or base.emission_enabled or base.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
		return null
	if base.next_pass != null:
		return null

	var is_double_sided := base.cull_mode == BaseMaterial3D.CULL_DISABLED
	var cache_key := "%d:%d" % [base.get_instance_id(), int(is_double_sided)]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as ShaderMaterial

	var styled := PENCIL.from_material(base)
	styled.set_meta(OPAQUE_META, true)
	# The supplied material draws its lines from the directional key light.
	# A small wash preserves the detailed source textures as the graphite reads.
	styled.set_shader_parameter(&"wash", 0.16)
	styled.set_shader_parameter(&"blotch", 0.08)
	styled.set_shader_parameter(&"shadow_color", Color(0.72, 0.72, 0.75))
	styled.set_shader_parameter(&"graphite_color", Color(0.10, 0.10, 0.13))
	styled.set_shader_parameter(&"graphite_strength", 0.96)
	styled.set_shader_parameter(&"hatch_space", 0)
	styled.set_shader_parameter(&"hatch_spacing", 6.5)
	styled.set_shader_parameter(&"crosshatch", 0.68)
	styled.set_shader_parameter(&"waver", 0.50)
	styled.set_shader_parameter(&"roughness", 0.34)
	var outline := styled.next_pass as ShaderMaterial
	outline.set_shader_parameter(&"outline_width", 4.0)
	outline.set_shader_parameter(&"outline_color", Color(0.09, 0.09, 0.12))
	outline.set_shader_parameter(&"outline_variation", 0.45)
	outline.set_shader_parameter(&"outline_fade_start", 16.0)
	outline.set_shader_parameter(&"outline_fade_end", 34.0)
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
