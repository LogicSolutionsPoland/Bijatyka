extends SceneTree

## Renders review images from the actual foundation scene and player camera.

const FoundationScene := preload("res://scenes/foundation.tscn")
const OUTPUT_DIR := "res://../build/character_views"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_path)
	var game: Variant = FoundationScene.instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.8).timeout
	game._camera_pitch = deg_to_rad(-12.0)
	game.camera_arm.rotation.x = game._camera_pitch
	game.player.rotation.y = 0.0
	game.player.velocity = Vector3.ZERO
	await _set_camera_and_settle(game, PI)
	await _save("front")
	await _set_camera_and_settle(game, 0.0)
	await _save("rear")
	Input.action_press("move_forward")
	await create_timer(0.45).timeout
	await _save("movement")
	Input.action_release("move_forward")
	game.player.global_position = FoundationPlayerPosition(game)
	game.player.rotation.y = 0.0
	await _set_camera_and_settle(game, PI)
	game.player.request_attack("punch", "right")
	await create_timer(0.12).timeout
	await _save("punch")
	game.player.attack_phase = "ready"
	game.player.attack_kind = ""
	game.player.request_attack("kick", "right")
	await create_timer(0.15).timeout
	await _save("kick")
	print("CAPTURED_PLAYER_VIEWS=" + output_path)
	quit(0)

func FoundationPlayerPosition(game: Variant) -> Vector3:
	return game.PLAYER_BASE_POSITION

func _set_camera_and_settle(game: Variant, yaw: float) -> void:
	game._camera_yaw = yaw
	game.camera_rig.rotation.y = yaw
	game.player.set_camera_yaw(yaw)
	await create_timer(0.32).timeout

func _save(view_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var filename := ProjectSettings.globalize_path(OUTPUT_DIR.path_join(view_name + ".png"))
	var error := image.save_png(filename)
	if error != OK:
		push_error("Unable to save %s screenshot: %s" % [view_name, error])
