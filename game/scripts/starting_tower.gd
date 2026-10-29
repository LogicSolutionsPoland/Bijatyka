extends Node3D
class_name StartingTower

const STARTING_ELEVATOR := preload("res://scripts/starting_elevator.gd")

## Hollow, 20-metre-tall starting tower built from compact collision boxes,
## batched trim, and a procedural safety cage on the rooftop. Local origin is
## ground level. The unobstructed northern doorway faces the boss/arena route.
## A covered elevator shaft connects the rooftop with the courtyard.
const HEIGHT := 20.0
const WIDTH := 9.0
const WALL_THICKNESS := 0.50
const ROOF_THICKNESS := 0.30
const DOOR_WIDTH := 2.80
const DOOR_HEIGHT := 3.40
const ELEVATOR_SHAFT_SIZE := 2.80
const WALL_HEIGHT := HEIGHT - ROOF_THICKNESS
const ROOF_GUARD_HEIGHT := 2.0
# Clear opening size between steel bars; the rooftop grid uses square 30 cm cells.
const ROOF_CAGE_OPENING := 0.30
const ROOF_CAGE_BAR_WIDTH := 0.02
const ROOF_CAGE_EDGE_BAR_WIDTH := 0.03
const ROOF_CAGE_EDGE_RAIL_HEIGHT := 0.05
# Safe area for a player capsule inside the rooftop cage.
const ROOF_SAFE_HALF_EXTENT := WIDTH * 0.5 - WALL_THICKNESS - 0.40

var _wall_material: Material
var _trim_material: Material
var _cage_material: Material
var elevator: StartingElevator
var _unit_box := BoxMesh.new()


func configure(wall_material: Material, trim_material: Material) -> void:
	_wall_material = wall_material
	_trim_material = trim_material


func _ready() -> void:
	if _wall_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.17, 0.19, 0.20)
		_wall_material = fallback
	if _trim_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.34, 0.19, 0.13)
		_trim_material = fallback
	if _cage_material == null:
		var fallback := StandardMaterial3D.new()
		fallback.albedo_color = Color(0.40, 0.43, 0.45)
		fallback.metallic = 0.35
		fallback.roughness = 0.68
		_cage_material = fallback
	_build_shell()
	_build_roof_cage()
	_build_trim()
	_build_elevator()


func _build_shell() -> void:
	var edge := (WIDTH - WALL_THICKNESS) * 0.5
	var doorway_section_width := (WIDTH - DOOR_WIDTH) * 0.5
	var section_center := (DOOR_WIDTH + doorway_section_width) * 0.5
	# Side and back walls are solid. No floor collider is needed: the
	# existing quarantine ground supports the player at ground level.
	_add_solid_box("WestWall", Vector3(-edge, WALL_HEIGHT * 0.5, 0.0),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, WIDTH))
	_add_solid_box("EastWall", Vector3(edge, WALL_HEIGHT * 0.5, 0.0),
		Vector3(WALL_THICKNESS, WALL_HEIGHT, WIDTH))
	_add_solid_box("RearWall", Vector3(0.0, WALL_HEIGHT * 0.5, edge),
		Vector3(WIDTH, WALL_HEIGHT, WALL_THICKNESS))
	# The door opening is an actual gap in collision, not a painted door.
	# It is wide enough for the player capsule and a camera-follow exit.
	_add_solid_box("DoorLeft", Vector3(-section_center, WALL_HEIGHT * 0.5, -edge),
		Vector3(doorway_section_width, WALL_HEIGHT, WALL_THICKNESS))
	_add_solid_box("DoorRight", Vector3(section_center, WALL_HEIGHT * 0.5, -edge),
		Vector3(doorway_section_width, WALL_HEIGHT, WALL_THICKNESS))
	_add_solid_box("DoorHeader", Vector3(0.0, (WALL_HEIGHT + DOOR_HEIGHT) * 0.5, -edge),
		Vector3(DOOR_WIDTH, WALL_HEIGHT - DOOR_HEIGHT, WALL_THICKNESS))
	# Leave a square shaft through the roof for the player elevator. The
	# lift platform or its safety hatch closes the opening at every other time.
	var roof_side_width := (WIDTH - ELEVATOR_SHAFT_SIZE) * 0.5
	var roof_side_center := (WIDTH + ELEVATOR_SHAFT_SIZE) * 0.25
	_add_solid_box("Roof", Vector3(-roof_side_center, HEIGHT - ROOF_THICKNESS * 0.5, 0.0),
		Vector3(roof_side_width, ROOF_THICKNESS, WIDTH))
	_add_solid_box("RoofEast", Vector3(roof_side_center, HEIGHT - ROOF_THICKNESS * 0.5, 0.0),
		Vector3(roof_side_width, ROOF_THICKNESS, WIDTH))
	_add_solid_box("RoofNorth", Vector3(0.0, HEIGHT - ROOF_THICKNESS * 0.5, roof_side_center),
		Vector3(ELEVATOR_SHAFT_SIZE, ROOF_THICKNESS, roof_side_width))
	_add_solid_box("RoofSouth", Vector3(0.0, HEIGHT - ROOF_THICKNESS * 0.5, -roof_side_center),
		Vector3(ELEVATOR_SHAFT_SIZE, ROOF_THICKNESS, roof_side_width))
	# The rooftop perimeter is added separately as a collidable 30 cm square
	# grid so the player stays safe while retaining a clear view of the city.


func _build_roof_cage() -> void:
	var placements: Array[Transform3D] = []
	var edge := (WIDTH - WALL_THICKNESS) * 0.5
	var west := _new_roof_cage_collision("RooftopCageWest")
	var east := _new_roof_cage_collision("RooftopCageEast")
	var north := _new_roof_cage_collision("RooftopCageNorth")
	var south := _new_roof_cage_collision("RooftopCageSouth")
	_append_roof_cage_panel(placements, west, -edge, true)
	_append_roof_cage_panel(placements, east, edge, true)
	_append_roof_cage_panel(placements, north, -edge, false)
	_append_roof_cage_panel(placements, south, edge, false)
	add_child(west)
	add_child(east)
	add_child(north)
	add_child(south)

	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _unit_box
	batch.instance_count = placements.size()
	for index in range(placements.size()):
		batch.set_instance_transform(index, placements[index])
	var cage_mesh := MultiMeshInstance3D.new()
	cage_mesh.name = "RooftopSpawnCageGrid"
	cage_mesh.multimesh = batch
	cage_mesh.material_override = _cage_material
	cage_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cage_mesh)


func _new_roof_cage_collision(label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_to_group("zombie_spawn_occluder")
	return body


func _append_roof_cage_panel(placements: Array[Transform3D], body: StaticBody3D,
		panel_coordinate: float, runs_along_z: bool) -> void:
	# Fit whole 30 cm openings within the panel, with narrow perimeter bars.
	var horizontal_cells := int(floor(
		(WIDTH - 2.0 * ROOF_CAGE_EDGE_BAR_WIDTH + ROOF_CAGE_BAR_WIDTH)
		/ (ROOF_CAGE_OPENING + ROOF_CAGE_BAR_WIDTH)))
	var vertical_cells := int(floor(
		(ROOF_GUARD_HEIGHT - 2.0 * ROOF_CAGE_EDGE_RAIL_HEIGHT + ROOF_CAGE_BAR_WIDTH)
		/ (ROOF_CAGE_OPENING + ROOF_CAGE_BAR_WIDTH)))
	var vertical_bar_height := ROOF_GUARD_HEIGHT - 2.0 * ROOF_CAGE_EDGE_RAIL_HEIGHT + ROOF_CAGE_BAR_WIDTH
	var center_y := HEIGHT + ROOF_GUARD_HEIGHT * 0.5
	var left_edge := -WIDTH * 0.5 + ROOF_CAGE_EDGE_BAR_WIDTH * 0.5
	var right_edge := WIDTH * 0.5 - ROOF_CAGE_EDGE_BAR_WIDTH * 0.5
	_append_roof_cage_vertical_bar(placements, body, panel_coordinate, left_edge,
		ROOF_CAGE_EDGE_BAR_WIDTH, center_y, vertical_bar_height, runs_along_z)
	_append_roof_cage_vertical_bar(placements, body, panel_coordinate, right_edge,
		ROOF_CAGE_EDGE_BAR_WIDTH, center_y, vertical_bar_height, runs_along_z)
	for index in range(horizontal_cells - 1):
		var axis_position := -WIDTH * 0.5 + ROOF_CAGE_EDGE_BAR_WIDTH
		axis_position += ROOF_CAGE_OPENING + ROOF_CAGE_BAR_WIDTH * 0.5
		axis_position += index * (ROOF_CAGE_OPENING + ROOF_CAGE_BAR_WIDTH)
		_append_roof_cage_vertical_bar(placements, body, panel_coordinate, axis_position,
			ROOF_CAGE_BAR_WIDTH, center_y, vertical_bar_height, runs_along_z)

	var bottom_y := HEIGHT + ROOF_CAGE_EDGE_RAIL_HEIGHT * 0.5
	var top_y := HEIGHT + ROOF_GUARD_HEIGHT - ROOF_CAGE_EDGE_RAIL_HEIGHT * 0.5
	_append_roof_cage_horizontal_bar(placements, body, panel_coordinate, bottom_y,
		ROOF_CAGE_EDGE_RAIL_HEIGHT, runs_along_z)
	_append_roof_cage_horizontal_bar(placements, body, panel_coordinate, top_y,
		ROOF_CAGE_EDGE_RAIL_HEIGHT, runs_along_z)
	for row in range(vertical_cells - 1):
		var row_y := HEIGHT + ROOF_CAGE_EDGE_RAIL_HEIGHT + ROOF_CAGE_OPENING
		row_y += ROOF_CAGE_BAR_WIDTH * 0.5
		row_y += row * (ROOF_CAGE_OPENING + ROOF_CAGE_BAR_WIDTH)
		_append_roof_cage_horizontal_bar(placements, body, panel_coordinate, row_y,
			ROOF_CAGE_BAR_WIDTH, runs_along_z)


func _append_roof_cage_vertical_bar(placements: Array[Transform3D], body: StaticBody3D,
		panel_coordinate: float, axis_position: float, axis_width: float, center_y: float,
		bar_height: float, runs_along_z: bool) -> void:
	var at: Vector3
	var dimensions: Vector3
	if runs_along_z:
		at = Vector3(panel_coordinate, center_y, axis_position)
		dimensions = Vector3(ROOF_CAGE_BAR_WIDTH, bar_height, axis_width)
	else:
		at = Vector3(axis_position, center_y, panel_coordinate)
		dimensions = Vector3(axis_width, bar_height, ROOF_CAGE_BAR_WIDTH)
	_append_roof_cage_bar(placements, body, at, dimensions)


func _append_roof_cage_horizontal_bar(placements: Array[Transform3D], body: StaticBody3D,
		panel_coordinate: float, y: float, rail_height: float, runs_along_z: bool) -> void:
	var at: Vector3
	var dimensions: Vector3
	if runs_along_z:
		at = Vector3(panel_coordinate, y, 0.0)
		dimensions = Vector3(ROOF_CAGE_BAR_WIDTH, rail_height, WIDTH)
	else:
		at = Vector3(0.0, y, panel_coordinate)
		dimensions = Vector3(WIDTH, rail_height, ROOF_CAGE_BAR_WIDTH)
	_append_roof_cage_bar(placements, body, at, dimensions)


func _append_roof_cage_bar(placements: Array[Transform3D], body: StaticBody3D,
		at: Vector3, dimensions: Vector3) -> void:
	placements.append(Transform3D(Basis.IDENTITY.scaled(dimensions), at))
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collider.shape = box
	collider.position = at
	body.add_child(collider)


func _build_elevator() -> void:
	elevator = STARTING_ELEVATOR.new() as StartingElevator
	elevator.name = "Elevator"
	elevator.configure(_wall_material, _trim_material)
	add_child(elevator)


func _add_solid_box(label: String, at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	body.add_to_group("zombie_spawn_occluder")
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collider.shape = box
	body.add_child(collider)
	var mesh := MeshInstance3D.new()
	mesh.mesh = _unit_box
	mesh.scale = dimensions
	mesh.material_override = _wall_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mesh)
	add_child(body)


func _build_trim() -> void:
	var placements: Array[Transform3D] = []
	var outer := WIDTH * 0.5 + 0.045
	# Four continuous exterior corner ribs, plus five thin horizontal bands.
	for x in [-outer, outer]:
		for z in [-outer, outer]:
			_append_trim(placements, Vector3(x, WALL_HEIGHT * 0.5, z),
				Vector3(0.17, WALL_HEIGHT, 0.17))
	for level in [0.35, 4.8, 9.6, 14.4, 19.5]:
		# Do not visually bridge the ground-floor entrance.
		if level < DOOR_HEIGHT:
			var front_section := (WIDTH - DOOR_WIDTH) * 0.5
			var front_offset := (DOOR_WIDTH + front_section) * 0.5
			for side in [-1.0, 1.0]:
				_append_trim(placements, Vector3(side * front_offset, level, -outer),
					Vector3(front_section, 0.15, 0.12))
		else:
			_append_trim(placements, Vector3(0.0, level, -outer),
				Vector3(WIDTH + 0.18, 0.15, 0.12))
		_append_trim(placements, Vector3(0.0, level, outer),
			Vector3(WIDTH + 0.18, 0.15, 0.12))
		_append_trim(placements, Vector3(-outer, level, 0.0),
			Vector3(0.12, 0.15, WIDTH + 0.18))
		_append_trim(placements, Vector3(outer, level, 0.0),
			Vector3(0.12, 0.15, WIDTH + 0.18))
	# Doorway gets an unmistakable frame, without blocking the exit.
	var front := -outer - 0.07
	for side in [-1.0, 1.0]:
		_append_trim(placements, Vector3(side * (DOOR_WIDTH * 0.5 + 0.12), DOOR_HEIGHT * 0.5, front),
			Vector3(0.16, DOOR_HEIGHT, 0.12))
	_append_trim(placements, Vector3(0.0, DOOR_HEIGHT + 0.07, front),
		Vector3(DOOR_WIDTH + 0.38, 0.15, 0.12))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = _unit_box
	batch.instance_count = placements.size()
	for index in range(placements.size()):
		batch.set_instance_transform(index, placements[index])
	var details := MultiMeshInstance3D.new()
	details.name = "BatchedTowerTrim"
	details.multimesh = batch
	details.material_override = _trim_material
	details.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(details)


func _append_trim(placements: Array[Transform3D], at: Vector3, dimensions: Vector3) -> void:
	placements.append(Transform3D(Basis.IDENTITY.scaled(dimensions), at))
