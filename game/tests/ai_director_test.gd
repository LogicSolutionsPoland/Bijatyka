extends SceneTree

const Director := preload("res://scripts/ai_director.gd")
const Spawns := preload("res://scripts/concealed_spawn.gd")
const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Player.new() as FoundationPlayer
	fixture.add_child(player)
	player.set_physics_process(false)
	var spawns := Spawns.new()
	spawns.player = player
	fixture.add_child(spawns)
	spawns.store_upstairs_population(4)
	var director := Director.new() as BijatykaAIDirector
	director.configure(player, spawns)
	fixture.add_child(director)
	director.activate()
	_check(not director.active and spawns.ordinary_population_count() == 4 and spawns._pending.is_empty(), "roof retains four data records and no Director births")
	spawns.activate_ground_population(30)
	spawns.set_physics_process(false)
	director.activate()
	_check(director.active and director._timer.time_left > 0.0 and spawns.director_attacker_target == 3, "arrival alone activates a 1 Hz pressure policy")
	for index in range(4):
		var enemy := Enemy.new() as FoundationEnemy
		enemy.configure("shambler")
		enemy.position = Vector3(float(index), 0.05, -6.0)
		enemy._player = player
		fixture.add_child(enemy)
		enemy.set_physics_process(false)
		spawns.register_enemy(enemy)
	_check(spawns.ordinary_population_count() == 4, "the stored opening four become four actors without duplication")
	var actors: Array = spawns._live.values()
	_check(spawns.try_acquire_attacker(actors[0]) and spawns.try_acquire_attacker(actors[1]) and spawns.try_acquire_attacker(actors[2]) and not spawns.try_acquire_attacker(actors[3]), "PRESSURE admits three of the unchanged maximum four attackers")
	director._evaluate(false)
	var calm_intensity := director.intensity
	player.take_boss_damage(35)
	_check(director.state == Director.State.RECOVERY and director.intensity > calm_intensity and spawns.director_attacker_target == 2, "damage spike quickly reduces ordinary attack pressure")
	_check(not spawns.try_acquire_attacker(actors[3]), "recovery does not interrupt existing attacks or admit a fifth attacker")
	for actor in actors:
		spawns.release_attacker(actor)
	director._recent_damage = 0.0
	director._recovery_cooldown = 8.0
	director._state_remaining = 0.0
	director._quiet_seconds = 8.0
	for actor in actors:
		actor.position = Vector3(40, 0.05, -40)
	director._evaluate(true)
	_check(director.state == Director.State.SURGE and spawns.director_attacker_target == 4 and spawns._pending.size() == 2, "quiet combat triggers a bounded surge with two reserved reinforcements")
	director._evaluate(true)
	_check(spawns._pending.size() <= 4, "one-second decisions cannot duplicate existing reservations")
	director._state_remaining = 0.0
	director._quiet_seconds = 0.0
	for actor in actors:
		actor.position = Vector3(0.0, 0.05, -6.0)
	for index in range(3):
		spawns.try_acquire_attacker(actors[index])
	for index in range(3):
		director.on_ordinary_defeated()
	_check(director.state == Director.State.PEAK and spawns.director_attacker_target == 4, "three quick kills and intensity promote a short peak")
	spawns.director_replacement_delay = 1.4
	spawns.request_reinforcements(1)
	spawns.director_replacement_delay = 0.65
	spawns.request_reinforcements(1)
	var ordered := true
	for index in range(1, spawns._pending.size()):
		ordered = ordered and spawns._pending[index] >= spawns._pending[index - 1]
	_check(ordered, "a faster replacement does not wait behind a later queue deadline")
	spawns.request_reinforcements(100)
	_check(spawns._live.size() + spawns._dormant_population.size() + spawns._pending.size() + spawns._initial_population_pending == 30, "reinforcement reservations never exceed the phase-one 30 cap")
	var start_us := Time.get_ticks_usec()
	for index in range(300):
		director._evaluate(false)
	var average_us := float(Time.get_ticks_usec() - start_us) / 300.0
	print("AI_DIRECTOR_HOST_EVALUATION_US=%.2f (4 tracked actors; no Android CPU measurement)" % average_us)
	spawns.store_upstairs_population(4)
	director.deactivate()
	_check(not director.active and director._timer.is_stopped() and spawns._pending.is_empty() and spawns.director_attacker_target == 4, "return to roof clears decisions and restores the original policy")
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: local AI Director (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: local AI Director (%d/%d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
