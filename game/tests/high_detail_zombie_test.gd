extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player_controller.gd")
const DETAIL_MODEL_PATH := "res://assets/zombies/high_detail/Retribution_Zombie_Reconstructed.glb"

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(ResourceLoader.exists(DETAIL_MODEL_PATH), "high-detail zombie asset is included in the Godot project")
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Player.new() as FoundationPlayer
	player.position = Vector3(0.0, 0.0, 5.0)
	player.set_physics_process(false)
	fixture.add_child(player)
	var enemy := Enemy.new() as FoundationEnemy
	enemy.configure("shambler", false, true)
	enemy.position = Vector3.ZERO
	enemy._player = player
	enemy.set_physics_process(false)
	fixture.add_child(enemy)

	enemy._set_distance_detail(5.0)
	enemy._set_full_animation_selected(true)
	await process_frame
	_check(enemy._high_detail_visual_ready, "the sample model attaches to the existing animated zombie rig")
	_check(enemy._high_detail_visual_meshes.size() == 32, "all 32 textured body-part meshes are attached")
	_check(enemy._high_detail_bone_attachments.size() == 16, "body parts follow the 16 matching animation bones")
	_check(enemy._fight_animations_ready, "player-derived punch and kick animation retargeting remains active")
	_check(enemy._animation_player.has_animation("enemy_combat/left_punch"), "zombie exposes the existing player-derived punch clip")
	_check(enemy._animation_player.has_animation("enemy_combat/right_kick"), "zombie exposes the existing player-derived kick clip")
	_check(enemy._high_detail_visual_active, "the photographic model is selected inside its 12 m detail band")
	_check(enemy._base_visual_meshes.all(func(mesh: MeshInstance3D) -> bool: return not mesh.visible), "the standard body mesh is hidden while the close detail is active")
	_check(enemy._high_detail_visual_meshes.all(func(mesh: MeshInstance3D) -> bool: return mesh.visible), "all high-detail body parts are visible together")

	var pooled_model := enemy._model
	enemy.set_quality_shadow_enabled(true)
	_check(enemy._high_detail_visual_meshes.all(func(mesh: MeshInstance3D) -> bool: return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON), "optional character-shadow comparison enables the sample casters")
	enemy.set_quality_shadow_enabled(false)
	_check(enemy._high_detail_visual_meshes.all(func(mesh: MeshInstance3D) -> bool: return mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF), "the sample returns to the default shadow-free preset")

	enemy._set_distance_detail(15.0)
	_check(not enemy._high_detail_visual_active, "the model exits high detail beyond 14 m")
	_check(enemy._base_visual_meshes.all(func(mesh: MeshInstance3D) -> bool: return mesh.visible), "the lightweight rigged model returns beyond the close detail range")
	enemy._set_distance_detail(10.0)
	_check(enemy._high_detail_visual_active, "the model re-enters high detail inside 12 m")

	enemy._set_full_animation_selected(false)
	_check(enemy._model == pooled_model and not enemy._full_animation_selected, "the one visual-sample rig stays resident without displacing other horde rigs")
	enemy._set_full_animation_selected(true)
	_check(enemy._model == pooled_model and enemy._high_detail_visual_active, "reselecting the sample reuses its existing animated detail rig")
	enemy._release_detailed_model()
	await process_frame
	_check(enemy._high_detail_visual_meshes.is_empty() and enemy._high_detail_bone_attachments.is_empty(), "sample teardown removes its attached geometry cleanly")

	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: high-detail zombie visual rig (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: high-detail zombie visual rig (%d/%d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
