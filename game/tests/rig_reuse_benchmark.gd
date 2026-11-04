extends SceneTree
## Run unchanged on baseline and candidate. Measures synchronous rig transfers,
## not whole frames, Android GPU time or thermal behavior.

const Enemy := preload("res://scripts/enemy.gd")
const Horde := preload("res://scripts/horde_far_visuals.gd")
const VARIANTS := ["shambler", "brute", "stalker"]
const SAMPLE_COUNT := 60

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var pool := Horde.new()
	pool.configure(20)
	fixture.add_child(pool)
	pool.set_process(false)
	var actors: Array[FoundationEnemy] = []
	for kind in VARIANTS:
		var enemy := Enemy.new()
		enemy.configure(kind)
		fixture.add_child(enemy)
		enemy.set_physics_process(false)
		pool.register_enemy(enemy)
		actors.append(enemy)
	var samples: Array[int] = []
	for index in range(9 + SAMPLE_COUNT):
		var enemy := actors[index % actors.size()]
		var start := Time.get_ticks_usec()
		enemy._set_full_animation_selected(true)
		enemy._set_full_animation_selected(false)
		var elapsed := Time.get_ticks_usec() - start
		if index >= 9:
			samples.append(elapsed)
	var stats := pool.get_rig_pool_stats()
	samples.sort()
	var total := 0
	for sample in samples:
		total += sample
	print("RIG_REUSE_SAMPLE " + JSON.stringify({
		"samples": samples.size(), "average_us": float(total) / samples.size(),
		"median_us": samples[samples.size() / 2],
		"p95_us": samples[ceili(samples.size() * 0.95) - 1],
		"rigs_created": stats.created, "rig_reuses": stats.reused,
		"static_memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"measure": "headless synchronous acquire+release, three warmed variants"
	}))
	fixture.queue_free()
	await process_frame
	if stats.created != 1 or stats.resident != 1:
		push_error("Transfer benchmark must retain exactly one model")
		quit(1)
		return
	print("PASS: repeated rig transfer benchmark")
	quit(0)
