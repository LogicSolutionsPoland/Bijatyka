extends MultiMeshInstance3D
class_name HordeFarVisuals
## One shared draw for the fog-softened zombies between the animated combat ring
## and the 30 m visibility edge. The gameplay bodies continue to act normally.

const DETAIL_DISTANCE_SQUARED := 18.0 * 18.0
const VIEW_DISTANCE_SQUARED := 30.0 * 30.0

var player: Node3D
var _enemies: Dictionary = {}
var _refresh_time := 0.0

func configure(capacity: int) -> void:
	name = "FogHordeSilhouettes"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var silhouette := _make_silhouette()
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(0.24, 0.26, 0.26)
	surface.vertex_color_use_as_albedo = true
	surface.roughness = 1.0
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	silhouette.surface_set_material(0, surface)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = silhouette
	batch.instance_count = capacity
	batch.visible_instance_count = 0
	multimesh = batch
	# The MultiMesh AABB must cover moving actors; the default mesh bounds only
	# cover the origin and would let the renderer incorrectly cull the whole batch.
	custom_aabb = AABB(Vector3(-110.0, -4.0, -110.0), Vector3(220.0, 12.0, 220.0))

func _make_silhouette() -> ArrayMesh:
	# One low-poly mesh per instance: a hunched torso, angular head, reaching
	# arms and separated legs. Parts share a surface, so 200 figures still draw
	# in one MultiMesh call instead of hundreds of animated rig surfaces.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(surface, Vector3(0, 1.18, 0), Vector3(0.74, 0.88, 0.42), Vector3(-0.12, 0, 0))
	_append_box(surface, Vector3(0, 1.77, -0.17), Vector3(0.40, 0.42, 0.40), Vector3(-0.16, 0, 0.10))
	_append_box(surface, Vector3(-0.52, 1.18, -0.19), Vector3(0.24, 0.83, 0.25), Vector3(-0.54, 0, -0.25))
	_append_box(surface, Vector3(0.52, 1.20, -0.25), Vector3(0.24, 0.85, 0.25), Vector3(-0.67, 0, 0.27))
	_append_box(surface, Vector3(-0.21, 0.46, 0.03), Vector3(0.27, 0.93, 0.32), Vector3(0.10, 0, -0.10))
	_append_box(surface, Vector3(0.21, 0.46, 0.02), Vector3(0.27, 0.93, 0.32), Vector3(-0.12, 0, 0.11))
	surface.generate_normals()
	return surface.commit()

func _append_box(surface: SurfaceTool, center: Vector3, size: Vector3, tilt: Vector3) -> void:
	var half := size * 0.5
	var corners: Array[Vector3] = [
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, half.y, -half.z), Vector3(-half.x, half.y, -half.z),
		Vector3(-half.x, -half.y, half.z), Vector3(half.x, -half.y, half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z),
	]
	var pose := Basis.from_euler(tilt)
	for face in [[0, 3, 2, 1], [4, 5, 6, 7], [4, 7, 3, 0],
			[1, 2, 6, 5], [4, 0, 1, 5], [3, 7, 6, 2]]:
		for index in [0, 1, 2, 0, 2, 3]:
			surface.add_vertex(center + pose * corners[face[index]])

func register_enemy(enemy: FoundationEnemy) -> void:
	if enemy.is_boss:
		return
	var id := enemy.get_instance_id()
	_enemies[id] = enemy
	enemy.tree_exiting.connect(_remove_enemy.bind(id))

func _remove_enemy(id: int) -> void:
	_enemies.erase(id)

func _process(delta: float) -> void:
	_refresh_time += delta
	if _refresh_time < 0.033:
		return
	_refresh_time = 0.0
	if not is_instance_valid(player):
		multimesh.visible_instance_count = 0
		return
	var count := 0
	for enemy in _enemies.values():
		if not is_instance_valid(enemy) or enemy.hp <= 0:
			continue
		var distance_squared: float = enemy.global_position.distance_squared_to(player.global_position)
		if distance_squared <= DETAIL_DISTANCE_SQUARED or distance_squared > VIEW_DISTANCE_SQUARED:
			continue
		var facing := Basis(Vector3.UP, enemy.rotation.y)
		multimesh.set_instance_transform(count, Transform3D(facing, enemy.global_position))
		# Small tonal variation prevents the crowd from reading as one flat texture.
		var tint := 0.80 + float(enemy.get_instance_id() % 5) * 0.055
		multimesh.set_instance_color(count, Color(tint, tint * 0.94, tint * 0.88))
		count += 1
	multimesh.visible_instance_count = count
