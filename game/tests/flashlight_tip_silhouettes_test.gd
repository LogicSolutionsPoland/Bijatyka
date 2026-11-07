extends SceneTree
## Focused checks for the non-gameplay, moving flashlight-tip artwork.

const Foundation := preload("res://scripts/foundation.gd")
const VisibilityManager := preload("res://scripts/flashlight_visibility.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Foundation.new()
	root.add_child(game)
	for frame in range(10):
		await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.hud._root.visible = false

	var manager = game.flashlight_visibility_manager
	manager.set_process(false)
	var effect = manager._tip_silhouettes
	_check(effect != null, "ground flashlight creates one separate silhouette effect")
	if effect == null:
		_finish()
		return
	_check(effect.overlay is MeshInstance3D and effect.material != null, "effect uses one persistent depth-tested quad and shader material")
	var zombie_texture := effect.material.get_shader_parameter("zombie_group_texture") as Texture2D
	_check(zombie_texture != null and zombie_texture.resource_path.ends_with("flashlight_tip_zombies.webp"),
		"effect uses detailed dark zombie artwork instead of procedural mannequin shapes")
	_check(effect.material.render_priority == 127, "effect draws after the 3D blackout composite")
	_check(is_equal_approx(float(effect.material.get_shader_parameter("silhouette_opacity")), 0.40),
		"solid silhouettes use 40 percent alpha")
	_check(effect.find_children("*", "MeshInstance3D", true, false).size() == 1,
		"effect creates one reusable quad instead of per-frame nodes")
	_check(game.burning_horizon.get_child_count() == 4,
		"the existing four-panel Zombie Horizon stays unchanged")

	game.player.global_position = Vector3(0.0, 0.05, -5.2)
	game.camera_rig.global_position = game.player.global_position + Vector3.UP * Foundation.CAMERA_PIVOT_HEIGHT
	game.camera_rig.rotation.y = 0.0
	game.camera_arm.spring_length = Foundation.CAMERA_FOLLOW_DISTANCE
	game.camera_arm.rotation.x = game._effective_camera_pitch()
	game._update_camera_framing()
	game._set_rooftop_render_profile(false)
	manager.set_aim_yaw(0.0)
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	_check(effect.overlay.visible, "effect is visible in the ground-level flashlight profile")
	_check(effect.beam_tip.distance_to(manager.beam_origin + manager.beam_direction * VisibilityManager.MAX_RADIUS) < 0.001,
		"effect follows the live beam origin, direction, and ten-meter range")

	var initial_center: Vector2 = effect.projected_center
	manager.set_aim_yaw(0.12)
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	_check(effect.projected_center.distance_to(initial_center) > 1.0,
		"aiming moves the silhouettes with the beam tip")
	manager.set_aim_yaw(0.0)
	game.player.global_position += Vector3.RIGHT * 0.5
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	_check(effect.projected_center.distance_to(initial_center) > 1.0,
		"moving the player moves the silhouettes with the beam origin")
	var normal_size: Vector2 = effect.projected_size
	effect.call("update_beam", manager.beam_origin, manager.beam_direction,
		VisibilityManager.MAX_RADIUS, VisibilityManager.BEAM_TANGENT * 0.5, true)
	_check(effect.projected_size.x < normal_size.x and effect.projected_size.y < normal_size.y,
		"projected silhouette footprint scales with flashlight cone width")
	manager._sync_tip_silhouettes()

	game._set_rooftop_render_profile(true)
	_check(not effect.overlay.visible and not manager.spotlight.visible,
		"silhouettes and flashlight beam disappear on the roof")
	game._set_rooftop_render_profile(false)
	_check(effect.overlay.visible and manager.spotlight.visible,
		"returning to the ground restores the flashlight-tip effect")
	manager.enabled = false
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	_check(not effect.overlay.visible and not manager.spotlight.visible,
		"silhouettes disappear when the flashlight is disabled")
	manager.enabled = true
	manager._upload_shader_parameters()
	manager._sync_tip_silhouettes()
	_check(effect.overlay.visible, "reenabling the flashlight restores the effect")
	_check(effect.projected_center.is_finite() and effect.projected_size.is_finite(),
		"beam projection stays finite after yaw, movement, and roof transitions")

	game.queue_free()
	await process_frame
	_finish()

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: flashlight tip silhouettes (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: flashlight tip silhouettes (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
