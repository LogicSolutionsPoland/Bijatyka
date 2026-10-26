extends Node
class_name FoundationTransientCombatFx

const BLOOD_IMPACT_ATLAS := preload("res://assets/vfx/brackeys_blood_impact_6x5.png")
const BLOOD_FIRST_FRAME := 1
const BLOOD_LAST_FRAME := 23
## Reusable visual-only combat effect. It never owns a target or a collision body.

var effect_kind := ""
var _visual: Node
var _material: StandardMaterial3D
var _hit_sprite: Sprite3D
var _impact_meshes: Array[MeshInstance3D] = []
var _sweep: Node2D
var _sweep_glow: Line2D
var _sweep_core: Line2D
var _sweep_punch_points := PackedVector2Array()
var _sweep_kick_points := PackedVector2Array()
var _base_color := Color.WHITE
var _age := 0.0
var _duration := 0.0
var _rotation_start := 0.0
var _rotation_delta := 0.0
var _active := false

func configure(kind: String, impact_sphere: SphereMesh, impact_shard: BoxMesh, spell_sphere: SphereMesh) -> void:
	effect_kind = kind
	match kind:
		"attack_sweep":
			_build_sweep()
		"attack_impact":
			_build_impact(impact_sphere, impact_shard, false)
		"zombie_hit_flash":
			_build_impact(impact_sphere, impact_shard, true)
		"spell_burst":
			_build_spell(spell_sphere)
	_set_visual_visible(false)

func _build_impact(impact_sphere: SphereMesh, impact_shard: BoxMesh, hit_flash: bool) -> void:
	var root := Node3D.new()
	root.name = "PooledHitFlash" if hit_flash else "PooledCombatImpact"
	add_child(root)
	_visual = root
	_material = _new_effect_material()
	if hit_flash:
		# One billboard instead of per-hit meshes/particles: the sprite is built
		# once per pooled effect and only its atlas frame changes on contact.
		_hit_sprite = Sprite3D.new()
		_hit_sprite.name = "BrackeysBloodImpact"
		_hit_sprite.texture = BLOOD_IMPACT_ATLAS
		_hit_sprite.hframes = 6
		_hit_sprite.vframes = 5
		_hit_sprite.frame = BLOOD_FIRST_FRAME
		_hit_sprite.pixel_size = 0.027
		_hit_sprite.position = Vector3(0.0, 1.0, 0.0)
		_hit_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_hit_sprite.shaded = false
		_hit_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(_hit_sprite)
		_material = null
		return
	for index in range(9):
		var piece := MeshInstance3D.new()
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.mesh = impact_sphere if index == 0 else impact_shard
		piece.material_override = _material
		if index > 0:
			var spark_index := index - 1
			var angle := TAU * float(spark_index) / 8.0
			piece.position = Vector3(cos(angle) * 0.18, sin(angle) * 0.18, 0.0)
			piece.rotation.y = angle
		root.add_child(piece)
		_impact_meshes.append(piece)

func _build_spell(spell_sphere: SphereMesh) -> void:
	var root := MeshInstance3D.new()
	root.name = "PooledSpellBurst"
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.mesh = spell_sphere
	_material = _new_effect_material()
	root.material_override = _material
	add_child(root)
	_visual = root

func _build_sweep() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PooledAttackSweepLayer"
	layer.layer = 12
	add_child(layer)
	_sweep = Node2D.new()
	_sweep.name = "AttackSweep"
	_sweep.z_index = 100
	layer.add_child(_sweep)
	_visual = _sweep
	_sweep_glow = _new_sweep_line()
	_sweep_glow.name = "Glow"
	_sweep.add_child(_sweep_glow)
	_sweep_core = _new_sweep_line()
	_sweep_core.name = "Core"
	_sweep.add_child(_sweep_core)
	_sweep_punch_points = _make_sweep_points(122.0)
	_sweep_kick_points = _make_sweep_points(168.0)

func _make_sweep_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(25)
	for point_index in range(25):
		var progress := float(point_index) / 24.0
		var angle := lerpf(-1.22, 1.22, progress)
		points[point_index] = Vector2(sin(angle) * radius, -cos(angle) * radius * 0.76)
	return points

func _new_sweep_line() -> Line2D:
	var line := Line2D.new()
	line.antialiased = true
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line

func _new_effect_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func begin_attack_impact(at: Vector3, color: Color) -> void:
	_begin(at, 0.18)
	_base_color = color
	var root := _visual as Node3D
	root.global_position = at
	root.scale = Vector3.ONE * 0.72
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = 2.2
	add_to_group("attack_impact_fx")

func begin_hit_flash(at: Vector3, is_jump_hit: bool) -> void:
	_begin(at, 0.28)
	var root := _visual as Node3D
	root.global_position = at - Vector3(0.0, 1.0, 0.0)
	root.scale = Vector3.ONE * (1.14 if is_jump_hit else 1.0)
	_hit_sprite.frame = BLOOD_FIRST_FRAME
	_hit_sprite.modulate = Color.WHITE

func begin_spell_burst(at: Vector3, color: Color) -> void:
	_begin(at, 0.22)
	_base_color = color
	var root := _visual as Node3D
	root.global_position = at
	root.scale = Vector3.ONE
	_material.albedo_color = color
	_material.emission = color
	_material.emission_energy_multiplier = 1.0

func begin_attack_sweep(kind: String, side: String, viewport_size: Vector2) -> void:
	_begin(Vector3.ZERO, 0.22)
	_sweep.position = viewport_size * Vector2(0.50, 0.49)
	var points := _sweep_kick_points if kind == "kick" else _sweep_punch_points
	_sweep_glow.points = points
	_sweep_glow.width = 22.0 if kind == "kick" else 17.0
	var is_kick := kind == "kick"
	var hot_color := Color(0.22, 0.76, 1.0, 0.96) if is_kick else Color(1.0, 0.26, 0.045, 0.96)
	_sweep_glow.default_color = hot_color
	_sweep_core.points = points
	_sweep_core.width = 5.0
	_sweep_core.default_color = Color(0.83, 0.96, 1.0, 1.0) if is_kick else Color(1.0, 0.94, 0.72, 1.0)
	var side_sign := 1.0 if side == "right" else -1.0
	_rotation_start = -0.28 * side_sign
	_rotation_delta = 0.78 * side_sign
	_sweep.rotation = _rotation_start
	_sweep.scale = Vector2.ONE * 0.62
	_sweep.modulate = Color.WHITE

func _begin(_at: Vector3, duration: float) -> void:
	_active = true
	_age = 0.0
	_duration = duration
	_set_visual_visible(true)

func _set_pool_active(is_active: bool) -> void:
	_active = is_active
	_age = 0.0
	_duration = 0.0
	_set_visual_visible(is_active)

func advance(delta: float) -> bool:
	if not _active:
		return false
	_age = minf(_duration, _age + maxf(0.0, delta))
	var progress := clampf(_age / maxf(0.001, _duration), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	match effect_kind:
		"attack_sweep":
			_sweep.scale = Vector2.ONE * lerpf(0.62, 1.18, eased)
			_sweep.rotation = _rotation_start + _rotation_delta * progress
			_sweep.modulate.a = 1.0 - progress
		"attack_impact":
			(_visual as Node3D).scale = Vector3.ONE * lerpf(0.72, 2.0, eased)
			_material.albedo_color = Color(_base_color.r, _base_color.g, _base_color.b, 1.0 - progress)
		"zombie_hit_flash":
			# Brackeys sheet: frames 1-23 contain the animation, while the
			# trailing empty frames are intentionally excluded.
			var frame_count := BLOOD_LAST_FRAME - BLOOD_FIRST_FRAME + 1
			_hit_sprite.frame = mini(BLOOD_LAST_FRAME, BLOOD_FIRST_FRAME + int(progress * float(frame_count)))
			_hit_sprite.modulate.a = 1.0 - smoothstep(0.68, 1.0, progress)
		"spell_burst":
			(_visual as Node3D).scale = Vector3.ONE * lerpf(1.0, 2.8, progress)
			_material.albedo_color = Color(_base_color.r, _base_color.g, _base_color.b, 1.0 - progress)
	return progress >= 1.0

func deactivate() -> void:
	if is_in_group("attack_impact_fx"):
		remove_from_group("attack_impact_fx")
	_active = false
	_age = 0.0
	_duration = 0.0
	_rotation_start = 0.0
	_rotation_delta = 0.0
	if _visual is Node3D:
		(_visual as Node3D).position = Vector3.ZERO
		(_visual as Node3D).rotation = Vector3.ZERO
		(_visual as Node3D).scale = Vector3.ONE
	elif _visual is Node2D:
		(_visual as Node2D).position = Vector2.ZERO
		(_visual as Node2D).rotation = 0.0
		(_visual as Node2D).scale = Vector2.ONE
		(_visual as Node2D).modulate = Color.WHITE
	if _material != null:
		_material.albedo_color = _base_color
		_material.emission = _base_color
	if _hit_sprite != null:
		_hit_sprite.frame = BLOOD_FIRST_FRAME
		_hit_sprite.modulate = Color.WHITE
	_set_visual_visible(false)

func _set_visual_visible(is_visible: bool) -> void:
	if _visual is CanvasItem:
		(_visual as CanvasItem).visible = is_visible
	elif _visual is Node3D:
		(_visual as Node3D).visible = is_visible

func is_effect_visible() -> bool:
	if _visual is CanvasItem:
		return (_visual as CanvasItem).visible
	if _visual is Node3D:
		return (_visual as Node3D).visible
	return false

func get_visual_position() -> Vector3:
	return (_visual as Node3D).global_position if _visual is Node3D else Vector3.ZERO

func get_visual_alpha() -> float:
	if _hit_sprite != null:
		return _hit_sprite.modulate.a
	return _material.albedo_color.a if _material != null else 1.0

func get_visual_scale() -> Vector3:
	if _visual is Node3D:
		return (_visual as Node3D).scale
	if _visual is Node2D:
		var scale_2d := (_visual as Node2D).scale
		return Vector3(scale_2d.x, scale_2d.y, 1.0)
	return Vector3.ONE

func has_collision_nodes() -> bool:
	return not find_children("*", "CollisionObject3D", true, false).is_empty()

