extends Node3D
class_name StartingElevator

## Compact two-stop lift for the starting tower. The car is a moving platform;
## a safety hatch closes the roof opening whenever the car is below the roof.
const HEIGHT := 20.0
const SHAFT_SIZE := 2.80
const CAR_SIZE := 2.30
const PLATFORM_THICKNESS := 0.18
const TOP_CAR_Y := HEIGHT - PLATFORM_THICKNESS * 0.5
const BOTTOM_CAR_Y := PLATFORM_THICKNESS * 0.5
const LIFT_SPEED := 4.0
const PLAYER_FOOT_CLEARANCE := 0.05
const HATCH_THICKNESS := 0.16

var _wall_material: Material
var _trim_material: Material
var _metal_material: StandardMaterial3D
var _car_root: Node3D
var _platform_body: AnimatableBody3D
var _roof_hatch_collision: CollisionShape3D
var _roof_hatch_mesh: MeshInstance3D
var _rider: CharacterBody3D
var _travelling := false
var _target_y := TOP_CAR_Y
var _roof_hatch_open := false


func configure(wall_material: Material, trim_material: Material) -> void:
	_wall_material = wall_material
	_trim_material = trim_material


func _ready() -> void:
	_metal_material = StandardMaterial3D.new()
	_metal_material.albedo_color = Color(0.12, 0.15, 0.18)
	_metal_material.roughness = 0.88
	_build_shaft_frame()
	_build_roof_hatch()
	_build_car()
	_set_roof_hatch_open(true)


func _physics_process(delta: float) -> void:
	if not _travelling or _car_root == null:
		return
	_car_root.position.y = move_toward(_car_root.position.y, _target_y, LIFT_SPEED * delta)
	_update_roof_hatch()
	if _rider != null and is_instance_valid(_rider):
		_position_rider()
	if absf(_car_root.position.y - _target_y) > 0.002:
		return
	_car_root.position.y = _target_y
	_travelling = false
	_update_roof_hatch()
	if _rider != null and is_instance_valid(_rider):
		_position_rider()
		_rider.velocity = Vector3.ZERO
		_rider.set_physics_process(true)
	_rider = null


func get_prompt_for_player(player: CharacterBody3D) -> String:
	if _travelling or not is_instance_valid(player) or _car_root == null:
		return ""
	var local := to_local(player.global_position)
	if Vector2(local.x, local.z).length() > 3.2:
		return ""
	var player_floor_y := TOP_CAR_Y if local.y >= HEIGHT * 0.5 else BOTTOM_CAR_Y
	if absf(local.y - player_floor_y) > 3.0:
		return ""
	if absf(_car_root.position.y - player_floor_y) > 0.35:
		return "CALL\nLIFT"
	return "LIFT\nDOWN" if player_floor_y > HEIGHT * 0.5 else "LIFT\nUP"


func interact(player: CharacterBody3D) -> bool:
	if _travelling or get_prompt_for_player(player).is_empty():
		return false
	var local := to_local(player.global_position)
	var player_floor_y := TOP_CAR_Y if local.y >= HEIGHT * 0.5 else BOTTOM_CAR_Y
	if absf(_car_root.position.y - player_floor_y) > 0.35:
		_start_trip(player_floor_y)
		return true
	var destination_y := BOTTOM_CAR_Y if player_floor_y > HEIGHT * 0.5 else TOP_CAR_Y
	_start_trip(destination_y, player)
	return true


func is_player_riding(player: CharacterBody3D) -> bool:
	return _rider != null and is_instance_valid(_rider) and _rider == player


func contains_local_shaft(local_position: Vector3) -> bool:
	var half := SHAFT_SIZE * 0.5
	return absf(local_position.x) <= half and absf(local_position.z) <= half


func _start_trip(destination_y: float, rider: CharacterBody3D = null) -> void:
	_target_y = destination_y
	_rider = rider
	_travelling = true
	if _rider != null and is_instance_valid(_rider):
		_rider.velocity = Vector3.ZERO
		_rider.set_physics_process(false)
		_position_rider()


func _position_rider() -> void:
	if _rider == null or not is_instance_valid(_rider):
		return
	var feet_y := _car_root.position.y + PLATFORM_THICKNESS * 0.5 + PLAYER_FOOT_CLEARANCE
	_rider.global_position = to_global(Vector3(0.0, feet_y, 0.0))


func _update_roof_hatch() -> void:
	if _target_y > TOP_CAR_Y - 0.01:
		if _car_root.position.y >= TOP_CAR_Y - 2.0:
			_set_roof_hatch_open(true)
	elif _car_root.position.y <= TOP_CAR_Y - 0.35:
		_set_roof_hatch_open(false)


func _set_roof_hatch_open(open: bool) -> void:
	if _roof_hatch_open == open or _roof_hatch_collision == null:
		return
	_roof_hatch_open = open
	_roof_hatch_collision.disabled = open
	_roof_hatch_mesh.visible = not open


func _build_shaft_frame() -> void:
	var rail_offset := SHAFT_SIZE * 0.5 - 0.08
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			_add_visual_box("GuideRail", Vector3(side * rail_offset, HEIGHT * 0.5, depth * rail_offset),
				Vector3(0.12, HEIGHT, 0.12), _trim_material, self)


func _build_roof_hatch() -> void:
	var hatch := StaticBody3D.new()
	hatch.name = "RoofHatch"
	hatch.collision_layer = 1
	hatch.collision_mask = 0
	hatch.position.y = HEIGHT - HATCH_THICKNESS * 0.5
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SHAFT_SIZE, HATCH_THICKNESS, SHAFT_SIZE)
	collider.shape = shape
	hatch.add_child(collider)
	_roof_hatch_collision = collider
	_roof_hatch_mesh = _add_visual_box("RoofHatchMesh", Vector3(0.0, 0.0, 0.0),
		Vector3(SHAFT_SIZE, HATCH_THICKNESS, SHAFT_SIZE), _metal_material, hatch)
	add_child(hatch)


func _build_car() -> void:
	_car_root = Node3D.new()
	_car_root.name = "ElevatorCar"
	_car_root.position.y = TOP_CAR_Y
	add_child(_car_root)
	_platform_body = AnimatableBody3D.new()
	_platform_body.name = "CarPlatform"
	_platform_body.collision_layer = 1
	_platform_body.collision_mask = 0
	_platform_body.sync_to_physics = true
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CAR_SIZE, PLATFORM_THICKNESS, CAR_SIZE)
	collider.shape = shape
	_platform_body.add_child(collider)
	_car_root.add_child(_platform_body)
	_add_visual_box("CarDeck", Vector3.ZERO, Vector3(CAR_SIZE, PLATFORM_THICKNESS, CAR_SIZE),
		_metal_material, _car_root)
	var half := CAR_SIZE * 0.5 - 0.12
	for side in [-1.0, 1.0]:
		for depth in [-1.0, 1.0]:
			_add_visual_box("CarPost", Vector3(side * half, 1.02, depth * half),
				Vector3(0.11, 2.0, 0.11), _trim_material, _car_root)
		_add_visual_box("CarSideRail", Vector3(side * half, 0.78, 0.0),
			Vector3(0.08, 0.09, CAR_SIZE - 0.18), _metal_material, _car_root)
		_add_visual_box("CarSideTopRail", Vector3(side * half, 1.85, 0.0),
			Vector3(0.08, 0.08, CAR_SIZE - 0.18), _metal_material, _car_root)
	_add_visual_box("CarRearRail", Vector3(0.0, 0.78, half),
		Vector3(CAR_SIZE - 0.18, 0.09, 0.08), _metal_material, _car_root)
	_add_visual_box("CarRearTopRail", Vector3(0.0, 1.85, half),
		Vector3(CAR_SIZE - 0.18, 0.08, 0.08), _metal_material, _car_root)
	_add_visual_box("ControlPanel", Vector3(half - 0.04, 1.13, -half),
		Vector3(0.07, 0.34, 0.24), _wall_material, _car_root)


func _add_visual_box(label: String, at: Vector3, dimensions: Vector3, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.position = at
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual
