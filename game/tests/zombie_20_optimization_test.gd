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
	director.population_limit = 30 # A legacy/debug request must be clamped.
	check(director.population_limit == 20 and Director.MAX_ORDINARY_POPULATION == 20, "all spawn paths cap ordinary zombies at 20")
	fixture.add_child(director)
	director.set_physics_process(false)
	director.dormant_enemy_wake_requested.connect(_on_wake)
	check(Director.DORMANT_SLEEP_DISTANCE_SQUARED == 100.0, "dormancy starts beyond 10m")
	check(Director.DORMANT_WAKE_DISTANCE_SQUARED == 25.0, "wake starts at 5m")
	check(Enemy.FAR_PHYSICS_DISTANCE == 7.0 and Enemy.FAR_PHYSICS_INTERVAL == 0.10, "physics switches to 10Hz beyond 7m")
	check(Enemy.FULL_ANIMATION_BUDGET == 7, "full rig budget is exactly seven")
	check(Enemy.SPATIAL_GRID_REFRESH_HZ == 10, "shared zombie neighbor grid refreshes at 10 Hz")
	check(Enemy._spatial_bucket(0, 60) == Enemy._spatial_bucket(5, 60), "neighbor grid remains cached for six 60 Hz ticks")
	check(Enemy._spatial_bucket(6, 60) == Enemy._spatial_bucket(0, 60) + 1, "neighbor grid advances on the seventh tick")
	check(Enemy._spatial_bucket(0, 30) == Enemy._spatial_bucket(2, 30) and Enemy._spatial_bucket(3, 30) == 1, "shared grid cadence adapts to 30 Hz physics")

	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Vector3(0.0, 0.05, -11.0)
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

	player.position.z = -5.75 # 5.25 m, still outside the wake radius
	director._update_dormant_population(Director.DORMANT_SCAN_INTERVAL)
	check(restored.is_empty() and director._dormant_population.size() == 1, "no wake until within five meters")
	player.position.z = -6.1 # 4.9 m, wake threshold crossed
	director._update_dormant_population(Director.DORMANT_SCAN_INTERVAL)
	check(restored.size() == 1 and director._dormant_population.is_empty(), "player approach wakes dormant record")
	if restored.size() == 1:
		check(restored[0].hp == 37, "health survives dormancy")
		check(is_equal_approx(restored[0].global_position.z, -11.0), "original position survives dormancy")
		check(director.ordinary_population_count() == 1, "wake never doubles count")
		check(restored[0].global_position.distance_to(player.global_position) <= 5.0, "actor wakes at requested five meter radius")

	for index in range(19):
		director._dormant_population.append({"position": Vector3(80.0 + float(index), 0.05, 0.0), "hp": 90, "kind": "shambler"})
	check(director.ordinary_population_count() == 20, "20 limit includes 19 data-only zombies")
	director.request_population()
	check(director._pending.is_empty(), "no spawn allowed over the 20 cap")
	if restored.size() == 1:
		director.replace_enemy(restored[0])
		check(director._pending.size() == 1, "death at cap queues just one free slot")
	director.store_upstairs_population(4)
	check(director.ordinary_population_count() == 4 and director.dormant_population_count() == 0, "rooftop reset retains four records only")
	check(not director.is_physics_processing(), "director is inactive on rooftop")
	director.activate_profiling_population(30)
	check(director.population_limit == 20, "profiling requests above 20 are clamped too")
	director.store_upstairs_population(30)
	check(director.ordinary_population_count() == 20, "even data-only rooftop storage cannot exceed the global cap")

	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: zombie 20 dormant population (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: zombie 20 dormant population (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
