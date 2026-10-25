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
	var silhouette := CapsuleMesh.new()
	silhouette.radius = 0.42
	silhouette.height = 1.85
	silhouette.radial_segments = 6
	silhouette.rings = 2
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color(0.27, 0.29, 0.29)
	surface.vertex_color_use_as_albedo = true
	surface.roughness = 1.0
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	silhouette.material = surface
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
	if _refresh_time < 0.06:
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
		multimesh.set_instance_transform(count, Transform3D(facing, enemy.global_position + Vector3.UP * 0.96))
		# Small tonal variation prevents the crowd from reading as one flat texture.
		var tint := 0.80 + float(enemy.get_instance_id() % 5) * 0.055
		multimesh.set_instance_color(count, Color(tint, tint * 0.94, tint * 0.88))
		count += 1
	multimesh.visible_instance_count = count
