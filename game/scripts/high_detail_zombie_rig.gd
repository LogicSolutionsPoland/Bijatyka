extends RefCounted
class_name HighDetailZombieRig

const MODEL_SCENE: PackedScene = preload("res://assets/zombies/high_detail/Retribution_Zombie_Reconstructed.glb")
const PART_TO_BONE := {
	"Torso": "Chest",
	"Hip": "Hips",
	"Neck": "Neck",
	"Head": "Head",
	"LeftUpperArm": "UpperArm_L",
	"LeftForearm": "Forearm_L",
	"LeftHand": "Hand_L",
	"LeftThigh": "Thigh_L",
	"LeftShin": "Shin_L",
	"LeftBoot": "Foot_L",
	"RightUpperArm": "UpperArm_R",
	"RightForearm": "Forearm_R",
	"RightHand": "Hand_R",
	"RightThigh": "Thigh_R",
	"RightShin": "Shin_R",
	"RightBoot": "Foot_R",
}

static var _packed_scene: PackedScene

static func attach(parent: Node3D, skeleton: Skeleton3D) -> Dictionary:
	if parent == null or skeleton == null:
		return {"ok": false, "error": "A parent and target Skeleton3D are required."}
	if _packed_scene == null:
		_packed_scene = MODEL_SCENE
	if _packed_scene == null:
		return {"ok": false, "error": "The high-detail zombie GLB did not import as a PackedScene."}

	var source_root := _packed_scene.instantiate() as Node3D
	if source_root == null:
		return {"ok": false, "error": "The high-detail zombie scene has no Node3D root."}
	parent.add_child(source_root)

	var source_meshes := source_root.find_children("*", "MeshInstance3D", true, false)
	var assignments: Array[Dictionary] = []
	for node in source_meshes:
		var mesh_node := node as MeshInstance3D
		var part_name := _part_name(mesh_node.name)
		var bone_name: String = PART_TO_BONE.get(part_name, "")
		if bone_name.is_empty():
			source_root.queue_free()
			return {"ok": false, "error": "No target bone mapping exists for mesh '%s'." % mesh_node.name}
		var bone_index := skeleton.find_bone(bone_name)
		if bone_index < 0:
			source_root.queue_free()
			return {"ok": false, "error": "The animation rig has no '%s' bone for mesh '%s'." % [bone_name, mesh_node.name]}
		var source_in_skeleton := skeleton.global_transform.affine_inverse() * mesh_node.global_transform
		assignments.append({
			"mesh": mesh_node,
			"bone_name": bone_name,
			"bone_index": bone_index,
			"source_transform": source_in_skeleton,
		})
	if assignments.is_empty():
		source_root.queue_free()
		return {"ok": false, "error": "The high-detail zombie scene contains no MeshInstance3D nodes."}

	var attachments_by_bone: Dictionary = {}
	var attachments: Array[BoneAttachment3D] = []
	var detail_meshes: Array[MeshInstance3D] = []
	for assignment in assignments:
		var bone_name: String = assignment.bone_name
		var attachment := attachments_by_bone.get(bone_name) as BoneAttachment3D
		if attachment == null:
			attachment = BoneAttachment3D.new()
			attachment.name = "HighDetail_%s" % bone_name
			attachment.bone_name = bone_name
			skeleton.add_child(attachment)
			attachments_by_bone[bone_name] = attachment
			attachments.append(attachment)
		var bone_index: int = assignment.bone_index
		var bone_rest := skeleton.get_bone_global_rest(bone_index)
		var mesh_node := assignment.mesh as MeshInstance3D
		var mesh_transform: Transform3D = bone_rest.affine_inverse() * assignment.source_transform
		mesh_node.reparent(attachment, false)
		mesh_node.transform = mesh_transform
		mesh_node.visible = false
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		detail_meshes.append(mesh_node)

	source_root.queue_free()
	return {
		"ok": true,
		"meshes": detail_meshes,
		"attachments": attachments,
	}

static func _part_name(mesh_name: String) -> String:
	if mesh_name.ends_with("_front"):
		return mesh_name.substr(0, mesh_name.length() - 6)
	if mesh_name.ends_with("_back"):
		return mesh_name.substr(0, mesh_name.length() - 5)
	return ""
