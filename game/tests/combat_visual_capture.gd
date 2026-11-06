extends SceneTree
## Render the normal ground camera, flashlight and both zombie detail levels.
## Keep actor transforms fixed across the mobile scale and Pencil comparisons.

const Foundation := preload("res://scripts/foundation.gd")
const FIGHT_START := Vector3(9.5, 0.05, 2.0)
const OFFSETS := [
	Vector2(-0.70, -2.25), Vector2(0.60, -3.0), Vector2(-1.10, -3.85), Vector2(1.40, -3.90),
	Vector2(-1.90, -4.80), Vector2(0.15, -5.35), Vector2(1.85, -5.70),
	Vector2(-1.25, -6.35), Vector2(0.75, -6.90), Vector2(2.0, -7.25),
]
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	if out.is_empty():
		push_error("Set BIJATYKA_CAPTURE_DIR for the combat captures.")
		quit(1)
		return
	seed(7417)
	root.scaling_3d_scale = 0.40
	var game := Foundation.new()
	root.add_child(game)
	for frame in range(12):
		await process_frame
	game.hud._root.visible = false
	game.set_process(false)
	game.player.set_physics_process(false)
	game.ai_director.set_physics_process(false)
	game.spawn_director.set_physics_process(false)
	game._boss_enemy.set_physics_process(false)
	game._set_debug_local_lights_enabled(false)
	game._set_debug_floor_fast_detail_enabled(true)
	await _save_frame(out.path_join("roof-40.png"))
	game.player.global_position = FIGHT_START
	game._ground_map_ready = true
	for visual in game._ground_map_visuals:
		visual.visible = true
	game._rooftop_camera_blend = 0.0
	game.camera_rig.global_position = FIGHT_START + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.camera_rig.rotation.y = 0.0
	game.camera_arm.spring_length = Foundation.CAMERA_FOLLOW_DISTANCE
	game.camera_arm.rotation.x = game._effective_camera_pitch()
	game._update_camera_framing()
	game._set_rooftop_render_profile(false)
	game._floor_material.set_shader_parameter("player_position", FIGHT_START)
	game.burning_horizon.follow_player(FIGHT_START)
	game._update_distance_visibility()
	game.spawn_director.population_limit = OFFSETS.size()
	var roles := {}
	var zombies: Array[FoundationEnemy] = []
	for i in range(OFFSETS.size()):
		var offset: Vector2 = OFFSETS[i]
		var enemy := game._spawn_enemy("shambler", FIGHT_START + Vector3(offset.x, 0.0, offset.y))
		enemy.set_physics_process(false)
		enemy.rotation.y = atan2(offset.x, offset.y)
		game.spawn_director.register_enemy(enemy)
		game.horde_far_visuals.register_enemy(enemy)
		zombies.append(enemy)
		roles[enemy.get_instance_id()] = "attacker" if i < 4 else "reserve"
	game.spawn_director.set_local_formation(roles, {})
	game.horde_far_visuals.visible = true
	for frame in range(6):
		await physics_frame
	var manager: Node = game.flashlight_visibility_manager
	manager.set_aim_yaw(0.0)
	manager._classify_enemies()
	manager.set_process(false)
	game.horde_far_visuals._process(0.25)
	for enemy in zombies:
		if enemy._animation_player != null:
			enemy._animation_player.play("Walk")
			enemy._animation_player.seek(0.22 + float(zombies.find(enemy) % 3) * 0.10, true)
			enemy._animation_player.pause()
	if game.player._animation_player != null:
		game.player._animation_player.pause()
	var style: Node = root.get_node("PencilSketchStyle")
	for scale in [0.40, 0.67]:
		game._set_debug_render_scale(scale)
		for pencil in [true, false]:
			game._set_debug_pencil_visible(pencil)
			while not style.is_gameplay_style_ready():
				await process_frame
			_check(style.is_enabled() == pencil and game._pencil_screen_pass.visible == pencil,
				"ground Pencil switch sets both the material and screen style")
			_check((int(style.get_style_stats().styled_meshes) > 0) == pencil,
				"turning Pencil off restores every styled mesh")
			for enemy in zombies:
				if enemy._model != null:
					_check(_wears_visible_outfit(enemy, pencil),
						"lit rig keeps its clothing and depth-tested flashlight reveal")
			var name := "ground-%d-%s.png" % [roundi(scale * 100), "pencil" if pencil else "plain"]
			await _save_frame(out.path_join(name))
			print("COMBAT_VIEW ", name, " scale=", root.scaling_3d_scale,
				" styled=", style.get_style_stats().styled_meshes, " rigs=", game.horde_far_visuals.get_full_rig_count(),
				" proxies=", game.horde_far_visuals.multimesh.visible_instance_count)
	if game.horde_far_visuals.get_full_rig_count() != 7 or game.horde_far_visuals.multimesh.visible_instance_count < 1:
		push_error("Combat capture must include seven detailed rigs and a visible crowd silhouette.")
		failed = true
	var newly_admitted := zombies.back() as FoundationEnemy
	roles[zombies[0].get_instance_id()] = "reserve"
	roles[newly_admitted.get_instance_id()] = "attacker"
	for enemy in zombies:
		if roles[enemy.get_instance_id()] == "reserve":
			enemy.state = "hit"
			enemy.combat_target = game.player
	game.spawn_director.set_local_formation(roles, {})
	game.horde_far_visuals._update_full_rig_selection()
	for enemy in zombies:
		if roles[enemy.get_instance_id()] == "attacker":
			_check(enemy._full_animation_selected, "visible attacker wins a rig over a hit reserve")
	_check(game.horde_far_visuals.get_resident_rig_count() == 7, "handoffs use the same seven rigs")
	game._set_rooftop_render_profile(true)
	game._set_rooftop_render_profile(false)
	_check(not style.is_enabled() and not game._pencil_screen_pass.visible,
		"a return to the ground respects the selected comparison")
	game.queue_free()
	await process_frame
	if not failed:
		print("PASS: close combat visual captures")
	quit(1 if failed else 0)

func _wears_visible_outfit(enemy: FoundationEnemy, pencil: bool) -> bool:
	for mesh in enemy._base_visual_meshes:
		for i in range(mesh.mesh.get_surface_count()):
			var material := mesh.get_active_material(i)
			if material == null or material.render_priority != FoundationEnemy.FLASHLIGHT_REVEAL.RENDER_PRIORITY:
				continue
			var source := FoundationEnemy.FLASHLIGHT_REVEAL.source_for(material)
			if pencil and source is ShaderMaterial:
				if source.get_shader_parameter("albedo_texture") == FoundationEnemy.INFECTED_ALBEDO:
					return true
			elif not pencil and source is StandardMaterial3D:
				if source.albedo_texture == FoundationEnemy.INFECTED_ALBEDO:
					return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func _save_frame(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(path) != OK:
		push_error("Cannot save combat frame " + path)
		failed = true
