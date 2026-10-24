extends Node3D
## A render-only crowd for the arena perimeter. These silhouettes never move,
## collide, animate, attack, or run per-zombie AI.
class_name StaticZombieHorde

const ZOMBIE_COUNT := 56
const RANDOM_SEED := 6103
const X_MIN := -18.0
const X_MAX := 18.0
const Z_MIN := -29.0
const Z_MAX := 22.0
const KEEP_CLEAR_RADIUS := 17.0
const PLAYER_START := Vector2(0.0, 3.2)

func _ready() -> void:
	_build_horde()

func _build_horde() -> void:
	var body_transforms: Array[Transform3D] = []
	var head_transforms: Array[Transform3D] = []
	var arm_transforms: Array[Transform3D] = []
	var leg_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = RANDOM_SEED
	var attempts := 0
	while body_transforms.size() < ZOMBIE_COUNT and attempts < ZOMBIE_COUNT * 50:
		attempts += 1
		var x := rng.randf_range(X_MIN, X_MAX)
		var z := rng.randf_range(Z_MIN, Z_MAX)
		if Vector2(x, z).distance_to(PLAYER_START) < KEEP_CLEAR_RADIUS:
			continue
		var root_position := Vector3(x, 0.0, z)
		var root_basis := Basis(Vector3.UP, rng.randf_range(-PI, PI))
		body_transforms.append(Transform3D(root_basis, root_position + root_basis * Vector3(0.0, 0.83, 0.0)))
		head_transforms.append(Transform3D(root_basis, root_position + root_basis * Vector3(0.0, 1.70, 0.0)))
		arm_transforms.append(Transform3D(root_basis * Basis(Vector3.FORWARD, 0.52), root_position + root_basis * Vector3(-0.43, 1.12, 0.0)))
		arm_transforms.append(Transform3D(root_basis * Basis(Vector3.FORWARD, -0.52), root_position + root_basis * Vector3(0.43, 1.12, 0.0)))
		leg_transforms.append(Transform3D(root_basis, root_position + root_basis * Vector3(-0.17, 0.43, 0.0)))
		leg_transforms.append(Transform3D(root_basis, root_position + root_basis * Vector3(0.17, 0.43, 0.0)))

	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.32
	body_mesh.height = 1.55
	body_mesh.radial_segments = 6
	body_mesh.rings = 2
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.23
	head_mesh.height = 0.46
	head_mesh.radial_segments = 6
	head_mesh.rings = 3
	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.12
	arm_mesh.height = 0.88
	arm_mesh.radial_segments = 5
	arm_mesh.rings = 2
	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.15
	leg_mesh.height = 0.90
	leg_mesh.radial_segments = 5
	leg_mesh.rings = 2

	_add_batch("CrowdBodies", body_mesh, _material(Color(0.21, 0.31, 0.23)), body_transforms)
	_add_batch("CrowdHeads", head_mesh, _material(Color(0.29, 0.36, 0.27)), head_transforms)
	_add_batch("CrowdArms", arm_mesh, _material(Color(0.17, 0.26, 0.20)), arm_transforms)
	_add_batch("CrowdLegs", leg_mesh, _material(Color(0.12, 0.18, 0.16)), leg_transforms)

func _add_batch(batch_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.visible_instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = batch_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.94
	return result
