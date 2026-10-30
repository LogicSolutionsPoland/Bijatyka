extends SceneTree

const Foundation := preload("res://scripts/foundation.gd")
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
	check(backdrop.get_child_count() == 4, "four panels enclose all compass directions")
	check(backdrop.find_children("*", "CollisionObject3D").is_empty(), "horde and camera cannot collide with scenery")
	var rooftop_sky := arena._rooftop_city_sky
	var city_material := rooftop_sky.sky_material as ShaderMaterial
	check(city_material != null, "rooftop sky uses a dedicated lower-hemisphere material")
	if city_material != null:
		check(city_material.shader == Foundation.ROOFTOP_LOWER_SKY_SHADER, "lower city is isolated from the ground-level procedural sky")
		var city_texture := city_material.get_shader_parameter("lower_city_panorama") as Texture2D
		check(city_texture != null and city_texture.get_width() == 1536 and city_texture.get_height() == 768, "the detailed rooftop city photograph is bound at full resolution")
	check(arena._environment.sky == rooftop_sky and not backdrop.visible, "rooftop spawn displays the city instead of the procedural walls")
	check(arena.flashlight_visibility_manager.rooftop_sky_visible, "flashlight lets rooftop sky pixels through")
	for at in [Vector3.ZERO, Vector3(70, 0, -50), Vector3(-40, 15, 60)]:
		arena.player.global_position = at
		backdrop.follow_player(at)
		arena._update_distance_visibility()
		check(backdrop.global_position.is_equal_approx(at), "backdrop follows walking, teleport and airborne dash")
		for child in backdrop.get_children():
			var wall := child as MeshInstance3D
			check(wall.visible, "distance culling must not remove horizon panels")
			check(wall.mesh.size == Vector2(40, 6), "each panel spans 60 m and stands 6 m tall")
			check(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "backdrop has no shadows")
		# Every horizontal ray must hit one of the four panels at 20..28.29 m.
		for degrees in range(0, 360, 5):
			var direction := Vector2(cos(deg_to_rad(float(degrees))), sin(deg_to_rad(float(degrees))))
			var distance := 20.0 / maxf(absf(direction.x), absf(direction.y))
			check(distance >= 19.99 and distance <= 28.29, "box covers the full horizontal view")
	var old_rotation := backdrop.global_rotation
	arena._apply_camera_look(1.5, -0.1)
	check(backdrop.global_rotation.is_equal_approx(old_rotation), "looking around does not rotate the skyline")
	arena.player.global_position = Vector3(0.0, 0.05, -5.2)
	arena._update_rooftop_sky()
	check(arena._environment.sky == arena._ground_sky and backdrop.visible, "ground floor restores Burning Horizon")
	check(not arena.flashlight_visibility_manager.rooftop_sky_visible, "ground floor retains black sky in flashlight mode")
	arena.player._reset_at_safe_base()
	arena._update_rooftop_sky()
	check(arena.player.global_position.is_equal_approx(Foundation.PLAYER_BASE_POSITION), "respawn returns to the tower rooftop")
	check(arena._environment.sky == rooftop_sky and not backdrop.visible, "respawn restores the city panorama")
	check(arena.flashlight_visibility_manager.rooftop_sky_visible, "respawn restores visible rooftop sky")
	check(Foundation.ZOMBIE_HORDE_SIZE == 4 and Foundation.ZOMBIE_SPAWN_DISTANCE == 50.0, "four dormant rooftop entries keep 50 m concealed replacements")
	check(Foundation.ZOMBIE_PERFORMANCE_CAPACITY == 200, "stress scenarios retain 200-zombie capacity")
	arena.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: burning horizon integration")
	quit(1 if failures else 0)
