extends Node3D
class_name StartingTower

## Hollow, 20-metre-tall starting tower built from a small number of
## collision boxes and one batched trim mesh. Local origin is ground level.
## The unobstructed northern doorway faces the existing boss/arena route.
const HEIGHT := 20.0
const WIDTH := 9.0
const WALL_THICKNESS := 0.50
const ROOF_THICKNESS := 0.30
const DOOR_WIDTH := 2.80
const DOOR_HEIGHT := 3.40
const WALL_HEIGHT := HEIGHT - ROOF_THICKNESS

var _wall_material: Material
var _trim_material: Material
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
	_build_shell()
	_build_trim()


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
	# Roof's top face is exactly HEIGHT (20 metres) above the courtyard.
	_add_solid_box("Roof", Vector3(0.0, HEIGHT - ROOF_THICKNESS * 0.5, 0.0),
		Vector3(WIDTH, ROOF_THICKNESS, WIDTH))


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
