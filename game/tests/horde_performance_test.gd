extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player_controller.gd")
const FarVisuals := preload("res://scripts/horde_far_visuals.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Player.new() as FoundationPlayer
	player.set_physics_process(false)
	fixture.add_child(player)
	var batch := FarVisuals.new() as HordeFarVisuals
	batch.configure(200)
	batch.player = player
	batch.set_process(false)
	fixture.add_child(batch)
	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Vector3(0, 0.05, -50)
	enemy.set_physics_process(false)
	fixture.add_child(enemy)
	batch.register_enemy(enemy)
	check(enemy._model == null, "50 m birth does not instantiate an animated zombie rig")
	enemy._set_distance_detail(50.0)
	check(not enemy._visual_root.visible, "newborn animated model stays hidden")
	enemy.position.z = -24.0
	enemy._set_distance_detail(24.0)
	batch._process(0.07)
	check(batch.multimesh.visible_instance_count == 1, "fog band uses the shared silhouette")
	check(enemy._model == null and not enemy._visual_root.visible, "fog band needs no animated rig")
	enemy.position.z = -12.0
	enemy._set_distance_detail(12.0)
	batch._process(0.07)
	check(batch.multimesh.visible_instance_count == 0, "shared silhouette leaves the near combat ring")
	check(enemy._model != null and enemy._visual_root.visible, "near zombie builds and shows its detailed rig")
	enemy.position.z = -50.0
	enemy._set_distance_detail(50.0)
	batch._process(0.07)
	check(batch.multimesh.visible_instance_count == 0 and not enemy._visual_root.visible, "30 m outer limit culls both visual tiers")
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: horde performance (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: horde performance (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
