extends RefCounted
## Draw only a lit enemy's own surfaces after the blackout. Keep depth testing
## so walls, the player, and nearer enemies remain in front of it.

const RENDER_PRIORITY := 127
const SOURCE_META := &"_flashlight_reveal_source"
static var _materials: Dictionary = {}
static var _shaders: Dictionary = {}

static func material_for(source: Material) -> Material:
	if source == null or source.has_meta(SOURCE_META):
		return source
	var id := source.get_instance_id()
	if _materials.has(id):
		return _materials[id] as Material
	var revealed := source.duplicate() as Material
	if source is StandardMaterial3D:
		var standard := revealed as StandardMaterial3D
		standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	elif source is ShaderMaterial:
		var shader := (source as ShaderMaterial).shader
		if shader == null:
			return source
		var shader_id := shader.get_instance_id()
		if not _shaders.has(shader_id):
			var variant := Shader.new()
			# Preserve the pencil shading, textures, skinning, and crowd motion.
			# Writing ALPHA selects the ordered transparent queue at full opacity.
			# The Compatibility depth prepass can consume the skinned mesh's
			# transparent draw before the fullscreen mask. Draw its color and depth
			# together at the final priority, still testing against opaque walls.
			variant.code = shader.code.replace("render_mode ", "render_mode depth_draw_always, ").replace(
				"void fragment() {", "void fragment() {\n\tALPHA = 1.0;")
			_shaders[shader_id] = variant
		(revealed as ShaderMaterial).shader = _shaders[shader_id] as Shader
	else:
		return source
	revealed.render_priority = RENDER_PRIORITY
	# Preserve the existing pencil outline in the same late drawing stage.
	if source.next_pass != null:
		revealed.next_pass = source.next_pass.duplicate() as Material
		revealed.next_pass.render_priority = RENDER_PRIORITY
	revealed.set_meta(SOURCE_META, source)
	_materials[id] = revealed
	return revealed

static func set_mesh_revealed(mesh: MeshInstance3D, is_revealed: bool) -> void:
	if mesh.mesh == null:
		return
	if mesh.material_override != null:
		mesh.material_override = _select(mesh.material_override, is_revealed)
	else:
		for surface in range(mesh.mesh.get_surface_count()):
			mesh.set_surface_override_material(surface, _select(mesh.get_active_material(surface), is_revealed))
	if mesh.material_overlay != null:
		mesh.material_overlay = _select(mesh.material_overlay, is_revealed)

static func _select(material: Material, is_revealed: bool) -> Material:
	if material == null:
		return null
	return material_for(material) if is_revealed else material.get_meta(SOURCE_META, material) as Material
