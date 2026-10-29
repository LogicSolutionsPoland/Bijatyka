extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player_controller.gd")
const FarVisuals := preload("res://scripts/horde_far_visuals.gd")
const CROWD_SHADER := preload("res://shaders/horde_crowd_animation.gdshader")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Player.new() as FoundationPlayer
	player.set_physics_process(false)
	fixture.add_child(player)
	check(player._animation_player != null, "player retains its independent full-quality animation player")
	var batch := FarVisuals.new() as HordeFarVisuals
	batch.configure(200)
	batch.player = player
	batch.set_process(false)
	fixture.add_child(batch)
	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Vector3(0, 0.05, -50)
	enemy.set_physics_process(false)
	fixture.add_child(enemy)
	batch.register_enemy(enemy)
	check(enemy._model == null, "50 m birth does not instantiate an animated zombie rig")
	enemy._set_distance_detail(50.0)
	check(not enemy._visual_root.visible, "newborn animated model stays hidden")
	enemy.position.z = -24.0
	enemy._set_distance_detail(24.0)
	batch._process(0.07)
	check(batch.multimesh.visible_instance_count == 1, "fog band uses the shared silhouette")
	check(enemy._model == null and not enemy._visual_root.visible, "fog band needs no animated rig")
	check(batch.multimesh.mesh.surface_get_material(0) is ShaderMaterial, "crowd tier uses the shared animated shader")
	check(CROWD_SHADER.code.contains("TIME * speed") and CROWD_SHADER.code.contains("part > 1.5"), "shared shader continuously swings limbs using render time")
	check(CROWD_SHADER.code.contains("COLOR.a * TAU"), "shared shader reads stable per-instance phase data from instance color")
	enemy.position.z = -12.0
	enemy._set_distance_detail(12.0)
	batch._process(0.07)
	check(batch.multimesh.visible_instance_count == 1, "close zombie uses the cheaper visible tier until selected")
	check(enemy._model == null and not enemy._visual_root.visible, "close non-priority zombie does not allocate a rig")
	batch._update_full_rig_selection()
	batch._process(0.04)
	check(enemy._full_animation_selected and enemy._model != null and enemy._visual_root.visible, "close combat selection promotes the zombie to a full rig")
	check(batch.multimesh.visible_instance_count == 0, "selected full rig is removed from the shared silhouette")
	var first_rig_id := enemy._model.get_instance_id()
	enemy.position.z = -18.7
	enemy._set_distance_detail(18.7)
	batch._update_full_rig_selection()
	check(not enemy._full_animation_selected and enemy._model == null, "leaving the rig tier returns its resident model to the bounded pool")
	check(batch.get_resident_rig_count() == 1 and batch.get_rig_pool_stats().spare == 1, "unselected detailed rigs are counted even while spare")
	check(not enemy._visual_root.visible, "reduced visual tier hides the rig container")
	enemy.position.z = -16.1
	enemy._set_distance_detail(16.1)
	batch._update_full_rig_selection()
	check(not enemy._full_animation_selected, "unselected zombie stays reduced just outside the 16 m entry threshold")
	enemy.position.z = -15.9
	enemy._set_distance_detail(15.9)
	batch._update_full_rig_selection()
	check(enemy._full_animation_selected, "zombie promotes when it crosses inside the 16 m entry threshold")
	check(enemy._model.get_instance_id() == first_rig_id, "LOD return reuses the same imported rig")
	check(enemy._animation_player != null and enemy._animation_player.is_playing() and enemy._animation_player.current_animation == "Idle", "LOD promotion resumes the correct idle animation on the recycled rig")
	check(is_equal_approx(enemy._model.rotation.y, PI), "recycled imported rig preserves forward-facing orientation")
	enemy.position.z = -17.5
	batch._update_full_rig_selection()
	check(enemy._full_animation_selected, "full rig remains selected between entry and exit thresholds")
	enemy.position.z = -18.7
	enemy._set_distance_detail(18.7)
	batch._update_full_rig_selection()
	enemy.position.z = -30.0
	enemy.position.y = 0.0
	enemy._set_distance_detail(30.0)
	batch._process(0.04)
	check(batch.multimesh.visible_instance_count == 1, "shared motion remains visible through the 30 m view edge")
	enemy.position.z = -30.1
	enemy._set_distance_detail(30.1)
	batch._process(0.04)
	check(batch.multimesh.visible_instance_count == 0, "zombie becomes invisible just outside the existing 30 m limit")
	enemy.position.z = -24.0
	batch._process(0.07)
	check(batch.multimesh.visible_instance_count == 1, "retained low-detail zombie reappears in the shared 18–30 m tier")
	enemy.position.z = -50.0
	enemy._set_distance_detail(50.0)
	batch._process(0.07)
	check(batch.multimesh.visible_instance_count == 0 and not enemy._visual_root.visible, "30 m outer limit culls both visual tiers")

	var boss := Enemy.new() as FoundationEnemy
	boss.configure("boss", true)
	boss.position = Vector3(0.0, 0.05, -20.0)
	boss.set_physics_process(false)
	fixture.add_child(boss)
	check(boss._full_animation_selected and boss._model != null and boss._visual_root.visible, "boss keeps its independent full-quality rig")
	batch.register_enemy(boss)
	check(batch.get_full_rig_count() <= batch.FULL_RIG_BUDGET, "player and boss do not consume the ordinary zombie rig budget")

	var crowd: Array[FoundationEnemy] = []
	for index in range(200):
		var member := Enemy.new() as FoundationEnemy
		member.position = Vector3(float(index % 20) * 0.7 - 6.65, 0.05, -8.0 - (float(index) / 20.0) * 0.45)
		member.set_physics_process(false)
		fixture.add_child(member)
		batch.register_enemy(member)
		crowd.append(member)
	var active_attacker := crowd[199]
	active_attacker.state = "windup"
	active_attacker.combat_target = player
	batch._update_full_rig_selection()
	check(batch.get_full_rig_count() == batch.FULL_RIG_BUDGET, "200 active close zombies stay independent from the 20 full-rig animation cap")
	check(batch.get_resident_rig_count() == batch.FULL_RIG_BUDGET, "200 close zombies never allocate more than 20 resident detailed rigs")
	check(active_attacker._full_animation_selected, "active attacker receives full-quality priority")
	check(player.get_parent() == fixture and player.is_in_group("player"), "player remains outside zombie visual-tier scheduling")
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: horde performance (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: horde performance (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
