extends SceneTree

const Foundation := preload("res://scripts/foundation.gd")
const PENCIL_SHADER := preload("res://shaders/pencil.gdshader")
const PENCIL_DOUBLE_SIDED_SHADER := preload("res://shaders/pencil_double_sided.gdshader")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Foundation.new()
	root.add_child(game)
	await process_frame
	var player := game.player as FoundationPlayer
	_check(Foundation.ZOMBIE_HORDE_SIZE == 5, "current playable branch remains capped at five active zombies")
	_check(player != null and player._fight_animations_ready, "player rig accepts responsive punch and kick clips")
	_check(player != null and player._character_motion_ready, "player rig accepts movement, magic, reaction, and defeat clips")
	if player == null or player._animation_player == null or player._skeleton == null:
		_finish(game)
		return
	var animator := player._animation_player
	var skeleton := player._skeleton
	_check(skeleton.get_bone_count() == 21, "character retains the established 21-bone gameplay rig")
	for clip_name in ["Idle", "Walk", "Sprint", "Jump", "Sword_Slash"]:
		_check(animator.has_animation(clip_name), "original locomotion/combat animation retained: %s" % clip_name)
	for clip_name in ["thornbound_combat/left_punch", "thornbound_combat/right_punch", "thornbound_combat/left_kick", "thornbound_combat/right_kick"]:
		_check(animator.has_animation(clip_name), "distinct fight clip installed: %s" % clip_name)
	for action_name in ThornboundMotion.ACTIONS:
		_check(animator.has_animation(ThornboundMotion.clip_path(action_name)), "additional action clip installed: %s" % action_name)
	_check(skeleton.find_bone("Sword") >= 0 and skeleton.find_bone("Halo") >= 0 and skeleton.find_bone("Cape") >= 0, "sword, halo, and cloak remain attached to named rig points")

	player.rotation.y = 0.0
	player._character_action_time = 0.0
	Input.action_press("move_left")
	player._update_movement(1.0 / 60.0)
	Input.action_release("move_left")
	_check(animator.current_animation == ThornboundMotion.clip_path("Turn_Left"), "movement input triggers a turning action")
	player._character_action_time = 0.0
	_check(player.try_dash() and animator.current_animation == ThornboundMotion.clip_path("Dash"), "accepted dash triggers its responsive full-body action")
	player.dash_time = 0.0
	player.rage.unlocked_spells.append("light")
	player.current_spell = "light"
	player._character_action_time = 0.0
	_check(player.cast_spell() and animator.current_animation == ThornboundMotion.clip_path("Magic_Light"), "healing spell triggers its distinct casting action")
	player.interrupt_by_zombie()
	_check(animator.current_animation == ThornboundMotion.clip_path("Hit"), "zombie interruption triggers a hit reaction")
	player.health = 100
	player.take_boss_damage(100)
	_check(animator.current_animation == ThornboundMotion.clip_path("Defeat"), "lethal boss damage triggers the defeat action")

	var mesh_count := 0
	var skinned_count := 0
	var styled_count := 0
	var textured_count := 0
	var triangles := 0
	for node in player.visual_root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		mesh_count += 1
		if instance.skin != null:
			skinned_count += 1
		for surface in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			triangles += int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
			var source_material := instance.mesh.surface_get_material(surface) as StandardMaterial3D
			var active_material := instance.get_active_material(surface) as ShaderMaterial
			if active_material != null and [PENCIL_SHADER, PENCIL_DOUBLE_SIDED_SHADER].has(active_material.shader):
				styled_count += 1
				if source_material != null and source_material.albedo_texture != null:
					var rendered_texture := active_material.get_shader_parameter("albedo_texture") as Texture2D
					if rendered_texture == source_material.albedo_texture:
						textured_count += 1
	_check(mesh_count >= 8, "player detail is split across multiple material meshes (%d)" % mesh_count)
	_check(skinned_count >= 8, "all visible character pieces are skinned (%d)" % skinned_count)
	_check(styled_count >= 8, "detailed player surfaces use the default pencil shaders (%d)" % styled_count)
	_check(textured_count >= 8, "pencil shaders keep each embedded player albedo map bound (%d)" % textured_count)
	_check(triangles >= 50000, "player silhouette mesh remains detailed (>50k triangles; %d)" % triangles)
	print("PLAYER_QUALITY_REPORT five_zombies=%d meshes=%d skinned=%d styled_surfaces=%d textured_surfaces=%d triangles=%d actions=%d" % [Foundation.ZOMBIE_HORDE_SIZE, mesh_count, skinned_count, styled_count, textured_count, triangles, ThornboundMotion.ACTIONS.size()])
	_finish(game)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish(game: Node) -> void:
	game.queue_free()
	if failures.is_empty():
		print("PASS: playable Thornbound character quality (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d character quality checks failed" % [failures.size(), checks])
		quit(1)
