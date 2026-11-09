extends SceneTree
## Stage 5 cached visibility, effect lifecycle, and no-blackout regression.

const WORLD := preload("res://scenes/foundation.tscn")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _run() -> void:
	var world := WORLD.instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	world._update_distance_visibility()

	_check(world.ZOMBIE_PERFORMANCE_CAPACITY == 20, "20 ordinary zombies remain the population cap")
	_check(world.flashlight_visibility_manager.MAX_RADIUS == 10.0, "10m flashlight range remains")
	_check(world.flashlight_visibility_manager._composite == null, "full-screen blackout remains absent")
	_check(world._distance_visuals.size() > 0, "visible geometry is registered without repeated traversal")

	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.position = world.player.global_position + Vector3(80.0, 0.0, 0.0)
	world.add_child(box)
	world._update_distance_visibility()
	_check(not box.visible, "distant dynamic geometry is culled")
	box.global_position = world.player.global_position
	world._update_distance_visibility()
	_check(box.visible, "near dynamic geometry is restored")

	var backdrop := Node3D.new()
	backdrop.add_to_group("distant_backdrop")
	world.add_child(backdrop)
	var horizon := MeshInstance3D.new()
	horizon.mesh = QuadMesh.new()
	backdrop.add_child(horizon)
	horizon.global_position = world.player.global_position + Vector3(80.0, 0.0, 0.0)
	world._update_distance_visibility()
	_check(not world._distance_visuals.has(horizon) and horizon.visible,
		"backdrop remains independently visible and is never distance culled")
	box.reparent(backdrop)
	world._update_distance_visibility()
	_check(not world._distance_visuals.has(box), "reparented geometry drops obsolete visibility management")
	box.reparent(world)
	world._update_distance_visibility()
	_check(world._distance_visuals.has(box), "restored geometry is again registered")
	box.queue_free()
	backdrop.queue_free()

	var pool: FoundationCombatFxPool = world.combat_fx_pool
	var burst := pool.acquire_effect("spell_burst")
	burst.begin_spell_burst(world.player.global_position + Vector3(80.0, 0.0, 0.0), Color.WHITE)
	world._update_distance_visibility()
	pool.release_effect(burst)
	world._update_distance_visibility()
	_check(not burst.is_effect_visible(), "released distant effect never reappears")
	var reused := pool.acquire_effect("spell_burst")
	reused.begin_spell_burst(world.player.global_position, Color.WHITE)
	world._update_distance_visibility()
	_check(reused == burst and reused.is_effect_visible(), "nearby pooled effect is reusable")
	pool.release_effect(reused)

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: stage5 cached visibility and FX regressions (%d checks)" % checks)
	else:
		for problem in failures:
			push_error(problem)
		print("FAIL: stage5 cached visibility and FX regressions (%d failures)" % failures.size())
	quit(0 if failures.is_empty() else 1)
