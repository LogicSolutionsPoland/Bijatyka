extends CharacterBody3D
class_name FoundationPlayer

signal attack_started(kind: String)
signal attack_connected(kind: String, target: Node)
signal attack_finished(kind: String)
signal health_changed(current: int, maximum: int)
signal magic_changed(current: float, maximum: float, school: String)
signal interrupted(duration: float)
signal jump_impact(target: Node)
signal parabolic_jump_started(takeoff_position: Vector3, travel_direction: Vector3)
signal parabolic_jump_landed(landing_position: Vector3, travel_direction: Vector3)
signal respawned
signal limb_grab_windup(limb: String)
signal limb_grab_started(limb: String)
signal limb_grab_ended
signal grab_state_changed(state: int, enemy: FoundationEnemy, limb: String)
signal grab_windup_started(enemy: FoundationEnemy, limb: String)
signal grab_established(enemy: FoundationEnemy, limb: String)
signal grab_interrupted(reason: String, enemy: FoundationEnemy, limb: String)
signal grab_escaped(enemy: FoundationEnemy, limb: String)
signal grab_failed(enemy: FoundationEnemy, limb: String)
signal grab_fully_ended(reason: String)
# Stable Stage 3 contract: session ID, attacker and limb are bound at GRABBED.
signal grab_qte_started(session_id: int, enemy: FoundationEnemy, limb: String, required_presses: int, duration_seconds: float)
signal grab_qte_progress(session_id: int, accepted_presses: int, required_presses: int, remaining_seconds: float)
signal grab_qte_finished(session_id: int, outcome: String)

const GRAB_QTE_SCRIPT := preload("res://scripts/brutal_grab_qte.gd")
const GRAB_CONTACT_SCRIPT := preload("res://scripts/brutal_grab_limb_contact.gd")
const RAGE_SCRIPT := preload("res://scripts/rage_progression.gd")
const FIGHT_ANIMATION_BUILDER := preload("res://scripts/universal_base_combat.gd")
const CHARACTER_MOTION := preload("res://scripts/universal_base_motion.gd")
const PLAYER_RING_REFERENCE := preload("res://scripts/player_ring_reference.gd")
const PLAYER_CHOREOGRAPHY := preload("res://scripts/player_choreography.gd")
const PLAYER_MODEL_PATH := "res://assets/characters/universal_base/Universal_Base_Characters_Male.glb"
const EXO_MODEL_PATH := "res://assets/characters/exo_gray/Exo_Gray_Player.glb"
const EXO_RETARGET := preload("res://scripts/player_exo_gray_retarget.gd")
const EXO_MIXAMO_OVERLAY_SCRIPT := preload("res://scripts/player_exo_mixamo_overlay.gd")
const GRAVITY := 24.0
const MAX_HEALTH := 100
const MAX_MAGIC := 100.0
enum JumpState { READY, ORDINARY, FORWARD }
enum GrabState { READY, WINDUP, GRABBED, ESCAPED, FAILED, RECOVERY }
const TARGET_MELEE_HITS_PER_SECOND := 5.0
const TARGET_MELEE_CYCLE_SECONDS := 1.0 / TARGET_MELEE_HITS_PER_SECOND
const MELEE_TIMER_EPSILON := 0.0001
const ATTACK_ANIMATION_BLEND_SECONDS := 0.06
const CHAIN_TARGET_RADIUS := 5.0
const CHAIN_GRAB_DISTANCE := 1.72
const CHAIN_STRIKE_DISTANCE := 1.45
const CHAIN_APPROACH_SECONDS := 0.48
const CHAIN_HOP_SPEED := 9.5
const CHAIN_GRAB_SECONDS := 0.16
const LOCOMOTION_ANIMATION_BLEND_SECONDS := 0.12
const ATTACKS := {
	"punch": {"windup": 0.10, "active": TARGET_MELEE_CYCLE_SECONDS - 0.10, "recovery": 0.24, "range": 1.55, "damage": 18, "cone": 0.42},
	"kick": {"windup": 0.12, "active": TARGET_MELEE_CYCLE_SECONDS - 0.12, "recovery": 0.28, "range": 2.15, "damage": 28, "cone": 0.30}
}
const SPELLS := {
	"light": {"cost": 20.0, "range": 8.0, "color": Color(1.0, 0.84, 0.32)},
	"judgment": {"cost": 20.0, "range": 18.0, "color": Color(0.40, 0.78, 1.0)},
	"fire": {"cost": 15.0, "range": 18.0, "color": Color(1.0, 0.24, 0.06)},
	"shadow": {"cost": 20.0, "range": 18.0, "color": Color(0.68, 0.30, 1.0)}
}

@export_range(1.0, 8.0, 0.1) var forward_jump_distance_m := 5.0
@export_range(0.8, 4.0, 0.1) var forward_jump_arc_height_m := 2.4
@export_range(0.5, 3.0, 0.1) var limb_grab_hold_seconds := 2.2
@export_range(1.0, 6.0, 0.1) var limb_grab_regrab_seconds := 3.0
@export_range(0.5, 4.0, 0.1) var grab_qte_duration_seconds := 1.5
@export_range(1, 8, 1) var grab_qte_required_presses := 3

var rage: RageProgression = RAGE_SCRIPT.new()
var health := MAX_HEALTH
var magic_energy := MAX_MAGIC
var current_spell := ""
var attack_phase := "ready"
var attack_kind := ""
var attack_side := "right"
var attack_phase_time := 0.0
var attack_count := 0
var _queued_attack_kind := ""
var _queued_attack_side := ""
var _attack_recovery_locked := false
var movement_slow_time := 0.0
var movement_slow_factor := 1.0
var _jump_state: JumpState = JumpState.READY
var _parabolic_jump_active := false
var _parabolic_jump_direction := Vector3.ZERO
var jump_impact_armed := false
var _was_airborne := false
var _animation_player: AnimationPlayer
var _skeleton: Skeleton3D
var _exo_visual_model: Node3D
var _exo_retarget: PlayerExoGrayRetarget
var _exo_overlay: PlayerExoMixamoOverlay
# Long Mixamo kicks use their native source timing; punch cadence is unchanged.
var _exo_kick_active := false
var _exo_kick_duration := 0.0
var _exo_kick_impact := 0.0
const EXO_KICK_ACTIVE_SECONDS := 0.08
var _fight_animations_ready := false
var _ring_animations_ready := false
var _choreography_ready := false
var _active_attack_clip: StringName = &""
var _ring_attack_counts: Dictionary = {}
var _engagement_target: FoundationEnemy
var _previous_engagement_target: FoundationEnemy
var _grabbed_target: FoundationEnemy # Player-to-zombie melee grapple.
# The player is the only grab-session authority; enemy.state is a tactical phase.
var grab_state: GrabState = GrabState.READY
var _limb_grab_candidate: FoundationEnemy
var _limb_grab_owner: FoundationEnemy
var _limb_grab_limb := ""
var _limb_grab_time := 0.0
var _limb_grab_cooldown := 0.0
# Monotonic IDs reject inputs/callbacks from earlier holds, even on the same enemy.
var _grab_session_serial := 0
var _grab_session_id := 0
var _grab_qte := GRAB_QTE_SCRIPT.new()
var _grab_contact: BrutalGrabLimbContact
var flashlight_visibility_manager: Node
var _character_motion_ready := false
var _character_action_time := 0.0
var _camera_yaw := 0.0
var _burns: Array[Dictionary] = []
var _magic_hud_timer := 0.0
var _desktop_attack_repeat_timers: Dictionary = {}
var safe_base_position := Vector3.ZERO
var combat_fx_pool: Node

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")

const SHADOW_POLICY := preload("res://scripts/shadow_policy.gd")

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 3
	if get_node_or_null("CollisionShape3D") == null:
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.38
		capsule.height = 1.85
		collision.shape = capsule
		collision.position.y = 0.92
		add_child(collision)
	if visual_root == null:
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)
	_load_player_visual()
	# Stage 3 visual contact listens to the established Stage 2 session only.
	_grab_contact = GRAB_CONTACT_SCRIPT.new() as BrutalGrabLimbContact
	add_child(_grab_contact)
	_grab_contact.configure(self)
	SHADOW_POLICY.disable_in_tree(visual_root)
	rage.condemned.connect(_on_condemned)
	rage.selection_resolved.connect(_on_selection_resolved)

func _load_player_visual() -> void:
	if visual_root.get_child_count() > 0:
		return
	if ResourceLoader.exists(PLAYER_MODEL_PATH):
		var packed := load(PLAYER_MODEL_PATH) as PackedScene
		if packed != null:
			var model := packed.instantiate() as Node3D
			if model != null:
				visual_root.add_child(model)
				model.rotation.y = PI
				_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
				if _animation_player == null:
					_animation_player = AnimationPlayer.new()
					_animation_player.name = "UniversalBaseAnimationPlayer"
					model.add_child(_animation_player)
				_animation_player.root_node = _animation_player.get_path_to(model)
				_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
				if _skeleton != null:
					_character_motion_ready = CHARACTER_MOTION.install(_animation_player, _skeleton)
					_fight_animations_ready = FIGHT_ANIMATION_BUILDER.install(_animation_player, _skeleton, ATTACKS)
					if _fight_animations_ready:
						_ring_animations_ready = PLAYER_RING_REFERENCE.install(_animation_player, _skeleton, ATTACKS)
				_animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
				_set_locomotion_animation("Idle")
				# Avoid displaying the imported T-pose on the first gameplay frame.
				if _animation_player.current_animation == "Idle":
					_animation_player.seek(0.05, true)
				_attach_exo_gray_player_model(model)
				return
	_add_debug_visual()

func _attach_exo_gray_player_model(source_model: Node3D) -> void:
	# Preserve the fully working 65-bone gameplay skeleton, animations,
	# combat hit markers, camera and physics. Only the rendered model changes.
	if _skeleton == null or not ResourceLoader.exists(EXO_MODEL_PATH):
		push_warning("Exo Gray model not installed; preserving Universal Base player visual")
		return
	var asset := load(EXO_MODEL_PATH) as PackedScene
	if asset == null:
		return
	var model := asset.instantiate() as Node3D
	if model == null:
		return
	model.name = "ExoGrayPlayerModel"
	model.rotation.y = PI
	visual_root.add_child(model)
	var target := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var retarget := EXO_RETARGET.new() as PlayerExoGrayRetarget
	if retarget == null or not retarget.configure(_skeleton, target):
		push_warning("Exo Gray rig is incompatible; using original player model")
		model.queue_free()
		return
	model.add_child(retarget)
	_exo_visual_model = model
	_exo_retarget = retarget
	# Invisible source model still runs its AnimationPlayer and Skeleton3D.
	source_model.visible = false
	# Optional imported Mixamo clips affect the Exo mesh only, never combat timing.
	var overlay := EXO_MIXAMO_OVERLAY_SCRIPT.new() as PlayerExoMixamoOverlay
	model.add_child(overlay)
	if overlay.configure(model, target, retarget):
		_exo_overlay = overlay
	else:
		overlay.queue_free()


## Explicit preview only: keep the 10s study out of normal melee state/timing.
## The demo scene can call this; the production player never auto-plays it.
func play_choreography_preview() -> bool:
	if _animation_player == null or _skeleton == null or not _ring_animations_ready:
		return false
	if attack_phase != "ready":
		return false
	if not _choreography_ready:
		_choreography_ready = PLAYER_CHOREOGRAPHY.install(_animation_player, _skeleton)
	if not _choreography_ready:
		return false
	var path := PLAYER_CHOREOGRAPHY.clip_path()
	if not _animation_player.has_animation(path):
		return false
	_animation_player.play(path, ATTACK_ANIMATION_BLEND_SECONDS)
	_animation_player.seek(0.0, true)
	return true

func _add_debug_visual() -> void:
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.8
	body.mesh = mesh
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.28, 0.34)
	body.material_override = material
	visual_root.add_child(body)

func _physics_process(delta: float) -> void:
	_update_limb_grab(delta)
	if rage.current_soul_condemned:
		return
	_character_action_time = maxf(0.0, _character_action_time - delta)
	_read_desktop_input(delta)
	_update_attack(delta)
	_update_burns(delta)
	magic_energy = minf(MAX_MAGIC, magic_energy + 5.0 * delta)
	if movement_slow_time > 0.0:
		movement_slow_time = maxf(0.0, movement_slow_time - delta)
		if movement_slow_time == 0.0:
			movement_slow_factor = 1.0
	if not _parabolic_jump_active:
		_update_movement(delta)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	var started_airborne := not is_on_floor() or velocity.y > 0.1
	move_and_slide()
	if _parabolic_jump_active and is_on_wall():
		# Keep vertical motion and landing intact while a wall stops forward travel.
		velocity.x = 0.0
		velocity.z = 0.0
	if started_airborne:
		_was_airborne = true
	if _was_airborne and is_on_floor():
		_was_airborne = false
		_play_character_action("Landing", float(CHARACTER_MOTION.ACTIONS.get("Landing", 0.38)))
		if _jump_state == JumpState.FORWARD:
			var landed_direction := _parabolic_jump_direction
			_parabolic_jump_active = false
			jump_impact_armed = false
			parabolic_jump_landed.emit(global_position, landed_direction)
			_parabolic_jump_direction = Vector3.ZERO
		elif _jump_state == JumpState.ORDINARY and jump_impact_armed:
			jump_impact_armed = false
			_resolve_jump_impact()
		_jump_state = JumpState.READY
		jump_impact_armed = false
	_update_locomotion_animation()
	_update_attack_pose()
	rage.advance(delta, true)
	_magic_hud_timer += delta
	if _magic_hud_timer >= 0.18:
		_magic_hud_timer = 0.0
		magic_changed.emit(magic_energy, MAX_MAGIC, current_spell)

func _read_desktop_input(delta: float) -> void:
	if Input.is_action_just_pressed("attack_punch"):
		request_attack("punch")
		_desktop_attack_repeat_timers[&"attack_punch"] = TARGET_MELEE_CYCLE_SECONDS
	elif Input.is_action_pressed("attack_punch"):
		var repeat_time := float(_desktop_attack_repeat_timers.get(&"attack_punch", TARGET_MELEE_CYCLE_SECONDS)) - minf(delta, TARGET_MELEE_CYCLE_SECONDS)
		if repeat_time <= MELEE_TIMER_EPSILON:
			request_attack("punch")
			repeat_time = TARGET_MELEE_CYCLE_SECONDS
		_desktop_attack_repeat_timers[&"attack_punch"] = repeat_time
	else:
		_desktop_attack_repeat_timers.erase(&"attack_punch")
	# The first accepted request owns this jump cycle. When both desktop actions
	# arrive together, this stable sampling order gives ordinary Jump priority.
	if Input.is_action_just_pressed("jump"):
		try_jump()
	if Input.is_action_just_pressed("jump_forward"):
		try_parabolic_jump()
	if Input.is_action_just_pressed("quick_cast_spell"):
		cast_spell_slot(1 if rage.unlocked_spells.size() > 1 else 0)
	if Input.is_action_just_pressed("cast_spell"):
		cast_spell()
	if Input.is_action_just_pressed("cycle_spell"):
		cycle_spell()
	if Input.is_action_just_pressed("escape_limb_grab"):
		try_escape_limb_grab()

func set_camera_yaw(yaw: float) -> void:
	_camera_yaw = yaw

func move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _update_movement(delta: float) -> void:
	if _limb_grab_owner != null:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	if attack_phase == "approach" and is_instance_valid(_engagement_target) and _engagement_target.hp > 0:
		var offset := _engagement_target.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > CHAIN_STRIKE_DISTANCE:
			var direction := offset.normalized()
			velocity.x = direction.x * CHAIN_HOP_SPEED
			velocity.z = direction.z * CHAIN_HOP_SPEED
			rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 16.0))
		else:
			velocity.x = 0.0
			velocity.z = 0.0
		return
	if attack_phase == "grapple":
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var stick := move_input()
	var relative := Vector3(stick.x, 0.0, stick.y)
	var direction := relative.rotated(Vector3.UP, _camera_yaw)
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		var target_yaw := atan2(-direction.x, -direction.z)
		var turn_delta := wrapf(target_yaw - rotation.y, -PI, PI)
		if attack_phase == "ready" and _character_action_time <= 0.0 and absf(turn_delta) > 0.72:
			var turn_action := "Turn_Left" if turn_delta > 0.0 else "Turn_Right"
			_play_character_action(turn_action, float(CHARACTER_MOTION.ACTIONS.get(turn_action, 0.28)))
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, delta * 16.0))
	var speed := 4.8 * movement_slow_factor
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

func request_attack(kind: String, side: String = "right") -> bool:
	if not ATTACKS.has(kind) or side not in ["left", "right"] or rage.current_soul_condemned or _limb_grab_owner != null:
		return false
	if attack_phase in ["approach", "grapple", "windup", "active"]:
		_queue_attack(kind, side)
		return true
	if attack_phase == "recovery":
		if _attack_recovery_locked or _exo_kick_active:
			_queue_attack(kind, side)
			return true
		_finish_attack()
	_start_attack(kind, side)
	return true

func _queue_attack(kind: String, side: String) -> void:
	_queued_attack_kind = kind
	_queued_attack_side = side

func _select_chain_target() -> FoundationEnemy:
	# Only normal zombies take part in cinematic grabs; the boss remains manual.
	var chosen: FoundationEnemy = null
	var best := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as FoundationEnemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_boss or enemy.hp <= 0:
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > CHAIN_TARGET_RADIUS:
			continue
		# The visible player cannot automatically lock onto zombies hidden in darkness.
		if is_instance_valid(flashlight_visibility_manager) and bool(flashlight_visibility_manager.get("enabled")):
			if not flashlight_visibility_manager.is_visible_to_flashlight(enemy):
				continue
			if not flashlight_visibility_manager.is_point_in_sector(enemy.global_position):
				continue
		# Prevent auto-grabs through arena walls or player-base obstacles.
		var sight := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, enemy.global_position + Vector3.UP, 1)
		sight.exclude = [get_rid(), enemy.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			continue
		var score := distance
		if enemy == _previous_engagement_target:
			score += CHAIN_TARGET_RADIUS + 0.5
		# Keep the next victim near the forward-facing arc where possible.
		var facing := -global_basis.z
		facing.y = 0.0
		if distance > 0.05 and facing.normalized().dot(offset.normalized()) < -0.25:
			score += 1.2
		if score < best:
			best = score
			chosen = enemy
	return chosen

func _start_attack(kind: String, side: String) -> void:
	attack_kind = kind
	attack_side = side
	_attack_recovery_locked = false
	_character_action_time = 0.0
	# A leap strike uses the current momentum and strike clip. Ground-only
	# approach and grapple would suspend the player in the middle of a jump.
	if not is_on_floor() and velocity.y > 0.1:
		_engagement_target = null
		_begin_strike()
		return
	_engagement_target = _select_chain_target()
	if is_instance_valid(_engagement_target):
		var separation := global_position.distance_to(_engagement_target.global_position)
		if separation > CHAIN_GRAB_DISTANCE:
			attack_phase = "approach"
			attack_phase_time = CHAIN_APPROACH_SECONDS
			# A short physical hop, never a teleport: CharacterBody3D collision remains active.
			if is_on_floor():
				velocity.y = 3.2
				_was_airborne = true
			_play_engagement_pose("slip_left" if side == "left" else "slip_right")
			return
		if _engagement_target != _previous_engagement_target:
			_begin_grapple()
			return
	_begin_strike()

func _play_engagement_pose(name: String) -> void:
	if _ring_animations_ready and _animation_player != null:
		var path := PLAYER_RING_REFERENCE.clip_path(name)
		if _animation_player.has_animation(path):
			_animation_player.play(path, ATTACK_ANIMATION_BLEND_SECONDS)
			_animation_player.seek(0.0, true)

func _begin_grapple() -> void:
	if not is_instance_valid(_engagement_target) or _engagement_target.hp <= 0 or _engagement_target.is_boss:
		_begin_strike()
		return
	attack_phase = "grapple"
	attack_phase_time = CHAIN_GRAB_SECONDS
	var offset := _engagement_target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.01:
		rotation.y = atan2(-offset.x, -offset.z)
	if not _engagement_target.begin_player_grapple(self, CHAIN_GRAB_SECONDS + (2.6 if attack_kind == "kick" and _exo_overlay != null else TARGET_MELEE_CYCLE_SECONDS) + 0.12):
		_begin_strike()
		return
	_grabbed_target = _engagement_target
	_play_engagement_pose("grapple_reach")

func _begin_strike() -> void:
	_exo_kick_active = false
	_exo_kick_duration = 0.0
	_exo_kick_impact = 0.0
	attack_phase = "windup"
	attack_phase_time = float(ATTACKS[attack_kind].windup)
	attack_count += 1
	attack_started.emit(attack_kind)
	_spawn_attack_sweep(attack_kind, attack_side)
	if is_instance_valid(_engagement_target) and _engagement_target.hp > 0:
		var offset := _engagement_target.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > 0.01:
			rotation.y = atan2(-offset.x, -offset.z)
	if _animation_player != null:
		if _fight_animations_ready:
			_active_attack_clip = FIGHT_ANIMATION_BUILDER.clip_path(attack_kind, attack_side)
			if _ring_animations_ready:
				var strike_key := "%s_%s" % [attack_kind, attack_side]
				var repetition := int(_ring_attack_counts.get(strike_key, 0))
				var airborne := velocity.y > 0.1 and not is_on_floor()
				var variant := PLAYER_RING_REFERENCE.attack_name(attack_kind, attack_side, repetition, airborne)
				var ring_path := PLAYER_RING_REFERENCE.clip_path(variant)
				if _animation_player.has_animation(ring_path):
					_active_attack_clip = ring_path
					_ring_attack_counts[strike_key] = repetition + 1
			_animation_player.play(_active_attack_clip, ATTACK_ANIMATION_BLEND_SECONDS)
			_animation_player.seek(0.0, true)
		else:
			_animation_player.stop()
	_play_exo_attack_visual()
	if _exo_kick_active:
		# The damage event must match the actual extended foot, not the old
		# 0.12-second contact of the hidden fallback combat rig.
		attack_phase_time = _exo_kick_impact

func _play_exo_attack_visual() -> void:
	if _exo_overlay == null:
		return
	if attack_kind != "kick":
		_exo_overlay.stop_clip()
		return
	# Full-speed source animation: delay damage until its measured kick frame.
	# New inputs wait until the whole clip finishes rather than cutting it off.
	var airborne := not is_on_floor() and velocity.y > 0.1
	var uses_roundhouse := posmod(int(_ring_attack_counts.get("kick_" + attack_side, 1)) - 1, 3) == 1
	var clip := "fly_kick" if airborne else ("roundhouse" if uses_roundhouse else "mma_kick")
	if _exo_overlay.play_strike(clip, attack_side):
		_exo_kick_duration = _exo_overlay.strike_duration(clip)
		_exo_kick_impact = _exo_overlay.impact_time(clip)
		_exo_kick_active = _exo_kick_duration > _exo_kick_impact + EXO_KICK_ACTIVE_SECONDS

func _start_queued_attack() -> bool:
	if _queued_attack_kind.is_empty():
		return false
	var next_kind := _queued_attack_kind
	var next_side := _queued_attack_side
	_queued_attack_kind = ""
	_queued_attack_side = ""
	_finish_attack()
	_start_attack(next_kind, next_side)
	return true

func _finish_attack() -> void:
	var finished := attack_kind
	if is_instance_valid(_grabbed_target):
		_grabbed_target.end_player_grapple(self)
	if is_instance_valid(_engagement_target):
		_previous_engagement_target = _engagement_target
	_grabbed_target = null
	_engagement_target = null
	if _exo_kick_active and _exo_overlay != null:
		_exo_overlay.stop_clip()
	_exo_kick_active = false
	_exo_kick_duration = 0.0
	_exo_kick_impact = 0.0
	attack_phase = "ready"
	attack_kind = ""
	attack_phase_time = 0.0
	_attack_recovery_locked = false
	_active_attack_clip = &""
	if not finished.is_empty():
		attack_finished.emit(finished)

func _update_attack(delta: float) -> void:
	if attack_phase == "ready":
		return
	var elapsed_time := maxf(0.0, delta)
	if attack_phase == "approach":
		if not is_instance_valid(_engagement_target) or _engagement_target.hp <= 0:
			_finish_attack()
			return
		var flat := _engagement_target.global_position - global_position
		flat.y = 0.0
		if flat.length() <= CHAIN_GRAB_DISTANCE:
			_begin_grapple()
			return
		attack_phase_time -= elapsed_time
		if attack_phase_time <= 0.0:
			# A blocked hop must not hit or warp through an obstacle.
			_queued_attack_kind = ""
			_queued_attack_side = ""
			_finish_attack()
		return
	if elapsed_time + MELEE_TIMER_EPSILON < attack_phase_time:
		attack_phase_time -= elapsed_time
		return
	var overflow_time := maxf(0.0, elapsed_time - attack_phase_time)
	attack_phase_time = 0.0
	match attack_phase:
		"grapple":
			_begin_strike()
		"windup":
			attack_phase = "active"
			_resolve_attack()
			attack_phase_time = EXO_KICK_ACTIVE_SECONDS if _exo_kick_active else float(ATTACKS[attack_kind].active)
		"active":
			# Full-length Exo kicks cannot chain at the 0.2s punch boundary.
			if _exo_kick_active:
				attack_phase = "recovery"
				attack_phase_time = maxf(0.01, _exo_kick_duration - _exo_kick_impact - EXO_KICK_ACTIVE_SECONDS)
				_attack_recovery_locked = false
			elif not _start_queued_attack():
				attack_phase = "recovery"
				attack_phase_time = float(ATTACKS[attack_kind].recovery)
				_attack_recovery_locked = false
		"recovery":
			if not _start_queued_attack():
				_finish_attack()
				return
		_:
			_finish_attack()
			return
	if attack_phase != "ready":
		attack_phase_time = maxf(0.0, attack_phase_time - overflow_time)

func _resolve_attack() -> void:
	var profile: Dictionary = ATTACKS[attack_kind]
	if _fight_animations_ready and _animation_player.current_animation == _active_attack_clip:
		_animation_player.seek(float(profile.windup), true)
	var target: FoundationEnemy = null
	if is_instance_valid(_engagement_target) and _engagement_target.hp > 0:
		var flat := _engagement_target.global_position - global_position
		flat.y = 0.0
		if flat.length() <= float(profile.range) + 0.28:
			# A moving enemy must still be physically reachable at the impact frame.
			var sight := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, _engagement_target.global_position + Vector3.UP, 1)
			sight.exclude = [get_rid(), _engagement_target.get_rid()]
			if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
				target = _engagement_target
	if target == null:
		target = _find_target(float(profile.range), float(profile.cone))
	if target == null:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	var dealt: int = target.receive_hit(int(profile.damage), direction.normalized())
	if dealt > 0:
		rage.record_effective_hit(float(dealt))
		attack_connected.emit(attack_kind, target)
		_spawn_attack_impact(target.global_position + Vector3(0.0, 1.0, 0.0), attack_kind)

func try_jump() -> bool:
	if _jump_state != JumpState.READY or not is_on_floor() or rage.current_soul_condemned or grab_state == GrabState.GRABBED:
		return false
	if grab_state == GrabState.WINDUP:
		cancel_limb_grab("jump_evaded")
	if attack_phase in ["approach", "grapple"]:
		_finish_attack()
	_jump_state = JumpState.ORDINARY
	velocity.y = 8.2
	jump_impact_armed = true
	_was_airborne = true
	# The original Jump animation stays active: the imported Mixamo leap
	# leans horizontally at midpoint without its source root translation.
	return true

func _resolve_jump_impact() -> void:
	var target := _find_target(2.25, 0.1)
	if target == null:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	var dealt: int = target.receive_hit(22, direction.normalized(), true)
	if dealt > 0:
		rage.record_effective_hit(float(dealt))
		jump_impact.emit(target)

func try_parabolic_jump() -> bool:
	if _jump_state != JumpState.READY or not is_on_floor() or _parabolic_jump_active or rage.current_soul_condemned or grab_state == GrabState.GRABBED:
		return false
	if grab_state == GrabState.WINDUP:
		cancel_limb_grab("jump_evaded")
	if attack_phase in ["approach", "grapple"]:
		_finish_attack()
	var direction := -global_transform.basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return false
	direction = direction.normalized()
	var arc_height := maxf(0.8, forward_jump_arc_height_m)
	var duration := sqrt(8.0 * arc_height / GRAVITY)
	if duration <= 0.0:
		return false
	var horizontal_speed := maxf(0.0, forward_jump_distance_m) / duration
	velocity.x = direction.x * horizontal_speed
	velocity.z = direction.z * horizontal_speed
	velocity.y = GRAVITY * duration * 0.5
	_parabolic_jump_direction = direction
	_jump_state = JumpState.FORWARD
	_parabolic_jump_active = true
	parabolic_jump_started.emit(global_position, direction)
	jump_impact_armed = false
	_was_airborne = true
	return true

# Enemy-to-player limb hold; independent from the player's melee grapple.
# FoundationPlayer is the sole grab authority. QTE stores only per-session progress.
func get_grab_state() -> int:
	return grab_state

func get_active_grab_enemy() -> FoundationEnemy:
	if grab_state == GrabState.WINDUP:
		return _limb_grab_candidate if is_instance_valid(_limb_grab_candidate) else null
	if grab_state == GrabState.GRABBED:
		return _limb_grab_owner if is_instance_valid(_limb_grab_owner) else null
	return null

func get_grab_limb() -> String:
	return _limb_grab_limb if grab_state in [GrabState.WINDUP, GrabState.GRABBED] else ""

func get_active_grab_session_id() -> int:
	return _grab_session_id if grab_state == GrabState.GRABBED else 0

func get_grab_qte_progress() -> int:
	return _grab_qte.get_press_count() if grab_state == GrabState.GRABBED else 0

func get_grab_qte_remaining_seconds() -> float:
	return _grab_qte.get_remaining_seconds() if grab_state == GrabState.GRABBED else 0.0

func get_grab_qte_required_presses() -> int:
	return _grab_qte.get_required_presses() if grab_state == GrabState.GRABBED else 0

func _set_grab_state(next_state: GrabState) -> void:
	if grab_state == next_state:
		return
	grab_state = next_state
	grab_state_changed.emit(grab_state, get_active_grab_enemy(), get_grab_limb())

func _grab_player_eligible() -> bool:
	return health > 0 and not rage.current_soul_condemned and _jump_state == JumpState.READY and not _parabolic_jump_active and is_on_floor() and not get_tree().paused

func _grab_enemy_eligible(enemy: FoundationEnemy) -> bool:
	# Read-only admission: the spawn manager owns all attacker-slot locks.
	return is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.hp > 0 and not enemy.is_boss and is_instance_valid(enemy.attack_director) and enemy.attack_director.has_method("can_maintain_limb_grab") and bool(enemy.attack_director.call("can_maintain_limb_grab", enemy))

func try_reserve_limb_grab(enemy: FoundationEnemy, limb: String) -> bool:
	if grab_state != GrabState.READY or _limb_grab_cooldown > 0.0 or not _grab_player_eligible() or not _grab_enemy_eligible(enemy):
		return false
	if limb not in ["LEFT ARM", "RIGHT ARM"] or attack_phase in ["approach", "grapple"]:
		return false
	_limb_grab_candidate = enemy
	_limb_grab_limb = limb
	_set_grab_state(GrabState.WINDUP)
	limb_grab_windup.emit(limb)
	grab_windup_started.emit(enemy, limb)
	return true

func is_limb_grab_candidate(enemy: FoundationEnemy) -> bool:
	return grab_state == GrabState.WINDUP and _limb_grab_candidate == enemy

func cancel_pending_limb_grab(enemy: FoundationEnemy, reason: String = "windup_cancelled") -> void:
	if grab_state == GrabState.WINDUP and _limb_grab_candidate == enemy:
		_finish_limb_grab(reason)

func begin_limb_grab(enemy: FoundationEnemy, limb: String) -> bool:
	if grab_state != GrabState.WINDUP or _limb_grab_candidate != enemy:
		return false
	if limb != _limb_grab_limb or not _grab_player_eligible() or not _grab_enemy_eligible(enemy):
		_finish_limb_grab("contact_ineligible")
		return false
	_limb_grab_candidate = null
	_queued_attack_kind = ""
	_queued_attack_side = ""
	_desktop_attack_repeat_timers.clear()
	_finish_attack()
	_limb_grab_owner = enemy
	_limb_grab_time = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	_play_character_action("Hit", float(CHARACTER_MOTION.ACTIONS.get("Hit", 0.34)))
	if _character_motion_ready and _animation_player != null and _animation_player.current_animation == CHARACTER_MOTION.clip_path("Hit"):
		_animation_player.seek(0.12, true)
		_animation_player.pause()
	_set_grab_state(GrabState.GRABBED)
	# Start only after GRABBED, never during WINDUP. No independent QTE timer.
	if grab_state != GrabState.GRABBED or _limb_grab_owner != enemy:
		return false
	_grab_session_serial += 1
	_grab_session_id = _grab_session_serial
	if not _grab_qte.begin(_grab_session_id, enemy, limb, grab_qte_duration_seconds, grab_qte_required_presses):
		_finish_limb_grab("qte_setup_failed")
		return false
	_limb_grab_time = _grab_qte.get_remaining_seconds()
	var started_session_id := _grab_session_id
	limb_grab_started.emit(limb)
	# Signals are synchronous: a listener may kill the attacker or cancel the
	# grab. Do not publish a ghost QTE for a session already cleaned up.
	if grab_state != GrabState.GRABBED or not _grab_qte.matches(started_session_id, enemy, limb):
		return false
	grab_established.emit(enemy, limb)
	if grab_state != GrabState.GRABBED or not _grab_qte.matches(started_session_id, enemy, limb):
		return false
	grab_qte_started.emit(started_session_id, enemy, limb, _grab_qte.get_required_presses(), _limb_grab_time)
	if grab_state != GrabState.GRABBED or not _grab_qte.matches(started_session_id, enemy, limb):
		return false
	grab_qte_progress.emit(started_session_id, 0, _grab_qte.get_required_presses(), _limb_grab_time)
	return grab_state == GrabState.GRABBED and _grab_qte.matches(started_session_id, enemy, limb)

# The caller must send a fresh input edge. Optional session token rejects stale events.
# True means the press was accepted, not necessarily that the player has escaped.
func try_escape_limb_grab(session_id: int = -1) -> bool:
	if grab_state != GrabState.GRABBED or get_tree().paused:
		return false
	if session_id >= 0 and session_id != _grab_session_id:
		return false
	if not _grab_qte.accept_press(_grab_session_id, _limb_grab_owner, _limb_grab_limb):
		return false
	grab_qte_progress.emit(_grab_session_id, _grab_qte.get_press_count(), _grab_qte.get_required_presses(), _grab_qte.get_remaining_seconds())
	if _grab_qte.is_complete():
		_finish_limb_grab("escaped")
	return true

func end_limb_grab(enemy: FoundationEnemy, reason: String = "enemy_released") -> void:
	if grab_state == GrabState.GRABBED and _limb_grab_owner == enemy:
		_finish_limb_grab(reason)

func _finish_limb_grab(reason: String) -> void:
	if grab_state not in [GrabState.WINDUP, GrabState.GRABBED]:
		return
	var held := grab_state == GrabState.GRABBED
	var zombie: FoundationEnemy = _limb_grab_owner if held else _limb_grab_candidate
	if not is_instance_valid(zombie):
		zombie = null
	var limb := _limb_grab_limb
	var finished_session_id := _grab_session_id
	# Invalidate before enemy release or any terminal signals can re-enter us.
	_grab_session_id = 0
	_grab_qte.cancel()
	if held and reason == "escaped":
		_set_grab_state(GrabState.ESCAPED)
	elif held and reason == "timeout":
		_set_grab_state(GrabState.FAILED)
	else:
		_set_grab_state(GrabState.RECOVERY)
	# Clear before calling enemy release; it calls back into this player.
	_limb_grab_candidate = null
	_limb_grab_owner = null
	_limb_grab_limb = ""
	_limb_grab_time = 0.0
	if held:
		_limb_grab_cooldown = maxf(_limb_grab_cooldown, limb_grab_regrab_seconds)
		_character_action_time = 0.0
	if is_instance_valid(zombie):
		if held:
			zombie.release_limb_grab(self, reason)
		else:
			zombie.cancel_limb_grab_windup(self, reason)
	if held and reason == "escaped":
		grab_escaped.emit(zombie, limb)
	elif held and reason == "timeout":
		grab_failed.emit(zombie, limb)
	else:
		grab_interrupted.emit(reason, zombie, limb)
	if grab_state != GrabState.RECOVERY:
		_set_grab_state(GrabState.RECOVERY)
	if held:
		if health > 0 and not rage.current_soul_condemned:
			if reason == "escaped":
				var action := "Turn_Right" if limb == "LEFT ARM" else "Turn_Left"
				_play_character_action(action, float(CHARACTER_MOTION.ACTIONS.get(action, 0.28)))
			else:
				_set_locomotion_animation("Idle")
		if _animation_player != null and not _animation_player.is_playing() and health > 0:
			_set_locomotion_animation("Idle")
		limb_grab_ended.emit()
	_set_grab_state(GrabState.READY)
	grab_fully_ended.emit(reason)
	if held and finished_session_id > 0:
		grab_qte_finished.emit(finished_session_id, reason)

func cancel_limb_grab(reason: String = "cancelled") -> void:
	_finish_limb_grab(reason)

func _update_limb_grab(delta: float) -> void:
	if get_tree().paused:
		return
	_limb_grab_cooldown = maxf(0.0, _limb_grab_cooldown - delta)
	if grab_state == GrabState.WINDUP:
		if not _grab_enemy_eligible(_limb_grab_candidate) or not _grab_player_eligible():
			_finish_limb_grab("windup_ineligible")
		return
	if grab_state != GrabState.GRABBED:
		return
	if not is_instance_valid(_limb_grab_owner) or _limb_grab_owner.is_queued_for_deletion():
		_finish_limb_grab("enemy_invalid")
	elif _limb_grab_owner.hp <= 0:
		_finish_limb_grab("enemy_died")
	elif health <= 0 or rage.current_soul_condemned:
		_finish_limb_grab("player_dead")
	elif _jump_state != JumpState.READY or _parabolic_jump_active or not _grab_enemy_eligible(_limb_grab_owner):
		_finish_limb_grab("reservation_lost")
	elif not _grab_qte.matches(_grab_session_id, _limb_grab_owner, _limb_grab_limb):
		_finish_limb_grab("qte_session_lost")
	else:
		var expired := _grab_qte.advance(_grab_session_id, delta)
		_limb_grab_time = _grab_qte.get_remaining_seconds()
		if expired:
			_finish_limb_grab("timeout")
		else:
			grab_qte_progress.emit(_grab_session_id, _grab_qte.get_press_count(), _grab_qte.get_required_presses(), _limb_grab_time)

func _exit_tree() -> void:
	cancel_limb_grab("scene_exit")

func interrupt_by_zombie(slow_seconds: float = 0.7, recovery_penalty: float = 0.45) -> void:
	if _limb_grab_owner != null:
		return
	if attack_phase in ["approach", "grapple"]:
		_finish_attack()
	elif is_instance_valid(_grabbed_target):
		_grabbed_target.end_player_grapple(self)
		_grabbed_target = null
	movement_slow_factor = minf(movement_slow_factor, 0.58)
	movement_slow_time = maxf(movement_slow_time, slow_seconds)
	if attack_phase != "ready":
		attack_phase = "recovery"
		attack_phase_time = maxf(attack_phase_time, recovery_penalty)
		_attack_recovery_locked = true
	_play_character_action("Hit", float(CHARACTER_MOTION.ACTIONS.get("Hit", 0.34)))
	interrupted.emit(slow_seconds)

func take_boss_damage(amount: int) -> void:
	if rage.current_soul_condemned or amount <= 0:
		return
	var was_alive := health > 0
	health = maxi(0, health - amount)
	health_changed.emit(health, MAX_HEALTH)
	if was_alive:
		cancel_limb_grab("player_dead" if health == 0 else "player_damaged")
		if health == 0:
			_play_character_action("Defeat", float(CHARACTER_MOTION.ACTIONS.get("Defeat", 1.25)))
		else:
			_play_character_action("Hit", float(CHARACTER_MOTION.ACTIONS.get("Hit", 0.34)))

func cycle_spell() -> bool:
	if grab_state == GrabState.GRABBED:
		return false
	var available: Array[String] = rage.unlocked_spells
	if available.is_empty():
		return false
	var index := available.find(current_spell)
	current_spell = available[(index + 1) % available.size()]
	magic_changed.emit(magic_energy, MAX_MAGIC, current_spell)
	return true

func cast_spell() -> bool:
	if rage.current_soul_condemned or _limb_grab_owner != null or rage.unlocked_spells.is_empty():
		return false
	if not rage.unlocked_spells.has(current_spell):
		current_spell = rage.unlocked_spells[0]
	return _cast_spell(current_spell)

func cast_blast() -> bool:
	if rage.current_soul_condemned or _limb_grab_owner != null or not rage.unlocked_spells.has("fire"):
		return false
	return _cast_spell("fire")

func _cast_spell(school: String) -> bool:
	if rage.current_soul_condemned or _limb_grab_owner != null or not rage.unlocked_spells.has(school):
		return false
	var spec: Dictionary = SPELLS[school]
	if magic_energy < float(spec.cost):
		return false
	var target: FoundationEnemy = null
	if school != "light":
		target = _find_target(float(spec.range), 0.25)
		if target == null:
			return false
	magic_energy -= float(spec.cost)
	match school:
		"light":
			health = mini(MAX_HEALTH, health + 30)
			health_changed.emit(health, MAX_HEALTH)

		"judgment":
			_apply_spell_damage(target, 35)
			if target.hp > 0:
				target.apply_stun(0.7)
		"fire":
			_apply_spell_damage(target, 20)
			if target.hp > 0:
				_burns.append({"target": weakref(target), "ticks": 4, "time": 1.0})
		"shadow":
			var damage := _apply_spell_damage(target, 25)
			if target.hp > 0:
				target.apply_slow(0.4, 5.0)
			health = mini(MAX_HEALTH, health + roundi(float(damage) * 0.3))
			health_changed.emit(health, MAX_HEALTH)
	if target != null:
		_spawn_spell_burst(target.global_position + Vector3(0.0, 1.0, 0.0), school)
	var action_name := "Magic_" + school.capitalize()
	_play_character_action(action_name, float(CHARACTER_MOTION.ACTIONS.get(action_name, 0.62)))
	magic_changed.emit(magic_energy, MAX_MAGIC, current_spell)
	return true

func cast_spell_slot(slot: int) -> bool:
	if grab_state == GrabState.GRABBED:
		return false
	if slot < 0 or slot >= rage.unlocked_spells.size() or rage.current_soul_condemned:
		return false
	current_spell = rage.unlocked_spells[slot]
	return cast_spell()

func _apply_spell_damage(target: FoundationEnemy, amount: int) -> int:
	var direction := target.global_position - global_position
	direction.y = 0.0
	var dealt: int = target.receive_hit(amount, direction.normalized())
	if dealt > 0:
		rage.record_effective_hit(float(dealt))
	return dealt

func _update_burns(delta: float) -> void:
	for index in range(_burns.size() - 1, -1, -1):
		var burn: Dictionary = _burns[index]
		burn.time = float(burn.time) - delta
		if float(burn.time) > 0.0:
			continue
		var ref: WeakRef = burn.target
		var target := ref.get_ref() as FoundationEnemy
		if target != null and is_instance_valid(target) and target.hp > 0:
			target.receive_hit(4, Vector3.ZERO)
		burn.ticks = int(burn.ticks) - 1
		if int(burn.ticks) <= 0 or target == null or not is_instance_valid(target) or target.hp <= 0:
			_burns.remove_at(index)
		else:
			burn.time = 1.0

func _find_target(max_range: float, min_facing_dot: float) -> FoundationEnemy:
	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var chosen: FoundationEnemy = null
	var best_distance := max_range
	for candidate_node in get_tree().get_nodes_in_group("enemies"):
		var candidate := candidate_node as FoundationEnemy
		if candidate == null or not is_instance_valid(candidate) or candidate.hp <= 0:
			continue
		var offset: Vector3 = candidate.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > best_distance:
			continue
		if distance > 0.1 and facing.dot(offset.normalized()) < min_facing_dot:
			continue
		best_distance = distance
		chosen = candidate
	return chosen

func _spawn_attack_sweep(kind: String, side: String) -> void:
	if is_instance_valid(combat_fx_pool) and combat_fx_pool.has_method("play_attack_sweep"):
		combat_fx_pool.call("play_attack_sweep", kind, side, get_viewport().get_visible_rect().size)
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	var sweep_layer := CanvasLayer.new()
	sweep_layer.layer = 12
	scene_root.add_child(sweep_layer)

	var sweep := Node2D.new()
	sweep_layer.add_child(sweep)
	var viewport_size := get_viewport().get_visible_rect().size
	sweep.position = viewport_size * Vector2(0.50, 0.49)
	sweep.z_index = 100

	var radius := 168.0 if kind == "kick" else 122.0
	var points := PackedVector2Array()
	for point_index in range(25):
		var progress := float(point_index) / 24.0
		var angle := lerpf(-1.22, 1.22, progress)
		points.append(Vector2(sin(angle) * radius, -cos(angle) * radius * 0.76))

	var hot_color := Color(0.22, 0.76, 1.0, 0.96) if kind == "kick" else Color(1.0, 0.26, 0.045, 0.96)
	var glow := Line2D.new()
	glow.points = points
	glow.width = 22.0 if kind == "kick" else 17.0
	glow.default_color = hot_color
	glow.antialiased = true
	glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	sweep.add_child(glow)

	var core := Line2D.new()
	core.points = points
	core.width = 5.0
	core.default_color = Color(0.83, 0.96, 1.0, 1.0) if kind == "kick" else Color(1.0, 0.94, 0.72, 1.0)
	core.antialiased = true
	core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	core.end_cap_mode = Line2D.LINE_CAP_ROUND
	sweep.add_child(core)

	var side_sign := 1.0 if side == "right" else -1.0
	var rotation_start := -0.28 * side_sign
	sweep.rotation = rotation_start
	sweep.scale = Vector2.ONE * 0.62
	sweep.modulate = Color(1.0, 1.0, 1.0, 0.96)
	var tween := create_tween()
	tween.tween_property(sweep, "scale", Vector2.ONE * 1.18, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(sweep, "rotation", rotation_start + 0.78 * side_sign, 0.22)
	tween.parallel().tween_property(sweep, "modulate:a", 0.0, 0.22)
	tween.tween_callback(sweep_layer.queue_free)

func _spawn_attack_impact(at: Vector3, kind: String) -> void:
	if is_instance_valid(combat_fx_pool) and combat_fx_pool.has_method("play_attack_impact"):
		combat_fx_pool.call("play_attack_impact", at, kind)
		return
	var impact := Node3D.new()
	impact.name = "CombatImpact"
	impact.add_to_group("attack_impact_fx")
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(impact)
	impact.global_position = at

	var color := Color(1.0, 0.74, 0.30) if kind == "punch" else Color(1.0, 0.38, 0.12)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.20
	sphere.height = 0.40
	flash.mesh = sphere
	flash.material_override = material
	impact.add_child(flash)
	for spark_index in range(8):
		var spark := MeshInstance3D.new()
		var shard := BoxMesh.new()
		shard.size = Vector3(0.055, 0.055, 0.30)
		spark.mesh = shard
		spark.material_override = material
		var angle := TAU * float(spark_index) / 8.0
		spark.position = Vector3(cos(angle) * 0.18, sin(angle) * 0.18, 0.0)
		spark.rotation.y = angle
		impact.add_child(spark)

	impact.scale = Vector3.ONE * 0.72
	var tween := create_tween()
	tween.tween_property(impact, "scale", Vector3.ONE * 2.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.18)
	tween.tween_callback(impact.queue_free)

func _spawn_spell_burst(at: Vector3, school: String = "") -> void:
	var effect_school: String = school if not school.is_empty() else current_spell
	var spell_color: Color = SPELLS[effect_school].color
	if is_instance_valid(combat_fx_pool) and combat_fx_pool.has_method("play_spell_burst"):
		combat_fx_pool.call("play_spell_burst", at, spell_color)
		return
	var root := MeshInstance3D.new()
	root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	root.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = spell_color
	material.emission_enabled = true
	material.emission = spell_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	root.material_override = material
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root
	scene_root.add_child(root)
	root.global_position = at
	var tween := create_tween()
	tween.tween_property(root, "scale", Vector3.ONE * 2.8, 0.22)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.tween_callback(root.queue_free)

func _update_attack_pose() -> void:
	if _skeleton == null or attack_phase == "ready" or _fight_animations_ready:
		return
	if _animation_player != null:
		_animation_player.stop()
	_skeleton.reset_bone_poses()
	var windup_blend := 1.0 if attack_phase == "active" else 0.55
	var limb := "Left" if attack_side == "left" else "Right"
	var mirror := -1.0 if attack_side == "left" else 1.0
	if attack_kind == "punch":
		_set_bone_rotation("Chest", Vector3(-0.08, -0.18 * windup_blend * mirror, 0.03 * mirror))
		_set_bone_rotation(limb + "UpperArm", Vector3(1.24 * windup_blend, 0.0, -0.15 * mirror))
		_set_bone_rotation(limb + "Forearm", Vector3(0.30 * windup_blend, 0.0, 0.0))
	else:
		_set_bone_rotation("Chest", Vector3(-0.12, 0.04 * mirror, 0.0))
		_set_bone_rotation(limb + "Thigh", Vector3(-1.28 * windup_blend, 0.0, 0.0))
		_set_bone_rotation(limb + "Shin", Vector3(0.42 * windup_blend, 0.0, 0.0))

func _set_bone_rotation(bone_name: String, euler: Vector3) -> void:
	var bone_index := _skeleton.find_bone(bone_name)
	if bone_index >= 0:
		_skeleton.set_bone_pose_rotation(bone_index, Quaternion.from_euler(euler))

func _set_locomotion_animation(animation_name: String) -> void:
	if _animation_player == null:
		return
	var selected_animation := StringName(animation_name)
	if not _animation_player.has_animation(selected_animation):
		return
	if _animation_player.current_animation != selected_animation or not _animation_player.is_playing():
		_animation_player.play(selected_animation, LOCOMOTION_ANIMATION_BLEND_SECONDS)

func _update_locomotion_animation() -> void:
	if _animation_player == null or attack_phase != "ready" or _character_action_time > 0.0 or _limb_grab_owner != null:
		return
	if not is_on_floor():
		_set_locomotion_animation("Jump")
	elif Vector2(velocity.x, velocity.z).length() > 0.4:
		_set_locomotion_animation("Walk")
	else:
		_set_locomotion_animation("Idle")

func _play_character_action(action_name: String, duration: float) -> void:
	# Movement, landing, and casting must not silently replace a melee clip
	# while its damage timer continues. Explicit hit/defeat reactions may win.
	if attack_phase != "ready" and action_name not in ["Hit", "Defeat"]:
		return
	if not _character_motion_ready or _animation_player == null:
		return
	var clip := CHARACTER_MOTION.clip_path(action_name)
	if _ring_animations_ready and action_name in ["Turn_Left", "Turn_Right"]:
		var pivot := "pivot_left" if action_name == "Turn_Left" else "pivot_right"
		var ring_clip := PLAYER_RING_REFERENCE.clip_path(pivot)
		if _animation_player.has_animation(ring_clip):
			clip = ring_clip
	if not _animation_player.has_animation(clip):
		return
	_character_action_time = maxf(0.0, duration)
	_animation_player.play(clip, ATTACK_ANIMATION_BLEND_SECONDS)
	if _exo_overlay != null and action_name in ["Landing", "Hit", "Defeat"]:
		_exo_overlay.stop_clip()

func _on_selection_resolved(_milestone: int, aura_id: String) -> void:
	current_spell = aura_id

func _on_condemned(_threshold: float, _maximum: float) -> void:
	cancel_limb_grab("player_condemned")
	call_deferred("_reset_at_safe_base")

func _reset_at_safe_base() -> void:
	cancel_limb_grab("respawn")
	_jump_state = JumpState.READY
	_parabolic_jump_active = false
	_parabolic_jump_direction = Vector3.ZERO
	jump_impact_armed = false
	_was_airborne = false
	_limb_grab_cooldown = limb_grab_regrab_seconds
	if _exo_overlay != null:
		_exo_overlay.stop_clip()
	_finish_attack()
	_previous_engagement_target = null
	global_position = safe_base_position
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	magic_energy = MAX_MAGIC
	current_spell = ""
	attack_phase = "ready"
	attack_kind = ""
	attack_phase_time = 0.0
	_queued_attack_kind = ""
	_queued_attack_side = ""
	_attack_recovery_locked = false
	_burns.clear()
	rage.reset_soul()
	health_changed.emit(health, MAX_HEALTH)
	respawned.emit()
