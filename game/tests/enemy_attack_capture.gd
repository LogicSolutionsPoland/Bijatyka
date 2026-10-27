extends SceneTree

## Render actual imported male/female rigs at guard, contact, and recovery.
const Enemy := preload("res://scripts/enemy.gd")
const OUTPUT := "res://../build/enemy_attack_views"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.09, 0.11, 0.14)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.2
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.8, 1.9, -3.8)
	camera.look_at(Vector3(0, 1.25, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.make_current()
	var count := 0
	for variant in ["shambler", "brute", "stalker", "boss"]:
		var enemy := Enemy.new() as FoundationEnemy
		enemy.configure(variant)
		stage.add_child(enemy)
		enemy.set_physics_process(false)
		enemy._set_full_animation_selected(true)
		if not enemy._fight_animations_ready:
			push_error("Missing combat clips on " + variant)
			quit(1)
			return
		enemy._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for kind in ["punch", "kick"]:
			for side in ["left", "right"]:
				var clip := Enemy.FIGHT_ANIMATION_BUILDER.clip_path(kind, side)
				var length := enemy._animation_player.get_animation(clip).length
				var contact := float(enemy._fight_attack_profiles()[kind].windup)
				for phase in ["guard", "contact", "recovery"]:
					var time := 0.0 if phase == "guard" else (contact if phase == "contact" else length)
					enemy._animation_player.play(clip, 0.0)
					enemy._animation_player.seek(time, true)
					enemy._skeleton.force_update_all_bone_transforms()
					await process_frame
					await RenderingServer.frame_post_draw
					var filename := "%s_%s_%s_%s.png" % [variant, side, kind, phase]
					var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join(filename)))
					if error != OK:
						push_error("Failed to render " + filename)
						quit(1)
						return
					count += 1
		enemy.queue_free()
		await process_frame
	print("CAPTURED_ENEMY_ATTACKS=%d" % count)
	stage.queue_free()
	quit(0)
