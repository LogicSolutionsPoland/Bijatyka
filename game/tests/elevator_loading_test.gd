extends SceneTree

const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")
const ELEVATOR := preload("res://scripts/starting_elevator.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_checks")


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("Elevator loading: " + message)


func _run_checks() -> void:
	var world = FOUNDATION_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	var elevator = world.starting_tower.elevator
	var coordinator = world._ground_loading_coordinator
	_check(not coordinator.is_active(), "load screen must start hidden")
	_check(world.player.global_position.y > 19.0, "spawn must stay on the rooftop")

	# Simulate the car parked on the lower floor, then use the real CALL input.
	elevator._car_root.position.y = ELEVATOR.BOTTOM_CAR_Y
	_check(elevator.get_prompt_for_player(world.player) == "CALL\nLIFT",
		"rooftop should be offered CALL LIFT when car is below")
	_check(elevator.interact(world.player), "lift call must be accepted")
	_check(coordinator.is_active(), "CALL must start loading before boarding")
	_check(coordinator.screen.is_loading_visible(), "overlay must appear on call")
	_check(not world._ground_map_ready, "ground cannot be marked ready before prep")

	# Complete the unoccupied lift motion, then let the batched visual/style
	# pipeline run. The overlay must not disappear while this is unfinished.
	elevator._car_root.position.y = ELEVATOR.TOP_CAR_Y
	for index in range(480):
		await process_frame
		if not coordinator.is_active():
			break
	_check(not coordinator.is_active(), "call/loading screen must complete")
	_check(not coordinator.screen.is_loading_visible(), "roof returns after warmup")
	_check(world._rooftop_sky_active, "roof graphics must be restored")
	_check(world.player.is_physics_processing(), "rooftop controls must be restored")
	_check(not world._ground_map_ready, "roof should not claim ground is active")

	# The already-called elevator is at the roof. Boarding starts a new
	# protected descent and must not accidentally create a second map.
	_check(elevator.interact(world.player), "descent must start when boarded")
	_check(coordinator.is_active(), "descent needs the loading screen")
	_check(not elevator._ground_floor_ready, "doors are gated while preparing")
	for index in range(480):
		await process_frame
		if world._ground_map_ready:
			break
	_check(world._ground_map_ready, "ground map must finish")
	_check(elevator._ground_floor_ready, "ground doors become ready")
	elevator._car_root.position.y = ELEVATOR.BOTTOM_CAR_Y
	for index in range(24):
		await process_frame
		if not coordinator.is_active():
			break
	_check(not coordinator.is_active(), "ground overlay should close after arrival")
	_check(world._ground_wave_started, "zombie population starts only at arrival")
	_check(world.player.is_physics_processing(), "ground controls must be restored")

	world._on_player_respawned()
	_check(not coordinator.is_active(), "respawn must cancel pending loading")
	_check(world._rooftop_sky_active, "respawn must restore rooftop profile")
	_check(not coordinator.screen.is_loading_visible(), "respawn hides screen")

	if failures.is_empty():
		print("PASS: elevator call loading and ground GPU warmup")
		quit(0)
	else:
		print("FAIL: %d elevator loading checks" % failures.size())
		quit(1)
