extends Control
## Actual enemy tooth glints plus a persistent, inexpensive illusion of a
## much larger horde outside the flashlight. The synthetic mouths are visual
## only: they never create enemies, colliders, AI, damage or spawn events.

const SYNTHETIC_MOUTH_COUNT := 420
const MAX_DRAWN_SYNTHETIC_MOUTHS := 96
const MIN_SYNTHETIC_DISTANCE := 14.0 # Always past the 10 m flashlight reach.
const MAX_SYNTHETIC_DISTANCE := 68.0
const MASK_WIDTH := 96
const MASK_HEIGHT := 48
# At most one mouth charges at a time; the 3 s animation leaves a 2 s pause.
const CHARGE_INTERVAL := 5.0
const CHARGE_DURATION := 3.0
const CHARGE_APPROACH_END := 1.2
const CHARGE_TURN_END := 1.65
const CHARGE_MIN_RADIUS := 10.8

var _glints: Array[Dictionary] = []
var _synthetic_mouths: Array[Dictionary] = []
var _mouth_texture: Texture2D
var _camera: Camera3D
var _player: Node3D
var _visibility_manager: Node
var _elapsed := 0.0
var _next_charge_at := CHARGE_INTERVAL
var _active_charge_index := -1
var _charge_started_at := -CHARGE_DURATION
var _charge_pick_cursor := 0
var _charge_event_count := 0

func configure(view_camera: Camera3D, game_player: Node3D, manager: Node) -> void:
	_camera = view_camera
	_player = game_player
	_visibility_manager = manager
	_build_mouth_texture()
	_build_synthetic_mouths()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	# The schedule is clock-based and cannot be retriggered by jumps/spawns.
	_elapsed += delta
	if _active_charge_index >= 0 and _elapsed - _charge_started_at >= CHARGE_DURATION:
		_active_charge_index = -1
	if _elapsed >= _next_charge_at:
		# Advance to the next five-second boundary even after a slow frame.
		_next_charge_at = (floorf(_elapsed / CHARGE_INTERVAL) + 1.0) * CHARGE_INTERVAL
		if _active_charge_index < 0:
			var candidate := _pick_charge_candidate()
			if candidate >= 0:
				_active_charge_index = candidate
				_charge_started_at = _elapsed
				_charge_event_count += 1

func _pick_charge_candidate() -> int:
	# Select a mouth the player can actually see in darkness. Perform this
	# cheap scan only once every five seconds, never on a combat/spawn event.
	if not is_instance_valid(_camera) or not is_instance_valid(_player):
		return -1
	if not is_instance_valid(_visibility_manager) or not _camera.is_current():
		return -1
	if float(_visibility_manager.call("get_teeth_glow_weight", Vector3.ZERO)) <= 0.0:
		return -1
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if viewport_size.x < 2.0 or viewport_size.y < 2.0:
		return -1
	var count := _synthetic_mouths.size()
	if count == 0:
		return -1
	for step in range(count):
		var index := (_charge_pick_cursor + step) % count
		var entry: Dictionary = _synthetic_mouths[index]
		var offset: Vector3 = entry["offset"]
		var radius := Vector2(offset.x, offset.z).length()
		if radius < 16.0 or radius > 50.0:
			continue
		var at := _player.global_position + offset
		if _camera.is_position_behind(at):
			continue
		var screen := _camera.unproject_position(at)
		var uv := screen / viewport_size
		# Avoid clipping an approaching mouth at the screen edge or drawing
		# it inside the central flashlight opening.
		if uv.x < 0.12 or uv.x > 0.88 or uv.y < 0.14 or uv.y > 0.86:
			continue
		if float(_visibility_manager.call("get_oval_weight", uv)) > 0.03:
			continue
		_charge_pick_cursor = (index + 47) % count
		return index
	return -1

func get_charge_proximity(age: float) -> float:
	# Sprint at the viewer, turn, then retreat to the original distance.
	if age < 0.0 or age >= CHARGE_DURATION:
		return 0.0
	if age < CHARGE_APPROACH_END:
		return smoothstep(0.0, CHARGE_APPROACH_END, age)
	if age < CHARGE_TURN_END:
		return 1.0
	return 1.0 - smoothstep(CHARGE_TURN_END, CHARGE_DURATION, age)

func get_charge_turn_scale(age: float) -> float:
	# A horizontal squash and signed flip approximates a 180-degree yaw:
	# front-facing -> edge-on -> facing away, without a 3D zombie rig.
	return cos(PI * smoothstep(CHARGE_APPROACH_END, CHARGE_TURN_END, age))

func set_glints(points: Array[Dictionary]) -> void:
	_glints = points
	# The existing manager updates real glints at 30 Hz. Reuse its redraw
	# rather than introducing a second per-frame canvas refresh.
	queue_redraw()

func get_synthetic_mouth_count() -> int:
	return _synthetic_mouths.size()

func _build_synthetic_mouths() -> void:
	_synthetic_mouths.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED132
	for index in range(SYNTHETIC_MOUTH_COUNT):
		# A full, deterministic 360-degree cloud survives turning around and
		# remains populated in the camera view without reacting to new spawns.
		var angle := TAU * (float(index) + rng.randf_range(-0.46, 0.46)) / float(SYNTHETIC_MOUTH_COUNT)
		var distance := lerpf(MIN_SYNTHETIC_DISTANCE, MAX_SYNTHETIC_DISTANCE, pow(rng.randf(), 0.75))
		_synthetic_mouths.append({
			"offset": Vector3(cos(angle) * distance, rng.randf_range(-0.5, 4.2), sin(angle) * distance),
			"phase": rng.randf_range(0.0, TAU),
			"speed": rng.randf_range(0.58, 1.83),
			"scale": rng.randf_range(0.70, 1.26),
			"brightness": rng.randf_range(0.62, 1.0),
		})

func _build_mouth_texture() -> void:
	# Generate a small RGBA teeth-mask atlas only once; every virtual mouth
	# shares the same GPU texture. No additional assets, models or draw nodes.
	var image := Image.create(MASK_WIDTH, MASK_HEIGHT, false, Image.FORMAT_RGBA8)
	for y in range(MASK_HEIGHT):
		for x in range(MASK_WIDTH):
			var core := 0.0
			var halo := 0.0
			for row in range(2):
				for tooth in range(8):
					var center_x := 12.5 + float(tooth) * 10.1 + (1.0 if row == 1 else 0.0)
					var arc := pow(absf((float(tooth) - 3.5) / 3.5), 2.0)
					var center_y := (16.2 + arc * 2.1) if row == 0 else (30.3 - arc * 2.1)
					var canine := 1.5 if tooth == 1 or tooth == 6 else 0.0
					var radius_x := 4.0 if tooth == 0 or tooth == 7 else 4.3
					var radius_y := 5.0 + canine
					var dx := (float(x) - center_x) / radius_x
					var dy := (float(y) - center_y) / radius_y
					var radial := sqrt(dx * dx + dy * dy)
					core = maxf(core, 1.0 - smoothstep(0.72, 1.0, radial))
					halo = maxf(halo, 1.0 - smoothstep(0.82, 1.63, radial))
			var opacity := clampf(core * 0.92 + halo * 0.11, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.83, 0.91, 1.0, opacity))
	_mouth_texture = ImageTexture.create_from_image(image)

func _draw() -> void:
	_draw_synthetic_horde()
	# Preserve every real enemy's original glint geometry and occlusion rules.
	for entry in _glints:
		var center: Vector2 = entry["center"]
		var strength: float = entry["strength"]
		var scale: float = entry["scale"]
		var pearl := Color(0.86, 0.94, 1.0, strength * 0.93)
		draw_circle(center, 5.0 * scale, Color(0.45, 0.72, 0.95, strength * 0.065), true, -1.0, true)
		draw_line(center + Vector2(-2.3, -0.5) * scale, center + Vector2(2.3, -0.5) * scale,
			Color(0.66, 0.83, 1.0, strength * 0.32), 1.0 * scale, true)
		for tooth in range(4):
			var x := (float(tooth) - 1.5) * 1.35 * scale
			var lower := (1.1 if tooth == 0 or tooth == 3 else 1.6) * scale
			draw_line(center + Vector2(x, -0.6 * scale), center + Vector2(x, lower),
				pearl, 0.95 * scale, true)

func _draw_synthetic_horde() -> void:
	if not is_instance_valid(_camera) or not is_instance_valid(_player) or _mouth_texture == null:
		return
	if not _camera.is_current() or not is_instance_valid(_visibility_manager):
		return
	if float(_visibility_manager.call("get_teeth_glow_weight", Vector3.ZERO)) <= 0.0:
		return
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	if viewport_size.x < 2.0 or viewport_size.y < 2.0:
		return
	var painted := 0
	for index in range(_synthetic_mouths.size()):
		if painted >= MAX_DRAWN_SYNTHETIC_MOUTHS:
			break
		# Reserve one of the 96 draw slots for the charging mouth, even if
		# its index falls after the other visible mouths in the 420-entry cloud.
		if _active_charge_index >= 0 and index != _active_charge_index:
			if painted >= MAX_DRAWN_SYNTHETIC_MOUTHS - 1:
				continue
		var entry: Dictionary = _synthetic_mouths[index]
		var phase: float = entry["phase"]
		var speed: float = entry["speed"]
		var wobble := _elapsed * speed + phase
		var offset: Vector3 = entry["offset"]
		var charge_age := _elapsed - _charge_started_at
		var charging := index == _active_charge_index and charge_age >= 0.0 and charge_age < CHARGE_DURATION
		var approach := get_charge_proximity(charge_age) if charging else 0.0
		if charging:
			var horizontal := Vector3(offset.x, 0.0, offset.z)
			var approach_distance := minf(18.0, maxf(0.0, horizontal.length() - CHARGE_MIN_RADIUS))
			offset -= horizontal.normalized() * (approach_distance * approach)
		var world_mouth := _player.global_position + offset + Vector3(
			sin(wobble * 0.65) * 0.37,
			sin(wobble) * 0.43,
			cos(wobble * 0.72) * 0.35
		)
		if _camera.is_position_behind(world_mouth):
			continue
		var screen_position := _camera.unproject_position(world_mouth)
		if screen_position.x < -32.0 or screen_position.x > viewport_size.x + 32.0:
			continue
		if screen_position.y < -24.0 or screen_position.y > viewport_size.y + 24.0:
			continue
		# Use the *same* camera-space flashlight footprint as the black mask.
		# Teeth never appear over the lit scene, even at the soft oval edge.
		var light_weight := float(_visibility_manager.call("get_oval_weight", screen_position / viewport_size))
		var dark_weight := 1.0 - clampf(light_weight, 0.0, 1.0)
		if dark_weight < 0.06:
			continue
		var distance := maxf(1.0, _camera.global_position.distance_to(world_mouth))
		var size_factor: float = entry["scale"]
		var width := clampf(920.0 * viewport_size.y / (720.0 * distance), 7.0, 44.0) * size_factor
		# An extra perspective cue makes the single sprint readable from afar.
		width *= 1.0 + 0.80 * approach
		var mouth_open := 0.37 + 0.085 * sin(wobble * 1.55)
		var height := width * mouth_open
		var distance_weight := 1.0 - smoothstep(18.0, 75.0, distance)
		var pulse := 0.78 + 0.22 * sin(wobble * 0.81)
		var brightness: float = entry["brightness"]
		var alpha := dark_weight * brightness * pulse * lerpf(0.20, 0.57, distance_weight)
		alpha = minf(1.0, alpha * (1.0 + 0.45 * approach))
		if alpha < 0.025:
			continue
		var yaw_scale := get_charge_turn_scale(charge_age) if charging else 1.0
		draw_set_transform(screen_position, sin(wobble * 0.48) * 0.075,
			Vector2(yaw_scale, 1.0))
		draw_texture_rect(_mouth_texture, Rect2(Vector2(-width * 0.5, -height * 0.5),
			Vector2(width, height)), false, Color(0.78, 0.89, 1.0, alpha))
		painted += 1
		if painted >= MAX_DRAWN_SYNTHETIC_MOUTHS:
			break
	draw_set_transform()
