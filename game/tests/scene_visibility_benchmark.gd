extends SceneTree
## Run the same script on both revisions with --headless --fixed-fps 60.
## Samples only the synchronous CPU time of the production visibility update.

const WORLD := preload("res://scenes/foundation.tscn")
const WARMUP := 12
const SAMPLES := 180

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := WORLD.instantiate()
	root.add_child(world)
	world.game_music_player.stop()
	for frame in range(40):
		await process_frame
	_sample(world, false)
	world._set_rooftop_render_profile(false)
	world._ground_map_ready = true
	_sample(world, true)
	world.queue_free()
	await process_frame
	quit()

func _sample(world: Node, ground: bool) -> void:
	var elapsed: Array[int] = []
	for i in range(WARMUP + SAMPLES):
		if ground:
			world.player.global_position = Vector3(18.0 * sin(i * 0.12), 0.05, -5.2 + 18.0 * cos(i * 0.12))
		var start := Time.get_ticks_usec()
		world._update_distance_visibility()
		var duration := Time.get_ticks_usec() - start
		if i >= WARMUP:
			elapsed.append(duration)
	elapsed.sort()
	print("VISIBILITY_CPU_SAMPLE " + JSON.stringify({
		"scene": "moving_ground" if ground else "stationary_roof",
		"samples": SAMPLES, "median_us": elapsed[SAMPLES / 2],
		"p95_us": elapsed[ceili(SAMPLES * 0.95) - 1]
	}))
