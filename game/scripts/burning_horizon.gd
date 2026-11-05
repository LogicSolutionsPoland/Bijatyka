extends Node3D
## Ground-level moving backdrop with a circular wall of generated zombie fog.
const WALL_HEIGHT := 6.0
const FLASHLIGHT_VISIBILITY := preload("res://scripts/flashlight_visibility.gd")
const HORIZON_RADIUS := FLASHLIGHT_VISIBILITY.MAX_RADIUS
const RING_SEGMENTS := 96
const WALL_SHADER := preload("res://shaders/burning_horizon.gdshader")
const SKY_SHADER := preload("res://shaders/burning_sky.gdshader")
const ZOMBIE_FOG_TEXTURES := [
	preload("res://assets/environment/zombie_fog_01.webp"),
	preload("res://assets/environment/zombie_fog_02.webp"),
	preload("res://assets/environment/zombie_fog_03.webp"),
	preload("res://assets/environment/zombie_fog_04.webp"),
]

func _ready() -> void:
	add_to_group("distant_backdrop")
	var material := ShaderMaterial.new()
	material.shader = WALL_SHADER
	for index in range(ZOMBIE_FOG_TEXTURES.size()):
		material.set_shader_parameter(
			StringName("zombie_fog_texture_%d" % index),
			ZOMBIE_FOG_TEXTURES[index]
		)

	var wall := MeshInstance3D.new()
	wall.name = "ZombieFogHorizon"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = HORIZON_RADIUS
	cylinder.bottom_radius = HORIZON_RADIUS
	cylinder.height = WALL_HEIGHT
	cylinder.radial_segments = RING_SEGMENTS
	cylinder.rings = 1
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	wall.mesh = cylinder
	wall.material_override = material
	wall.position.y = WALL_HEIGHT * 0.5
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)

func follow_player(at: Vector3) -> void:
	# Follow elevation as well: an airborne dash cannot cross the backdrop.
	# Keep the ring centered on the player without rotating it with the camera.
	global_position = at

static func make_sky() -> Sky:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return sky
