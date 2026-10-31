extends Node
class_name FingerGunFireEvent

## Signal-only trigger. Resolve the current animated bone pose at the firing
## instant; BoneAttachment3D's cached node transform can lag one animation tick.
signal fired(muzzle_transform: Transform3D)

var muzzle_path: NodePath

func emit_fire() -> void:
	var muzzle := get_node_or_null(muzzle_path) as Marker3D
	if muzzle == null:
		return
	var attachment := muzzle.get_parent() as BoneAttachment3D
	var skeleton := attachment.get_parent() as Skeleton3D if attachment != null else null
	if skeleton == null:
		return
	var tip := skeleton.find_bone(attachment.bone_name)
	if tip < 0:
		return
	skeleton.force_update_all_bone_transforms()
	var bone_world := skeleton.global_transform * skeleton.get_bone_global_pose(tip)
	fired.emit(bone_world * muzzle.transform)
