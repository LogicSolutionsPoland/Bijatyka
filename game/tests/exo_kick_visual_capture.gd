extends SceneTree

## Visual review of the actual visible Exo Gray 112-bone mesh.
## Old contact screenshots reproduce the exact source frame used by the
## previous percent-based cutter; new ones use the corrected compact clips.
## No game map, enemy AI or APK export is required.

const PLAYER := preload("res://scripts/player_controller.gd")
const OUT := "res://../build/exo_kick_comparison"
const LEGACY_FRACTIONS := {"mma_kick": 0.37, "roundhouse": 0.65, "fly_kick": 0.50}
const PHASES := {
	"start": 0.0,
	"chamber": 0.065,
	"contact": 0.12,
	"follow": 0.20,
	"recovery": 0.32,
}

var camera: Camera3D
var captures := 0
var errors := 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var directory := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(directory)
	var stage := Node3D.new()
	root.add_child(stage)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.10, 0.12, 0.15)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.8
	stage.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -30, 0)
	key.light_energy = 1.2
	stage.add_child(key)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(5.0, 5.0)
	floor.mesh = plane
	floor.position.y = -0.025
	stage.add_child(floor)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.9
	stage.add_child(camera)
	camera.make_current()
	var player := PLAYER.new() as FoundationPlayer
	stage.add_child(player)
	player.set_physics_process(false)
	if player._exo_overlay == null:
		push_error("Exo visual overlay missing")
		quit(1)
		return
	player._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var overlay := player._exo_overlay as PlayerExoMixamoOverlay
	var animator := overlay._animator
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip_name in ["mma_kick", "roundhouse", "fly_kick"]:
		for view in ["rear", "side"]:
			_aim(view)
			# Before: original 0.12-s contact sample from the broken APK.
			if overlay.play_clip(clip_name):
				var original := animator.get_animation(StringName("exo_mixamo/" + clip_name))
				animator.seek(original.length * float(LEGACY_FRACTIONS[clip_name]), true)
				await _save("before_%s_%s_contact" % [clip_name, view])
			else:
				errors += 1
			overlay.stop_clip()
			for side in ["left", "right"]:
				for phase in PHASES:
					if not overlay.play_strike(clip_name, side):
						errors += 1
						continue
					animator.seek(float(PHASES[phase]), true)
					await _save("after_%s_%s_%s_%s" % [clip_name, side, view, phase])
					overlay.stop_clip()
	# Rapid repeats at 0.2s spacing with a real 0.12s contact pose.
	_aim("side")
	for i in range(5):
		if not overlay.play_strike("mma_kick", "right"):
			errors += 1
			continue
		animator.advance(0.12)
		await _save("repeat_%02d_contact" % i)
		animator.advance(0.08)
	overlay.stop_clip()
	player.queue_free()
	stage.queue_free()
	print("EXO_KICK_CAPTURED=%d ERRORS=%d OUTPUT=%s" % [captures, errors, directory])
	quit(0 if errors == 0 and captures >= 71 else 1)


func _aim(view: String) -> void:
	camera.position = Vector3(3.4, 1.55, 0.0) if view == "side" else Vector3(0.0, 1.55, 3.4)
	camera.look_at(Vector3(0.0, 0.95, 0.0))


func _save(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var filename := ProjectSettings.globalize_path(OUT.path_join(name + ".png"))
	if image == null or image.save_png(filename) != OK:
		push_error("Cannot save Exo screenshot: " + filename)
		errors += 1
	else:
		captures += 1
