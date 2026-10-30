extends Node

const PENCIL := preload("res://scripts/pencil.gd")
const STYLE_META := &"_pencil_sketch_materials_processed"
const OPAQUE_META := &"_pencil_sketch_opaque_material"

var _material_cache: Dictionary = {}
var _pending_mesh_ids: Dictionary = {}
var _pending_mesh_queue: Array[int] = []
var _original_mesh_materials: Dictionary = {}
var _gameplay_pencil_enabled := true
const MAX_MESHES_PER_FRAME := 6
var _styled_surface_count := 0
var _styled_mesh_count := 0

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	# The rooftop is intentionally drawn without graphite. Ground materials
	# are converted in small per-frame batches while the lift is enclosed.
	set_process(false)
	_scan_tree(get_tree().root)


func set_gameplay_pencil_enabled(is_enabled: bool) -> void:
	if _gameplay_pencil_enabled == is_enabled:
		return
	_gameplay_pencil_enabled = is_enabled
	if is_enabled:
		_scan_tree(get_tree().root)
	else:
		_pending_mesh_ids.clear()
		_pending_mesh_queue.clear()
		set_process(false)
		_restore_original_materials()


func is_gameplay_style_ready() -> bool:
	return not _gameplay_pencil_enabled or _pending_mesh_queue.is_empty()


func _process(_delta: float) -> void:
	var count := mini(MAX_MESHES_PER_FRAME, _pending_mesh_queue.size())
	for index in range(count):
		var instance_id: int = _pending_mesh_queue.pop_front()
		_pending_mesh_ids.erase(instance_id)
		_apply_to_mesh(instance_id)
	set_process(not _pending_mesh_queue.is_empty())


func _restore_original_materials() -> void:
	for instance_id in _original_mesh_materials:
		var object: Object = instance_from_id(int(instance_id))
		if not is_instance_valid(object) or not object is MeshInstance3D:
			continue
		var mesh := object as MeshInstance3D
		if mesh.mesh == null:
			continue
		var original: Dictionary = _original_mesh_materials[instance_id]
		mesh.material_override = original["material_override"] as Material
		var overrides: Array = original["surface_overrides"]
		for surface_index in range(mini(mesh.mesh.get_surface_count(), overrides.size())):
			mesh.set_surface_override_material(surface_index, overrides[surface_index] as Material)
		if mesh.has_meta(STYLE_META):
			mesh.remove_meta(STYLE_META)
	_original_mesh_materials.clear()
	_styled_mesh_count = 0
	_styled_surface_count = 0

func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		_queue_mesh(node as MeshInstance3D)

func _scan_tree(node: Node) -> void:
	if node is MeshInstance3D:
		_queue_mesh(node as MeshInstance3D)
	for child in node.get_children():
		_scan_tree(child)

func _queue_mesh(mesh: MeshInstance3D) -> void:
	if not _gameplay_pencil_enabled or mesh.mesh == null or mesh.has_meta(STYLE_META):
		return
	var instance_id := mesh.get_instance_id()
	if _pending_mesh_ids.has(instance_id):
		return
	_pending_mesh_ids[instance_id] = true
	_pending_mesh_queue.append(instance_id)
	set_process(true)


func _apply_to_mesh(instance_id: int) -> void:
	var object: Object = instance_from_id(instance_id)
	if is_instance_valid(object) and object is MeshInstance3D:
		apply_mesh(object as MeshInstance3D)


func apply_mesh(mesh: MeshInstance3D) -> void:
	if not _gameplay_pencil_enabled or mesh.mesh == null or mesh.has_meta(STYLE_META):
		return

	# Remember exact source overrides for a lossless rooftop restoration.
	var original_surface_overrides: Array[Material] = []
	for surface_index in range(mesh.mesh.get_surface_count()):
		original_surface_overrides.append(mesh.get_surface_override_material(surface_index))
	var original_override := mesh.material_override
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
		_original_mesh_materials[mesh.get_instance_id()] = {
			"material_override": original_override,
			"surface_overrides": original_surface_overrides,
		}
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
	return _gameplay_pencil_enabled

func get_style_stats() -> Dictionary:
	return {
		"enabled": _gameplay_pencil_enabled,
		"styled_meshes": _styled_mesh_count,
		"styled_surfaces": _styled_surface_count,
		"shared_materials": _material_cache.size()
	}
