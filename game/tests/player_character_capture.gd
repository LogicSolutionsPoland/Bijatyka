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
	await _set_camera_and_settle(game, 0.0)
	await _save("front")
	await _set_camera_and_settle(game, PI)
	await _save("rear")
	await _set_camera_and_settle(game, 0.0)
	Input.action_press("move_forward")
	await create_timer(0.45).timeout
	await _save("movement")
	Input.action_release("move_forward")
	game.player.global_position = FoundationPlayerPosition(game)
	game.player.rotation.y = 0.0
	await _set_camera_and_settle(game, 0.0)
	game.player.request_attack("punch", "right")
	await create_timer(0.12).timeout
	await _save("punch")
	game.player.attack_phase = "ready"
	game.player.attack_kind = ""
	game.player.request_attack("kick", "right")
	await create_timer(0.15).timeout
	await _save("kick")
	await _capture_exo_clips(game)
	print("CAPTURED_PLAYER_VIEWS=" + output_path)
	quit(0)

func _capture_exo_clips(game: Variant) -> void:
	var overlay := game.player._exo_overlay as PlayerExoMixamoOverlay
	if overlay == null:
		push_error("Exo Mixamo overlay is missing; no visual animation can be reviewed")
		return
	var animator := overlay._animator as AnimationPlayer
	if animator == null:
		push_error("Exo Mixamo AnimationPlayer is missing")
		return
	game.player.set_physics_process(false)
	game.player.velocity = Vector3.ZERO
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	await _set_camera_and_settle(game, PI)
	var count := 0
	for clip_name in ["mma_kick", "roundhouse", "fly_kick", "jump", "roll"]:
		if not overlay.play_clip(clip_name, 0.8):
			push_error("Could not play Exo Mixamo " + clip_name)
			continue
		var animation := animator.get_animation(StringName("exo_mixamo/" + clip_name))
		for fraction in [0.22, 0.55, 0.80]:
			animator.seek(animation.length * float(fraction), true)
			await _save("exo_%s_%02d" % [clip_name, roundi(float(fraction) * 100.0)])
			count += 1
		overlay.stop_clip()
	print("CAPTURED_EXO_POSES=%d" % count)

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
