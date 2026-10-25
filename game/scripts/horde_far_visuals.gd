extends MultiMeshInstance3D
class_name HordeFarVisuals
## One shared draw for the fog-softened zombies between the animated combat ring
## and the 30 m visibility edge. The gameplay bodies continue to act normally.

const VIEW_DISTANCE_SQUARED := 30.0 * 30.0
const FULL_RIG_ENTRY_DISTANCE_SQUARED := 16.0 * 16.0
const FULL_RIG_EXIT_DISTANCE_SQUARED := 18.5 * 18.5
const SCHEDULER_INTERVAL := 0.20
const CROWD_TRANSFORM_INTERVAL := 0.033
# Phase 2's smallest concentrated-horde sample exercised 20 nearby zombies
# at 6.722 ms average frame processing on the CI runner. This is a conservative
# initial animation envelope, not a claim about Android capacity.
const FULL_RIG_BUDGET := FoundationEnemy.FULL_ANIMATION_BUDGET

var player: Node3D
var visibility_manager: Node
var _enemies: Dictionary = {}
var _slot_enemy_ids: Array[int] = []
var _refresh_time := 0.0
var _scheduler_time := 0.0
var _full_rig_count := 0
var _spare_rigs: Array[Node3D] = []
var _rig_creations := 0
var _rig_reuses := 0
var _rig_overflow := 0

func configure(capacity: int) -> void:
	name = "FogHordeSilhouettes"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var silhouette := _make_silhouette()
	var animated_surface := ShaderMaterial.new()
	animated_surface.shader = load("res://shaders/horde_crowd_animation.gdshader") as Shader
	silhouette.surface_set_material(0, animated_surface)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = silhouette
	batch.instance_count = capacity
	batch.visible_instance_count = 0
	_slot_enemy_ids.resize(capacity)
	_slot_enemy_ids.fill(-1)
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
	_append_box(surface, Vector3(0, 1.18, 0), Vector3(0.74, 0.88, 0.42), Vector3(-0.12, 0, 0), 0.0)
	_append_box(surface, Vector3(0, 1.77, -0.17), Vector3(0.40, 0.42, 0.40), Vector3(-0.16, 0, 0.10), 3.0)
	_append_box(surface, Vector3(-0.52, 1.18, -0.19), Vector3(0.24, 0.83, 0.25), Vector3(-0.54, 0, -0.25), 1.0)
	_append_box(surface, Vector3(0.52, 1.20, -0.25), Vector3(0.24, 0.85, 0.25), Vector3(-0.67, 0, 0.27), 1.0)
	_append_box(surface, Vector3(-0.21, 0.46, 0.03), Vector3(0.27, 0.93, 0.32), Vector3(0.10, 0, -0.10), 2.0)
	_append_box(surface, Vector3(0.21, 0.46, 0.02), Vector3(0.27, 0.93, 0.32), Vector3(-0.12, 0, 0.11), 2.0)
	surface.generate_normals()
	return surface.commit()

func _append_box(surface: SurfaceTool, center: Vector3, size: Vector3, tilt: Vector3, part: float) -> void:
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
			surface.set_uv(Vector2(part, 0.0))
			surface.add_vertex(center + pose * corners[face[index]])

func register_enemy(enemy: FoundationEnemy) -> void:
	if enemy.is_boss:
		return
	var id := enemy.get_instance_id()
	if _enemies.has(id):
		return
	if enemy._model != null and get_resident_rig_count() >= FULL_RIG_BUDGET:
		# A preconfigured actor can be registered by a caller outside the normal
		# spawn path. Demote it before adopting it into the horde budget.
		enemy._release_detailed_model()
	_enemies[id] = enemy
	enemy._rig_budget_owner = self
	enemy.tree_exiting.connect(_remove_enemy.bind(id))
	if is_instance_valid(visibility_manager):
		visibility_manager.track_enemy(enemy)

func _remove_enemy(id: int) -> void:
	var enemy := _enemies.get(id) as FoundationEnemy
	if is_instance_valid(visibility_manager):
		visibility_manager.untrack_enemy(id)
	if is_instance_valid(enemy):
		# Scenario resets and scene teardown may free an enemy outside the usual
		# defeat signal. Its rig must not remain counted against a vanished actor.
		enemy._release_detailed_model()
		enemy._rig_budget_owner = null
	_enemies.erase(id)

func _acquire_rig(enemy: FoundationEnemy) -> bool:
	if not _enemies.has(enemy.get_instance_id()) or enemy._model != null:
		return enemy._model != null
	var model: Node3D
	if not _spare_rigs.is_empty():
		model = _spare_rigs.pop_back()
		remove_child(model)
		_rig_reuses += 1
	elif get_resident_rig_count() < FULL_RIG_BUDGET:
		model = enemy._instantiate_detailed_model()
		if model != null:
			_rig_creations += 1
	else:
		_rig_overflow += 1
		return false
	if model == null:
		return false
	enemy._adopt_detailed_model(model)
	return enemy._model != null

func _release_rig(model: Node3D) -> void:
	if is_queued_for_deletion():
		model.free()
		return
	model.visible = false
	add_child(model)
	_spare_rigs.append(model)

func get_resident_rig_count() -> int:
	var total := _spare_rigs.size()
	for enemy_variant in _enemies.values():
		var enemy := enemy_variant as FoundationEnemy
		if is_instance_valid(enemy) and enemy._model != null:
			total += 1
	return total

func get_dying_rig_count() -> int:
	var total := 0
	for enemy_variant in _enemies.values():
		var enemy := enemy_variant as FoundationEnemy
		if is_instance_valid(enemy) and enemy._death_started and not enemy._death_completed and enemy._model != null:
			total += 1
	return total

func get_rig_pool_stats() -> Dictionary:
	return {"resident": get_resident_rig_count(), "dying": get_dying_rig_count(),
		"spare": _spare_rigs.size(), "created": _rig_creations,
		"reused": _rig_reuses, "overflow": _rig_overflow}

func _process(delta: float) -> void:
	_refresh_time += delta
	_scheduler_time += delta
	if _scheduler_time >= SCHEDULER_INTERVAL:
		_scheduler_time = 0.0
		_update_full_rig_selection()
		_refresh_time = CROWD_TRANSFORM_INTERVAL
	if _refresh_time < CROWD_TRANSFORM_INTERVAL:
		return
	_refresh_time = 0.0
	if not is_instance_valid(player):
		multimesh.visible_instance_count = 0
		return
	var count := 0
	for enemy in _enemies.values():
		if not is_instance_valid(enemy) or (enemy.hp <= 0 and (not enemy._death_started or enemy._death_completed)):
			continue
		var distance_squared: float = enemy.global_position.distance_squared_to(player.global_position)
		if enemy._full_animation_selected or distance_squared > VIEW_DISTANCE_SQUARED:
			continue
		if is_instance_valid(visibility_manager) and not visibility_manager.is_visible_to_flashlight(enemy):
			continue
		var facing := Basis(Vector3.UP, enemy.rotation.y)
		if enemy._death_started:
			facing = facing.scaled(Vector3(1.0, enemy._low_poly_death_scale, 1.0))
		multimesh.set_instance_transform(count, Transform3D(facing, enemy.global_position))
		# Compact the visible set, but avoid redundant instance-color uploads while
		# the same zombie remains in this slot. The shader reads stable per-zombie
		# phase/speed from that color; transforms still refresh at 30 Hz.
		var id := int(enemy.get_instance_id())
		if _slot_enemy_ids[count] != id:
			var tint := 0.80 + float(id % 5) * 0.055
			var phase := float(id % 97) * 0.065
			multimesh.set_instance_color(count, Color(tint, tint * 0.94, tint * 0.88, phase / TAU))
			_slot_enemy_ids[count] = id
		count += 1
	multimesh.visible_instance_count = count

func _update_full_rig_selection() -> void:
	if not is_instance_valid(player):
		_full_rig_count = 0
		return
	var candidates: Array[Dictionary] = []
	for enemy_variant in _enemies.values():
		if not is_instance_valid(enemy_variant):
			continue
		var enemy := enemy_variant as FoundationEnemy
		if enemy.hp <= 0 or enemy.is_boss:
			continue
		if is_instance_valid(visibility_manager) and not visibility_manager.is_visible_to_flashlight(enemy):
			continue
		var distance_squared := enemy.global_position.distance_squared_to(player.global_position)
		var active_combatant := enemy.state in ["windup", "hit", "recovery"] or enemy.combat_target == player
		var boundary := FULL_RIG_EXIT_DISTANCE_SQUARED if enemy._full_animation_selected or active_combatant else FULL_RIG_ENTRY_DISTANCE_SQUARED
		if distance_squared > boundary:
			continue
		var score := sqrt(distance_squared)
		if enemy.state == "windup": score -= 9.0
		elif enemy.state == "hit": score -= 7.0
		elif enemy.state == "recovery": score -= 3.0
		if enemy.combat_target == player: score -= 4.0
		if enemy._full_animation_selected: score -= 1.5
		candidates.append({"enemy": enemy, "score": score})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) < float(b.score))
	var selected_ids: Dictionary = {}
	# Dying detailed actors keep their rigs until the authored clip completes.
	# They consume resident slots even though they are no longer selectable.
	var limit := mini(maxi(0, FULL_RIG_BUDGET - get_dying_rig_count()), candidates.size())
	for index in range(limit):
		var enemy := candidates[index].enemy as FoundationEnemy
		selected_ids[enemy.get_instance_id()] = true
	# Return every deselected rig before promoting candidates. A spare is moved
	# directly between actors, so a priority change cannot transiently exceed 20.
	for enemy_variant in _enemies.values():
		if not is_instance_valid(enemy_variant):
			continue
		var enemy := enemy_variant as FoundationEnemy
		if enemy.hp <= 0 or enemy.is_boss:
			continue
		if not selected_ids.has(enemy.get_instance_id()) and (enemy._full_animation_selected or enemy._model != null):
			enemy._set_full_animation_selected(false)
	_full_rig_count = 0
	for enemy_variant in _enemies.values():
		if not is_instance_valid(enemy_variant):
			continue
		var enemy := enemy_variant as FoundationEnemy
		if enemy.hp > 0 and selected_ids.has(enemy.get_instance_id()):
			enemy._set_full_animation_selected(true)
			if enemy._model != null:
				_full_rig_count += 1

func get_full_rig_count() -> int:
	return _full_rig_count
