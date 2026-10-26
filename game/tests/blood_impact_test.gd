extends SceneTree
## Standalone functional test:
## godot --headless --path game --script res://tests/blood_impact_test.gd

const FX_POOL := preload("res://scripts/combat_fx_pool.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var anchor := Node3D.new()
	root.add_child(anchor)
	var pool := FX_POOL.new() as FoundationCombatFxPool
	pool.visibility_origin = anchor
	root.add_child(pool)
	await process_frame

	_check(pool.play_zombie_hit_flash(Vector3(2.0, 1.0, 0.0), false), "visible zombie hit starts")
	var active := pool.get_active_effects("zombie_hit_flash")
	_check(active.size() == 1, "one pooled hit effect becomes active")
	if not active.is_empty():
		var fx := active[0]
		var sprite := fx.find_child("BrackeysBloodImpact", true, false) as Sprite3D
		_check(sprite != null, "hit uses an atlas Sprite3D")
		if sprite != null:
			_check(sprite.texture != null, "Brackeys CC0 atlas is loaded")
			if sprite.texture != null:
				_check(sprite.texture.get_size() == Vector2(138, 100), "optimized mobile texture size")
			_check(sprite.hframes == 6 and sprite.vframes == 5, "sprite reads 6x5 atlas")
			_check(sprite.frame == 1, "starts at first non-empty atlas frame")
			_check(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "effect faces camera")
			_check(not sprite.shaded, "effect remains visible in dark scenes")
		_check(not fx.has_collision_nodes(), "visual hit has no collision")
		_check(fx.is_effect_visible(), "effect is visible after acquire")
		fx.advance(0.14)
		if sprite != null:
			_check(sprite.frame > 1 and sprite.frame <= 23, "flipbook advances frames")
		fx.advance(0.10)
		_check(fx.get_visual_alpha() < 1.0, "flipbook fades before expiry")
		_check(pool.release_effect(fx), "effect can be returned to pool")
		_check(not fx.is_effect_visible(), "released effect is hidden")
		_check(is_equal_approx(fx.get_visual_alpha(), 1.0), "release resets alpha")
		if sprite != null:
			_check(sprite.frame == 1, "release resets atlas frame")
		_check(pool.play_zombie_hit_flash(Vector3(3.0, 1.0, 0.0), true), "jump hit reuses the pool")
		var recycled := pool.get_active_effects("zombie_hit_flash")
		_check(recycled.size() == 1 and recycled[0].get_instance_id() == fx.get_instance_id(), "jump hit uses same Sprite3D instance")
		for effect in recycled:
			pool.release_effect(effect)

	_check(not pool.play_zombie_hit_flash(Vector3(31.0, 1.0, 0.0), false), "distant hits are culled past 30 metres")
	_check(pool.get_created_count("zombie_hit_flash") <= 6, "pool never exceeds six effects")
	_check(pool.get_active_count("zombie_hit_flash") == 0, "no effects remain active")
	pool.queue_free()
	anchor.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: blood impact atlas (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: blood impact atlas (%d/%d failed)" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
