extends SceneTree

const Pool := preload("res://scripts/combat_fx_pool.gd")
const Enemy := preload("res://scripts/enemy.gd")
const SpawnDirector := preload("res://scripts/concealed_spawn.gd")
const POOL_LIMITS := {
	"attack_sweep": 4,
	"attack_impact": 6,
	"spell_burst": 3,
	"zombie_hit_flash": 6,
}

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_anchor := Node3D.new()
	root.add_child(player_anchor)
	var pool := Pool.new() as FoundationCombatFxPool
	pool.visibility_origin = player_anchor
	root.add_child(pool)
	for _frame in range(24):
		await process_frame
	for kind in POOL_LIMITS:
		_check(pool.get_created_count(String(kind)) == int(POOL_LIMITS[kind]), "%s pool prewarms only to its bounded capacity" % kind)

	var first_position := Vector3(2.0, 1.0, -3.0)
	_check(pool.play_attack_impact(first_position, "punch"), "impact pool acquires a visual")
	var first_active := pool.get_active_effects("attack_impact")
	_check(first_active.size() == 1, "impact is tracked active exactly once")
	var first := first_active[0] if not first_active.is_empty() else null
	if first != null:
		var first_id := first.get_instance_id()
		_check(first.is_effect_visible(), "acquired impact becomes visible")
		_check(first.is_in_group("attack_impact_fx"), "active impact joins its temporary visual group")
		_check(first.get_visual_position().distance_to(first_position) < 0.001, "impact uses its current world position")
		_check(not first.has_collision_nodes(), "pooled impact has no collision or targeting body")
		_check(pool.release_effect(first), "active impact releases once")
		_check(not pool.release_effect(first), "duplicate impact release is ignored")
		_check(not first.is_effect_visible(), "released effect is hidden")
		_check(not first.is_in_group("attack_impact_fx"), "released effect leaves the temporary visual group")
		_check(is_equal_approx(first.get_visual_alpha(), 1.0), "release restores material alpha")
		_check(first.get_visual_position() == Vector3.ZERO and first.get_visual_scale() == Vector3.ONE, "release resets transforms before reuse")
		var second_position := Vector3(-4.0, 1.5, 7.0)
		_check(pool.play_attack_impact(second_position, "kick"), "released impact can be reacquired")
		var second_active := pool.get_active_effects("attack_impact")
		_check(second_active.size() == 1 and second_active[0].get_instance_id() == first_id, "reuse returns the same bounded object")
		if not second_active.is_empty():
			_check(second_active[0].is_effect_visible(), "reused object is visible again")
			_check(second_active[0].get_visual_position().distance_to(second_position) < 0.001, "reuse overwrites stale position")
			_check(second_active[0].is_in_group("attack_impact_fx"), "reuse restores active group membership")
			_check(not second_active[0].has_collision_nodes(), "reuse cannot inherit a stale collision body")
		for _frame in range(15):
			await process_frame
		_check(pool.get_active_count("attack_impact") == 0, "effect expiry releases the active slot")
		_check(not first.is_effect_visible(), "expired effect remains hidden in the pool")

	var hit_far := pool.play_zombie_hit_flash(Vector3(31.0, 1.0, 0.0), false)
	_check(not hit_far, "pooled hit visuals preserve the 30 m visibility boundary")
	_check(pool.play_zombie_hit_flash(Vector3(8.0, 1.0, 0.0), true), "visible hit flash can be acquired")
	var hit_flash := pool.get_active_effects("zombie_hit_flash")
	_check(hit_flash.size() == 1 and hit_flash[0].is_effect_visible(), "hit flash is visible while active")
	_check(hit_flash.is_empty() or not hit_flash[0].has_collision_nodes(), "hit flash never becomes targetable")
	_check(pool.play_spell_burst(Vector3(1.0, 1.0, 1.0), Color.ORANGE), "spell effect pool acquires a burst")
	_check(pool.play_attack_sweep("kick", "left", Vector2(1080.0, 2400.0)), "sweep pool acquires a screen effect")
	var visible_sweeps := pool.get_active_effects("attack_sweep")
	_check(not visible_sweeps.is_empty() and visible_sweeps[0].is_effect_visible(), "screen effect is visible while active")
	for effect in pool.get_active_effects("attack_sweep"):
		pool.release_effect(effect)
	for effect in pool.get_active_effects("spell_burst"):
		pool.release_effect(effect)
	for effect in pool.get_active_effects("zombie_hit_flash"):
		pool.release_effect(effect)

	var held: Array[FoundationTransientCombatFx] = []
	for _slot in range(int(POOL_LIMITS.attack_sweep)):
		var effect := pool.acquire_effect("attack_sweep")
		if effect != null:
			held.append(effect)
	var created_before_overflow := pool.get_created_count("attack_sweep")
	var overflow_effect := pool.acquire_effect("attack_sweep")
	_check(overflow_effect == null, "exhausted pool declines cosmetic work safely")
	_check(pool.get_created_count("attack_sweep") == created_before_overflow, "overflow never grows the pool beyond its cap")
	_check(pool.get_overflow_count() == 1, "pool records one safe overflow")
	for effect in held:
		pool.release_effect(effect)
	for effect in pool.get_active_effects("attack_sweep"):
		pool.release_effect(effect)
	for effect in pool.get_active_effects("spell_burst"):
		pool.release_effect(effect)
	for effect in pool.get_active_effects("zombie_hit_flash"):
		pool.release_effect(effect)

	await _test_repeated_zombie_death_and_replacement(pool)
	var stats := pool.get_profile_stats()
	_check(int(stats.created) == 19, "total pooled effect count stays within all four caps")
	_check(int(stats.active) == 0, "all test effects release exactly once")
	print("RUNTIME_FX_POOL_SAMPLE " + JSON.stringify(stats))
	pool.queue_free()
	player_anchor.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: runtime effect pooling (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d runtime effect checks failed" % [failures.size(), checks])
		quit(1)

func _test_repeated_zombie_death_and_replacement(pool: FoundationCombatFxPool) -> void:
	var director := SpawnDirector.new()
	root.add_child(director)
	var enemy := Enemy.new() as FoundationEnemy
	enemy.configure("shambler")
	enemy._lod_band = 3
	enemy.combat_fx_pool = pool
	root.add_child(enemy)
	var target := Node3D.new()
	root.add_child(target)
	enemy.combat_target = target
	director.register_enemy(enemy)
	director.register_enemy(enemy)
	_check(director._live.size() == 1, "duplicate registration adds one living replacement slot")
	enemy.defeated.connect(director.replace_enemy)
	enemy.receive_hit(1000, Vector3.FORWARD)
	_check(enemy.hp == 0 and enemy.collision_layer == 0 and enemy.collision_mask == 0, "death disables targeting collision immediately")
	await process_frame
	var collision := enemy.get_node("CollisionShape3D") as CollisionShape3D
	_check(collision.disabled, "deferred death collision disable completes")
	enemy._complete_death()
	enemy._complete_death()
	enemy.defeated.emit(enemy)
	director.replace_enemy(enemy)
	_check(director._live.is_empty(), "death removes its live slot once")
	_check(director._pending.size() == 1, "duplicate death signals schedule one replacement only")
	await process_frame
	_check(not is_instance_valid(enemy), "completed death frees the original zombie")
	for effect in pool.get_active_effects("zombie_hit_flash"):
		_check(not effect.has_collision_nodes(), "death hit flash remains visual-only")
		pool.release_effect(effect)
	director.queue_free()
	target.queue_free()
	await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

