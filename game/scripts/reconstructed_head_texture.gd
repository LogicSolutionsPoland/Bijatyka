extends RefCounted
## Non-destructive texture-only experiment: the target stays the Universal Base
## skinned male zombie. The reconstructed GLB supplies its HEAD albedo images.
## Projection is needed because the models have unrelated UV unwraps.

const SOURCE_MODEL := "res://assets/zombies/high_detail/Retribution_Zombie_Reconstructed.glb"
const HEAD_SHADER := preload("res://shaders/reconstructed_zombie_head.gdshader")

static var _tried_source := false
static var _front_texture: Texture2D
static var _back_texture: Texture2D
static var _shared_overlays: Dictionary = {}


static func install(skeleton: Skeleton3D, meshes: Array[MeshInstance3D]) -> int:
	if skeleton == null or not _load_head_textures():
		return 0
	var count := 0
	for node in meshes:
		if not is_instance_valid(node) or node.mesh == null:
			continue
		var head_bind := _find_head_bind(node, skeleton)
		if head_bind < 0:
			continue
		var cache_key := "%d:%d" % [node.mesh.get_instance_id(), head_bind]
		var overlay := _shared_overlays.get(cache_key) as ShaderMaterial
		if overlay == null:
			var head_bounds := _measure_head(node.mesh, head_bind)
			if head_bounds.size.length_squared() < 0.0025:
				continue
			overlay = ShaderMaterial.new()
			overlay.shader = HEAD_SHADER
			overlay.set_shader_parameter("front_texture", _front_texture)
			overlay.set_shader_parameter("back_texture", _back_texture)
			overlay.set_shader_parameter("head_bone", head_bind)
			overlay.set_shader_parameter("head_center", head_bounds.get_center())
			overlay.set_shader_parameter("head_half_span", head_bounds.size * 0.5)
			_shared_overlays[cache_key] = overlay
		# Overlay does not replace the mesh, skeleton, skin, base material or clips.
		# Bone-weight clipping ensures this additional pass never paints the torso.
		node.material_overlay = overlay
		count += 1
	return count


static func _load_head_textures() -> bool:
	if _tried_source:
		return _front_texture != null and _back_texture != null
	_tried_source = true
	if not ResourceLoader.exists(SOURCE_MODEL):
		push_warning("Reconstructed zombie: source GLB missing; original enemy material retained.")
		return false
	var source_scene := load(SOURCE_MODEL) as PackedScene
	if source_scene == null:
		return false
	var source := source_scene.instantiate()
	if source == null:
		return false
	for child in source.find_children("*", "MeshInstance3D", true, false):
		var part := child as MeshInstance3D
		var name_lower := part.name.to_lower()
		if not name_lower.begins_with("head"):
			continue
		if part.mesh == null:
			continue
		for surface in range(part.mesh.get_surface_count()):
			var material := part.get_active_material(surface) as BaseMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			if name_lower.contains("front") and _front_texture == null:
				_front_texture = material.albedo_texture
			elif name_lower.contains("back") and _back_texture == null:
				_back_texture = material.albedo_texture
			elif _front_texture == null:
				_front_texture = material.albedo_texture
	# Keep Texture2D refs before releasing the source scene instance.
	source.free()
	if _front_texture == null and _back_texture == null:
		push_warning("Reconstructed zombie: Head meshes have no transferable albedo texture.")
		return false
	if _front_texture == null:
		_front_texture = _back_texture
	if _back_texture == null:
		_back_texture = _front_texture
	return true


static func _find_head_bind(node: MeshInstance3D, skeleton: Skeleton3D) -> int:
	var skeleton_head := -1
	for bone in range(skeleton.get_bone_count()):
		if _is_head_name(String(skeleton.get_bone_name(bone))):
			skeleton_head = bone
			break
	if skeleton_head < 0:
		return -1
	var skin := node.skin
	if skin == null:
		return skeleton_head
	for binding in range(skin.get_bind_count()):
		if skin.get_bind_bone(binding) == skeleton_head or _is_head_name(String(skin.get_bind_name(binding))):
			return binding
	return -1


static func _is_head_name(label: String) -> bool:
	var n := label.to_lower()
	return n == "head" or n.ends_with("/head") or n.ends_with(":head") or n.ends_with("_head")


static func _measure_head(mesh: Mesh, head_bind: int) -> AABB:
	var has_vertex := false
	var minimum := Vector3.ZERO
	var maximum := Vector3.ZERO
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if vertices.is_empty() or bones.is_empty() or weights.is_empty():
			continue
		var stride := int(bones.size() / vertices.size())
		if stride < 4:
			continue
		for vertex in range(vertices.size()):
			var influenced := 0.0
			for slot in range(mini(stride, 4)):
				var index := vertex * stride + slot
				if bones[index] == head_bind:
					influenced += weights[index]
			if influenced < 0.30:
				continue
			var position := vertices[vertex]
			if not has_vertex:
				minimum = position
				maximum = position
				has_vertex = true
			else:
				minimum = minimum.min(position)
				maximum = maximum.max(position)
	if not has_vertex:
		return AABB()
	return AABB(minimum, maximum - minimum)
