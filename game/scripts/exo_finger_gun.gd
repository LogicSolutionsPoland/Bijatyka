extends RefCounted
class_name ExoFingerGun

## Preview-ready Exo-only clip. Never changes input, magic damage or the source punch.
const LIBRARY := &"finger_gun"
const CLIP := &"finger_gun/Finger_Gun_Shoot"
const RESOURCE_PATH := "res://assets/characters/exo_gray/animations/Finger_Gun_Shoot.res"
const INDEX_TIP := "RightHandIndex3"

static func install(model: Node3D, skeleton: Skeleton3D, animator: AnimationPlayer) -> bool:
	if model == null or skeleton == null or animator == null:
		return false
	if skeleton.find_bone(INDEX_TIP) < 0:
		push_warning("Finger gun: Exo Gray has no RightHandIndex3; no fabricated attachment")
		return false
	if not ResourceLoader.exists(RESOURCE_PATH):
		# The first CI job bakes this resource from the actual imported punch.
		return false
	var clip := load(RESOURCE_PATH) as Animation
	if clip == null:
		return false
	var attachment := BoneAttachment3D.new()
	attachment.name = "FingerGunIndexTip"
	skeleton.add_child(attachment)
	attachment.bone_name = INDEX_TIP
	var marker := Marker3D.new()
	marker.name = "FingerGunMuzzle"
	attachment.add_child(marker)
	var tip := skeleton.find_bone(INDEX_TIP)
	var prev := skeleton.get_bone_parent(tip)
	if prev < 0:
		attachment.queue_free()
		return false
	var tip_rest := skeleton.get_bone_global_rest(tip)
	var prev_rest := skeleton.get_bone_global_rest(prev)
	var segment := tip_rest.origin - prev_rest.origin
	if segment.length_squared() < 0.000001:
		attachment.queue_free()
		return false
	var local_out := (tip_rest.basis.inverse() * segment.normalized()).normalized()
	marker.position = local_out * segment.length() * 0.75
	# Muzzle forward is -Z, irrespective of the GLB's arbitrary finger local axis.
	var up := Vector3.UP if absf(local_out.dot(Vector3.UP)) < 0.94 else Vector3.FORWARD
	marker.basis = Basis.looking_at(-local_out, up)
	var relay := Node.new()
	relay.name = "FingerGunFireEvent"
	relay.set_script(preload("res://scripts/finger_gun_fire_event.gd"))
	model.add_child(relay)
	relay.set("muzzle_path", relay.get_path_to(marker))
	var library := AnimationLibrary.new()
	if library.add_animation(&"Finger_Gun_Shoot", clip) != OK:
		relay.queue_free()
		attachment.queue_free()
		return false
	if animator.add_animation_library(LIBRARY, library) != OK:
		relay.queue_free()
		attachment.queue_free()
		return false
	return animator.has_animation(CLIP)
