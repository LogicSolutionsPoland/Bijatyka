extends SceneTree
## Full runtime selection test: actual FoundationEnemy, camera, and manager.
## Confirms the code produces or suppresses glints, not just their pixel art.
const VISIBILITY := preload("res://scripts/flashlight_visibility.gd")
const ENEMY := preload("res://scripts/enemy.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := Node3D.new()
	stage.add_child(player)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.9, 3.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.6, -35.0))
	camera.current = true

	var enemy := ENEMY.new() as FoundationEnemy
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.position = Vector3(0.0, 0.0, -34.0)
	enemy.rotation.y = PI

	var manager := VISIBILITY.new()
	manager.configure(player, camera, true)
	stage.add_child(manager)
	manager.set_aim_yaw(0.0)
	manager.track_enemy(enemy)
	manager.set_process(false)
	for frame in range(5):
		await process_frame

	_check(camera.is_current(), "test camera is active")
	_check(enemy.collision_layer == 2, "ordinary enemy body is excluded from static-occluder ray")
	manager._update_distant_teeth()
	_check(_glint_count(manager) == 1, "real facing zombie at 34m creates one glint beyond the normal beam")

	enemy.rotation.y = 0.0
	manager._update_distant_teeth()
	_check(_glint_count(manager) == 0, "turning the zombie away hides its teeth")

	enemy.rotation.y = PI
	enemy.position.z = -36.0
	manager._update_distant_teeth()
	_check(_glint_count(manager) == 0, "zombie beyond the extra 5m cannot glint")

	enemy.position.z = -20.0
	manager._update_distant_teeth()
	_check(_glint_count(manager) == 1, "zombie inside the normal flashlight range glints")

	enemy.is_boss = true
	manager._update_distant_teeth()
	_check(_glint_count(manager) == 0, "boss remains excluded from ordinary-zombie glints")
	enemy.is_boss = false

	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(5.0, 4.0, 1.0)
	shape.shape = block
	wall.add_child(shape)
	stage.add_child(wall)
	wall.position = Vector3(0.0, 1.8, -11.0)
	await physics_frame
	manager._update_distant_teeth()
	_check(_glint_count(manager) == 0, "solid wall stops teeth glints from showing through geometry")

	stage.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: zombie teeth tracked enemy integration (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: zombie teeth tracked enemy integration (%d of %d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _glint_count(manager: Node) -> int:
	var entries: Array = manager._teeth_overlay.get("_glints")
	return entries.size()

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
