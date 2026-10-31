extends SceneTree

## Real Exo Gray GL Compatibility screenshots of Finger_Gun_Shoot.
## Produces review frames only; no APK, changes to input or combat timing.
const PLAYER := preload("res://scripts/player_controller.gd")
const OUT := "res://../build/finger_gun_spell_review"
const PHASES := {"prepare": 0.08, "fire": 0.30, "recover": 0.80}
var camera: Camera3D
var captures := 0
var errors := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.085, 0.095, 0.12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.9
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -34, 0)
	light.light_energy = 1.4
	stage.add_child(light)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.0, 5.0)
	floor.mesh = plane
	floor.position.y = -0.025
	stage.add_child(floor)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	stage.add_child(camera)
	camera.make_current()
	var player := PLAYER.new() as FoundationPlayer
	stage.add_child(player)
	player.set_physics_process(false)
	if player._exo_overlay == null:
		push_error("Cannot capture: Exo Gray finger gun animation missing")
		quit(1)
		return
	var overlay := player._exo_overlay as PlayerExoMixamoOverlay
	var animator := overlay._animator as AnimationPlayer
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for view in ["rear", "side"]:
		_aim(view)
		for phase in ["prepare", "fire", "recover"]:
			if not overlay.play_finger_gun():
				errors += 1
				continue
			animator.seek(float(PHASES[phase]), true)
			await _save("%s_%s" % [view, phase])
			overlay.stop_clip()
	player.queue_free()
	stage.queue_free()
	print("FINGER_GUN_CAPTURED=%d ERRORS=%d OUTPUT=%s" % [
		captures, errors, ProjectSettings.globalize_path(OUT)])
	quit(0 if errors == 0 and captures == 6 else 1)

func _aim(view: String) -> void:
	camera.position = Vector3(3.4, 1.55, 0.0) if view == "side" else Vector3(0.0, 1.55, 3.4)
	camera.look_at(Vector3(0.0, 0.95, 0.0))

func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var snapshot := root.get_texture().get_image()
	var target := ProjectSettings.globalize_path(OUT.path_join(name + ".png"))
	if snapshot == null or snapshot.save_png(target) != OK:
		push_error("Failed to save Exo pose: " + target)
		errors += 1
	else:
		captures += 1
