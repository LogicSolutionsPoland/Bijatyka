extends SceneTree

const Rage := preload("res://scripts/rage_progression.gd")
const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Foundation := preload("res://scripts/foundation.gd")
const Hud := preload("res://scripts/mobile_hud.gd")
const TouchStickResource := preload("res://scripts/touch_stick.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	_check(Foundation != null and Hud != null and TouchStickResource != null, "scene, HUD, and touch-control scripts compile")
	_test_rage_rules()
	_test_multiple_milestones_and_reset()
	await _test_touch_stick_direction()
	await _test_hud_aura_choices()
	await _test_enemy_variant_health()
	await _test_manual_attack_and_hit_window()
	await _test_punch_animation_faces_forward()
	await _test_magic_unlock_and_damage()
	await _test_jump_and_enemy_interrupt_rules()
	await _test_boss_damage_rule()
	await _test_ten_button_controls()
	if failures.is_empty():
		print("PASS: %d foundation checks" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d of %d checks failed" % [failures.size(), checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _test_rage_rules() -> void:
	var rage := Rage.new(10.0, 1.0, 100.0) as RageProgression
	_check(rage.rage == 0.0 and rage.maximum_rage == 0.0 and rage.unlocked_spells.is_empty(), "new soul starts with no RAGE or spell")
	_check(not rage.record_effective_hit(0.0), "zero damage does not build RAGE")
	_check(not rage.record_effective_hit(-5.0), "negative damage does not build RAGE")
	_check(rage.record_effective_hit(12.0), "positive effective damage builds RAGE")
	_check(rage.rage == 10.0 and rage.maximum_rage == 10.0, "effective hit updates current and maximum RAGE")
	_check(rage.pending_milestone() == 10, "crossing the first milestone queues its choice")
	_check(not rage.resolve_selection("unknown"), "invalid aura selection is rejected")
	_check(rage.resolve_selection("fire"), "player may choose any aura from the supported pool")
	_check(rage.aura_is_active(10) and rage.unlocked_spells.has("fire"), "chosen aura is active at threshold and spell is unlocked")
	rage.advance(2.0)
	_check(not rage.aura_is_active(10), "aura turns off below its selection threshold")
	_check(rage.unlocked_spells.has("fire"), "unlocked spell persists while RAGE decays")
	rage.advance(5.0)
	_check(not rage.current_soul_condemned, "equality with condemnation threshold is not condemnation")
	rage.advance(0.01)
	_check(rage.current_soul_condemned, "strictly falling below the maximum-based threshold condemns")
	var maximum_before := rage.maximum_rage
	rage.advance(2.0)
	_check(rage.maximum_rage == maximum_before, "maximum RAGE never decreases within a soul")
	rage.reset_soul()
	_check(rage.rage == 0.0 and rage.unlocked_spells.is_empty() and rage.aura_choices.is_empty(), "soul reset clears RAGE, spells, and aura choices")
	_check(rage.record_effective_hit(1.0), "new soul can record a new effective hit")
	var value_before_pause := rage.rage
	rage.advance(5.0, false)
	_check(rage.rage == value_before_pause, "paused gameplay does not decay RAGE")

func _test_multiple_milestones_and_reset() -> void:
	var rage := Rage.new(95.0, 0.0, 100.0) as RageProgression
	_check(rage.record_effective_hit(1.0), "one verified hit may cross several thresholds")
	_check(rage.pending_milestones == [10, 30, 50, 70, 90], "crossed milestones queue in ascending order")
	_check(rage.maximum_rage == 95.0, "maximum tracks the run peak")
	for aura_id in ["light", "judgment", "fire", "shadow", "light"]:
		_check(rage.resolve_selection(aura_id), "milestone selection accepts the full pool and repeated choices")
	_check(rage.pending_milestones.is_empty() and rage.claimed_milestones.size() == 5, "each milestone selection resolves once")
	_check(rage.aura_choices[10] == "light" and rage.aura_choices[90] == "light", "aura choices stay mapped to their milestone")
	rage.reset_soul()
	_check(rage.maximum_rage == 0.0 and rage.claimed_milestones.is_empty(), "new soul clears run peak and claimed milestones")

func _test_touch_stick_direction() -> void:
	var stick := TouchStickResource.new() as TouchStick
	stick.size = Vector2(156.0, 156.0)
	root.add_child(stick)
	stick._update_touch(Vector2(78.0, 20.0))
	_check(stick.get_vector().y < -0.5, "upward virtual-stick drag maps to forward movement")
	stick._update_touch(Vector2(78.0, 78.0))
	_check(stick.get_vector() == Vector2.ZERO, "centered virtual stick is neutral")
	stick.queue_free()
	await process_frame

func _test_hud_aura_choices() -> void:
	var hud := Hud.new() as FoundationHUD
	root.add_child(hud)
	await process_frame
	hud.show_aura_selection(10)
	var panel := hud._selection_panel as PanelContainer
	var column := panel.get_child(0) as VBoxContainer
	var selected: Array[String] = []
	hud.aura_chosen.connect(func(aura_id: String) -> void: selected.append(aura_id))
	var expected := ["light", "judgment", "fire", "shadow"]
	for index in range(expected.size()):
		var button := column.get_child(index + 2) as Button
		button.pressed.emit()
		_check(not selected.is_empty() and selected.back() == expected[index], "aura menu button emits its distinct selection")
	hud.update_status(50, 100, 15.0, 20.0, 5.0, 60.0, "fire")
	_check(is_equal_approx(hud._health_bar.value, 50.0), "HUD health meter reflects current HP")
	_check(is_equal_approx(hud._rage_bar.value, 15.0), "HUD RAGE meter reflects current RAGE")
	_check(is_equal_approx(hud._magic_bar.value, 60.0), "HUD magic meter reflects current energy")
	hud.queue_free()
	await process_frame

func _test_manual_attack_and_hit_window() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	root.add_child(player)
	var target := Enemy.new() as FoundationEnemy
	target.configure("shambler")
	target.position = Vector3(0.0, 0.0, -1.1)
	target.set_physics_process(false)
	root.add_child(target)
	await process_frame
	_check(player.request_attack("punch"), "punch press starts one attack")
	_check(player.request_attack("kick") and player.attack_count == 1 and player._queued_attack_kind == "kick", "next input buffers during the current attack")
	player._update_attack(0.15)
	_check(target.hp < target.starting_health, "punch hit window detects an in-range enemy")
	_check(player.rage.rage == 3.0, "only a confirmed positive hit increases RAGE")
	player._update_attack(0.13)
	_check(player.attack_kind == "kick" and player.attack_count == 2 and player.attack_phase == "windup", "buffered kick begins as soon as the punch hit window ends")
	for _frame in range(100):
		player._update_attack(0.01)
	await process_frame
	_check(player.attack_phase == "ready" and player.request_attack("kick") and player.attack_count == 3, "a fresh kick starts immediately after the previous action finishes")
	var rage_before_miss := player.rage.rage
	target.hp = target.starting_health
	player.attack_phase = "ready"
	player.attack_kind = ""
	target.position = Vector3(4.0, 0.0, 0.0)
	_check(player.request_attack("kick"), "kick input starts its distinct action")
	player._update_attack(0.24)
	_check(target.hp == target.starting_health, "missed kick does not damage or build RAGE")
	_check(player.rage.rage == rage_before_miss, "missed kick does not increase RAGE")
	player.queue_free()
	target.queue_free()
	await process_frame

func _test_punch_animation_faces_forward() -> void:
	var player := Player.new() as FoundationPlayer
	player.set_physics_process(false)
	root.add_child(player)
	await process_frame
	_check(player._fight_animations_ready, "imported player rig accepts the authored fight clips")
	if player._fight_animations_ready:
		player.rotation.y = deg_to_rad(65.0)
		for side in ["left", "right"]:
			_check(player.request_attack("punch", side), "%s punch starts its authored clip" % side)
			player._animation_player.advance(0.04)
			player._animation_player.advance(float(Player.ATTACKS["punch"].windup) - 0.04)
			var shoulder_index := player._skeleton.find_bone("%sUpperArm" % side.capitalize())
			var wrist_index := player._skeleton.find_bone("%sHand" % side.capitalize())
			var shoulder := player._skeleton.to_global(player._skeleton.get_bone_global_pose(shoulder_index).origin)
			var wrist := player._skeleton.to_global(player._skeleton.get_bone_global_pose(wrist_index).origin)
			var forward := -player.global_transform.basis.z
			_check((wrist - shoulder).dot(forward) > 0.25, "%s fist extends in front of the player at contact" % side)
			player.attack_phase = "ready"
			player.attack_kind = ""
	player.queue_free()
	await process_frame

func _test_magic_unlock_and_damage() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	root.add_child(player)
	var target := Enemy.new() as FoundationEnemy
	target.configure("shambler")
	target.position = Vector3(0.0, 0.0, -3.0)
	target.set_physics_process(false)
	root.add_child(target)
	await process_frame
	_check(player.rage.unlocked_spells.is_empty() and not player.cast_spell(), "new soul cannot cast a spell before an aura choice")
	player.rage.gain_per_effective_hit = 10.0
	_check(player.rage.record_effective_hit(1.0), "verified hit opens the first spell choice")
	_check(player.rage.resolve_selection("fire") and player.current_spell == "fire", "aura choice unlocks its associated legacy spell")
	var hp_before := target.hp
	_check(player.cast_spell(), "unlocked legacy spell can be cast at a valid target")
	_check(target.hp == hp_before - 20 and player.magic_energy == 85.0, "fire preserves direct damage and energy cost")
	var rage_before_burn := player.rage.rage
	player._update_burns(1.0)
	_check(target.hp == hp_before - 24 and player.rage.rage == rage_before_burn, "fire burn damages over time without double-counting RAGE")
	player.queue_free()
	target.queue_free()
	await process_frame

func _test_jump_and_enemy_interrupt_rules() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	root.add_child(player)
	var zombie := Enemy.new() as FoundationEnemy
	zombie.configure("shambler")
	zombie.position = Vector3(0.0, 0.0, -1.3)
	zombie.set_physics_process(false)
	root.add_child(zombie)
	await process_frame
	player._resolve_jump_impact()
	_check(zombie.hp < zombie.starting_health, "jump impact damages an enemy")
	_check(player.rage.rage == 3.0, "effective jump impact contributes RAGE")
	var hp_before := player.health
	zombie._player = player
	zombie._resolve_enemy_attack(1.2)
	_check(player.health == hp_before, "ordinary zombie attack cannot reduce player HP")
	_check(player.movement_slow_factor < 1.0, "ordinary zombie attack applies a readable slow")
	_check(zombie.state == "recovery", "enemy telegraph resolves into a recoverable attack state")
	player.queue_free()
	zombie.queue_free()
	await process_frame

func _test_enemy_variant_health() -> void:
	var variants := {"shambler": 90, "brute": 150, "stalker": 75, "boss": 360}
	var spawned: Array[FoundationEnemy] = []
	for kind in variants.keys():
		var enemy := Enemy.new() as FoundationEnemy
		enemy.configure(str(kind), str(kind) == "boss")
		enemy.set_physics_process(false)
		root.add_child(enemy)
		spawned.append(enemy)
	await process_frame
	for index in range(spawned.size()):
		var enemy := spawned[index]
		var expected := int(variants[enemy.enemy_variant])
		_check(enemy.hp == expected and enemy.starting_health == expected, "%s starts at its configured health" % enemy.enemy_variant)
	for enemy in spawned:
		enemy.queue_free()
	await process_frame

func _test_boss_damage_rule() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3.ZERO
	player.set_physics_process(false)
	root.add_child(player)
	var boss := Enemy.new() as FoundationEnemy
	boss.configure("boss", true)
	boss.position = Vector3(0.0, 0.0, -2.0)
	boss.set_physics_process(false)
	root.add_child(boss)
	await process_frame
	boss._player = player
	_check(boss.hp == 360, "boss starts with configured boss health")
	for _hit in range(17):
		boss._resolve_enemy_attack(2.0)
	_check(player.health == 0, "boss attacks can defeat the player")
	player.queue_free()
	boss.queue_free()
	await process_frame

func _send_touch(at: Vector2, finger: int, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = finger
	event.pressed = down
	event.canceled = canceled
	root.push_input(event, true)

func _tap(button: Button, finger: int = 5) -> void:
	var at := button.get_global_rect().get_center()
	_send_touch(at, finger, true)
	_send_touch(at, finger, false)

func _test_ten_button_controls() -> void:
	var original_size := root.size
	root.size = Vector2i(1280, 720)
	var arena := Foundation.new()
	root.add_child(arena)
	var player: FoundationPlayer = arena.player
	var hud: FoundationHUD = arena.hud
	var shoulder_arm := arena.camera.get_parent() as SpringArm3D
	_check(shoulder_arm != null, "close third-person camera uses a collision-aware shoulder spring arm")
	if shoulder_arm != null:
		_check(shoulder_arm.position.x > 0.0 and shoulder_arm.rotation_degrees.x < 0.0, "camera sits above and to the right of the player")
		_check(is_equal_approx(arena.camera_rig.position.y - player.global_position.y, Foundation.CAMERA_PIVOT_HEIGHT), "camera follow rig maintains the intended eye-level height")
		_check(is_equal_approx(shoulder_arm.spring_length, Foundation.CAMERA_FOLLOW_DISTANCE) and shoulder_arm.collision_mask == 1, "camera holds close distance and retracts near level geometry")
		var horizontal_half_span := shoulder_arm.spring_length * tan(deg_to_rad(arena.camera.fov * 0.5)) * (float(root.size.x) / float(root.size.y))
		var estimated_actor_x := 0.5 - shoulder_arm.position.x / (2.0 * horizontal_half_span)
		_check(estimated_actor_x > 0.28 and estimated_actor_x < 0.43, "over-shoulder composition places the character left of screen center")
		_check(arena.camera.current, "third-person camera is active")
	player.set_physics_process(false)
	arena.set_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await process_frame
	var expected_rows := [
		["punch_left", "punch_right"], ["kick_left", "kick_right"],
		["spell_0", "spell_1"], ["spell_2", "spell_3"], ["dash", "jump"]
	]
	_check(hud._action_buttons.size() == 10, "HUD has exactly the ten requested action buttons")
	for viewport_size in [Vector2(1280, 720), Vector2(1600, 720), Vector2(960, 540)]:
		hud._root.size = viewport_size
		hud._layout()
		var occupied: Array[Rect2] = [hud._stick.get_global_rect()]
		var previous_y := -1.0
		for row in expected_rows:
			var left := hud._button_for_action(row[0])
			var right := hud._button_for_action(row[1])
			_check(left != null and right != null, "both requested row actions exist")
			if left == null or right == null:
				continue
			_check(is_equal_approx(left.position.y, right.position.y) and left.position.y > previous_y, "left and right actions align in the requested top-to-bottom order")
			_check(left.position.x < viewport_size.x * 0.2 and right.position.x > viewport_size.x * 0.8, "action columns stay at opposite screen edges")
			previous_y = left.position.y
			for button: Button in [left, right]:
				var rect := button.get_global_rect()
				_check(Rect2(Vector2.ZERO, viewport_size).encloses(rect), "action stays inside the landscape viewport")
				for other in occupied:
					_check(not rect.intersects(other), "buttons and movement stick do not overlap")
				occupied.append(rect)
	hud._root.size = Vector2(1280, 720)
	hud._layout()
	var emitted: Array[String] = []
	hud.action_requested.connect(func(action: String) -> void: emitted.append(action))
	for slot in range(4):
		var locked := hud._button_for_action("spell_%d" % slot)
		_check(locked.disabled and locked.text == "MAGIC", "locked MAGIC slot remains visible")
		_tap(locked)
	_check(emitted.is_empty() and player.magic_energy == 100.0, "locked magic taps cannot cast or spend energy")

	var stick_at := hud._stick.get_global_rect().get_center() - Vector2(0, 50)
	_send_touch(stick_at, 0, true)
	_check(player.move_input().y < -0.5, "real touch event moves the joystick forward")
	var left_punch := hud._button_for_action("punch_left")
	var punch_at := left_punch.get_global_rect().get_center()
	_send_touch(punch_at, 1, true)
	_check(player.attack_count == 1 and player.attack_kind == "punch" and player.attack_side == "left", "second finger starts one left-arm punch while moving")
	_check(player.move_input().y < -0.5, "attacking does not steal the movement finger")
	_send_touch(punch_at, 1, true)
	_check(player.attack_count == 1 and emitted.size() == 1, "holding one pointer does not repeat an action")
	_tap(hud._button_for_action("punch_right"), 2)
	_check(player.attack_count == 1 and player.attack_side == "left" and player._queued_attack_kind == "punch" and player._queued_attack_side == "right", "opposite punch buffers without interrupting the active hit")
	for step in range(4):
		player._update_attack(1.0)
	_check(player.attack_phase == "recovery" and player.attack_count == 2 and player.attack_kind == "punch" and player.attack_side == "right", "buffered opposite punch starts as soon as the first hit window ends")
	_send_touch(Vector2(640, 360), 1, false, true)
	_check(not left_punch.button_pressed, "canceled touch releases its button even outside its rectangle")
	_send_touch(stick_at, 0, false)
	_check(player.move_input() == Vector2.ZERO, "releasing the movement finger stops movement")

	for action: String in ["punch_right", "kick_left", "kick_right"]:
		var count_before := player.attack_count
		_tap(hud._button_for_action(action))
		_check(player.attack_count == count_before + 1 and player.attack_kind == action.get_slice("_", 0) and player.attack_side == action.get_slice("_", 1), "touch routes %s to the correct limb" % action)
		player._update_attack_pose()
		for step in range(4):
			player._update_attack(1.0)
	var count_before_mouse := player.attack_count
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = punch_at
	mouse.pressed = true
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(mouse, true)
	_check(player.attack_count == count_before_mouse, "emulated mouse events do not duplicate touch attacks")

	player.rage.unlocked_spells.assign(["light"])
	arena._refresh_hud()
	_check(not hud._button_for_action("spell_0").disabled and hud._button_for_action("spell_1").disabled, "first unlocked spell only enables its own slot")
	player.rage.unlocked_spells.assign(["light", "fire", "judgment", "shadow"])
	player.rage.gain_per_effective_hit = 0.0
	arena._refresh_hud()
	var target := get_first_node_in_group("enemies") as FoundationEnemy
	target.global_position = player.global_position + Vector3(0, 0, -3)
	var energy_after := [80.0, 85.0, 80.0, 80.0]
	var damage := [0, 20, 35, 25]
	for slot in range(4):
		player.health = 50
		player.magic_energy = 100.0
		target.hp = 100
		var button := hud._button_for_action("spell_%d" % slot)
		_check(not button.disabled and button.text.begins_with("MAGIC\n"), "unlocked slot retains MAGIC label and names its spell")
		_tap(button)
		_check(player.current_spell == player.rage.unlocked_spells[slot] and player.magic_energy == energy_after[slot], "direct magic slot casts the matching spell with its existing cost")
		_check(target.hp == 100 - damage[slot], "direct magic slot preserves its spell effect")
	player.rage.advance(0.1)
	arena._refresh_hud()
	_check(not hud._button_for_action("spell_3").disabled, "ordinary RAGE decay keeps unlocked magic slots")
	hud._root.size = Vector2(960, 540)
	hud._layout()
	for slot in range(4):
		_check(Rect2(Vector2.ZERO, hud._root.size).encloses(hud._button_for_action("spell_%d" % slot).get_global_rect()), "unlocked spell labels stay inside the smaller viewport")
	hud._root.size = Vector2(1280, 720)
	hud._layout()

	var actions_before_pause := emitted.size()
	paused = true
	hud.show_aura_selection(10)
	_tap(hud._button_for_action("dash"))
	_check(emitted.size() == actions_before_pause and player.dash_time == 0.0, "aura menu blocks gameplay buttons")
	hud.close_aura_selection()
	paused = false
	await process_frame
	_tap(hud._button_for_action("dash"))
	_check(player.dash_time > 0.0 and player.DASH_DISTANCE == 15.0, "bottom-left button starts the existing 15 m dash")
	await physics_frame
	player.velocity = Vector3(0, -10, 0)
	player.move_and_slide()
	_check(player.is_on_floor(), "jump fixture is grounded on the courtyard")
	_tap(hud._button_for_action("jump"))
	_check(player.velocity.y > 0.0 and player.jump_impact_armed, "bottom-right button jumps and arms landing impact")
	player._reset_at_safe_base()
	arena._refresh_hud()
	for slot in range(4):
		_check(hud._button_for_action("spell_%d" % slot).disabled and not player.cast_spell_slot(slot), "soul reset clears and locks every magic slot")
	_check(not player.cast_spell_slot(-1) and not player.cast_spell_slot(4), "out-of-range magic slots cannot cast")
	arena.queue_free()
	await process_frame
	root.size = original_size
