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
	_check(Foundation != null and Hud != null, "scene and gamepad HUD scripts compile")
	_test_gamepad_input_map()
	_test_rage_rules()
	_test_multiple_milestones_and_reset()
	await _test_hud_aura_choices()
	await _test_roaming_aggression()
	await _test_enemy_variant_health()
	await _test_manual_attack_and_hit_window()
	await _test_punch_animation_faces_forward()
	await _test_magic_unlock_and_damage()
	await _test_jump_and_enemy_interrupt_rules()
	await _test_boss_damage_rule()
	await _test_no_touch_controls()
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
		&"pad_jump": [JOY_BUTTON_A], &"pad_jump_forward": [JOY_BUTTON_X],
		&"pad_escape_limb_grab": [JOY_BUTTON_RIGHT_STICK], &"pad_cast_spell": [JOY_BUTTON_B],
		&"pad_punch_left": [JOY_BUTTON_LEFT_SHOULDER], &"pad_punch_right": [JOY_BUTTON_RIGHT_SHOULDER],
		&"pad_blast": [JOY_BUTTON_Y],
		&"pad_spell_0": [JOY_BUTTON_DPAD_UP], &"pad_spell_1": [JOY_BUTTON_DPAD_RIGHT],
		&"pad_spell_2": [JOY_BUTTON_DPAD_DOWN], &"pad_spell_3": [JOY_BUTTON_DPAD_LEFT]
	}
	var routed_actions: Array[String] = []
	for action: String in Hud.GAMEPAD_ACTIONS.values():
		routed_actions.append(action)
	_check(Hud.GAMEPAD_ACTIONS.size() == expected_buttons.size() + 2,
		"gamepad routes eleven buttons and two analog triggers")
	var left_trigger_events := InputMap.action_get_events(&"pad_kick_left")
	_check(left_trigger_events.size() == 1 and left_trigger_events[0] is InputEventJoypadMotion and (left_trigger_events[0] as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT and is_equal_approx((left_trigger_events[0] as InputEventJoypadMotion).axis_value, 1.0), "L2 / LT maps to the left trigger axis")
	var right_trigger_events := InputMap.action_get_events(&"pad_kick_right")
	_check(right_trigger_events.size() == 1 and right_trigger_events[0] is InputEventJoypadMotion and (right_trigger_events[0] as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_RIGHT and is_equal_approx((right_trigger_events[0] as InputEventJoypadMotion).axis_value, 1.0), "R2 / RT maps to the right trigger axis")
	_check(Hud.GAMEPAD_ACTIONS.get(&"pad_kick_left", "") == "kick_left" and Hud.GAMEPAD_ACTIONS.get(&"pad_kick_right", "") == "kick_right", "L2 and R2 route to their matching touch kicks")
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
			_check(routed_actions.has(Hud.GAMEPAD_ACTIONS.get(action, "")), "%s routes to a gamepad action" % action)
	var assigned_buttons := {}
	for buttons: Array in expected_buttons.values():
		for button: int in buttons:
			assigned_buttons[button] = true
	_check(assigned_buttons.size() == 11 and not assigned_buttons.has(JOY_BUTTON_START) and not assigned_buttons.has(JOY_BUTTON_GUIDE), "eleven gameplay buttons leave system buttons unassigned")

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
	_check(hud._selection_cards.size() == 4, "gamepad aura menu shows four selectable cards")
	var selected: Array[String] = []
	hud.aura_chosen.connect(func(aura_id: String) -> void: selected.append(aura_id))
	var expected := ["light", "judgment", "fire", "shadow"]
	for index in range(expected.size()):
		if index > 0:
			hud._move_aura_selection(1)
		hud._confirm_aura_selection()
		_check(not selected.is_empty() and selected.back() == expected[index], "gamepad aura selection emits its distinct choice")
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
	_check(player.request_attack("punch"), "punch press starts a cinematic engagement")
	_check(player.attack_phase == "grapple" and target._player_grapple_owner == player, "first enemy is grabbed before striking")
	player._update_attack(Player.CHAIN_GRAB_SECONDS)
	_check(player.attack_count == 1 and player.attack_phase == "windup", "grapple reaches into the first punch")
	_check(player.request_attack("kick") and player._queued_attack_kind == "kick", "next input buffers during the current attack")
	player._update_attack(float(Player.ATTACKS["punch"].windup))
	_check(target.hp < target.starting_health, "punch hit window detects an in-range enemy")
	_check(player.rage.rage == 3.0, "only a confirmed positive hit increases RAGE")
	player._update_attack(float(Player.ATTACKS["punch"].active))
	_check(player.attack_kind == "kick" and player.attack_count == 2 and player.attack_phase == "windup", "buffered kick begins after half a second of fighting")
	for _frame in range(350):
		player._update_attack(0.01)
	await process_frame
	_check(player.attack_phase == "ready" and player.request_attack("kick") and player.attack_count == 3, "a fresh kick starts after the complete native-speed previous kick")
	var rage_before_miss := player.rage.rage
	target.hp = target.starting_health
	player._finish_attack()
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
			var shoulder_index := player._skeleton.find_bone(Player.CHARACTER_MOTION.BONE_MAP["%sUpperArm" % side.capitalize()])
			var wrist_index := player._skeleton.find_bone(Player.CHARACTER_MOTION.BONE_MAP["%sHand" % side.capitalize()])
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

func _send_pad(button: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = down
	root.push_input(event, true)

func _send_trigger(amount: float, device: int = 0, axis: int = JOY_AXIS_TRIGGER_RIGHT) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = amount
	root.push_input(event, true)

func _test_no_touch_controls() -> void:
	var hud := Hud.new() as FoundationHUD
	root.add_child(hud)
	await process_frame
	var escape_buttons := hud.find_children("*", "BaseButton", true, false)
	_check(escape_buttons.size() == 1 and escape_buttons[0].name == "EscapeLimbGrab"
		and not escape_buttons[0].visible,
		"gameplay HUD keeps only the hidden limb-grab escape button until a grab")
	_check(hud.find_child("MovementStick", true, false) == null,
		"gameplay HUD has no touch movement stick")
	var emitted: Array[String] = []
	hud.action_requested.connect(func(action: String) -> void: emitted.append(action))
	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(640, 360)
	touch.pressed = true
	root.push_input(touch, true)
	touch.pressed = false
	root.push_input(touch, true)
	_check(emitted.is_empty(), "screen touches never trigger combat")
	hud.queue_free()
	await process_frame

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
		JOY_BUTTON_X: "jump_forward", JOY_BUTTON_RIGHT_STICK: "escape_limb_grab",
		JOY_BUTTON_Y: "blast",
		JOY_BUTTON_LEFT_SHOULDER: "punch_left", JOY_BUTTON_RIGHT_SHOULDER: "punch_right",
		JOY_BUTTON_DPAD_UP: "spell_0", JOY_BUTTON_DPAD_RIGHT: "spell_1",
		JOY_BUTTON_DPAD_DOWN: "spell_2", JOY_BUTTON_DPAD_LEFT: "spell_3"
	}
	for button in buttons:
		var before := routed.size()
		var energy_before := player.magic_energy
		_send_pad(button, true)
		_check(routed.size() == before + 1 and routed.size() > 0 and routed.back() == buttons[button], "%s press reaches the gamepad HUD action path" % buttons[button])
		_send_pad(button, false)
		hud._process(0.4)
		_check(routed.size() == before + 1, "%s release stops held input" % buttons[button])
		if str(buttons[button]).begins_with("spell_") or buttons[button] == "cast_spell" or buttons[button] == "blast":
			_check(player.magic_energy == energy_before, "locked %s spends no energy" % buttons[button])
		if str(buttons[button]).begins_with("punch_") or str(buttons[button]).begins_with("kick_"):
			_check(player.attack_kind == str(buttons[button]).get_slice("_", 0) or player._queued_attack_kind == str(buttons[button]).get_slice("_", 0), "%s uses the existing melee path" % buttons[button])
			for step in range(4):
				player._update_attack(1.0)

	var energy_before_locked_b := player.magic_energy
	_send_pad(JOY_BUTTON_B, true)
	_check(not player._parabolic_jump_active and player.magic_energy == energy_before_locked_b, "B cannot start the forward jump or spend energy while magic is locked")
	_send_pad(JOY_BUTTON_B, false)

	var attacks_before_l1 := player.attack_count
	_send_pad(JOY_BUTTON_LEFT_SHOULDER, true)
	_check(player.attack_count == attacks_before_l1 + 1 and player.attack_kind == "punch" and player.attack_side == "left", "L1 triggers left punch and not left kick")
	_send_pad(JOY_BUTTON_LEFT_SHOULDER, false)
	for step in range(4):
		player._update_attack(1.0)

	var attacks_before_r1 := player.attack_count
	_send_pad(JOY_BUTTON_RIGHT_SHOULDER, true)
	_check(player.attack_count == attacks_before_r1 + 1 and player.attack_kind == "punch" and player.attack_side == "right", "R1 triggers right punch and not right kick")
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
		for repeat in range(9):
			for frame in range(20):
				hud._process(0.01)
				player._update_attack(0.01)
		_check(routed.size() == before + 11, "%s permits one immediate hit plus ten 0.20-second repeats" % buttons[button])
		_send_pad(button, false)
		for frame in range(20):
			player._update_attack(0.01)
		_check(player.attack_count == attacks_before + 11, "%s starts eleven distinct melee attempts" % buttons[button])
		hud._process(0.2)
		_check(routed.size() == before + 11, "%s stops repeating on release" % buttons[button])
		for step in range(4):
			player._update_attack(1.0)

	var before_left_trigger := routed.size()
	_send_trigger(0.4, 0, JOY_AXIS_TRIGGER_LEFT)
	_check(routed.size() == before_left_trigger, "partial L2 pull below threshold does not kick")
	_send_trigger(0.7, 0, JOY_AXIS_TRIGGER_LEFT)
	_check(routed.size() == before_left_trigger + 1 and routed.back() == "kick_left" and player.attack_kind == "kick" and player.attack_side == "left", "L2 starts one left kick")
	_send_trigger(0.0, 0, JOY_AXIS_TRIGGER_LEFT)
	hud._process(0.4)
	_check(routed.size() == before_left_trigger + 1, "releasing L2 stops repeats")
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
	for repeat in range(9):
		for frame in range(20):
			hud._process(0.01)
			player._update_attack(0.01)
	_check(routed.size() == before_trigger + 11 and player.attack_count < attacks_before_trigger + 11 and player._queued_attack_kind == "kick",
		"held R2 delivers ten repeat inputs while completed kicks retain their native durations")
	_send_trigger(0.0)
	hud._process(0.4)
	_check(routed.size() == before_trigger + 11, "releasing R2 stops repeats")
	for step in range(4):
		player._update_attack(1.0)
	_send_trigger(0.8)
	_check(routed.size() == before_trigger + 12, "R2 makes a new kick after release and press")
	_send_trigger(0.0)
	for step in range(4):
		player._update_attack(1.0)

	var before_negative_rest := routed.size()
	hud._left_trigger_rest_values[0] = -1.0
	_send_trigger(0.0, 0, JOY_AXIS_TRIGGER_LEFT)
	_check(routed.size() == before_negative_rest + 1 and routed.back() == "kick_left" and player.attack_side == "left", "L2 works on controllers whose trigger rests at -1")
	_send_trigger(-1.0, 0, JOY_AXIS_TRIGGER_LEFT)
	hud._left_trigger_rest_values[0] = 0.0
	for step in range(4):
		player._update_attack(1.0)

	var before_right_negative_rest := routed.size()
	hud._right_trigger_rest_values[0] = -1.0
	_send_trigger(0.0)
	_check(routed.size() == before_right_negative_rest + 1 and routed.back() == "kick_right" and player.attack_side == "right", "R2 works on controllers whose trigger rests at -1")
	_send_trigger(-1.0)
	hud._right_trigger_rest_values[0] = 0.0
	for step in range(4):
		player._update_attack(1.0)

	for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT]:
		var before := routed.size()
		_send_pad(button, true)
		hud._process(1.0)
		_send_pad(button, true)
		_check(routed.size() == before + 1, "%s activates only once while held" % buttons[button])
		_send_pad(button, false)
		_send_pad(button, true)
		_check(routed.size() == before + 2, "%s can activate on a new press" % buttons[button])
		_send_pad(button, false)

	var before_forward_jump_route := routed.size()
	_send_pad(JOY_BUTTON_X, true)
	_check(routed.size() == before_forward_jump_route + 1 and routed.back() == "jump_forward",
		"Xbox X reaches the forward-jump action without triggering left punch")
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
	_check(routed.size() == before_combo + 1 and player.attack_side == "right", "both sticks and an R1 punch can operate together")
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

func _test_roaming_aggression() -> void:
	var player := Player.new() as FoundationPlayer
	player.position = Vector3(60, 0, 0)
	player.set_physics_process(false)
	root.add_child(player)
	var a := Enemy.new() as FoundationEnemy
	var b := Enemy.new() as FoundationEnemy
	for enemy in [a, b]:
		enemy.set_physics_process(false)
		root.add_child(enemy)
		enemy._player = player
	b.position = Vector3(1.5, 0, 0)
	await physics_frame
	a._choose_target()
	_check(a.combat_target == null and b.combat_target == null, "unalerted zombie does not hunt nearby rivals")
	var before := b.hp
	a._resolve_enemy_attack(1.5)
	_check(b.hp == before, "zombies do not infight when the player is distant")
	_check(b.combat_target == null, "unalerted rival remains focused on the player")
	_check(player.rage.rage == 0.0, "no infighting adds player RAGE")
	player.position = Vector3(0, 0, 10)
	a._choose_target()
	_check(a.combat_target == player and b.combat_target == player, "player detection alerts nearby zombies")
	player.position = Vector3(60, 0, 0)
	a._choose_target()
	_check(a.combat_target == player and b.combat_target == player, "alerted pack retains the player target at distance")
	b.position = Vector3(40, 0, 0)
	a.combat_target = null
	a.state = "idle"
	a._wander_time = 0.0
	a._wander(0.1)
	_check(a.state == "wander" and a.velocity.length() > 0.0, "idle zombie begins walking without a target")
	a._wander_time = 0.0
	a._wander(0.1)
	_check(a.state == "idle" and a.velocity.length() == 0.0, "wandering alternates with idle pauses")
	a.combat_target = b
	b.hp = 0
	_check(not a._valid_target(), "dead opponents are rejected")
	for node in [a, b, player]:
		node.queue_free()
	await process_frame
