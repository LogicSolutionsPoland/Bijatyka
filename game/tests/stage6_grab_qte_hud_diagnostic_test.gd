extends SceneTree
## Stage 6 P1 diagnostics only. Checks existing HUD and R3 signal routing without changing gameplay.
## Not a substitute for a physical Android controller test.

const HUD_SCRIPT := preload("res://scripts/mobile_hud.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("P1 QTE HUD diagnostic: " + description)

func _run() -> void:
	var hud := HUD_SCRIPT.new() as FoundationHUD
	root.add_child(hud)
	await process_frame
	_check(is_instance_valid(hud._root), "HUD root created")
	_check(is_instance_valid(hud._limb_grab_button), "existing QTE widget constructed")
	_check(not hud._limb_grab_button.visible, "QTE initially hidden")
	var emitted: Array[String] = []
	hud.action_requested.connect(func(action: String) -> void:
		emitted.append(action)
	)
	hud.begin_grab_qte(42, null, "LEFT ARM", 3, 1.5)
	_check(hud._limb_grab_button.visible, "HUD shows QTE on start signal")
	_check(hud._active_grab_qte_session_id == 42, "HUD binds QTE to session 42")
	_check(hud._limb_grab_button.text.contains("0/3"), "HUD displays zero of three presses")

	# Match Godot's input map (R3 = button 8); use the exact existing HUD handler.
	var press := InputEventJoypadButton.new()
	press.device = 0
	press.button_index = JOY_BUTTON_RIGHT_STICK
	press.pressed = true
	hud._handle_gamepad_button(press)
	_check(emitted.size() == 1 and emitted[0] == "escape_limb_grab", "R3 produces one escape action")
	hud._handle_gamepad_button(press)
	_check(emitted.size() == 1, "held R3 does not repeat QTE actions")

	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = JOY_BUTTON_RIGHT_STICK
	release.pressed = false
	hud._handle_gamepad_button(release)
	hud._handle_gamepad_button(press)
	_check(emitted.size() == 2, "R3 fresh edge after release produces another action")

	hud.update_grab_qte(42, 2, 3, 0.4)
	_check(hud._limb_grab_button.text.contains("2/3"), "QTE HUD progress updated")
	hud.finish_grab_qte(41, "timeout")
	_check(hud._limb_grab_button.visible, "stale completion does not hide active QTE")
	hud.finish_grab_qte(42, "escaped")
	_check(not hud._limb_grab_button.visible and hud._active_grab_qte_session_id == 0, "correct completion clears QTE widget")

	hud.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: Stage6 P1 QTE HUD and simulated R3 diagnostics (%d checks)" % checks)
		quit(0)
	else:
		for failure in failures:
			print("FAIL: " + failure)
		print("FAIL: Stage6 P1 QTE HUD diagnostics %d of %d" % [failures.size(), checks])
		quit(1)
