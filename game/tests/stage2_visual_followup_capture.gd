extends SceneTree

## Stage 2 temporary QA capture only. Never referenced by production scenes.
## Uses the real foundation scene and real shader passes. No gameplay edits.

const SCENE := preload("res://scenes/foundation.tscn")
const Foundation := preload("res://scripts/foundation.gd")
const OUT := "res://../build/stage2_followup"

var captured := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var directory := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(directory)
	root.scaling_3d_scale = 0.40
	Engine.max_fps = 60
	var game := SCENE.instantiate()
	root.add_child(game)
	for i in range(18):
		await process_frame
	if game.player == null or game.camera == null or game.camera_rig == null:
		push_error("Stage 2 scene lacks player or camera")
		quit(1)
		return
	game.set_process(false)
	game.player.set_physics_process(false)

	for degrees in [-35, 0, 35]:
		var yaw := deg_to_rad(float(degrees))
		game._camera_yaw = yaw
		game.camera_rig.rotation.y = yaw
		game.player.set_camera_yaw(yaw)
		if not await _save("roof_camera_yaw_%s" % str(degrees)):
			failures += 1
	game._camera_yaw = 0.0
	game.camera_rig.rotation.y = 0.0
	game.player.set_camera_yaw(0.0)

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
	var manager: Node = game.flashlight_visibility_manager
	manager._upload_shader_parameters()
	manager.set_process(false)
	if game._boss_enemy._animation_player != null:
		game._boss_enemy._animation_player.pause()
	var pencil: MeshInstance3D = game._pencil_screen_pass
	var mask: MeshInstance3D = manager._composite
	if pencil == null or mask == null:
		push_error("Stage 2 expected screen passes missing")
		quit(1)
		return

	for pencil_enabled in [true, false]:
		for mask_enabled in [true, false]:
			pencil.visible = pencil_enabled
			mask.visible = mask_enabled
			var label := "ground_pencil_%s_mask_%s" % [str(pencil_enabled), str(mask_enabled)]
			if not await _save(label):
				failures += 1
	pencil.visible = true
	mask.visible = true

	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2240, 1080)]:
		root.size = dimensions
		if not await _save("hud_%dx%d" % [dimensions.x, dimensions.y]):
			failures += 1
	root.size = Vector2i(1280, 720)
	game.queue_free()
	await process_frame
	print("STAGE2_QA_CAPTURED=%d FAILED=%d OUTPUT=%s" % [captured, failures, directory])
	quit(0 if failures == 0 and captured == 10 else 1)

func _save(name: String) -> bool:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Stage 2 readback failed: " + name)
		return false
	var filename := ProjectSettings.globalize_path(OUT.path_join(name + ".png"))
	var error := image.save_png(filename)
	if error != OK:
		push_error("Stage 2 PNG save failed: " + name)
		return false
	captured += 1
	print("STAGE2_QA_FRAME " + JSON.stringify({
		"file": filename,
		"source": "real foundation scene / live Godot frame",
		"renderer": "Godot 4.7.2 software OpenGL Compatibility",
		"viewport_width": image.get_width(),
		"viewport_height": image.get_height(),
		"label": name
	}))
	return true
