extends SceneTree

const Rage := preload("res://scripts/rage_progression.gd")
const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Foundation := preload("res://scripts/foundation.gd")
const Hud := preload("res://scripts/mobile_hud.gd")

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run_all")

func _run_all() -> void:
	_check(Foundation != null and Hud != null, "scene and swipe-control scripts compile")
	_test_gamepad_input_map()
	_test_rage_rules()
	_test_multiple_milestones_and_reset()
	await _test_hud_aura_choices()
	await _test_enemy_variant_health()
	await _test_manual_attack_and_hit_window()
	await _test_punch_animation_faces_forward()
	await _test_magic_unlock_and_damage()
	await _test_jump_and_enemy_interrupt_rules()
	await _test_boss_damage_rule()
	await _test_ten_button_controls()
	await _test_gamepad_controls()
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

func _test_gamepad_input_map() -> void:
	var expected_axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
		"move_back": [JOY_AXIS_LEFT_Y, 1.0],
		"camera_left": [JOY_AXIS_RIGHT_X, -1.0],
		"camera_right": [JOY_AXIS_RIGHT_X, 1.0],
		"camera_up": [JOY_AXIS_RIGHT_Y, -1.0],
		"camera_down": [JOY_AXIS_RIGHT_Y, 1.0]
	}
	for raw_action in expected_axes.keys():
		var action := StringName(raw_action)
		var expected: Array = expected_axes[raw_action]
		var found := false
		for input_event: InputEvent in InputMap.action_get_events(action):
			if input_event is InputEventJoypadMotion:
				var motion := input_event as InputEventJoypadMotion
				if motion.axis == int(expected[0]) and is_equal_approx(motion.axis_value, float(expected[1])):
					found = true
					break
		_check(found, "%s maps to the expected gamepad stick axis" % String(action))
	var expected_buttons := {
		&"pad_jump": [JOY_BUTTON_A], &"pad_dash": [JOY_BUTTON_X], &"pad_cast_spell": [JOY_BUTTON_B],
		&"pad_punch_left": [JOY_BUTTON_RIGHT_SHOULDER], &"pad_blast": [JOY_BUTTON_Y],
		&"pad_kick_left": [JOY_BUTTON_LEFT_SHOULDER],
		&"pad_spell_0": [JOY_BUTTON_DPAD_UP], &"pad_spell_1": [JOY_BUTTON_DPAD_RIGHT],
		&"pad_spell_2": [JOY_BUTTON_DPAD_DOWN], &"pad_spell_3": [JOY_BUTTON_DPAD_LEFT]
	}
	var routed_actions: Array[String] = []
	for row in Hud.ACTION_ROWS:
		for action: String in row:
			routed_actions.append(action)
	_check(expected_buttons.size() == routed_actions.size() and Hud.GAMEPAD_ACTIONS.size() == routed_actions.size() + 1, "gamepad includes all digital controls plus direct magic and Blast actions")
	var trigger_events := InputMap.action_get_events(&"pad_kick_right")
	_check(trigger_events.size() == 1 and trigger_events[0] is InputEventJoypadMotion and (trigger_events[0] as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT and is_equal_approx((trigger_events[0] as InputEventJoypadMotion).axis_value, 1.0), "R2 / RT maps to the right trigger axis")
	_check(Hud.GAMEPAD_ACTIONS.get(&"pad_kick_right", "") == "kick_right", "R2 routes to the right touch kick")
	for action: StringName in expected_buttons:
		var events := InputMap.action_get_events(action)
		var actual: Array[int] = []
		for input_event: InputEvent in events:
			if input_event is InputEventJoypadButton:
				actual.append((input_event as InputEventJoypadButton).button_index)
		actual.sort()
		var expected: Array = expected_buttons[action].duplicate()
		expected.sort()
		_check(actual == expected and events.size() == expected.size(), "%s uses its assigned SDL logical gamepad buttons" % action)
		if action == &"pad_cast_spell":
			_check(Hud.GAMEPAD_ACTIONS[action] == "cast_spell", "B casts the selected unlocked spell")
		elif action == &"pad_blast":
			_check(Hud.GAMEPAD_ACTIONS[action] == "blast", "Y triggers Blast")
		else:
			_check(routed_actions.has(Hud.GAMEPAD_ACTIONS.get(action, "")), "%s routes to an existing touch HUD action" % action)
	var assigned_buttons := {}
	for buttons: Array in expected_buttons.values():
		for button: int in buttons:
			assigned_buttons[button] = true
	_check(assigned_buttons.size() == 10 and not assigned_buttons.has(JOY_BUTTON_START) and not assigned_buttons.has(JOY_BUTTON_GUIDE), "ten physical gameplay buttons leave system buttons unassigned")

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
	_check(player.rage.unlocked_spells.is_empty() and not player.cast_spell() and not player.cast_blast(), "new soul cannot cast magic or Blast before an aura choice")
	player.rage.gain_per_effective_hit = 10.0
	_check(player.rage.record_effective_hit(1.0), "verified hit opens the first spell choice")
	_check(player.rage.resolve_selection("fire") and player.current_spell == "fire", "aura choice unlocks its associated legacy spell")
	var hp_before := target.hp
	_check(player.cast_spell(), "unlocked legacy spell can be cast at a valid target")
	_check(target.hp == hp_before - 20 and player.magic_energy == 85.0, "fire preserves direct damage and energy cost")
	var rage_before_burn := player.rage.rage
	player._update_burns(1.0)
	_check(target.hp == hp_before - 24 and player.rage.rage == rage_before_burn, "fire burn damages over time without double-counting RAGE")
	player.rage.unlocked_spells.append("light")
	player.current_spell = "light"
	var blast_hp_before := target.hp
	var blast_magic_before := player.magic_energy
	_check(player.cast_blast(), "unlocked Fire school can cast Blast directly")
	_check(target.hp == blast_hp_before - 20 and player.magic_energy == blast_magic_before - 15 and player.current_spell == "light", "Blast uses Fire damage and cost without changing the selected spell")
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

func _send_drag(to: Vector2, finger: int, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.position = to
	event.relative = relative
	event.index = finger
	root.push_input(event, true)

func _tap(button: Button, finger: int = 5) -> void:
	var at := button.get_global_rect().get_center()
	_send_touch(at, finger, true)
	_send_touch(at, finger, false)

func _send_pad(button: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	root.push_input(event, true)

func _send_trigger(amount: float, device: int = 0) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = JOY_AXIS_TRIGGER_RIGHT
	event.axis_value = amount
	root.push_input(event, true)

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
		_check(
			shoulder_arm.position.x > 0.0
			and is_equal_approx(shoulder_arm.rotation_degrees.x, Foundation.CAMERA_PITCH_DEGREES)
			and shoulder_arm.rotation_degrees.x > 0.0,
			"camera sits above and to the right with a slight downward combat angle"
		)
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
	_check(hud.find_child("MovementStick", true, false) == null, "HUD removes the lower-left analog stick")
	for viewport_size in [Vector2(1280, 720), Vector2(1600, 720), Vector2(960, 540)]:
		hud._root.size = viewport_size
		hud._layout()
		var occupied: Array[Rect2] = []
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
					_check(not rect.intersects(other), "action buttons do not overlap each other")
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

	var movement_at := Vector2(420, 500)
	_send_touch(movement_at, 0, true)
	_send_drag(movement_at + Vector2(0, -96), 0, Vector2(0, -96))
	_check(player.move_input().y < -0.5, "left-side drag moves the player forward without a visible joystick")
	var yaw_before_swipe := arena._camera_yaw
	var camera_at := Vector2(900, 500)
	_send_touch(camera_at, 3, true)
	_send_drag(camera_at + Vector2(100, -50), 3, Vector2(100, -50))
	_check(arena._camera_yaw < yaw_before_swipe, "right-side swipe rotates the over-shoulder camera")
	_check(arena._camera_pitch > deg_to_rad(Foundation.CAMERA_PITCH_DEGREES), "vertical swipe tilts the camera upward")
	_check(player.move_input().y < -0.5, "camera swipe does not steal the movement finger")
	var yaw_before_pad := arena._camera_yaw
	Input.action_press(&"camera_right")
	arena._update_gamepad_camera(0.25)
	Input.action_release(&"camera_right")
	_check(arena._camera_yaw < yaw_before_pad, "right gamepad stick rotates the over-shoulder camera")
	var pitch_before_pad := arena._camera_pitch
	Input.action_press(&"camera_up")
	arena._update_gamepad_camera(0.25)
	Input.action_release(&"camera_up")
	_check(arena._camera_pitch > pitch_before_pad, "right gamepad stick tilts the camera upward")
	var yaw_after_swipe := arena._camera_yaw
	player.rotation.y = 1.1
	arena._process(0.016)
	_check(is_equal_approx(arena.camera_rig.rotation.y, yaw_after_swipe), "camera swipe yaw stays independent from player facing")
	_send_touch(camera_at + Vector2(100, -50), 3, false)
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
	_send_touch(movement_at + Vector2(0, -96), 0, false)
	_check(player.move_input() == Vector2.ZERO, "releasing the movement gesture stops movement")

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

func _test_gamepad_controls() -> void:
	var original_size := root.size
	root.size = Vector2i(1280, 720)
	var arena := Foundation.new()
	root.add_child(arena)
	var player: FoundationPlayer = arena.player
	var hud: FoundationHUD = arena.hud
	player.set_physics_process(false)
	arena.set_process(false)
	for enemy: Node in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await process_frame
	var routed: Array[String] = []
	hud.action_requested.connect(func(action: String) -> void: routed.append(action))
	var buttons := {
		JOY_BUTTON_A: "jump", JOY_BUTTON_B: "cast_spell",
		JOY_BUTTON_X: "dash", JOY_BUTTON_Y: "blast",
		JOY_BUTTON_LEFT_SHOULDER: "kick_left", JOY_BUTTON_RIGHT_SHOULDER: "punch_left",
		JOY_BUTTON_DPAD_UP: "spell_0", JOY_BUTTON_DPAD_RIGHT: "spell_1",
		JOY_BUTTON_DPAD_DOWN: "spell_2", JOY_BUTTON_DPAD_LEFT: "spell_3"
	}
	for button in buttons:
		var before := routed.size()
		var energy_before := player.magic_energy
		_send_pad(button, true)
		_check(routed.size() == before + 1 and routed.size() > 0 and routed.back() == buttons[button], "%s press reaches the touch HUD action path" % buttons[button])
		_send_pad(button, false)
		hud._process(0.4)
		_check(routed.size() == before + 1, "%s release stops held input" % buttons[button])
		if str(buttons[button]).begins_with("spell_") or buttons[button] == "cast_spell" or buttons[button] == "blast":
			_check(player.magic_energy == energy_before, "locked %s spends no energy" % buttons[button])
		if str(buttons[button]).begins_with("punch_") or str(buttons[button]).begins_with("kick_"):
			_check(player.attack_kind == str(buttons[button]).get_slice("_", 0) or player._queued_attack_kind == str(buttons[button]).get_slice("_", 0), "%s uses the existing melee path" % buttons[button])
			for step in range(4):
				player._update_attack(1.0)

	player.dash_time = 0.0
	var energy_before_locked_b := player.magic_energy
	_send_pad(JOY_BUTTON_B, true)
	_check(player.dash_time == 0.0 and player.magic_energy == energy_before_locked_b, "B cannot dash or spend energy while magic is locked")
	_send_pad(JOY_BUTTON_B, false)

	var attacks_before_r1 := player.attack_count
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, true)
	_check(player.attack_count == attacks_before_r1 + 1 and player.attack_kind == "punch" and player.attack_side == "left", "R1 triggers left punch and not right kick")
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	for step in range(4):
		player._update_attack(1.0)

	# Every melee button has one immediate strike and repeats at the touch cadence.
	for button in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var before := routed.size()
		var attacks_before := player.attack_count
		_send_pad(button, true)
		_send_pad(button, true)
		_check(routed.size() == before + 1, "duplicate %s down event cannot double-strike" % buttons[button])
		hud._process(0.19)
		player._update_attack(0.19)
		_check(routed.size() == before + 1, "%s has no early repeat" % buttons[button])
		hud._process(0.01)
		player._update_attack(0.01)
		_check(routed.size() == before + 2, "%s repeats after 0.20 seconds" % buttons[button])
		for repeat in range(3):
			for frame in range(20):
				hud._process(0.01)
				player._update_attack(0.01)
		_check(routed.size() == before + 5, "%s permits five attempts over the first 0.8 seconds" % buttons[button])
		_send_pad(button, false)
		for frame in range(20):
			player._update_attack(0.01)
		_check(player.attack_count == attacks_before + 5, "%s starts five distinct melee attempts" % buttons[button])
		hud._process(0.2)
		_check(routed.size() == before + 5, "%s stops repeating on release" % buttons[button])
		for step in range(4):
			player._update_attack(1.0)

	var before_trigger := routed.size()
	var attacks_before_trigger := player.attack_count
	_send_trigger(0.4)
	_check(routed.size() == before_trigger, "partial R2 pull below threshold does not kick")
	_send_trigger(0.7)
	_check(routed.size() == before_trigger + 1 and routed.back() == "kick_right" and player.attack_kind == "kick" and player.attack_side == "right", "R2 starts one right kick")
	_send_trigger(0.45)
	_send_trigger(0.8)
	_check(routed.size() == before_trigger + 1, "R2 trigger noise cannot double-strike")
	hud._process(0.19)
	player._update_attack(0.19)
	_check(routed.size() == before_trigger + 1, "held R2 has no early repeat")
	hud._process(0.01)
	player._update_attack(0.01)
	_check(routed.size() == before_trigger + 2, "held R2 repeats after 0.20 seconds")
	for repeat in range(3):
		for frame in range(20):
			hud._process(0.01)
			player._update_attack(0.01)
	_check(routed.size() == before_trigger + 5 and player.attack_count == attacks_before_trigger + 5, "held R2 permits five distinct right-kick attempts over 0.8 seconds")
	_send_trigger(0.0)
	hud._process(0.4)
	_check(routed.size() == before_trigger + 5, "releasing R2 stops repeats")
	for step in range(4):
		player._update_attack(1.0)
	_send_trigger(0.8)
	_check(routed.size() == before_trigger + 6, "R2 makes a new kick after release and press")
	_send_trigger(0.0)
	for step in range(4):
		player._update_attack(1.0)

	var before_negative_rest := routed.size()
	hud._right_trigger_rest_values[0] = -1.0
	_send_trigger(0.0)
	_check(routed.size() == before_negative_rest + 1 and routed.back() == "kick_right" and player.attack_side == "right", "R2 works on controllers whose trigger rests at -1")
	_send_trigger(-1.0)
	hud._right_trigger_rest_values[0] = 0.0
	for step in range(4):
		player._update_attack(1.0)

	for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT]:
		var before := routed.size()
		_send_pad(button, true)
		hud._process(1.0)
		_send_pad(button, true)
		_check(routed.size() == before + 1, "%s activates only once while held" % buttons[button])
		_send_pad(button, false)
		_send_pad(button, true)
		_check(routed.size() == before + 2, "%s can activate on a new press" % buttons[button])
		_send_pad(button, false)

	player.dash_time = 0.0
	var attacks_before_x := player.attack_count
	_send_pad(JOY_BUTTON_X, true)
	_check(player.dash_time > 0.0 and player.attack_count == attacks_before_x, "Xbox X dashes without triggering left punch")
	_send_pad(JOY_BUTTON_X, false)

	player.rage.unlocked_spells.assign(["light"])
	arena._refresh_hud()
	var before_magic := player.magic_energy
	_send_pad(JOY_BUTTON_DPAD_UP, true)
	_send_pad(JOY_BUTTON_DPAD_UP, false)
	_check(player.current_spell == "light" and player.magic_energy == before_magic - 20.0, "D-pad Up casts unlocked slot 1 via touch spell handler")
	var before_selected_cast := player.magic_energy
	_send_pad(JOY_BUTTON_B, true)
	hud._process(0.4)
	_check(player.current_spell == "light" and player.magic_energy == before_selected_cast - 20.0, "B casts the selected spell once while held")
	_send_pad(JOY_BUTTON_B, false)
	for button in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT]:
		var energy_before := player.magic_energy
		_send_pad(button, true)
		_send_pad(button, false)
		_check(player.magic_energy == energy_before, "locked D-pad spell slot remains harmless")

	player.rage.unlocked_spells.assign(["light", "fire"])
	arena._refresh_hud()
	var blast_target := get_nodes_in_group("enemies")[0] as FoundationEnemy
	# Horde members now spawn 50 m away; put this test target inside Blast range.
	var blast_direction := -player.global_transform.basis.z
	blast_direction.y = 0.0
	blast_target.global_position = player.global_position + blast_direction.normalized() * 4.0
	var blast_hp_before := blast_target.hp
	var blast_energy_before := player.magic_energy
	var blast_routes_before := routed.size()
	_send_pad(JOY_BUTTON_Y, true)
	hud._process(0.4)
	_check(routed.size() == blast_routes_before + 1 and routed.back() == "blast", "Xbox Y routes once to Blast")
	_check(blast_target.hp == blast_hp_before - 20 and player.magic_energy == blast_energy_before - 15 and player.current_spell == "light", "Xbox Y casts Fire Blast without changing the selected B spell")
	_send_pad(JOY_BUTTON_Y, false)

	Input.action_press(&"move_forward")
	Input.action_press(&"move_right")
	Input.action_press(&"camera_right")
	Input.action_press(&"camera_up")
	var yaw_before := arena._camera_yaw
	var pitch_before := arena._camera_pitch
	var before_combo := routed.size()
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, true)
	arena._update_gamepad_camera(0.1)
	_check(player.move_input().x > 0.0 and player.move_input().y < 0.0, "left stick supports diagonal movement during an attack")
	_check(arena._camera_yaw < yaw_before and arena._camera_pitch > pitch_before, "right stick simultaneously turns and tilts upward")
	_check(routed.size() == before_combo + 1 and player.attack_side == "left", "both sticks and an R1 punch can operate together")
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, false)
	Input.action_release(&"move_forward")
	Input.action_release(&"move_right")
	Input.action_release(&"camera_right")
	Input.action_release(&"camera_up")
	_check(player.move_input() == Vector2.ZERO, "left stick release stops movement")
	Input.action_press(&"camera_up")
	arena._update_gamepad_camera(10.0)
	_check(is_equal_approx(arena._camera_pitch, deg_to_rad(Foundation.CAMERA_MAX_PITCH_DEGREES)), "upward stick look obeys upper pitch clamp")
	Input.action_release(&"camera_up")
	Input.action_press(&"camera_down")
	arena._update_gamepad_camera(10.0)
	_check(is_equal_approx(arena._camera_pitch, deg_to_rad(Foundation.CAMERA_MIN_PITCH_DEGREES)), "downward stick look obeys lower pitch clamp")
	Input.action_release(&"camera_down")

	var before_menu := routed.size()
	paused = true
	hud.show_aura_selection(10)
	_send_pad(JOY_BUTTON_Y, true)
	_send_pad(JOY_BUTTON_X, true)
	_send_trigger(0.8)
	hud._process(0.4)
	arena._update_gamepad_camera(0.4)
	_check(routed.size() == before_menu, "controller gameplay buttons cannot fire through an aura menu")
	hud.close_aura_selection()
	paused = false
	hud._process(0.4)
	_check(routed.size() == before_menu, "holding buttons across pause cannot trigger delayed gameplay")
	_send_pad(JOY_BUTTON_Y, false)
	_send_pad(JOY_BUTTON_X, false)
	_send_trigger(0.0)
	_send_pad(JOY_BUTTON_Y, true)
	_check(routed.size() == before_menu + 1 and routed.back() == "blast", "a fresh Y press after the menu activates Blast")
	_send_pad(JOY_BUTTON_Y, false)
	_send_trigger(0.8)
	_check(routed.size() == before_menu + 2 and routed.back() == "kick_right", "R2 requires a new press after the menu")
	_send_trigger(0.0)
	arena.queue_free()
	await process_frame
	root.size = original_size
