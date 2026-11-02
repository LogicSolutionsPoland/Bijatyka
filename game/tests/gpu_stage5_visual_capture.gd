extends SceneTree
## Fixed roof and ground frame captures for comparing the Compatibility pass.
## Set BIJATYKA_CAPTURE_DIR to a disposable absolute output directory.

const SCENE := preload("res://scenes/foundation.tscn")
const Foundation := preload("res://scripts/foundation.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output_dir := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	if output_dir.is_empty():
		push_error("BIJATYKA_CAPTURE_DIR is required")
		quit(1)
		return
	root.scaling_3d_scale = 0.40
	Engine.max_fps = 60
	var game := SCENE.instantiate()
	root.add_child(game)
	for frame in range(12):
		await process_frame
	if game._pencil_screen_pass.visible or game.flashlight_visibility_manager._composite.visible or game.flashlight_visibility_manager.spotlight.visible:
		push_error("Rooftop effects are unexpectedly visible")
		quit(1)
		return
	if not await _capture(output_dir.path_join("roof.png")):
		quit(1)
		return
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(0.0, 0.05, -5.2)
	for visual in game._ground_map_visuals:
		visual.visible = true
	game._ground_map_ready = true
	game._set_rooftop_render_profile(false)
	game._rooftop_camera_blend = 0.0
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.camera_arm.spring_length = Foundation.CAMERA_FOLLOW_DISTANCE
	game.camera_arm.rotation.x = game._effective_camera_pitch()
	game._update_camera_framing()
	game.flashlight_visibility_manager._upload_shader_parameters()
	game.set_process(false)
	game.flashlight_visibility_manager.set_process(false)
	if game._boss_enemy._animation_player != null:
		game._boss_enemy._animation_player.pause()
	for frame in range(6):
		await process_frame
	if not game._pencil_screen_pass.visible or not game.flashlight_visibility_manager._composite.visible or not game.flashlight_visibility_manager.spotlight.visible:
		push_error("Ground effects are unexpectedly hidden")
		quit(1)
		return
	if not await _capture(output_dir.path_join("ground.png")):
		quit(1)
		return
	game.queue_free()
	await process_frame
	print("PASS: Stage 5 fixed roof and ground captures")
	quit(0)

func _capture(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if frame == null or frame.is_empty():
		push_error("No Compatibility frame to capture: " + path)
		return false
	var error := frame.save_png(path)
	if error != OK:
		push_error("Cannot save Compatibility frame %s: %s" % [path, error_string(error)])
		return false
	print("STAGE5_VISUAL_CAPTURE " + JSON.stringify({"path": path, "size": frame.get_size()}))
	return true
