extends SceneTree

## Checks the model and material budget used by the current playable character.
## Motion timing and input behavior are covered by player_animation_test.gd.

const Player := preload("res://scripts/player_controller.gd")
const ExoMixamoData := preload("res://scripts/exo_mixamo_data.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := Player.new() as FoundationPlayer
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame
	_check(player.visual_root != null and player.visual_root.get_child_count() == 2, "source animation rig and visible Exo Gray model are instantiated")
	_check(player._animation_player != null and player._skeleton != null, "player model has an animator and skeleton")
	_check(player._character_motion_ready and player._fight_animations_ready and player._ring_animations_ready, "movement, combat, and ring clips install on the player rig")
	if player._animation_player == null or player._skeleton == null:
		_finish(player)
		return
	var model := player.visual_root.get_child(0) as Node3D
	_check(model != null and model.scene_file_path == Player.PLAYER_MODEL_PATH, "source gameplay rig remains Universal Base male")
	_check(model != null and not model.visible, "source gameplay rig is hidden without stopping animation")
	_check(player._exo_visual_model != null and player._exo_visual_model.scene_file_path == Player.EXO_MODEL_PATH, "visible player uses Exo Gray GLB")
	_check(player._exo_retarget != null and player._exo_retarget.target_skeleton != null, "Exo Gray retargeter is running")
	_check_exo_mixamo_clips(player)
	if player._exo_retarget != null and player._exo_retarget.target_skeleton != null:
		_check(player._exo_retarget.target_skeleton.get_bone_count() == 112, "Exo Gray retains its 112-bone skinned rig")
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
		if instance == null or instance.mesh == null or not instance.is_visible_in_tree():
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
	_check(mesh_count >= 3 and skinned_count == mesh_count, "all visible Exo Gray meshes are skinned (%d/%d)" % [skinned_count, mesh_count])
	_check(textured_count >= 2, "player materials keep at least two textures after Pencil conversion (%d)" % textured_count)
	_check(triangles >= 10000 and triangles <= 35000, "Exo Gray remains within the 35k mobile triangle cap (%d)" % triangles)
	print("PLAYER_QUALITY_REPORT bones=%d meshes=%d skinned=%d textured_surfaces=%d triangles=%d" % [player._skeleton.get_bone_count(), mesh_count, skinned_count, textured_count, triangles])
	_finish(player)

func _check_exo_mixamo_clips(player: FoundationPlayer) -> void:
	_check(ExoMixamoData.CLIPS.size() == 5, "five real Mixamo clips are installed")
	var overlay := player._exo_overlay as PlayerExoMixamoOverlay
	_check(overlay != null, "Exo Gray Mixamo visual overlay initializes")
	if overlay == null:
		return
	var target := player._exo_retarget.target_skeleton as Skeleton3D
	var animator := overlay._animator as AnimationPlayer
	_check(target != null and animator != null, "overlay has a real Skeleton3D and AnimationPlayer")
	if target == null or animator == null:
		return
	# Deterministic pose samples: gameplay physics and hidden source animation do not run.
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip_name in ["mma_kick", "roundhouse", "fly_kick", "jump", "roll"]:
		var path := StringName("exo_mixamo/" + clip_name)
		_check(animator.has_animation(path), "Exo Mixamo clip available: " + clip_name)
		if not animator.has_animation(path):
			continue
		var clip := animator.get_animation(path)
		var clip_data: Dictionary = ExoMixamoData.CLIPS[clip_name]
		_check(clip.get_track_count() == ExoMixamoData.BONES.size(), "clip drives 20 Exo bones: " + clip_name)
		_check(is_equal_approx(clip.length, float(clip_data["length"])), "clip duration survives import: " + clip_name)
		_check(overlay.play_clip(clip_name, 0.5), "visual clip starts: " + clip_name)
		_check(not player._exo_retarget.is_processing(), "source retargeter pauses during Exo clip: " + clip_name)
		animator.seek(clip.length * 0.18, true)
		var first: Array[Quaternion] = []
		for name in ExoMixamoData.BONES:
			first.append(target.get_bone_pose_rotation(target.find_bone(String(name))))
		animator.seek(clip.length * 0.64, true)
		var maximum := 0.0
		for index in range(ExoMixamoData.BONES.size()):
			var bone := target.find_bone(String(ExoMixamoData.BONES[index]))
			maximum = maxf(maximum, first[index].angle_to(target.get_bone_pose_rotation(bone)))
		_check(maximum > 0.10, "clip has distinct body poses (%.2f radians): %s" % [maximum, clip_name])
		overlay.stop_clip()
		_check(player._exo_retarget.is_processing(), "retargeter resumes after clip: " + clip_name)

	# Strike overlays must hit their authored peak at exactly the damage boundary,
	# while the original source clips remain available for uncropped review.
	for clip_name in ["mma_kick", "roundhouse", "fly_kick"]:
		var combat_path := StringName("exo_mixamo/" + clip_name + "_combat")
		_check(animator.has_animation(combat_path), "compressed attack exists: " + clip_name)
		if not animator.has_animation(combat_path):
			continue
		var compact := animator.get_animation(combat_path)
		var full := animator.get_animation(StringName("exo_mixamo/" + clip_name))
		_check(is_equal_approx(compact.length, PlayerExoMixamoOverlay.STRIKE_LENGTH),
			"short strike does not exceed intended cadence: " + clip_name)
		_check(compact.get_track_count() == 20, "short clip retains all 20 bones: " + clip_name)
		var pelvis_index := 0
		var actual := compact.rotation_track_interpolate(pelvis_index, PlayerExoMixamoOverlay.STRIKE_CONTACT)
		var expected := full.rotation_track_interpolate(pelvis_index,
			full.length * float(PlayerExoMixamoOverlay.PEAK_FRACTIONS[clip_name]))
		_check(actual.angle_to(expected) < 0.02, "kick extension matches damage instant: " + clip_name)
		_check(overlay.play_strike(clip_name), "short strike plays: " + clip_name)
		_check(not player._exo_retarget.is_processing(), "short strike owns rendered rig: " + clip_name)
		overlay.stop_clip()
		_check(player._exo_retarget.is_processing(), "normal animation resumes after strike: " + clip_name)
	_check(PlayerExoMixamoOverlay.ROLL_VISUAL_DURATION > Player.DASH_DURATION,
		"ground roll remains visible after physical dash without changing dash timing")
	_check(not overlay.play_ground_roll(), "roll is rejected without established floor contact")
	_check(player._exo_visual_model.position.y == 0.0, "visual floor correction starts at zero")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish(player: Node) -> void:
	player.queue_free()
	if failures.is_empty():
		print("PASS: Exo Gray player model and retained source rig (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d player quality checks failed" % [failures.size(), checks])
		quit(1)
