extends Node3D
## Decorative moving backdrop: never participates in gameplay collision or culling.
const WALL_HEIGHT := 6.0
const HALF_EXTENT := 20.0
const WALL_SHADER := preload("res://shaders/burning_horizon.gdshader")
const SKY_SHADER := preload("res://shaders/burning_sky.gdshader")

func _ready() -> void:
	add_to_group("distant_backdrop")
	var material := ShaderMaterial.new()
	material.shader = WALL_SHADER
	for side in range(4):
		var wall := MeshInstance3D.new()
		wall.name = "HorizonWall%d" % side
		var quad := QuadMesh.new()
		quad.size = Vector2(HALF_EXTENT * 2.0, WALL_HEIGHT)
		wall.mesh = quad
		wall.material_override = material
		wall.rotation.y = float(side) * PI * 0.5
		wall.position = Vector3(0.0, WALL_HEIGHT * 0.5, -HALF_EXTENT).rotated(Vector3.UP, wall.rotation.y)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wall)

func follow_player(at: Vector3) -> void:
	# Follow elevation as well: an airborne dash cannot cross the backdrop.
	# Keep world yaw fixed so looking around does not rotate the painted city.
	global_position = at

static func make_sky() -> Sky:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return sky
