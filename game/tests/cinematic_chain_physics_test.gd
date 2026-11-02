extends SceneTree

## CI-only integration test: actual CharacterBody3D physics, line of sight,
## flashlight-target selection and contact-synchronized chain strikes.
const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Flashlight := preload("res://scripts/flashlight_visibility.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _check_flashlight_selection()
	await _check_physical_hop_and_collision()
	if failures.is_empty():
		print("PASS: cinematic zombie chain physics (%d checks)" % checks)
		quit(0)
	else:
		for problem in failures:
			push_error(problem)
		print("FAIL: %d of %d cinematic zombie chain physics checks failed" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _check_flashlight_selection() -> void:
	var player := Player.new() as FoundationPlayer
	player.set_physics_process(false)
	root.add_child(player)
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	var dark := Enemy.new() as FoundationEnemy
	dark.set_physics_process(false)
	root.add_child(dark)
	dark.global_position = Vector3(0.0, 0.0, -1.0)
	var lit := Enemy.new() as FoundationEnemy
	lit.set_physics_process(false)
	root.add_child(lit)
	lit.global_position = Vector3(0.0, 0.0, -2.5)
	var manager := Flashlight.new() as FlashlightVisibilityManager
	manager.player = player
	manager.enabled = true
	manager.aim_direction = Vector3.FORWARD
	manager._bands[dark.get_instance_id()] = Flashlight.Band.DARK_CLOSE_COMBAT
	manager._bands[lit.get_instance_id()] = Flashlight.Band.VISIBLE_CLOSE
	player.flashlight_visibility_manager = manager
	_check(player._select_chain_target() == lit, "chain skips dark zombie despite shorter distance")
	manager.aim_direction = Vector3.BACK
	_check(player._select_chain_target() == null, "chain cannot auto-lock zombies behind flashlight sector")
	manager.enabled = false
	_check(player._select_chain_target() == dark, "disabled flashlight restores nearest-zombie chain targeting")
	player.flashlight_visibility_manager = null
	manager.free()
	player.queue_free()
	dark.queue_free()
	lit.queue_free()
	await process_frame

func _add_floor() -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	floor.collision_mask = 0
	floor.position.y = -0.50
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40.0, 1.0, 40.0)
	box.shape = shape
	floor.add_child(box)
	root.add_child(floor)
	return floor

func _check_physical_hop_and_collision() -> void:
	var floor := _add_floor()
	var player := Player.new() as FoundationPlayer
	player.position = Vector3(0.0, 0.03, 0.0)
	root.add_child(player)
	var target := Enemy.new() as FoundationEnemy
	target.set_physics_process(false)
	target.position = Vector3(0.0, 0.03, -3.65)
	root.add_child(target)
	for i in range(4):
		await physics_frame
	var start_position := player.global_position
	var original_hp := target.hp
	_check(player.request_attack("punch", "left"), "hop attack request is accepted")
	_check(player.attack_phase == "approach", "target starts out of grab reach")
	var closest := INF
	for i in range(55):
		await physics_frame
		closest = minf(closest, player.global_position.distance_to(target.global_position))
	_check(player.global_position.z < start_position.z - 0.60, "actual physics frames move player toward the target")
	_check(closest < Player.CHAIN_GRAB_DISTANCE + 0.1, "real movement reaches grapple distance")
	_check(target.hp == original_hp - int(Player.ATTACKS["punch"].damage), "physical chain reaches contact and deals exactly one hit")
	player._finish_attack()
	player._queued_attack_kind = ""
	player._queued_attack_side = ""
	player.global_position = Vector3(0.0, 0.04, 0.0)
	player.velocity = Vector3.ZERO
	target.global_position = Vector3(0.0, 0.04, -3.65)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = Vector3(0.0, 1.0, -1.8)
	var collider := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(5.0, 3.0, 0.5)
	collider.shape = block
	wall.add_child(collider)
	root.add_child(wall)
	for i in range(3):
		await physics_frame
	_check(player._select_chain_target() == null, "wall blocks automatic zombie lock-on")
	var wall_hp := target.hp
	# Force a previously acquired target to test collision after the target was locked.
	player._engagement_target = target
	player.attack_kind = "punch"
	player.attack_side = "left"
	player.attack_phase = "approach"
	player.attack_phase_time = Player.CHAIN_APPROACH_SECONDS
	for i in range(40):
		await physics_frame
	_check(player.global_position.z > -1.32, "CharacterBody3D cannot hop through a solid wall")
	_check(player.attack_phase == "ready", "blocked approach times out rather than teleporting")
	_check(target.hp == wall_hp, "blocked approach cannot damage zombie through wall")
	player.queue_free()
	target.queue_free()
	wall.queue_free()
	floor.queue_free()
	await process_frame
