extends SceneTree
## Isolated Compatibility pixel probe for the six texture sectors, alpha and motion.

const Horizon := preload("res://scripts/burning_horizon.gd")
const SECTOR_TEXTURES := [0, 1, 2, 3, 2, 1]
const SWATCHES := [Color.RED, Color.GREEN, Color.BLUE, Color(1.0, 1.0, 0.0)]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.02, 0.02, 0.02)
	world_environment.environment = environment
	root.add_child(world_environment)
	var backdrop := Horizon.new()
	root.add_child(backdrop)
	backdrop.follow_player(Vector3.ZERO)
	var wall := backdrop.get_child(0) as MeshInstance3D
	var material := wall.material_override as ShaderMaterial
	var originals: Array[Texture2D] = []
	for index in range(4):
		var parameter := "zombie_fog_texture_%d" % index
		var original := material.get_shader_parameter(parameter) as Texture2D
		_check(original != null and original.get_width() == 1024 and original.get_height() == 576,
			"source image %d was imported" % (index + 1))
		originals.append(original)
		var swatch := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		swatch.fill(SWATCHES[index])
		swatch.generate_mipmaps()
		material.set_shader_parameter(parameter, ImageTexture.create_from_image(swatch))

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.0, 0.0)
	camera.far = 30.0
	root.add_child(camera)
	camera.current = true
	var arrays := wall.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_check(vertices.size() == uvs.size() and not vertices.is_empty(),
		"cylinder supplies matching positions and UVs")
	if vertices.size() != uvs.size() or vertices.is_empty():
		_finish()
		return
	for sector in range(6):
		# Derive the camera direction from the actual cylinder UV mapping.
		# Each sector center falls on a vertex of the 96-segment mesh.
		var desired_u := (float(sector) + 0.5) / 6.0
		var nearest_index := 0
		var nearest_delta := INF
		for index in range(uvs.size()):
			var difference := absf(uvs[index].x - desired_u)
			if difference < nearest_delta:
				nearest_delta = difference
				nearest_index = index
		_check(nearest_delta < 0.001, "sector %d has a center UV" % (sector + 1))
		var target := wall.to_global(vertices[nearest_index])
		target.y = camera.global_position.y
		camera.look_at(target)
		for frame in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty(), "Compatibility frame readback exists")
		if image == null or image.is_empty():
			continue
		var pixel := image.get_pixel(int(image.get_width() / 2), int(image.get_height() / 2))
		var expected: Color = SWATCHES[SECTOR_TEXTURES[sector]]
		var bright := Vector3(pixel.r, pixel.g, pixel.b)
		var target_color := Vector3(expected.r, expected.g, expected.b)
		_check(bright.dot(target_color) > 0.20 and
			bright.distance_to(target_color * bright.dot(target_color) / target_color.length_squared()) < 0.20,
			"sector %d renders the selected texture through Compatibility" % (sector + 1))
		_check(maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.95,
			"sector %d blends with the backdrop instead of drawing opaque" % (sector + 1))

	# Use the supplied image for the motion check, so changing TIME in the
	# shader must change the actual fog pixels rather than only a test swatch.
	for index in range(4):
		material.set_shader_parameter("zombie_fog_texture_%d" % index, originals[index])
	var fog_target := wall.to_global(vertices[nearest_index_for_uv(uvs, vertices, 0.25)])
	fog_target.y = camera.global_position.y
	camera.look_at(fog_target)
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	var maximum_delta := 0.0
	for y in range(-24, 25, 4):
		for x in range(-24, 25, 4):
			var at := Vector2i(int(before.get_width() / 2) + x, int(before.get_height() / 2) + y)
			var first := before.get_pixelv(at)
			var second := after.get_pixelv(at)
			maximum_delta = maxf(maximum_delta,
				absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b))
	_check(maximum_delta > 0.003, "supplied fog image visibly drifts over time")
	_finish()

func nearest_index_for_uv(uvs: PackedVector2Array, vertices: PackedVector3Array, target_u: float) -> int:
	var nearest := 0
	var difference := INF
	for index in range(mini(uvs.size(), vertices.size())):
		var current := absf(uvs[index].x - target_u)
		if current < difference:
			difference = current
			nearest = index
	return nearest

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: zombie fog Compatibility pixels and motion")
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: zombie fog Compatibility probe (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
