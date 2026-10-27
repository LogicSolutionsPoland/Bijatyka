extends SceneTree

const Enemy := preload("res://scripts/enemy.gd")
const Player := preload("res://scripts/player_controller.gd")
const MODEL_PATH := "res://assets/characters/universal_base/Universal_Base_Characters_Male.glb"
const EXPECTED_CLIPS := [
	"Idle_Loop",
	"Walk_Loop",
	"Sprint_Loop",
	"Jump_Loop",
	"Punch_Cross",
	"Punch_Jab",
	"Spell_Simple_Enter",
	"Spell_Simple_Idle_Loop",
	"Spell_Simple_Shoot",
	"Spell_Simple_Exit",
	"Hit_Chest",
	"Death01",
]

var failures: Array[String] = []
var checks := 0
var defeated_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_imported_clip_names()
	await _test_behavior_animation_connections()
	if failures.is_empty():
		print("PASS: zombie animation (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d zombie animation checks failed" % [failures.size(), checks])
		quit(1)

func _check_imported_clip_names() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	_check(packed != null, "Universal Base enemy GLB imports as a scene")
	if packed == null:
		return
	var model := packed.instantiate()
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_check(player != null, "imported character exposes an AnimationPlayer")
	if player == null:
		model.free()
		return
	var found: Array[String] = []
	for library_name in player.get_animation_library_list():
		var library := player.get_animation_library(library_name)
		for animation_name in library.get_animation_list():
			var full_name := String(animation_name) if library_name == &"" else "%s/%s" % [library_name, animation_name]
			found.append(full_name)
	_check(found.size() >= 43, "imported character contains all 43 Universal Animation Library clips")
	for animation_name in EXPECTED_CLIPS:
		_check(player.has_animation(animation_name), "imported animation exists: %s" % animation_name)
	model.free()

func _test_behavior_animation_connections() -> void:
	var player := Player.new() as FoundationPlayer
	var enemy := Enemy.new() as FoundationEnemy
	enemy.configure("stalker")
	root.add_child(player)
	root.add_child(enemy)
	player.position = Vector3(0.0, 0.0, 12.0)
	enemy.position = Vector3.ZERO
	enemy._player = player
	enemy._set_distance_detail(0.0)
	enemy._set_full_animation_selected(true)
	var animations := enemy._animation_player
	_check(animations != null, "near enemy creates its imported character rig")
	if animations == null:
		enemy.queue_free()
		player.queue_free()
		return

	enemy._wander_time = 0.5
	enemy._wander(0.01)
	_check(animations.current_animation == "Idle", "stationary targetless zombie plays Idle")
	enemy._wander_time = 0.0
	enemy._wander(0.01)
	_check(enemy.state == "wander" and animations.current_animation == "Walk", "wandering zombie plays Walk")

	_check(enemy.begin_spawn_assault(player), "spawn assault starts for ordinary zombie")
	_check(animations.current_animation == "Sprint", "concealed spawn assault plays Sprint")
	_check(enemy._is_high_speed_chase(), "high speed stalker chase is classified for Sprint")

	enemy.rotation.y = 0.0
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(-1.2, 0.0, 0.0)
	enemy._spawn_assault_time = 0.0
	enemy.state = "approach"
	_check(enemy._select_attack_animation(target, 1.2, ["Attack_Swipe_L", "Attack_Swipe_R", "Attack_Bite"]) == "Attack_Swipe_L", "target on zombie's left selects left swipe")
	target.position.x = 1.2
	_check(enemy._select_attack_animation(target, 1.2, ["Attack_Swipe_L", "Attack_Swipe_R", "Attack_Bite"]) == "Attack_Swipe_R", "target on zombie's right selects right swipe")
	_check(enemy._select_attack_animation(target, 0.5, ["Attack_Swipe_L", "Attack_Swipe_R", "Attack_Bite"]) == "Attack_Bite", "close target selects bite")
	_check(enemy._select_attack_animation(target, 1.2, ["Attack_Swipe_R"]) == "Attack_Swipe_R", "missing desired clip falls back to an available swipe")

	enemy._begin_attack_animation(target, 1.2, 0.4)
	_check(animations.current_animation == "enemy_combat/right_kick", "attack windup uses the player kick retargeted to the enemy rig")
	animations.advance(0.4)
	_check(absf(animations.current_animation_position - enemy._attack_contact_time) < 0.025, "attack contact pose reaches the existing windup expiry")
	enemy.combat_target = target
	enemy._resolve_enemy_attack(1.2)
	_check(absf(animations.current_animation_position - enemy._attack_contact_time) < 0.01, "existing resolution event is corrected to the authored contact pose")

	_check(not enemy._play_animation("Missing_Clip"), "missing animation fails safely")
	_check(animations.current_animation == "enemy_combat/right_kick", "missing clip leaves the current visual fallback intact")
	_check(enemy.receive_hit(5, Vector3(0.0, 0.0, 1.0)) == 5, "nonlethal hit still applies its existing damage")
	_check(animations.current_animation == "Hit_React", "nonlethal hit plays Hit_React")

	defeated_count = 0
	enemy.defeated.connect(_on_defeated)
	enemy.state = "approach"
	_check(enemy.receive_hit(1000, Vector3(0.0, 0.0, -1.0)) > 0, "lethal hit defeats zombie")
	_check(enemy.hp == 0 and enemy.collision_layer == 0 and enemy.collision_mask == 0 and not enemy.is_physics_processing(), "death immediately disables targeting collision and AI")
	_check(animations.current_animation == "Death_Backward", "forward knockback selects Death_Backward")
	_check(defeated_count == 0, "replacement signal waits until death animation ends")
	enemy._complete_death()
	enemy._complete_death()
	_check(defeated_count == 1, "death completion and replacement signal happen once")
	await process_frame
	if is_instance_valid(target): target.queue_free()
	if is_instance_valid(player): player.queue_free()
	await process_frame

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _on_defeated(_enemy: Node) -> void:
	defeated_count += 1
