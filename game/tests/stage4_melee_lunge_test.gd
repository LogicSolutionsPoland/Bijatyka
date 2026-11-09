extends SceneTree
## Stage 4: real Godot CharacterBody3D lunge, collision and state ownership.
const Player := preload("res://scripts/player_controller.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("Stage4 lunge: " + label)

func _floor() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(25.0, 1.0, 25.0)
	collision.shape = shape
	body.position.y = -0.5
	body.add_child(collision)
	root.add_child(body)
	return body

func _wall() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = Vector3(0.0, 1.0, -0.55)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 3.0, 0.2)
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body

func _run() -> void:
	var floor_body := _floor()
	var player := Player.new() as FoundationPlayer
	player.position = Vector3(0.0, 0.06, 0.0)
	root.add_child(player)
	for frame in range(25):
		await physics_frame
		if player.is_on_floor():
			break
	_check(player.is_on_floor(), "player settles on a real collision floor")
	_check(is_equal_approx(Player.MELEE_LUNGE_SPEED_MPS, 1.5), "source speed kept at 1.5 m/s")
	_check(is_equal_approx(Player.MELEE_LUNGE_DURATION_SECONDS, 0.20), "source duration remains 0.20 s")
	player.attack_kind = "punch"
	player.attack_phase = "active"
	player.attack_phase_time = 0.65
	player._start_melee_lunge()
	_check(player._melee_lunge_time > 0.0, "grounded impact starts forward lunge")
	var before := player.global_position
	for frame in range(15):
		await physics_frame
	var displacement := before.z - player.global_position.z
	_check(displacement > 0.19 and displacement < 0.38, "unblocked lunge moves about 0.30 m using physics")
	_check(is_zero_approx(player._melee_lunge_time), "lunge timer expires without drift")
	player._finish_attack()
	player.global_position = Vector3(0.0, 0.06, 0.0)
	player.velocity = Vector3.ZERO
	var wall := _wall()
	for frame in range(6):
		await physics_frame
	player.attack_kind = "punch"
	player.attack_phase = "active"
	player.attack_phase_time = 0.65
	player._start_melee_lunge()
	for frame in range(16):
		await physics_frame
	_check(player.global_position.z > -0.36, "solid wall blocks forward lunge")
	player.cancel_melee_lunge()
	_check(is_zero_approx(player._melee_lunge_time), "explicit cancellation clears lunge")
	player.attack_phase = "active"
	player._parabolic_jump_active = true
	player._jump_state = Player.JumpState.FORWARD
	player._start_melee_lunge()
	_check(is_zero_approx(player._melee_lunge_time), "forward parabolic jump blocks lunge")
	player._parabolic_jump_active = false
	player._jump_state = Player.JumpState.READY
	player.grab_state = Player.GrabState.GRABBED
	player._start_melee_lunge()
	_check(is_zero_approx(player._melee_lunge_time), "zombie limb grab blocks lunge")
	player.grab_state = Player.GrabState.READY
	player._melee_lunge_time = 0.12
	player._melee_lunge_direction = Vector3.FORWARD
	player._set_grab_state(Player.GrabState.WINDUP)
	_check(is_zero_approx(player._melee_lunge_time), "grab windup cancels an active lunge")
	player._reset_at_safe_base()
	_check(is_zero_approx(player._melee_lunge_time) and player._melee_lunge_direction == Vector3.ZERO, "respawn clears lunge")
	player.queue_free()
	wall.queue_free()
	floor_body.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: stage4 melee lunge physics (%d checks)" % checks)
		quit(0)
	else:
		print("FAIL: stage4 melee lunge physics (%d of %d failed)" % [failures.size(), checks])
		quit(1)
