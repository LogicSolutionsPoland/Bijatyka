extends SceneTree

## Deterministic review views of the actual player model and runtime clips.
const Player := preload("res://scripts/player_controller.gd")
const OUTPUT := "res://../build/player_attack_views"

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
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 1.2
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.8, 1.6, -3.4)
	camera.look_at(Vector3(0, 0.92, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.6
	camera.make_current()
	var player := Player.new() as FoundationPlayer
	stage.add_child(player)
	player.set_physics_process(false)
	player._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for kind in ["punch", "kick"]:
		for side in ["left", "right"]:
			var clip: StringName = Player.PLAYER_RING_REFERENCE.clip_path(side + "_front_kick") if kind == "kick" else Player.FIGHT_ANIMATION_BUILDER.clip_path(kind, side)
			if not player._animation_player.has_animation(clip):
				push_error("Missing visible player attack clip " + String(clip))
				quit(1)
				return
			player._animation_player.play(clip, 0.0)
			for phase in ["guard", "chamber", "contact", "recovery"]:
				var time := 0.0
				if phase == "chamber":
					time = float(Player.ATTACKS[kind].windup) * 0.72
				elif phase == "contact":
					time = float(Player.ATTACKS[kind].windup)
				elif phase == "recovery":
					time = player._animation_player.current_animation_length
				player._animation_player.seek(time, true)
				player._skeleton.force_update_all_bone_transforms()
				await process_frame
				await RenderingServer.frame_post_draw
				var filename := "%s_%s_%s.png" % [side, kind, phase]
				var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join(filename)))
				if error != OK:
					push_error("Failed to capture " + filename)
					quit(1)
					return
	print("CAPTURED_PLAYER_ATTACKS=16")
	stage.queue_free()
	quit()
