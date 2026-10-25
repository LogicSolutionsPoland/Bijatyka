extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player_controller.gd")
const FarVisuals := preload("res://scripts/horde_far_visuals.gd")
const SpawnDirector := preload("res://scripts/concealed_spawn.gd")

var failures: Array[String] = []
var checks := 0
var defeats := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Player.new() as FoundationPlayer
	fixture.add_child(player)
	player.set_physics_process(false)
	var batch := FarVisuals.new() as HordeFarVisuals
	batch.configure(200)
	batch.player = player
	fixture.add_child(batch)
	batch.set_process(false)
	var director := SpawnDirector.new()
	fixture.add_child(director)
	director.set_physics_process(false)
	var crowd: Array[FoundationEnemy] = []
	for index in range(200):
		var enemy := _add_enemy(fixture, batch, director, index)
		crowd.append(enemy)
	batch._update_full_rig_selection()
	_check(batch.get_full_rig_count() == 20, "200 close zombies select exactly 20 detailed rigs")
	_check(batch.get_resident_rig_count() == 20 and int(batch.get_rig_pool_stats().created) == 20, "resident and created model counts are strictly capped")

	var dying: FoundationEnemy
	var reduced: FoundationEnemy
	for enemy in crowd:
		if enemy._full_animation_selected and dying == null:
			dying = enemy
		elif not enemy._full_animation_selected and reduced == null:
			reduced = enemy
	_check(dying != null and reduced != null, "fixture provides both animation tiers")
	if dying != null and reduced != null:
		dying.receive_hit(1000, Vector3.FORWARD)
		_check(dying._animation_player != null and dying._animation_player.current_animation.begins_with("Death_"), "selected zombie finishes on its authored death rig")
		_check(dying._model != null and batch.get_dying_rig_count() == 1, "dying rig remains resident until animation completion")
		batch._update_full_rig_selection()
		_check(batch.get_full_rig_count() == 19 and batch.get_resident_rig_count() == 20, "death reserves a slot before replacement selection")
		var before_reduced := batch.get_rig_pool_stats()
		reduced.receive_hit(1000, Vector3.FORWARD)
		batch._process(0.04)
		_check(reduced._model == null and reduced._death_started and not reduced._death_completed, "reduced zombie remains a dying shared silhouette")
		_check(batch.get_rig_pool_stats().created == before_reduced.created and batch.get_resident_rig_count() == 20, "unselected death never creates a detailed rig")
		reduced._complete_death()
		reduced._complete_death()
		dying._complete_death()
		dying._complete_death()
		_check(defeats == 2 and director._pending.size() == 2, "both deaths emit one defeat and queue one replacement each")
		await process_frame
		_check(not is_instance_valid(reduced) and not is_instance_valid(dying), "both completed deaths release their nodes")
		for index in range(2):
			director._pending.pop_back()
			_add_enemy(fixture, batch, director, 200 + index)
		batch._update_full_rig_selection()
		_check(director._live.size() == 200 and batch.get_resident_rig_count() == 20, "population and rig budget restore after mixed death tiers")

	# Repeated combat/respawn cycles must reuse the same 20 imported models.
	for cycle in range(25):
		var victim: FoundationEnemy
		for member in crowd:
			if is_instance_valid(member) and member.hp > 0:
				victim = member
				break
		_check(victim != null, "cycle %d finds a living victim" % cycle)
		if victim == null:
			break
		victim.receive_hit(1000, Vector3.BACK)
		victim._complete_death()
		victim._complete_death()
		_check(batch.get_resident_rig_count() <= 20, "death cycle %d respects resident cap" % cycle)
		await process_frame
		director._pending.pop_back()
		_add_enemy(fixture, batch, director, 202 + cycle)
		batch._update_full_rig_selection()
		_check(director._live.size() == 200 and batch.get_resident_rig_count() <= 20, "respawn cycle %d restores 200 without rig growth" % cycle)
	_check(int(batch.get_rig_pool_stats().created) == 20, "repeated respawns create no additional detailed models")
	_check(int(batch.get_rig_pool_stats().reused) > 0, "demotions and deaths actually reuse detailed rigs")
	_check(int(batch.get_rig_pool_stats().overflow) == 0, "scheduler reserves dying rigs without overflow")
	_check(defeats == 27, "repeated deaths emit one defeat per victim")
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: resident rig and death lifecycle (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: resident rig and death lifecycle (%d/%d failed)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func _add_enemy(fixture: Node3D, batch: HordeFarVisuals, director: Node, index: int) -> FoundationEnemy:
	var enemy := Enemy.new() as FoundationEnemy
	enemy.position = Vector3(float(index % 20) * 0.7 - 6.65, 0.05, -8.0 - (float(index % 200) / 20.0) * 0.45)
	fixture.add_child(enemy)
	enemy.set_physics_process(false)
	batch.register_enemy(enemy)
	director.register_enemy(enemy)
	enemy.defeated.connect(director.replace_enemy)
	enemy.defeated.connect(_on_defeated)
	return enemy

func _on_defeated(_enemy: Node) -> void:
	defeats += 1

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
