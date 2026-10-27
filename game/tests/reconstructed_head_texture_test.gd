extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const HeadTransfer := preload("res://scripts/reconstructed_head_texture.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check(ResourceLoader.exists(HeadTransfer.SOURCE_MODEL), "reconstructed high-detail source exists")
	for kind in ["shambler", "brute", "stalker", "boss"]:
		var enemy := Enemy.new() as FoundationEnemy
		enemy.configure(kind)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy._set_full_animation_selected(true)
		_check(enemy._model != null and enemy._skeleton != null, "%s original rig loads" % kind)
		if enemy._model == null:
			enemy.queue_free()
			continue
		_check(enemy._model.scene_file_path == (Enemy.BOSS_MODEL_PATH if kind == "boss" else Enemy.ENEMY_MODEL_PATH), "%s GLB was not replaced" % kind)
		var covered := 0
		for visual in enemy._base_visual_meshes:
			var mat := visual.material_overlay as ShaderMaterial
			if mat != null and mat.shader == HeadTransfer.HEAD_SHADER:
				covered += 1
				_check(mat.get_shader_parameter("front_texture") is Texture2D, "reconstructed front albedo loaded")
				_check(mat.get_shader_parameter("back_texture") is Texture2D, "reconstructed back albedo loaded")
				_check(int(mat.get_shader_parameter("head_bone")) >= 0, "head bind is valid")
		_check(covered == 0 if kind == "boss" else covered > 0, "%s material only affects ordinary zombie head" % kind)
		_check(enemy._fight_animations_ready, "%s existing combat animations remain installed" % kind)
		enemy.queue_free()
		await process_frame
	if failures.is_empty():
		print("PASS: reconstructed zombie head texture (%d checks)" % checks)
		quit(0)
	else:
		for item in failures:
			push_error(item)
		print("FAIL: reconstructed zombie head texture (%d/%d failures)" % [failures.size(), checks])
		quit(1)


func _check(ok: bool, title: String) -> void:
	checks += 1
	if not ok:
		failures.append(title)
