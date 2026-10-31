extends Node
class_name FingerGunFireEvent

## Non-combat animation event. Future spells may connect to this signal.
signal fired(muzzle_transform: Transform3D)

var muzzle_path: NodePath

func emit_fire() -> void:
	var muzzle := get_node_or_null(muzzle_path) as Marker3D
	if muzzle != null:
		fired.emit(muzzle.global_transform)
