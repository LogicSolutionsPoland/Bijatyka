extends Node3D

## White-stage rehearsal for the actual Bijatyka player scene and its Skeleton3D.
## Run res://scenes/player_choreography_preview.tscn in Godot 4.7.2.
## No enemy, damage, AI, camera or flashlight configuration is modified.
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CHOREOGRAPHY := preload("res://scripts/player_choreography.gd")

@export var loop_preview := true
var _player: FoundationPlayer

func _ready() -> void:
	_setup_white_stage()
	_player = PLAYER_SCENE.instantiate() as FoundationPlayer
	if _player == null:
		push_error("Failed to instantiate the current Bijatyka player")
		return
	add_child(_player)
	_player.set_physics_process(false)
	if _player._animation_player == null or not _player.play_choreography_preview():
		push_error("Player rehearsal could not bind choreography to the existing skeleton")
		return
	_player._animation_player.animation_finished.connect(_animation_finished)

func _setup_white_stage() -> void:
	var world := WorldEnvironment.new()
	world.name = "WhiteBackground"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	world.environment = env
	add_child(world)

	var floor := MeshInstance3D.new()
	floor.name = "RehearsalFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor.mesh = plane
	var matte := StandardMaterial3D.new()
	matte.albedo_color = Color.WHITE
	matte.roughness = 1.0
	floor.material_override = matte
	add_child(floor)

	var key := DirectionalLight3D.new()
	key.name = "SoftKeyLight"
	key.light_energy = 1.15
	key.shadow_enabled = false
	key.rotation_degrees = Vector3(-52.0, -25.0, 0.0)
	add_child(key)

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector3(3.6, 2.65, -6.2)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.fov = 46.0
	camera.current = true

func _animation_finished(animation_name: StringName) -> void:
	if loop_preview and is_instance_valid(_player) and animation_name == CHOREOGRAPHY.clip_path():
		_player.play_choreography_preview()
