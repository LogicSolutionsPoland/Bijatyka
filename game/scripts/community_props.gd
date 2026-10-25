extends Node3D
## Optional, collision-free visual props from locally installed user-supplied GLBs.
## Off by default; never changes zombie spawning, navigation, damage or controls.

const DECORATIONS := [
	{"scene": "res://assets/environment/community/rocks/RocksPack.glb", "part": "rock_small_1", "pos": Vector3(-14.0, 0.0, -19.0), "size": 0.65},
	{"scene": "res://assets/environment/community/rocks/RocksPack.glb", "part": "rock_medium_2", "pos": Vector3(16.0, 0.0, -24.0), "size": 0.5},
	{"scene": "res://assets/environment/community/rocks/RocksPack.glb", "part": "rock_block_1", "pos": Vector3(-19.0, 0.0, 0.0), "size": 0.4},
	{"scene": "res://assets/environment/community/cemetery/CementeryPack.glb", "part": "coffin", "pos": Vector3(21.0, 0.0, -13.0), "size": 0.5},
	{"scene": "res://assets/environment/community/cemetery/CementeryPack.glb", "part": "prop_tomb_1", "pos": Vector3(-18.0, 0.0, -12.0), "size": 0.5},
	{"scene": "res://assets/environment/community/cemetery/CementeryPack.glb", "part": "fence_fragment", "pos": Vector3(24.0, 0.0, -5.0), "size": 0.5},
	{"scene": "res://assets/environment/community/metro/Metro.glb", "part": "trash_can", "pos": Vector3(17.0, 0.0, -15.0), "size": 0.7},
]

func _ready() -> void:
	var cache := {}
	for config in DECORATIONS:
		var path: String = config["scene"]
		if not ResourceLoader.exists(path):
			continue
		if not cache.has(path):
			cache[path] = ResourceLoader.load(path)
		var source = cache[path] as PackedScene
		if source == null:
			continue
		var library: Node = source.instantiate()
		var part := library.get_node_or_null(NodePath(config["part"])) as Node3D
		if part == null:
			library.free()
			continue
		var visual := part.duplicate(0) as Node3D
		library.free()
		if visual == null:
			continue
		var original_scale := visual.scale
		visual.position = Vector3.ZERO
		visual.scale = original_scale * float(config["size"])
		var anchor := Node3D.new()
		anchor.name = "EnvironmentProp%d" % get_child_count()
		anchor.position = config["pos"]
		anchor.add_child(visual)
		add_child(anchor)
