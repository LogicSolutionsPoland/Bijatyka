extends RefCounted

# Imported GLBs and procedural meshes share one no-shadow policy.
static func disable_in_tree(root: Node) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Light3D:
			(node as Light3D).shadow_enabled = false
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for child in node.get_children():
			pending.append(child)
