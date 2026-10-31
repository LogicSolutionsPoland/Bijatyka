extends Node
class_name FingerGunFireEvent

## Signal-only trigger for future spells. Godot may call method tracks before
## their skeletal animation keys are applied in the current AnimationPlayer tick.
## Defer the muzzle lookup until the updated Exo bone pose is available.
signal fired(muzzle_transform: Transform3D)

var muzzle_path: NodePath

func emit_fire() -> void:
	call_deferred("_emit_from_final_pose")

func _emit_from_final_pose() -> void:
	# A manual/physics AnimationPlayer updates bone attachments after method
	# callbacks. Wait for one frame boundary to read the skinned final pose.
	await get_tree().process_frame
	var muzzle := get_node_or_null(muzzle_path) as Marker3D
	if muzzle == null:
		return
	# BoneAttachment3D follows RightHandIndex3; this is the same transform
	# used by any projectile attached to FingerGunMuzzle in future gameplay.
	fired.emit(muzzle.global_transform)
