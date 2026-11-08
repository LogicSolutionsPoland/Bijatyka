extends SceneTree

## Disposable Stage 2 evidence capture: actual elevator and real combat actors.
## QA branch only; never loaded by the shipping scene.
const SCENE := preload("res://scenes/foundation.tscn")
const OUT := "res://../build/stage2_sequence"

var shots := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.scaling_3d_scale = 0.40
	Engine.max_fps = 60
	var game := SCENE.instantiate()
	root.add_child(game)
	for i in range(18):
		await process_frame
	var elevator: StartingElevator = game.starting_tower.elevator
	if elevator == null:
		push_error("No actual starting elevator in foundation")
		quit(1)
		return
	game.player.global_position = elevator.to_global(Vector3(0.0, StartingElevator.TOP_CAR_Y + 0.16, 0.0))
	game.player.velocity = Vector3.ZERO
	for i in range(8):
		await physics_frame
	await _save("elevator_before_boarding")
	var prompt := elevator.get_prompt_for_player(game.player)
	print("STAGE2_ELEVATOR_INITIAL_PROMPT=" + JSON.stringify(prompt))
	var accepted := elevator.interact(game.player)
	if not accepted:
		push_error("Real elevator interact rejected near roof car")
		quit(1)
		return
	await _save("elevator_boarding")
	for i in range(420):
		await physics_frame
		if i in [20, 70, 140, 210, 280, 340, 410]:
			await _save("elevator_travel_%03d" % i)
		if i >= 310 and not elevator._travelling:
			break
	for i in range(90):
		await physics_frame
	await _save("elevator_after_arrival")
	print("STAGE2_ELEVATOR_STATE " + JSON.stringify({
		"travelling": elevator._travelling, "ground_ready": game._ground_map_ready,
		"rider_y": game.player.global_position.y, "ground_wave": game._ground_wave_started
	}))
	if elevator._travelling:
		push_warning("QA: elevator still travelling or awaiting ground resources after 510 physics frames")
	game.player.velocity = Vector3.ZERO
	var forward: Vector3 = -game.player.global_transform.basis.z.normalized()
	var anchor: Vector3 = game.player.global_position
	var enemies: Array[FoundationEnemy] = []
	var near := game._spawn_enemy("shambler", anchor + forward * 2.2 + Vector3.UP * 0.05)
	enemies.append(near)
	near.begin_spawn_assault(game.player)
	for i in range(18):
		await physics_frame
	await _save("combat_one_zombie_approach")
	game.player.request_attack("punch", "right")
	for i in range(20):
		await physics_frame
		if i in [3, 8, 13, 19]:
			await _save("combat_punch_%02d" % i)
	for offset in [-1.35, 1.35]:
		var enemy := game._spawn_enemy("shambler", anchor + forward * 2.8 + game.player.global_transform.basis.x * offset)
		enemies.append(enemy)
		enemy.begin_spawn_assault(game.player)
	for i in range(15):
		await physics_frame
	await _save("combat_three_zombies")
	game.player.request_attack("kick", "right")
	for i in range(20):
		await physics_frame
		if i in [3, 8, 13, 19]:
			await _save("combat_kick_%02d" % i)
	if game._boss_enemy != null:
		game._boss_enemy.global_position = game.player.global_position + forward * 4.0
		for i in range(12):
			await physics_frame
		await _save("combat_boss_visible")
	game.queue_free()
	await process_frame
	print("STAGE2_SEQUENCE_CAPTURED=%d ERRORS=%d" % [shots, failures])
	quit(0 if shots >= 14 and failures == 0 else 1)

func _save(label: String) -> void:
	for i in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		failures += 1
		push_error("No real Godot image for " + label)
		return
	var path := ProjectSettings.globalize_path(OUT.path_join(label + ".png"))
	if image.save_png(path) != OK:
		failures += 1
		push_error("Could not save " + label)
		return
	shots += 1
	print("STAGE2_SEQUENCE_FRAME " + JSON.stringify({
		"filename": path, "phase": label,
		"renderer": "Godot 4.7.2 GL Compatibility Mesa llvmpipe",
		"size": image.get_size(), "index": shots
	}))
