extends Node
class_name FoundationCombatFxPool
## Bounded main-thread pool for short-lived, visual-only combat effects.

const EFFECT_SCRIPT := preload("res://scripts/transient_combat_fx.gd")
const POOL_LIMITS := {
	"attack_sweep": 4,
	"attack_impact": 6,
	"spell_burst": 3,
	"zombie_hit_flash": 6,
}

var visibility_origin: Node3D
var _available: Dictionary = {}
var _active: Array[FoundationTransientCombatFx] = []
var _active_ids: Dictionary = {}
var _created: Dictionary = {}
var _reused: Dictionary = {}
var _overflow := 0
var _prewarm_queue: Array[String] = []
var _impact_sphere: SphereMesh
var _impact_shard: BoxMesh
var _spell_sphere: SphereMesh

func _ready() -> void:
	_impact_sphere = SphereMesh.new()
	_impact_sphere.radius = 0.20
	_impact_sphere.height = 0.40
	_impact_sphere.radial_segments = 8
	_impact_sphere.rings = 4
	_impact_shard = BoxMesh.new()
	_impact_shard.size = Vector3(0.055, 0.055, 0.30)
	_spell_sphere = SphereMesh.new()
	_spell_sphere.radius = 0.28
	_spell_sphere.height = 0.56
	for raw_kind in POOL_LIMITS:
		var kind := String(raw_kind)
		_available[kind] = []
		_created[kind] = 0
		_reused[kind] = 0
		for _index in range(int(POOL_LIMITS[kind])):
			_prewarm_queue.append(kind)
	set_process(true)

func _process(delta: float) -> void:
	# Prepare one bounded visual object per frame; no scene nodes are touched by
	# background threads, and first combat does not build the full pool at once.
	if not _prewarm_queue.is_empty():
		_create_available(_prewarm_queue.pop_front())
	for index in range(_active.size() - 1, -1, -1):
		var effect := _active[index]
		if not is_instance_valid(effect):
			_active.remove_at(index)
			continue
		if effect.advance(delta):
			release_effect(effect)

func play_attack_sweep(kind: String, side: String, viewport_size: Vector2) -> bool:
	var effect := acquire_effect("attack_sweep")
	if effect == null:
		return false
	effect.begin_attack_sweep(kind, side, viewport_size)
	return true

func play_attack_impact(at: Vector3, kind: String) -> bool:
	var effect := acquire_effect("attack_impact")
	if effect == null:
		return false
	var color := Color(1.0, 0.74, 0.30) if kind == "punch" else Color(1.0, 0.38, 0.12)
	effect.begin_attack_impact(at, color)
	return true

func play_spell_burst(at: Vector3, color: Color) -> bool:
	var effect := acquire_effect("spell_burst")
	if effect == null:
		return false
	effect.begin_spell_burst(at, color)
	return true

func play_zombie_hit_flash(at: Vector3, is_jump_hit: bool) -> bool:
	var actor_position := at - Vector3(0.0, 1.0, 0.0)
	if is_instance_valid(visibility_origin) and visibility_origin.global_position.distance_squared_to(actor_position) > 900.0:
		return false
	var effect := acquire_effect("zombie_hit_flash")
	if effect == null:
		return false
	# Face the blood-splatter billboard toward the player and place it just
	# outside the zombie mesh so its depth test does not hide the sprite.
	var impact_position := at
	if is_instance_valid(visibility_origin):
		var toward_viewer := visibility_origin.global_position - at
		if toward_viewer.length_squared() > 0.0001:
			impact_position += toward_viewer.normalized() * 0.35
	effect.begin_hit_flash(impact_position, is_jump_hit)
	return true

func acquire_effect(kind: String) -> FoundationTransientCombatFx:
	if not POOL_LIMITS.has(kind):
		return null
	var available: Array = _available[kind]
	if available.is_empty():
		if int(_created[kind]) >= int(POOL_LIMITS[kind]):
			_overflow += 1
			return null
		_create_available(kind)
	if available.is_empty():
		return null
	var effect := available.pop_back() as FoundationTransientCombatFx
	if effect == null or not is_instance_valid(effect):
		return null
	_reused[kind] = int(_reused[kind]) + 1
	effect._set_pool_active(true)
	var id := effect.get_instance_id()
	_active.append(effect)
	_active_ids[id] = true
	return effect

func release_effect(effect: FoundationTransientCombatFx) -> bool:
	if effect == null or not is_instance_valid(effect):
		return false
	var id := effect.get_instance_id()
	if not _active_ids.has(id):
		return false
	_active_ids.erase(id)
	var index := _active.find(effect)
	if index >= 0:
		_active.remove_at(index)
	effect.deactivate()
	if _available.has(effect.effect_kind):
		_available[effect.effect_kind].append(effect)
	return true

func _create_available(kind: String) -> FoundationTransientCombatFx:
	if not POOL_LIMITS.has(kind) or int(_created[kind]) >= int(POOL_LIMITS[kind]):
		return null
	var effect := EFFECT_SCRIPT.new() as FoundationTransientCombatFx
	effect.name = "Pooled_%s_%d" % [kind, int(_created[kind])]
	effect.configure(kind, _impact_sphere, _impact_shard, _spell_sphere)
	add_child(effect)
	_available[kind].append(effect)
	_created[kind] = int(_created[kind]) + 1
	return effect

func get_created_count(kind: String) -> int:
	return int(_created.get(kind, 0))

func get_reuse_count(kind: String) -> int:
	return int(_reused.get(kind, 0))

func get_active_count(kind: String = "") -> int:
	if kind.is_empty():
		return _active.size()
	var count := 0
	for effect in _active:
		if is_instance_valid(effect) and effect.effect_kind == kind:
			count += 1
	return count

func get_overflow_count() -> int:
	return _overflow

func get_active_effects(kind: String) -> Array[FoundationTransientCombatFx]:
	var result: Array[FoundationTransientCombatFx] = []
	for effect in _active:
		if is_instance_valid(effect) and effect.effect_kind == kind:
			result.append(effect)
	return result

func get_available_effects(kind: String) -> Array[FoundationTransientCombatFx]:
	var result: Array[FoundationTransientCombatFx] = []
	for effect_variant in _available.get(kind, []):
		var effect := effect_variant as FoundationTransientCombatFx
		if is_instance_valid(effect):
			result.append(effect)
	return result

func get_profile_stats() -> Dictionary:
	var total_reused := 0
	var total_created := 0
	for kind in POOL_LIMITS:
		total_reused += int(_reused[kind])
		total_created += int(_created[kind])
	return {
		"created": total_created,
		"reused": total_reused,
		"active": _active.size(),
		"overflow": _overflow,
	}

