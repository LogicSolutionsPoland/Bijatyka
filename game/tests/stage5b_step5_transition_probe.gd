extends SceneTree
## Stage 5B Step 5 real Foundation/elevator integration, actual Mesa readbacks.
## Elevator endpoint travel is accelerated; not a complete timed ride.

const WORLD := preload("res://scenes/foundation.tscn")
const ELEVATOR := preload("res://scripts/starting_elevator.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
	return ok

func _run() -> void:
	var game = WORLD.instantiate()
	root.add_child(game)
	for i in range(6):
		await process_frame
	var manager = game.flashlight_visibility_manager
	var tip = manager._tip_silhouettes
	var lift = game.starting_tower.elevator
	var loader = game._ground_loading_coordinator
	check(game._rooftop_sky_active and not manager._composite.visible
		and not game.burning_horizon.visible and not tip.overlay.visible,
		"initial rooftop hides blackout/horizon/tip")
	check(game.hud._root.visible, "initial HUD")
	save(await capture(), "step5-roof-initial.png")
	lift._car_root.position.y = ELEVATOR.BOTTOM_CAR_Y
	if not check(lift.interact(game.player), "call elevator from roof"):
		finish(game)
		return
	check(loader.is_active(), "call activates real loading coordinator")
	save(await capture(), "step5-call-loading.png")
	lift._car_root.position.y = ELEVATOR.TOP_CAR_Y
	for i in range(480):
		await process_frame
		if not loader.is_active():
			break
	check(not loader.is_active() and game._rooftop_sky_active,
		"called car arrives at roof after load")
	if not check(lift.interact(game.player), "board real elevator"):
		finish(game)
		return
	check(loader.is_active(), "descent activates loading")
	for i in range(480):
		await process_frame
		if game._ground_map_ready:
			break
	check(game._ground_map_ready and lift._ground_floor_ready, "real ground preparation")
	lift._car_root.position.y = ELEVATOR.BOTTOM_CAR_Y
	for i in range(80):
		await process_frame
		if not loader.is_active():
			break
	check(not loader.is_active() and game._ground_wave_started,
		"zombies activate on actual arrival")
	check(not game._rooftop_sky_active and manager._composite.visible
		and game.burning_horizon.visible and manager.spotlight.visible,
		"ground effects enable together after elevator")
	game.player.global_position = Vector3(20.0, 1.2, 20.0)
	for i in range(35):
		await physics_frame
	game._apply_camera_look(0.18, -0.05)
	for i in range(6):
		await process_frame
	var origin: Vector3 = manager.beam_origin
	for scale in [1.0, 0.67, 0.40]:
		root.scaling_3d_scale = scale
		for i in range(5):
			await process_frame
		var frame := await capture()
		save(frame, "step5-ground-%.2f.png" % scale)
		check(manager._composite.visible and game.burning_horizon.visible
			and manager.spotlight.visible and game.hud._root.visible,
			"gameplay layers preserved at scale %.2f" % scale)
		check(peak(frame, Vector2(0.02, 0.42)) < 0.09
			and peak(frame, Vector2(0.98, 0.42)) < 0.09,
			"off-beam framebuffer remains black at scale %.2f" % scale)
		check(game.burning_horizon.global_position.distance_to(game.player.global_position) < 0.06,
			"circular fog follows player at scale %.2f" % scale)
	root.scaling_3d_scale = 0.40
	game.player.global_position += Vector3(1.4, 0.0, 1.1)
	game._apply_camera_look(0.24, -0.03)
	for i in range(10):
		await process_frame
	check(manager.beam_origin.distance_to(origin) > 1.0, "beam follows player translation")
	check(game.burning_horizon.global_position.distance_to(game.player.global_position) < 0.06,
		"fog stays centered during camera yaw")
	save(await capture(), "step5-ground-aim.png")
	# A teleported camera/player test position is not proof of floor contact.
	# Unlike a physical walk, physics needs to settle after the test translation.
	for frame in range(120):
		await physics_frame
		if frame > 5 and game.player.is_on_floor():
			break
	check(game.player.is_on_floor(), "fixture player grounded before limb grab")
	print("STEP5_GRAB_PRECONDITIONS " + JSON.stringify({
		"grounded": game.player.is_on_floor(),
		"grab_state": game.player.grab_state,
		"cooldown": game.player._limb_grab_cooldown,
		"active_zombies": game.spawn_director.ordinary_population_count()
	}))
	# Genuine limb-grab state; existing QTE regressions cover button timing.
	game.ai_director._refresh_formation()
	var grabber: FoundationEnemy = null
	for value in game.spawn_director._live.values():
		var enemy := value as FoundationEnemy
		if enemy == null or game.spawn_director.formation_role_for(enemy) != "attacker":
			continue
		grabber = enemy
		if game.spawn_director._attackers.has(enemy.get_instance_id()):
			break
	if check(is_instance_valid(grabber), "local grab attacker exists"):
		grabber.set_physics_process(false)
		grabber._player = game.player
		grabber.global_position = game.player.global_position + Vector3(1.5, 0, 0)
		var allowed: bool = game.spawn_director.try_acquire_attacker(grabber)
		var reserved: bool = allowed and game.player.try_reserve_limb_grab(grabber, "LEFT ARM")
		var begun: bool = reserved and game.player.begin_limb_grab(grabber, "LEFT ARM")
		print("STEP5_GRAB_ADMISSION " + JSON.stringify({
			"acquired": allowed, "reserved": reserved, "begun": begun,
			"enemy_director": is_instance_valid(grabber.attack_director),
			"formation_role": game.spawn_director.formation_role_for(grabber),
			"player_grounded": game.player.is_on_floor()
		}))
		check(begun, "grab begins through player state machine")
		if begun:
			for i in range(3):
				await process_frame
			check(game.player._limb_grab_owner == grabber and manager._composite.visible
				and game.hud._root.visible, "grab retains blackout and HUD")
			save(await capture(), "step5-grab-active.png")
			game.player.cancel_limb_grab()
			check(game.player._limb_grab_owner == null, "grab cleanup")
	grabber = null
	game.player.global_position = game.player.safe_base_position
	game._on_player_respawned()
	for i in range(8):
		await process_frame
	check(game._rooftop_sky_active and not manager._composite.visible
		and not game.burning_horizon.visible and not tip.overlay.visible,
		"actual respawn callback restores roof and disables ground effects")
	check(not loader.is_active() and game.hud._root.visible, "respawn HUD and loading")
	save(await capture(), "step5-roof-respawn.png")
	# Force a second ground render profile only after moving the fixture
	# physically back to ground. On a 20m roof, _update_rooftop_sky
	# correctly re-enables roof effects and would invalidate this test.
	# This is not a second ridden elevator descent.
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(20.0, 0.05, 20.0)
	game._ground_map_ready = true
	game._set_rooftop_render_profile(false)
	for i in range(6):
		await process_frame
	check(manager._composite.visible and game.burning_horizon.visible
		and manager.spotlight.visible, "forced ground profile reactivates all core effects")
	save(await capture(), "step5-ground-forced-profile.png")
	print("STEP5_TRANSITION_SCOPE actual_elevator_interact=YES endpoint_accelerated=YES grab=YES respawn_callback=YES final_profile_forced=YES")
	finish(game)

func capture() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func peak(image: Image, uv: Vector2) -> float:
	if image.is_empty():
		return 1.0
	var c := image.get_pixel(clampi(int(image.get_width() * uv.x), 0, image.get_width() - 1),
		clampi(int(image.get_height() * uv.y), 0, image.get_height() - 1))
	return maxf(c.r, maxf(c.g, c.b))

func save(image: Image, filename: String) -> void:
	var folder := OS.get_environment("BIJATYKA_CAPTURE_DIR")
	if folder.is_empty() or image.is_empty() or DirAccess.make_dir_recursive_absolute(folder) != OK \
		or image.save_png(folder.path_join(filename)) != OK:
		failures.append("cannot save actual Mesa capture " + filename)

func finish(game: Node) -> void:
	game.queue_free()
	if failures.is_empty():
		print("PASS: Stage5B Step5 real gameplay-transition render checks (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("Step5 transition: " + failure)
		print("FAIL: Stage5B Step5 gameplay-transition render (%d failures)" % failures.size())
		quit(1)
