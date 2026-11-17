extends SceneTree
## Repeat the phone's lower landing view with the real car, camera and HUD.

const Foundation := preload("res://scripts/foundation.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	if out.is_empty():
		push_error("BIJATYKA_CAPTURE_DIR is required")
		quit(1)
		return
	root.size = Vector2i(1536, 709)
	root.scaling_3d_scale = 0.40
	seed(7417)
	var game := Foundation.new()
	root.add_child(game)
	for i in range(8):
		await process_frame
	var lift := game.starting_tower.elevator
	var loader := game._ground_loading_coordinator
	_check(lift.interact(game.player), "player boards the car from the rooftop")
	_check(lift.is_player_riding(game.player) and game.camera_arm.spring_length <= 0.8,
		"travelling camera stays inside the car")
	# Skip empty travel time. The real prep and rider-arrived signals finish normally.
	lift._car_root.position.y = StartingElevator.BOTTOM_CAR_Y
	for i in range(800):
		await process_frame
		if not loader.is_active() and not lift.is_player_riding(game.player):
			break
	_check(game._ground_map_ready and not game._rooftop_sky_active and not loader.is_active(),
		"the normal ground handoff has finished")
	game.player.set_physics_process(false)
	game.spawn_director.set_physics_process(false)
	game.ai_director.set_physics_process(false)
	for node in get_nodes_in_group("enemies"):
		node.set_physics_process(false)
	for angle in [0, 35, -42]:
		game._apply_camera_look(deg_to_rad(float(angle)) - game._camera_yaw, 0.0)
		await _settle()
		var prompt := game.hud._elevator_prompt_panel
		if prompt == null or not prompt.is_visible_in_tree():
			failures.append("parked car must show its interaction prompt")
			continue
		print("LIFT_VIEW yaw=", angle, " arm=", game.camera_arm.spring_length,
			" overlap=", game.hud._status_panel.get_global_rect().intersects(prompt.get_global_rect()),
			" feet=", game.player.global_position, " camera=", game.camera.global_position)
		await _save(out.path_join("lift-%s.png" % angle))
	game.player.global_position = game.starting_tower.to_global(Vector3(0.0, 0.18, -6.0))
	game._apply_camera_look(-game._camera_yaw, 0.0)
	await _settle()
	_check(not game.hud._elevator_prompt_panel.visible, "the lift prompt clears outside its interaction radius")
	await _save(out.path_join("lift-exit.png"))
	game.queue_free()
	await process_frame
	for problem in failures:
		push_error(problem)
	if failures.is_empty():
		print("PASS: ground lift gameplay captures")
	quit(0 if failures.is_empty() else 1)

func _settle() -> void:
	for i in range(22):
		await physics_frame
		await process_frame

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty() or frame.save_png(path) != OK:
		failures.append("could not capture " + path)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
