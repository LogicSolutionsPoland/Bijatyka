extends SceneTree

const Foundation := preload("res://scripts/foundation.gd")
const FlashlightVisibility := preload("res://scripts/flashlight_visibility.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var arena := Foundation.new()
	root.add_child(arena)
	await process_frame
	arena.set_process(false)
	arena.player.set_physics_process(false)
	var backdrop: Node3D = arena.burning_horizon
	check(backdrop.get_child_count() == 1, "one circular mesh encloses all compass directions")
	check(backdrop.find_children("*", "CollisionObject3D").is_empty(), "horde and camera cannot collide with scenery")
	var horizon := backdrop.get_child(0) as MeshInstance3D
	var ring := horizon.mesh as CylinderMesh if horizon != null else null
	check(ring != null, "Zombie Horizon uses an open cylinder mesh")
	if ring != null:
		check(is_equal_approx(ring.top_radius, FlashlightVisibility.MAX_RADIUS)
			and is_equal_approx(ring.bottom_radius, FlashlightVisibility.MAX_RADIUS),
			"Zombie Horizon radius matches the flashlight maximum")
		check(is_equal_approx(ring.height, 6.0) and ring.radial_segments == 96,
			"circular fog wall keeps its six-meter height and 96-sided outline")
		check(not ring.cap_top and not ring.cap_bottom, "fog ring has no horizontal cap surfaces")
		var halfway_radius := ring.top_radius * cos(PI / float(ring.radial_segments))
		check(halfway_radius >= FlashlightVisibility.MAX_RADIUS - 0.01,
			"the shortest distance between adjacent vertices stays within 1 cm of the flashlight maximum")
	var fog_material := horizon.material_override as ShaderMaterial if horizon != null else null
	check(fog_material != null and fog_material.shader != null, "fog ring has a shader material")
	if fog_material != null:
		check(fog_material.render_priority == 127 and arena.flashlight_visibility_manager._material.render_priority == 126,
			"fog draws after fullscreen blackout without changing its priority")
		check((fog_material.get_shader_parameter("oval_center_uv") as Vector2).is_equal_approx(FlashlightVisibility.OVAL_CENTER_UV),
			"fog uses existing flashlight oval instead of an independent footprint")
		for index in range(4):
			var fog_texture := fog_material.get_shader_parameter("zombie_fog_texture_%d" % index) as Texture2D
			check(fog_texture != null and fog_texture.get_width() == 1024 and fog_texture.get_height() == 576,
				"zombie fog image %d is imported and bound at its source size" % (index + 1))
	var rooftop_sky := arena._rooftop_city_sky
	var city_material := rooftop_sky.sky_material as ShaderMaterial
	check(city_material != null, "rooftop sky uses a dedicated lower-hemisphere material")
	if city_material != null:
		check(city_material.shader == Foundation.ROOFTOP_LOWER_SKY_SHADER, "lower city is isolated from the ground-level procedural sky")
		var city_texture := city_material.get_shader_parameter("lower_city_panorama") as Texture2D
		check(city_texture != null and city_texture.get_width() == 1536 and city_texture.get_height() == 768, "the detailed rooftop city photograph is bound at full resolution")
	check(arena._environment.sky == rooftop_sky and not backdrop.visible, "rooftop spawn displays the city instead of the procedural walls")
	check(arena.flashlight_visibility_manager.rooftop_sky_visible, "flashlight lets rooftop sky pixels through")
	check(not arena.flashlight_visibility_manager._composite.visible, "rooftop hides the flashlight blackout pass")
	check(not arena.flashlight_visibility_manager.spotlight.visible, "rooftop has no 3D flashlight beam")
	check(not arena._pencil_screen_pass.visible, "rooftop has no Pencil Sketch screen pass")
	check(not root.get_node("PencilSketchStyle").is_enabled(), "rooftop meshes retain normal materials")
	# A real material checks the global converter as well as the screen pass.
	var material_fixture := MeshInstance3D.new()
	material_fixture.mesh = SphereMesh.new()
	var plain_material := StandardMaterial3D.new()
	material_fixture.material_override = plain_material
	arena.add_child(material_fixture)
	await process_frame
	check(material_fixture.material_override == plain_material, "rooftop keeps the source PBR material")
	arena._update_distance_visibility()
	check(not arena.flashlight_visibility_manager._composite.visible and not arena._pencil_screen_pass.visible,
		"distance culling cannot re-enable hidden rooftop screen effects")
	for at in [Vector3.ZERO, Vector3(70, 0, -50), Vector3(-40, 15, 60)]:
		arena.player.global_position = at
		backdrop.follow_player(at)
		arena._update_distance_visibility()
		check(not arena._distance_visuals.has(horizon), "circular mesh is independent of Stage 5 cached culling")
		check(backdrop.global_position.is_equal_approx(at), "backdrop follows walking, teleport and airborne dash")
		for child in backdrop.get_children():
			var wall := child as MeshInstance3D
			check(wall.visible, "distance culling must not remove the horizon")
			check(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "backdrop has no shadows")
		if ring != null:
			var segment_angle := TAU / float(ring.radial_segments)
			for degrees in range(0, 360, 5):
				var angle := deg_to_rad(float(degrees))
				var local_angle := fposmod(angle, segment_angle)
				var radial_distance := ring.top_radius * cos(segment_angle * 0.5) / cos(local_angle - segment_angle * 0.5)
				check(radial_distance >= FlashlightVisibility.MAX_RADIUS - 0.01
					and radial_distance <= FlashlightVisibility.MAX_RADIUS + 0.01,
					"the horizon stays at the 10 m flashlight limit in every direction")
	var old_rotation := backdrop.global_rotation
	arena._apply_camera_look(1.5, -0.1)
	check(backdrop.global_rotation.is_equal_approx(old_rotation), "looking around does not rotate the skyline")
	arena.player.global_position = Vector3(0.0, 0.05, -5.2)
	arena._update_rooftop_sky()
	check(arena._environment.sky == arena._ground_sky and backdrop.visible, "ground floor restores Burning Horizon")
	for at in [Vector3(70, 0.05, -50), Vector3(-40, 6.0, 60)]:
		arena.player.global_position = at
		backdrop.follow_player(at)
		arena._update_distance_visibility()
		check(backdrop.is_visible_in_tree() and backdrop.global_position.is_equal_approx(at),
			"ground-floor ring follows walking and airborne movement despite distance culling")
	arena.player.global_position = Vector3(0.0, 0.05, -5.2)
	backdrop.follow_player(arena.player.global_position)
	check(not arena.flashlight_visibility_manager.rooftop_sky_visible, "ground floor retains black sky in flashlight mode")
	check(arena.flashlight_visibility_manager._composite.visible, "ground floor enables flashlight blackout")
	check(arena.flashlight_visibility_manager.spotlight.visible, "ground floor enables the flashlight beam")
	check(arena._pencil_screen_pass.visible, "ground floor restores Pencil Sketch screen pass")
	check(root.get_node("PencilSketchStyle").is_enabled(), "ground floor enables Pencil Sketch materials")
	for frame in range(60):
		if root.get_node("PencilSketchStyle").is_gameplay_style_ready():
			break
		await process_frame
	check(material_fixture.material_override is ShaderMaterial,
		"ground floor converts source materials to Pencil Sketch in bounded batches")
	arena.player._reset_at_safe_base()
	arena._update_rooftop_sky()
	check(arena.player.global_position.is_equal_approx(Foundation.PLAYER_BASE_POSITION), "respawn returns to the tower rooftop")
	check(arena._environment.sky == rooftop_sky and not backdrop.visible, "respawn restores the city panorama")
	check(arena.flashlight_visibility_manager.rooftop_sky_visible, "respawn restores visible rooftop sky")
	check(not arena.flashlight_visibility_manager._composite.visible, "respawn hides flashlight blackout")
	check(not arena.flashlight_visibility_manager.spotlight.visible, "respawn hides flashlight cone")
	check(not arena._pencil_screen_pass.visible and not root.get_node("PencilSketchStyle").is_enabled(), "respawn disables Pencil Sketch again")
	check(material_fixture.material_override == plain_material, "respawn restores the exact PBR material")
	check(Foundation.ZOMBIE_HORDE_SIZE == 4 and Foundation.ZOMBIE_SPAWN_DISTANCE == 50.0, "four dormant rooftop entries keep 50 m concealed replacements")
	check(Foundation.ZOMBIE_PERFORMANCE_CAPACITY == 20, "debug scenarios respect the 20-zombie gameplay cap")
	arena.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: burning horizon integration")
	quit(1 if failures else 0)
