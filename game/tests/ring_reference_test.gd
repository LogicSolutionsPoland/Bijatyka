extends SceneTree

const Player := preload("res://scripts/player_controller.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Ring := preload("res://scripts/ring_reference_combat.gd")
var failures: Array[String] = []
var checks := 0
var max_joint_step := 0.0
var max_foot_drift := 0.0

func _initialize() -> void: call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _point(skeleton: Skeleton3D, name: String) -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin

func _run() -> void:
	for rig in ["male", "female"]:
		var actor: Node3D
		if rig == "male": actor = Player.new()
		else:
			actor = Enemy.new()
			actor.configure("boss")
		root.add_child(actor)
		actor.set_physics_process(false)
		if rig == "female": actor._set_full_animation_selected(true)
		var animator := actor._animation_player as AnimationPlayer
		var skeleton := actor._skeleton as Skeleton3D
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var original := animator.get_animation(&"Punch_Jab")
		var original_length := original.length
		var original_contact := original.rotation_track_interpolate(1, 0.2)
		_check(animator.has_animation_library(Ring.LIBRARY_NAME), rig + " reference library installed on actual actor")
		var library := animator.get_animation_library(Ring.LIBRARY_NAME)
		_check(library.get_animation_list().size() == 16, rig + " has all separate reference clips")
		for name in library.get_animation_list():
			var animation := library.get_animation(name)
			_check(animation.get_track_count() == 66, "%s %s complete 65-bone pose and pelvis position" % [rig, name])
			for track in range(animation.get_track_count()):
				var bone_name := animation.track_get_path(track).get_subname(0)
				_check(skeleton.find_bone(bone_name) >= 0, "%s %s binds %s" % [rig, name, bone_name])
				for key in range(animation.track_get_key_count(track)):
					var value: Variant = animation.track_get_key_value(track, key)
					_check(value.is_finite(), "%s %s finite key" % [rig, name])
					if value is Quaternion:
						_check(absf(value.length() - 1.0) < 0.0001, "%s %s normalized rotation" % [rig, name])
						if key > 0:
							var previous: Quaternion = animation.track_get_key_value(track, key - 1)
							if previous.angle_to(value) > max_joint_step:
								max_joint_step = previous.angle_to(value)
			animator.play(StringName("ring_reference/" + name), 0.0)
			animator.seek(0.0, true)
			skeleton.force_update_all_bone_transforms()
			var left := _point(skeleton, "foot_l")
			var right := _point(skeleton, "foot_r")
			for frame in range(1, ceili(animation.length * 120.0) + 1):
				animator.seek(minf(frame / 120.0, animation.length), true)
				skeleton.force_update_all_bone_transforms()
				if name in [&"lead_straight", &"rear_hook", &"overhand", &"duck_roll", &"body_slip", &"rope_recoil", &"guard_raise"]:
					max_foot_drift = maxf(max_foot_drift, maxf(left.distance_to(_point(skeleton, "foot_l")), right.distance_to(_point(skeleton, "foot_r"))))
				elif name in [&"right_high_kick", &"left_high_kick", &"downward_stamp", &"downward_punch"]:
					var support := "foot_r" if name == &"left_high_kick" else "foot_l"
					var start := right if support == "foot_r" else left
					max_foot_drift = maxf(max_foot_drift, start.distance_to(_point(skeleton, support)))
		_check(is_equal_approx(original.length, original_length) and original_contact.is_equal_approx(original.rotation_track_interpolate(1, 0.2)), rig + " imported UAL source retained")
		for kind in ["punch", "kick"]:
			for side in ["left", "right"]:
				var profile: Dictionary = Player.ATTACKS[kind] if rig == "male" else actor._fight_attack_profiles()[kind]
				var clip := Ring.build_attack(animator, kind, side, profile)
				_check(clip != null and clip == Ring.build_attack(animator, kind, side, profile), rig + " identical attacks share cached baked resource")
				_check(is_equal_approx(clip.get_marker_time(&"contact"), profile.windup), rig + " retimed contact")
		actor.free()
	_check(max_foot_drift < 0.012, "120 Hz planted foot drift under 12 mm")
	_check(max_joint_step < 1.15, "no baked joint step exceeds 66 degrees per key interval")
	print("RING_MAX_FOOT_DRIFT_METRES=", max_foot_drift, " MAX_JOINT_STEP_RADIANS=", max_joint_step)
	for failure in failures: push_error(failure)
	print("%s: ring reference resources (%d checks; both actual rigs)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
