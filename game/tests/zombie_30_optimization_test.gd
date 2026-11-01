extends SceneTree

const Director := preload("res://scripts/concealed_spawn.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player_controller.gd")

var failures: Array[String] = []
var checks := 0
var fixture: Node3D
var player: FoundationPlayer
var director
var restored: Array[FoundationEnemy] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func _on_wake(at: Vector3, health: int, kind: String) -> void:
	var enemy := Enemy.new() as FoundationEnemy
	enemy.configure(kind)
	enemy.position = at
	enemy._player = player
	fixture.add_child(enemy)
	enemy.hp = health
	enemy._update_health_display()
	director.register_enemy(enemy)
	restored.append(enemy)

func run() -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	player = Player.new() as FoundationPlayer
	fixture.add_child(player)
	player.set_physics_process(false)
	director = Director.new()
	director.player = player
	director.population_limit = 30
	fixture.add_child(director)
	director.set_physics_process(false)
	director.dormant_enemy_wake_requested.connect(_on_wake)

	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Vector3(0.0, 0.05, -55.0)
	enemy._player = player
	fixture.add_child(enemy)
	enemy.hp = 37
	director.register_enemy(enemy)
	director._update_dormant_population(Director.DORMANT_SCAN_INTERVAL)
	check(director._dormant_population.size() == 1, "far unalerted zombie becomes data-only entry")
	check(director._live.is_empty() and director.ordinary_population_count() == 1, "data entry counts as living zombie")
	check(enemy.is_queued_for_deletion() and not enemy.is_physics_processing(), "sleeping actor does not run physics")
	await process_frame
	check(director.ordinary_population_count() == 1 and director._pending.is_empty(), "tree exit does not queue replacement")

	player.position.z = -20.0
	director._update_dormant_population(Director.DORMANT_SCAN_INTERVAL)
	check(restored.size() == 1 and director._dormant_population.is_empty(), "player approach wakes dormant record")
	if restored.size() == 1:
		check(restored[0].hp == 37, "health survives dormancy")
		check(is_equal_approx(restored[0].global_position.z, -55.0), "original position survives dormancy")
		check(director.ordinary_population_count() == 1, "wake never doubles count")
		check(restored[0].global_position.distance_to(player.global_position) > 30.0, "actor wakes outside visual range")

	for index in range(29):
		director._dormant_population.append({"position": Vector3(80.0 + float(index), 0.05, 0.0), "hp": 90, "kind": "shambler"})
	check(director.ordinary_population_count() == 30, "30 limit includes 29 data-only zombies")
	director.request_population()
	check(director._pending.is_empty(), "no spawn allowed over the 30 cap")
	if restored.size() == 1:
		director.replace_enemy(restored[0])
		check(director._pending.size() == 1, "death at cap queues just one free slot")
	director.store_upstairs_population(4)
	check(director.ordinary_population_count() == 4 and director.dormant_population_count() == 0, "rooftop reset retains four records only")
	check(not director.is_physics_processing(), "director is inactive on rooftop")

	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: zombie 30 dormant population (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: zombie 30 dormant population (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
