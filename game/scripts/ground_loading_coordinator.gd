extends Node
class_name GroundLoadingCoordinator

const SCREEN := preload("res://scripts/ground_loading_screen.gd")

## Coordinates the already-instantiated map batches, the ground graphics profile,
## Pencil Sketch conversion and real GPU draw warmup without duplicating the map.
## Called by the elevator's lifecycle signals, never by camera-height changes.
var world
var screen: GroundLoadingScreen
var _mode: StringName = &""
var _step := 0
var _visual_index := 0
var _delay_frames := 0
var _settle_frames := 0
var _style_pending_max := 0
var _gpu_frame := 0
var _call_arrived := false
var _warmup_camera: Camera3D


func configure(foundation: Node3D) -> void:
	world = foundation


func _ready() -> void:
	screen = SCREEN.new() as GroundLoadingScreen
	screen.name = "GroundMapLoadingScreen"
	add_child(screen)
	set_process(false)


func is_active() -> bool:
	return _mode != &""


func is_preparing_ground_profile() -> bool:
	return _mode == &"call" or _mode == &"ride"


func start_call() -> void:
	# Called while the unoccupied elevator rises to the rooftop.
	_start(&"call")


func call_arrived() -> void:
	if _mode == &"call":
		_call_arrived = true


func start_descent() -> void:
	_start(&"ride")


func ground_arrived() -> void:
	if _mode != &"ride":
		return
	_mode = &"ground_settle"
	_settle_frames = 4
	screen.set_progress(1.0, "Uruchamianie dolnego poziomu")
	world.player.velocity = Vector3.ZERO
	world.player.set_physics_process(false)


func cancel() -> void:
	_stop_warmup_camera()
	_mode = &""
	set_process(false)
	if is_instance_valid(screen):
		screen.hide_loading()


func _start(mode: StringName) -> void:
	if is_active():
		return
	_mode = mode
	_step = 0
	_visual_index = 0
	_delay_frames = 2 # The opaque CanvasLayer gets drawn before shader work.
	_settle_frames = 0
	_style_pending_max = 0
	_gpu_frame = 0
	_call_arrived = false
	world._ground_map_ready = false
	world._ground_map_preparing = true
	if mode == &"ride":
		world.starting_tower.elevator.set_ground_floor_ready(false)
	else:
		world.player.velocity = Vector3.ZERO
		world.player.set_physics_process(false)
	screen.show_loading()
	set_process(true)


func _process(_delta: float) -> void:
	if _mode == &"call_settle" or _mode == &"ground_settle":
		_settle_frames -= 1
		if _settle_frames <= 0:
			_finish()
		return
	if _mode == &"call" and world._ground_map_ready:
		if _call_arrived:
			# Cached GPU pipelines remain available for the later descent.
			world._restore_rooftop_map()
			_mode = &"call_settle"
			_settle_frames = 3
			screen.set_progress(0.99, "Przywracanie widoku dachu")
		return
	if _mode == &"ride" and world._ground_map_ready:
		# The lift is still travelling or waiting for the arrival callback.
		screen.set_progress(0.99, "Oczekiwanie na dolny poziom")
		return
	if _mode != &"call" and _mode != &"ride":
		return
	if _delay_frames > 0:
		_delay_frames -= 1
		return
	_prepare_next_step()


func _prepare_next_step() -> void:
	# The real arena is built once in Foundation._ready(). Its static visual
	# batches were hidden on the roof; reveal one per frame, never reinstance.
	var visuals: Array = world._ground_map_visuals
	if _visual_index < visuals.size():
		var visual: GeometryInstance3D = visuals[_visual_index]
		if is_instance_valid(visual):
			visual.visible = true
		_visual_index += 1
		screen.set_progress(
			0.08 + 0.45 * float(_visual_index) / float(maxi(1, visuals.size())),
			"Przygotowywanie geometrii")
		return
	match _step:
		0:
			world._environment.sky = world._ground_sky
			screen.set_progress(0.60, "Ładowanie oświetlenia")
		1:
			world.burning_horizon.visible = true
			screen.set_progress(0.68, "Ładowanie efektów")
		2:
			world._set_rooftop_render_profile(false)
			screen.set_progress(0.74, "Przygotowywanie Pencil Sketch")
		_:
			var style := get_tree().root.get_node_or_null("PencilSketchStyle")
			if style != null and not style.is_gameplay_style_ready():
				var remaining := int(style.get_pending_mesh_count())
				_style_pending_max = maxi(_style_pending_max, remaining)
				var fraction := 1.0 - float(remaining) / float(maxi(1, _style_pending_max))
				screen.set_progress(0.74 + 0.10 * fraction, "Przetwarzanie materiałów")
				return
			# A loaded shader is not necessarily a compiled GPU pipeline.
			# Render the real ground environment from multiple perspectives
			# behind the opaque overlay to prime first-use variants.
			if _gpu_frame < 8:
				_draw_warmup_view(_gpu_frame)
				_gpu_frame += 1
				screen.set_progress(
					0.84 + 0.14 * float(_gpu_frame) / 8.0,
					"Przygotowywanie efektów graficznych")
				return
			_stop_warmup_camera()
			world._ground_map_preparing = false
			world._ground_map_ready = true
			if _mode == &"ride":
				world.starting_tower.elevator.set_ground_floor_ready(true)
			else:
				screen.set_progress(0.99, "Oczekiwanie na windę")
			return
	_step += 1


func _draw_warmup_view(frame: int) -> void:
	if not is_instance_valid(_warmup_camera):
		_warmup_camera = Camera3D.new()
		_warmup_camera.name = "TemporaryGroundGPUWarmupCamera"
		_warmup_camera.fov = world.camera.fov
		_warmup_camera.near = world.camera.near
		_warmup_camera.far = world.camera.far
		add_child(_warmup_camera)
		_warmup_camera.current = true
	var eye := Vector3(0.0, 2.0, -9.0)
	var look_at := Vector3(0.0, 2.0, -24.0)
	match frame:
		1:
			look_at = Vector3(-18.0, 2.0, -20.0)
		2:
			look_at = Vector3(18.0, 2.0, -20.0)
		3:
			eye = Vector3(-13.0, 3.0, -19.0)
			look_at = Vector3(6.0, 2.0, -13.0)
		4:
			eye = Vector3(13.0, 3.0, -19.0)
			look_at = Vector3(-6.0, 2.0, -13.0)
		5:
			eye = Vector3(0.0, 7.0, -22.0)
			look_at = Vector3(0.0, 0.0, -7.0)
		6:
			eye = Vector3(0.0, 2.0, -24.0)
			look_at = Vector3(0.0, 2.0, -7.0)
		7:
			# Include the player's flashlight volume in at least one draw.
			eye = world.player.global_position + Vector3(0.0, 1.7, 5.0)
			look_at = world.player.global_position + Vector3(0.0, 1.5, -10.0)
	_warmup_camera.global_position = eye
	_warmup_camera.look_at(look_at, Vector3.UP)


func _stop_warmup_camera() -> void:
	if is_instance_valid(_warmup_camera):
		world.camera.current = true
		_warmup_camera.queue_free()
		_warmup_camera = null


func _finish() -> void:
	screen.hide_loading()
	_mode = &""
	set_process(false)
	if is_instance_valid(world.player):
		world.player.set_physics_process(true)
