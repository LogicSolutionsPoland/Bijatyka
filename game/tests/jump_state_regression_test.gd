extends SceneTree
## Host regression checks for exclusive ordinary and forward jump ownership.
## This exercises game physics on the host; it does not represent Android device testing.

const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")

var _checks := 0
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("Jump-state host regression: " + message)

func _settle_on_ground(player: FoundationPlayer, at: Vector3) -> bool:
	player.velocity = Vector3.ZERO
	player.global_position = at
	player.rotation.y = 0.0
	for frame in range(120):
		await physics_frame
		if frame > 2 and player.is_on_floor() and is_zero_approx(player.velocity.y):
			return true
	return false

func _wait_for_landing(player: FoundationPlayer, max_frames: int = 150) -> bool:
	for frame in range(max_frames):
		await physics_frame
		if frame > 1 and player.is_on_floor() and not player._parabolic_jump_active and not player.jump_impact_armed:
			return true
	return false

func _flat_distance(from: Vector3, to: Vector3) -> float:
	var displacement := to - from
	displacement.y = 0.0
	return displacement.length()

func _run() -> void:
	var world := FOUNDATION_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	var player: FoundationPlayer = world.player
	_check(await _settle_on_ground(player, Vector3(20.0, 1.2, 20.0)), "player reaches a stable arena floor before jump checks")

	var signals := {"started": [], "landed": [], "impact_count": 0}
	player.parabolic_jump_started.connect(func(takeoff: Vector3, _direction: Vector3) -> void:
		signals["started"].append(takeoff)
	)
	player.parabolic_jump_landed.connect(func(landing: Vector3, _direction: Vector3) -> void:
		signals["landed"].append(landing)
	)
	player.jump_impact.connect(func(_target: Node) -> void:
		signals["impact_count"] = int(signals["impact_count"]) + 1
	)

	# Arbitration is first accepted request wins. A same-frame ordinary request
	# therefore keeps ownership, including while is_on_floor() is still stale.
	_check(player.try_jump(), "ordinary Jump starts when grounded")
	_check(not player.try_parabolic_jump(), "forward Jump is rejected after same-frame ordinary Jump")
	_check(player.jump_impact_armed and not player._parabolic_jump_active,
		"ordinary Jump owns only the ordinary landing impact")
	await physics_frame
	_check(not player.try_parabolic_jump(), "a forward command just after ordinary takeoff stays locked out")
	_check(await _wait_for_landing(player), "ordinary Jump reaches a normal landing")
	_check(not player.jump_impact_armed and not player._parabolic_jump_active,
		"ordinary landing releases the jump lock")
	_check(signals["started"].is_empty() and signals["landed"].is_empty(),
		"ordinary Jump emits no forward-jump signals")
	_check(not world.spawn_director._initial_horde_activated,
		"ordinary Jump cannot activate the prepared horde")

	_check(await _settle_on_ground(player, Vector3(20.0, 1.2, 20.0)), "player resets to the test takeoff point")
	var clear_takeoff := player.global_position
	_check(player.try_parabolic_jump(), "forward Jump starts when grounded")
	_check(not player.try_jump(), "ordinary Jump is rejected after same-frame forward Jump")
	_check(not player.jump_impact_armed and player._parabolic_jump_active,
		"forward Jump does not arm the ordinary landing impact")
	await physics_frame
	_check(not player.try_jump(), "an ordinary command just after forward takeoff stays locked out")
	_check(await _wait_for_landing(player), "forward Jump reaches a normal landing")
	var clear_landing := player.global_position
	_check(absf(_flat_distance(clear_takeoff, clear_landing) - player.forward_jump_distance_m) <= 0.15,
		"unobstructed forward Jump retains its intended 5 m travel")
	_check(signals["started"].size() == 1 and signals["landed"].size() == 1,
		"successful forward Jump emits start and landing exactly once")
	_check(int(signals["impact_count"]) == 0,
		"forward landing never triggers the ordinary jump impact")
	_check(not world.spawn_director._initial_horde_activated,
		"forward landing without an active population does not alter horde state")

	_check(await _settle_on_ground(player, Vector3(20.0, 1.2, 20.0)), "player returns to the obstructed-jump start")
	var wall := StaticBody3D.new()
	wall.name = "JumpRegressionWall"
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(4.0, 3.0, 0.4)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.global_position = player.global_position + Vector3.UP * 1.5 + Vector3.FORWARD * 2.8
	await physics_frame
	var obstructed_takeoff := player.global_position
	_check(player.try_parabolic_jump(), "forward Jump starts toward a physical wall")
	_check(await _wait_for_landing(player), "obstructed forward Jump completes its vertical arc and lands")
	var obstructed_landing := player.global_position
	_check(_flat_distance(obstructed_takeoff, obstructed_landing) < 4.5,
		"wall collision stops the forward travel before 5 m")
	_check(signals["started"].size() == 2 and signals["landed"].size() == 2,
		"obstructed forward Jump still emits one start and one landing")
	_check(int(signals["impact_count"]) == 0 and not world.spawn_director._initial_horde_activated,
		"obstructed forward landing does not cause ordinary impact or horde activation")

	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS: jump-state regression (%d checks; host physics, Android device not tested)" % _checks)
	else:
		print("FAIL: jump-state regression (%d/%d checks)" % [_failures.size(), _checks])
	quit(0 if _failures.is_empty() else 1)
