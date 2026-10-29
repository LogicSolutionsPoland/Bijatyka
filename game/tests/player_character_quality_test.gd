extends SceneTree

## Checks the model and material budget used by the current playable character.
## Motion timing and input behavior are covered by player_animation_test.gd.

const Player := preload("res://scripts/player_controller.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := Player.new() as FoundationPlayer
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame
	_check(player.visual_root != null and player.visual_root.get_child_count() == 1, "Universal Base player model is instantiated")
	_check(player._animation_player != null and player._skeleton != null, "player model has an animator and skeleton")
	_check(player._character_motion_ready and player._fight_animations_ready and player._ring_animations_ready, "movement, combat, and ring clips install on the player rig")
	if player._animation_player == null or player._skeleton == null:
		_finish(player)
		return
	var model := player.visual_root.get_child(0) as Node3D
	_check(model != null and model.scene_file_path == Player.PLAYER_MODEL_PATH, "runtime player uses the Universal Base male asset")
	var animator := player._animation_player as AnimationPlayer
	_check(player._skeleton.get_bone_count() == 65, "current imported player rig has 65 bones")
	for clip_name in ["Idle_Loop", "Walk_Loop", "Sprint_Loop", "Jump_Loop", "Spell_Simple_Shoot"]:
		_check(animator.has_animation(clip_name), "source animation remains available: %s" % clip_name)
	for action_name in Player.CHARACTER_MOTION.ACTIONS:
		_check(animator.has_animation(Player.CHARACTER_MOTION.clip_path(String(action_name))), "current character action exists: %s" % action_name)
	for kind in ["punch", "kick"]:
		for side in ["left", "right"]:
			_check(animator.has_animation(Player.FIGHT_ANIMATION_BUILDER.clip_path(kind, side)), "current %s %s combat clip exists" % [side, kind])
	_check(animator.has_animation(Player.PLAYER_RING_REFERENCE.clip_path("grapple_reach")), "player-only grapple animation is present")

	var mesh_count := 0
	var skinned_count := 0
	var textured_count := 0
	var triangles := 0
	for node in player.visual_root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		mesh_count += 1
		if instance.skin != null:
			skinned_count += 1
		_check(instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "player mesh follows the no-shadow policy")
		for surface in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			triangles += int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
			var material := instance.get_active_material(surface)
			var texture: Variant = null
			if material is BaseMaterial3D:
				texture = (material as BaseMaterial3D).albedo_texture
			elif material is ShaderMaterial:
				texture = (material as ShaderMaterial).get_shader_parameter(&"albedo_texture")
			if texture is Texture2D:
				textured_count += 1
	_check(mesh_count >= 3 and skinned_count == mesh_count, "all imported player meshes use the 65-bone skin (%d/%d)" % [skinned_count, mesh_count])
	_check(textured_count >= 2, "player materials keep at least two textures after Pencil conversion (%d)" % textured_count)
	_check(triangles >= 10000 and triangles <= 25000, "mobile player geometry stays in its 10k–25k triangle budget (%d)" % triangles)
	print("PLAYER_QUALITY_REPORT bones=%d meshes=%d skinned=%d textured_surfaces=%d triangles=%d" % [player._skeleton.get_bone_count(), mesh_count, skinned_count, textured_count, triangles])
	_finish(player)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish(player: Node) -> void:
	player.queue_free()
	if failures.is_empty():
		print("PASS: current Universal Base player quality (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d player quality checks failed" % [failures.size(), checks])
		quit(1)
