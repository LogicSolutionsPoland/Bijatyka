class_name Pencil
## Pencil materials: make one, or turn a whole scene's StandardMaterial3Ds into pencil ones.
##
##     Pencil.convert(level)                              # every mesh under level, outlined
##     Pencil.set_param(level, &"hatch_spacing", 12.0) # on every pencil material under level
##     Pencil.set_param(level, &"outline_width", 5.0)     # and on their outlines
##     Pencil.add_screen_pass(camera)                     # the ink line on the finished image
##     Pencil.add_screen_pass(camera, true)               # same, creases from the engine's normals (Forward+ only)

const DIR := "res://shaders/"
const MATERIAL := DIR + "pencil.gdshader"
const MATERIAL_DOUBLE_SIDED := DIR + "pencil_double_sided.gdshader"
const OUTLINE := DIR + "pencil_outline.gdshader"
const SCREEN := DIR + "pencil_screen.gdshader"
const SCREEN_VULKAN := DIR + "pencil_screen_vulkan.gdshader"
const SCREEN_FORWARD := DIR + "pencil_screen_forward.gdshader"


## A pencil material, outlined unless `outline` is off.
static func make(texture: Texture2D = null, color := Color.WHITE, outline := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(MATERIAL)
	m.set_shader_parameter(&"albedo", color)
	if texture:
		m.set_shader_parameter(&"albedo_texture", texture)
	if outline:
		m.next_pass = make_outline()
	return m


## An outline on its own, for the next_pass of a material of your own.
static func make_outline(width := 3.0, color := Color(0.2, 0.2, 0.24)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(OUTLINE)
	m.set_shader_parameter(&"outline_width", width)
	m.set_shader_parameter(&"outline_color", color)
	return m


## The pencil material closest to a BaseMaterial3D: colour, texture, UV1 scale and offset, vertex
## colours and emission carry over.
static func from_material(source: BaseMaterial3D, outline := true) -> ShaderMaterial:
	var m := make(source.albedo_texture, source.albedo_color, outline)
	if source.cull_mode == BaseMaterial3D.CULL_DISABLED:
		m.shader = load(MATERIAL_DOUBLE_SIDED)
	m.set_shader_parameter(&"uv_scale", Vector2(source.uv1_scale.x, source.uv1_scale.y))
	m.set_shader_parameter(&"uv_offset", Vector2(source.uv1_offset.x, source.uv1_offset.y))
	m.set_shader_parameter(&"use_vertex_color", source.vertex_color_use_as_albedo)
	if source.emission_enabled:
		m.set_shader_parameter(&"emission", source.emission * source.emission_energy_multiplier)
	return m


## Swaps every lit BaseMaterial3D on the meshes under `root` for its pencil match, one per source
## material, and returns how many it made. Unshaded materials (lamps, glows) are left alone.
static func convert(root: Node, outline := true) -> int:
	# Bijatyka's style manager keeps shared materials across newly spawned rigs.
	# Use the same converter for the opening scene and for replacement actors.
	if root.is_inside_tree():
		var manager := root.get_tree().root.get_node_or_null("PencilSketchStyle")
		if manager != null and manager.has_method("apply_mesh"):
			var before: int = manager.get_style_stats()["shared_materials"]
			for mi in _meshes(root):
				manager.apply_mesh(mi)
			return int(manager.get_style_stats()["shared_materials"]) - before
	var made := {}
	for mi in _meshes(root):
		if _takes(mi.material_override):
			mi.material_override = _swap(mi.material_override, made, outline)
		if mi.mesh:
			for s in mi.mesh.get_surface_count():
				var source: Material = mi.get_surface_override_material(s)
				if not source:
					source = mi.mesh.surface_get_material(s)
				if _takes(source):
					mi.set_surface_override_material(s, _swap(source, made, outline))
	return made.size()


## Sets a shader parameter on every pencil material under `root` and on their outlines.
static func set_param(root: Node, param: StringName, value: Variant) -> void:
	for m in materials(root):
		m.set_shader_parameter(param, value)
		if m.next_pass is ShaderMaterial:
			m.next_pass.set_shader_parameter(param, value)


## Every pencil material on the meshes under `root`, once each.
static func materials(root: Node) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for mi in _meshes(root):
		var mats: Array[Material] = [mi.material_override]
		for s in mi.get_surface_override_material_count():
			mats.append(mi.get_surface_override_material(s))
		for m in mats:
			if is_pencil(m) and m not in out:
				out.append(m)
	return out


static func is_pencil(m: Material) -> bool:
	return m is ShaderMaterial and m.shader != null and m.shader.resource_path in [MATERIAL, MATERIAL_DOUBLE_SIDED]


## Adds the screen pass (ink line from depth, colour grade) to `camera` and returns its material.
## It picks the shader for the running renderer. `engine_normals` draws the creases from the normals
## the engine rendered, which are cleaner on curved surfaces, but they exist only in Forward+; in the
## other renderers it warns and uses the depth-only pass.
static func add_screen_pass(camera: Camera3D, engine_normals := false) -> ShaderMaterial:
	var existing := camera.get_node_or_null("PencilScreenPass") as MeshInstance3D
	if existing != null:
		return existing.material_override as ShaderMaterial
	# One active composite per viewport even if the gameplay camera is replaced.
	for old in camera.get_tree().get_nodes_in_group("pencil_screen_pass"):
		if old is MeshInstance3D and old.get_viewport() == camera.get_viewport():
			old.visible = false
			old.queue_free()
	var quad := MeshInstance3D.new()
	quad.name = "PencilScreenPass"
	quad.add_to_group("pencil_screen_pass")
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	quad.mesh = mesh
	quad.extra_cull_margin = 16384.0
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = load(shader_for_screen(engine_normals))
	# FlashlightVisibilityComposite uses priority 126. Graphite must be applied
	# to the lit scene first so its paper never brightens the dark half.
	m.render_priority = 125
	quad.material_override = m
	camera.add_child(quad)
	return m


## The screen pass shader for a renderer: Compatibility and Vulkan (Forward+, Mobile) map depth differently.
## With `engine_normals` Forward+ gets the variant that reads the engine's normals; Mobile cannot, so it warns.
static func shader_for_screen(engine_normals: bool, renderer := "") -> String:
	if renderer == "":
		renderer = RenderingServer.get_current_rendering_method()
	if renderer == "forward_plus":
		return SCREEN_FORWARD if engine_normals else SCREEN_VULKAN
	if engine_normals:
		push_warning("Pencil: engine normals need Forward+ (this is %s); using the depth-only pass." % renderer)
	return SCREEN_VULKAN if renderer == "mobile" else SCREEN


static func _takes(m: Material) -> bool:
	return m is BaseMaterial3D and m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED \
			and m.blend_mode != BaseMaterial3D.BLEND_MODE_ADD \
			and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
			and not m.emission_enabled and m.next_pass == null


static func _swap(source: BaseMaterial3D, made: Dictionary, outline: bool) -> ShaderMaterial:
	if source not in made:
		made[source] = from_material(source, outline)
	return made[source]


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for n in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n)
	if root is MeshInstance3D:
		out.append(root)
	return out
