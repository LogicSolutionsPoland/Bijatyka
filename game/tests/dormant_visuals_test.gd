extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player_controller.gd")
const Director := preload("res://scripts/concealed_spawn.gd")
const Batch := preload("res://scripts/horde_far_visuals.gd")
const Flashlight := preload("res://scripts/flashlight_visibility.gd")

class VisibilityGate:
	extends Node
	var allowed := true
	func is_world_position_visible(_point: Vector3) -> bool:
		return allowed
	func is_visible_to_flashlight(_enemy: Node3D) -> bool:
		return allowed
	func track_enemy(_enemy: Node3D) -> void:
		pass
	func untrack_enemy(_id: int) -> void:
		pass

var failures: Array[String] = []
var checks := 0
var fixture: Node3D
var player: FoundationPlayer
var director: Node
var batch: HordeFarVisuals
var restored: Array[FoundationEnemy] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)

func _on_wake(at: Vector3, health: int, kind: String) -> void:
	var enemy := Enemy.new() as FoundationEnemy
	enemy.configure(kind)
	enemy.position = at
	enemy._player = player
	fixture.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.hp = health
	director.register_enemy(enemy)
	batch.register_enemy(enemy)
	restored.append(enemy)

func run() -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	player = Player.new() as FoundationPlayer
	fixture.add_child(player)
	player.set_physics_process(false)
	var gate := VisibilityGate.new()
	fixture.add_child(gate)
	director = Director.new()
	director.player = player
	director.population_limit = 30
	fixture.add_child(director)
	director.set_physics_process(false)
	batch = Batch.new() as HordeFarVisuals
	batch.configure(30)
	batch.player = player
	batch.dormant_source = director
	batch.visibility_manager = gate
	fixture.add_child(batch)
	batch.set_process(false)
	director.dormant_enemy_wake_requested.connect(_on_wake)

	var zombie := Enemy.new() as FoundationEnemy
	zombie.position = Vector3(0.0, 0.05, -11.0)
	zombie.rotation.y = 0.7
	zombie._player = player
	fixture.add_child(zombie)
	zombie.set_physics_process(false)
	zombie.hp = 37
	director.register_enemy(zombie)
	batch.register_enemy(zombie)
	director._update_dormant_population(Director.DORMANT_SCAN_INTERVAL)
	check(director.dormant_population_count() == 1 and director.ordinary_population_count() == 1, "sleep keeps exactly one living record")
	var records: Array[Dictionary] = director.get_dormant_visual_records()
	check(records.size() == 1 and records[0].has("visual_id") and records[0].has("facing_y"), "record retains stable proxy identity and orientation")
	batch._process(0.04)
	check(batch.get_visible_dormant_count() == 1 and batch.multimesh.visible_instance_count == 1, "data-only proxy draws in existing MultiMesh without duplicate actor")
	check(batch.multimesh.get_instance_transform(0).origin.distance_to(Vector3(0.0, 0.05, -11.0)) < 0.01, "proxy renders at original world position")
	check(batch.get_resident_rig_count() == 0, "data-only proxy requires no full zombie rig")

	gate.allowed = false
	batch._process(0.13)
	check(batch.get_visible_dormant_count() == 0 and batch.multimesh.visible_instance_count == 0, "dark flashlight band hides the dormant silhouette")
	gate.allowed = true
	batch._process(0.13)
	check(batch.get_visible_dormant_count() == 1, "proxy reappears only after flashlight illumination")
	player.position.z = -5.75 # 5.25m, no wake yet
	director._update_dormant_population(Director.DORMANT_SCAN_INTERVAL)
	check(restored.is_empty() and director.dormant_population_count() == 1, "visible proxy does not wake at 5.25 m")
	batch._process(0.13)
	check(batch.get_visible_dormant_count() == 1, "single proxy remains visible before crossing 5 m")
	player.position.z = -6.1 # 4.9m, materialize in place
	director._update_dormant_population(Director.DORMANT_SCAN_INTERVAL)
	check(restored.size() == 1 and director.dormant_population_count() == 0, "wake swaps proxy to real actor without duplicate record")
	batch._process(0.04)
	check(batch.get_visible_dormant_count() == 0, "woken zombie has no leftover proxy")
	check(director.ordinary_population_count() == 1, "wake does not change total living population")
	if restored.size() == 1:
		check(restored[0].hp == 37 and is_equal_approx(restored[0].global_position.z, -11.0), "wake retains HP and actual position")

	var world_gate := Flashlight.new() as FlashlightVisibilityManager
	world_gate.player = player
	world_gate.enabled = true
	world_gate.aim_direction = Vector3(0, 0, -1)
	check(world_gate.is_world_position_visible(Vector3(0.0, 0.05, -11.0)), "shared classifier admits record inside front flashlight sector")
	check(not world_gate.is_world_position_visible(Vector3(0.0, 0.05, 10.0)), "shared classifier rejects record behind flashlight")
	check(not world_gate.is_world_position_visible(Vector3(0.0, 0.05, -40.0)), "shared classifier rejects record outside 30 m range")
	world_gate.enabled = false
	check(world_gate.is_world_position_visible(Vector3(0.0, 0.05, 10.0)), "disabling flashlight mask restores in-range visibility")

	director.store_upstairs_population(4)
	check(director.get_dormant_visual_records().is_empty() and director.ordinary_population_count() == 4, "roof stores four invisible population entries")
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: dormant proxy MultiMesh and flashlight (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: dormant proxy MultiMesh (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
