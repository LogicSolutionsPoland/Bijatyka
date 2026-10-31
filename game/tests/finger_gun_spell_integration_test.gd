extends SceneTree

## Executes the real accepted spell path with the imported 112-bone Exo Gray.
## Finger-gun projectiles are visual only; all damage and mana stay immediate.
const PLAYER := preload("res://scripts/player_controller.gd")
const ENEMY := preload("res://scripts/enemy.gd")
const FINGER := preload("res://scripts/exo_finger_gun.gd")

var failures: Array[String] = []
var checks := 0
var visuals: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player := PLAYER.new() as FoundationPlayer
	root.add_child(player)
	player.set_physics_process(false)
	var enemy := ENEMY.new() as FoundationEnemy
	enemy.configure("shambler")
	enemy.position = Vector3(0.0, 0.0, -3.0)
	enemy.set_physics_process(false)
	root.add_child(enemy)
	await process_frame
	_check(player._exo_overlay != null and player._exo_visual_model != null,
		"real Exo Gray is installed and owns a visual overlay")
	if player._exo_overlay == null:
		_finish(player, enemy)
		return
	var animator := player._exo_overlay._animator as AnimationPlayer
	var skeleton := player._exo_retarget.target_skeleton as Skeleton3D
	var tip := skeleton.get_node_or_null("FingerGunIndexTip/FingerGunMuzzle") as Marker3D
	_check(animator.has_animation(FINGER.CLIP) and tip != null, "existing validated Exo finger animation and fingertip are registered")
	if not animator.has_animation(FINGER.CLIP) or tip == null:
		_finish(player, enemy)
		return
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animator.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	player._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.finger_gun_visual_shot.connect(_on_visual)
	player.rage.unlocked_spells.assign(["fire", "light", "judgment", "shadow"])
	player.current_spell = "fire"
	player.magic_energy = 100.0
	player.attack_phase = "ready"
	player.rotation.y = 0.0
	enemy.hp = 100
	_check(player.cast_spell(), "Fire accepted through the real cast_spell path")
	_check(enemy.hp == 80 and is_equal_approx(player.magic_energy, 85.0),
		"original immediate Fire damage and mana remain unchanged")
	_check(animator.current_animation == FINGER.CLIP and animator.is_playing(),
		"accepted offensive magic starts dedicated 1x finger-gun animation")
	_check(player._finger_gun_visuals.size() == 1 and visuals.is_empty(),
		"visual projectile is queued until the 0.300-second firing frame")
	animator.advance(0.12)
	await process_frame
	_check(visuals.is_empty(), "no projectile before fire marker")
	animator.advance(0.20)
	await process_frame
	await process_frame
	_check(visuals.size() == 1, "exactly one fingertip projectile appears at fire")
	if visuals.size() == 1:
		var shot: Dictionary = visuals[0]
		_check(String(shot["school"]) == "fire", "projectile has the selected school's color and type")
		_check((shot["from"] as Vector3).distance_to(tip.global_position) < 0.01,
			"projectile starts at animated RightHandIndex3")
		_check((shot["to"] as Vector3).distance_to(enemy.global_position + Vector3.UP) < 0.05,
			"projectile travels toward the selected enemy")
	_check(not get_nodes_in_group("finger_gun_projectiles").is_empty(),
		"lightweight visual-only MeshInstance3D projectile exists")
	# Light is healing, not a projectile. Its old animation remains selected.
	player._exo_overlay.stop_clip()
	player._finger_gun_visuals.clear()
	player.health = 50
	player.magic_energy = 100.0
	player.current_spell = "light"
	var old_count := visuals.size()
	_check(player.cast_spell(), "Light healing still casts")
	_check(player.health == 80 and is_equal_approx(player.magic_energy, 80.0),
		"Light heal and cost unchanged")
	_check(player._finger_gun_visuals.is_empty() and visuals.size() == old_count,
		"healing spell creates no offensive fingertip projectile")
	# Reject insufficient mana without playing the finger-gun animation.
	player._exo_overlay.stop_clip()
	player.current_spell = "fire"
	player.magic_energy = 0.0
	_check(not player.cast_spell(), "insufficient mana rejects cast")
	_check(player._finger_gun_visuals.is_empty() and not animator.is_playing(),
		"rejected cast does not play firing visual")
	# Two accepted casts inside the same prep window must produce two separate
	# projectiles on one fire event, without canceling the first attack.
	player.magic_energy = 100.0
	enemy.hp = 100
	player.attack_phase = "ready"
	visuals.clear()
	_check(player.cast_blast() and player.cast_blast(), "two rapid Fire blasts accepted")
	_check(enemy.hp == 60 and is_equal_approx(player.magic_energy, 70.0),
		"rapid magic retains exactly two old hits and two mana costs")
	_check(player._finger_gun_visuals.size() == 2 and visuals.is_empty(),
		"both accepted spells are buffered until the same fire event")
	animator.advance(0.32)
	await process_frame
	await process_frame
	_check(visuals.size() == 2 and player._finger_gun_visuals.is_empty(),
		"two visual-only projectiles emitted exactly once")
	# Melee interrupts unfinished spell pose and restores the original punch.
	player._exo_overlay.stop_clip()
	player._finger_gun_visuals.clear()
	player.magic_energy = 100.0
	enemy.hp = 100
	enemy.global_position = Vector3(0.0, 0.0, -3.0)
	_check(player.cast_blast(), "new spell animation can start")
	_check(player.request_attack("punch", "right"), "original punch remains usable immediately")
	_check(player._finger_gun_visuals.is_empty(), "punch cancels pending projectile visual")
	_check(not (animator.is_playing() and animator.current_animation == FINGER.CLIP),
		"punch visibly interrupts finger gun rather than corrupting melee")
	_check(player._animation_player.has_animation(player.FIGHT_ANIMATION_BUILDER.clip_path("punch", "right")),
		"old Punch_Cross-based combat clip is preserved")
	_finish(player, enemy)

func _on_visual(from: Vector3, to: Vector3, school: String) -> void:
	visuals.append({"from": from, "to": to, "school": school})

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _finish(player: Node, enemy: Node) -> void:
	player.queue_free()
	enemy.queue_free()
	if failures.is_empty():
		print("PASS: Finger Gun gameplay spell integration (%d checks)" % checks)
		quit(0)
	else:
		for reason in failures:
			push_error("FINGER_GUN_INTEGRATION_FAILED: " + reason)
		print("FAIL: Finger Gun gameplay spell integration %d/%d" % [failures.size(), checks])
		quit(1)
