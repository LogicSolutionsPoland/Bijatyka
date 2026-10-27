extends SceneTree

const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const NAMES := ["lead_straight", "rear_hook", "right_high_kick", "left_high_kick", "overhand", "duck_roll", "body_slip", "downward_stamp", "downward_punch", "step_in", "pivot_exit", "rope_recoil", "arms_raised_taunt", "kick_landing", "guard_raise", "guard_hold"]
const OUTPUT := "res://../build/ring_reference_views"
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var stage := Node3D.new(); root.add_child(stage)
	var world := WorldEnvironment.new(); world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.09, 0.11, 0.14)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.8
	stage.add_child(world)
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-35, -35, 0); light.light_energy = 1.2; stage.add_child(light)
	var camera := Camera3D.new(); stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 3.0
	camera.position = Vector3(2.6, 1.6, -3.3); camera.look_at(Vector3(0, 1.0, 0)); camera.make_current()
	for actor_type in ["player", "boss"]:
		var actor: Node3D
		if actor_type == "player": actor = Player.new()
		else:
			actor = Enemy.new(); actor.configure("boss")
		stage.add_child(actor); actor.set_physics_process(false)
		if actor_type == "boss": actor._set_full_animation_selected(true)
		var animator := actor._animation_player as AnimationPlayer
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for name in NAMES:
			var path := StringName("ring_reference/" + name)
			if not animator.has_animation(path): push_error("Missing reference " + name); quit(1); return
			var animation := animator.get_animation(path)
			var time := animation.get_marker_time(&"contact") if animation.has_marker(&"contact") else animation.length * .5
			animator.play(path, 0.0); animator.seek(time, true)
			actor._skeleton.force_update_all_bone_transforms()
			await process_frame; await RenderingServer.frame_post_draw
			var filename := "%s_%s.png" % [actor_type, name]
			var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join(filename)))
			if error != OK: push_error(filename); quit(1); return
			if name in ["lead_straight", "rear_hook", "right_high_kick", "left_high_kick"]:
				for step in range(1, 12):
					animator.seek(float(step) / 12.0 * animation.length, true)
					actor._skeleton.force_update_all_bone_transforms()
					await process_frame; await RenderingServer.frame_post_draw
					var frame_file := "%s_%s_frame_%02d.png" % [actor_type, name, step]
					if root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUTPUT.path_join(frame_file))) != OK:
						push_error(frame_file); quit(1); return
		actor.queue_free(); await process_frame
	print("CAPTURED_RING_REFERENCE=32")
	stage.queue_free(); quit(0)
