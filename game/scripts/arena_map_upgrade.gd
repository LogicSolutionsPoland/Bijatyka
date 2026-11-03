extends Node3D
## Spatially batched ruined city with broad streets and selected solid cover.

const RUIN_SURFACE_SHADER := preload("res://shaders/ruined_surface.gdshader")
const DEAD_TREE_1 := preload("res://assets/environment/nature/DeadTree_1.gltf")
const DEAD_TREE_2 := preload("res://assets/environment/nature/DeadTree_2.gltf")
const DEAD_TREE_3 := preload("res://assets/environment/nature/DeadTree_3.gltf")
const DEAD_TREE_4 := preload("res://assets/environment/nature/DeadTree_4.gltf")
const DEAD_TREE_5 := preload("res://assets/environment/nature/DeadTree_5.gltf")
const ROCK_MEDIUM_1 := preload("res://assets/environment/nature/Rock_Medium_1.gltf")
const ROCK_MEDIUM_2 := preload("res://assets/environment/nature/Rock_Medium_2.gltf")
const ROCK_MEDIUM_3 := preload("res://assets/environment/nature/Rock_Medium_3.gltf")
const BUSH_COMMON := preload("res://assets/environment/nature/Bush_Common.gltf")
var _static_box_batches: Dictionary = {}
var collision_bounds: Array[AABB] = []
const CITY_CELL_SIZE := 24.0

func _ready() -> void:
	_build_map()

func _build_map() -> void:
	var asphalt := _surface(Color(0.047, 0.052, 0.060), 0.97)
	var concrete := _surface(Color(0.24, 0.255, 0.27), 0.93)
	var dark_concrete := _surface(Color(0.075, 0.085, 0.10), 0.98)
	var rust := _surface(Color(0.29, 0.15, 0.10), 0.88)
	var glass := _surface(Color(0.035, 0.065, 0.078), 0.30, 0.42)
	var road_paint := _surface(Color(0.49, 0.22, 0.09), 0.82)
	var amber := _glow(Color(0.95, 0.20, 0.035))
	var soot := _surface(Color(0.038, 0.036, 0.037), 1.0)
	var scorched := _surface(Color(0.13, 0.075, 0.055), 0.98)

	_build_street(asphalt, concrete, dark_concrete, road_paint)
	_build_transit_corner(concrete, dark_concrete, rust, glass, amber)
	_build_memorial_corner(concrete, dark_concrete, rust)
	_build_ruined_fronts(concrete, dark_concrete, glass)
	_build_edge_debris(rust, concrete)
	_build_southern_checkpoint(concrete, dark_concrete, rust, amber)
	_build_outer_streets(asphalt, concrete, road_paint, soot)
	_build_burned_blocks(concrete, dark_concrete, soot, scorched, rust, glass, amber)
	_build_wrecks_and_rubble(rust, soot, scorched, glass, amber)
	_flush_static_boxes()
	_build_nature()

func _build_nature() -> void:
	# Quaternius CC0 scenery from Zasoby. Keep trunks beyond the fence and the
	# protected base so the four opening zombies' combat routes and spawns stay open.
	_add_nature_batch("DeadTreesShort", DEAD_TREE_1, [
		_nature_transform(-17.8, -22.0, 20.0, 0.65),
		_nature_transform(23.0, 7.5, -37.0, 0.65),
		_nature_transform(-27.0, -5.0, 112.0, 0.82),
		_nature_transform(-79.0, -53.0, 12.0, 0.76),
		_nature_transform(72.0, 43.0, 35.0, 0.73),
		_nature_transform(-51.0, 69.0, -21.0, 0.78),
	])
	_add_nature_batch("DeadTreesTall", DEAD_TREE_3, [
		_nature_transform(18.2, -23.0, 45.0, 0.50),
		_nature_transform(-23.5, 17.0, -28.0, 0.62),
		_nature_transform(22.0, 17.5, 131.0, 0.59),
		_nature_transform(79.0, -68.0, 42.0, 0.55),
		_nature_transform(-74.0, 63.0, -63.0, 0.59),
		_nature_transform(48.0, -72.0, 115.0, 0.54),
	])
	_add_nature_batch("DeadTreesGnarled", DEAD_TREE_2, [
		_nature_transform(-87.0, -48.0, 22.0, 0.76),
		_nature_transform(87.0, 48.0, 79.0, 0.71),
		_nature_transform(-86.0, 62.0, -35.0, 0.74),
		_nature_transform(86.0, -63.0, 148.0, 0.77),
	])
	_add_nature_batch("DeadTreesBroken", DEAD_TREE_4, [
		_nature_transform(-88.0, 30.0, -18.0, 0.73),
		_nature_transform(88.0, -30.0, 161.0, 0.69),
		_nature_transform(-46.0, -86.0, 48.0, 0.74),
		_nature_transform(47.0, 86.0, -44.0, 0.72),
	])
	_add_nature_batch("DeadTreesSplit", DEAD_TREE_5, [
		_nature_transform(-89.0, -8.0, 8.0, 0.70),
		_nature_transform(89.0, 10.0, 132.0, 0.73),
		_nature_transform(-17.0, -87.0, -26.0, 0.74),
		_nature_transform(17.0, 87.0, 84.0, 0.71),
	])
	_add_nature_batch("RoadsideRocks", ROCK_MEDIUM_1, [
		_nature_transform(-19.0, 8.5, 12.0, 0.70),
		_nature_transform(20.0, 10.0, 58.0, 0.65),
		_nature_transform(-25.0, -1.5, 115.0, 0.75),
		_nature_transform(26.0, 0.5, -25.0, 0.63),
		_nature_transform(-20.5, 17.5, 80.0, 0.60),
		_nature_transform(19.0, -25.0, 143.0, 0.57),
		_nature_transform(-22.0, -25.0, -53.0, 0.70),
		_nature_transform(23.5, -17.0, 33.0, 0.66),
		_nature_transform(-61.0, -76.0, 20.0, 0.61),
		_nature_transform(60.0, 73.0, 80.0, 0.64),
		_nature_transform(-35.0, 47.0, -17.0, 0.62),
		_nature_transform(84.0, 8.0, 120.0, 0.68),
	])
	_add_nature_batch("RoadsideRocksAngular", ROCK_MEDIUM_2, [
		_nature_transform(-38.0, -63.0, 12.0, 0.78),
		_nature_transform(38.0, -63.0, 44.0, 0.73),
		_nature_transform(-38.0, 55.0, -31.0, 0.82),
		_nature_transform(38.0, 55.0, 127.0, 0.76),
		_nature_transform(-82.0, -29.0, 59.0, 0.71),
		_nature_transform(82.0, 29.0, -14.0, 0.79),
		_nature_transform(-21.0, 82.0, 91.0, 0.75),
		_nature_transform(21.0, -82.0, 157.0, 0.80),
	])
	_add_nature_batch("RoadsideRocksFlat", ROCK_MEDIUM_3, [
		_nature_transform(-38.0, -46.0, 31.0, 0.92),
		_nature_transform(38.0, -46.0, -52.0, 0.86),
		_nature_transform(-38.0, 38.0, 113.0, 0.89),
		_nature_transform(38.0, 38.0, 56.0, 0.94),
		_nature_transform(-80.0, 48.0, -18.0, 0.85),
		_nature_transform(80.0, -48.0, 129.0, 0.90),
		_nature_transform(-67.0, -83.0, 43.0, 0.88),
		_nature_transform(68.0, 83.0, -74.0, 0.91),
	])
	_add_nature_batch("OvergrownShrubs", BUSH_COMMON, [
		_nature_transform(-19.2, 10.0, 0.0, 0.78),
		_nature_transform(19.5, 11.5, 70.0, 0.85),
		_nature_transform(-25.3, -3.0, 114.0, 0.90),
		_nature_transform(25.5, 1.5, -21.0, 0.76),
		_nature_transform(-21.5, -23.5, 40.0, 0.87),
		_nature_transform(23.0, -23.0, 115.0, 0.80),
		_nature_transform(-82.0, 15.0, 40.0, 0.86),
		_nature_transform(82.0, -22.0, 90.0, 0.72),
		_nature_transform(-48.0, -73.0, 145.0, 0.79),
		_nature_transform(49.0, 71.0, 15.0, 0.82),
	])

func _build_outer_streets(asphalt: Material, concrete: Material, road_paint: Material, soot: Material) -> void:
	# The original courtyard remains intact. Four broad loops and two cross
	# streets fill the previously empty ground out to roughly 90 m each way.
	for x in [-58.0, -30.0, 0.0, 30.0, 58.0]:
		for segment in range(8):
			var z := -77.0 + float(segment) * 22.0
			_box("NorthSouthStreet", Vector3(x, 0.010, z), Vector3(10.0, 0.018, 22.0), asphalt)
			if absf(x) > 1.0 or z < -37.0 or z > 31.0:
				_box("FadedLaneMark", Vector3(x, 0.026, z), Vector3(0.16, 0.012, 2.8), road_paint)
	for z in [-62.0, -35.0, 24.0, 54.0]:
		for segment in range(8):
			var x := -77.0 + float(segment) * 22.0
			_box("EastWestStreet", Vector3(x, 0.012, z), Vector3(22.0, 0.018, 9.5), asphalt)
			_box("FadedCrossStreetMark", Vector3(x, 0.027, z), Vector3(2.8, 0.012, 0.16), road_paint)
	# Sidewalk slabs visually border each block without closing the roads.
	for side in [-1.0, 1.0]:
		for lane in [30.0, 58.0]:
			for segment in range(7):
				var z := -70.0 + float(segment) * 22.0
				_box("CharredSidewalk", Vector3(side * (lane + 6.4), 0.07, z), Vector3(2.4, 0.12, 20.0), concrete)
				_box("CinderStrip", Vector3(side * (lane + 7.7), 0.14, z), Vector3(0.12, 0.012, 15.0), soot)

func _build_burned_blocks(concrete: Material, dark_concrete: Material, soot: Material,
		scorched: Material, rust: Material, glass: Material, amber: Material) -> void:
	# Solid cores make real cover; broken upper silhouettes stay visual only.
	# Every street is at least 9.5 m wide and remains connected around the blocks.
	for side in [-1.0, 1.0]:
		for lane in [44.0, 74.0]:
			for z in [-76.0, -48.0, 38.0, 72.0]:
				var x: float = float(side) * float(lane)
				var at := Vector3(x, 0.0, z)
				var height := 5.4 + float((int(lane) + int(z)) % 3) * 1.3
				_solid_box("BurnedBuildingCore", at + Vector3.UP * height * 0.5,
					Vector3(7.0, height, 8.0), soot)
				_box("BrokenUpperFloor", at + Vector3(-side * 0.8, height + 0.38, 0.6),
					Vector3(5.1, 0.72, 6.4), concrete)
				_box("CollapsedParapet", at + Vector3(side * 1.7, height + 1.1, -2.7),
					Vector3(1.0, 1.4, 2.8), dark_concrete)
				_box("ScorchedWallFace", at + Vector3(0.0, height * 0.53, -4.03),
					Vector3(6.0, height * 0.77, 0.08), scorched)
				for window in [-1.8, 1.8]:
					_box("BurnedWindow", at + Vector3(window, 2.9, -4.09),
						Vector3(1.08, 1.52, 0.10), glass)
				_box("ExposedRebar", at + Vector3(-side * 2.6, height + 1.45, 2.4),
					Vector3(0.13, 2.9, 0.13), rust)
				if z == -48.0 or z == 38.0:
					_box("DyingEmber", at + Vector3(2.0, 0.34, 4.5),
						Vector3(0.48, 0.14, 0.28), amber)
	# A shattered back row closes the view before the existing world boundary.
	for index in range(9):
		var x := -84.0 + float(index) * 21.0
		if absf(x) < 15.0:
			continue
		_box("DistantBurnedSkyline", Vector3(x, 7.5 + float(index % 3), -89.0),
			Vector3(7.5, 15.0 + float(index % 3) * 2.0, 5.0), dark_concrete)

func _build_wrecks_and_rubble(rust: Material, soot: Material, scorched: Material,
		glass: Material, amber: Material) -> void:
	# Wrecks sit at road shoulders and leave the central routes clear. Their
	# chassis collide with player and zombies; sparks have no dynamic lights.
	for side in [-1.0, 1.0]:
		for x_lane in [25.0, 64.0]:
			for z in [-68.0, -39.0, 21.0, 59.0]:
				var x: float = float(side) * float(x_lane)
				var yaw: float = float(side) * 0.16
				var at := Vector3(x, 0.0, z)
				_solid_box("BurnedVehicleChassis", at + Vector3.UP * 0.73,
					Vector3(2.4, 1.46, 4.8), soot, yaw)
				_box("BurnedVehicleCabin", at + Vector3(0.0, 1.62, 0.5),
					Vector3(2.0, 0.56, 2.2), rust, yaw)
				_box("ShatteredWindshield", at + Vector3(0.0, 1.64, -0.66),
					Vector3(1.55, 0.34, 0.08), glass, yaw)
				_box("WreckEmbers", at + Vector3(0.65, 0.27, 2.30),
					Vector3(0.52, 0.13, 0.26), amber, yaw)
	for index in range(32):
		var side := -1.0 if index % 2 == 0 else 1.0
		var ring := float(index / 8)
		var z := -72.0 + float(index % 8) * 19.0
		var x := side * (37.0 + ring * 11.0)
		_box("BlackenedDebris", Vector3(x, 0.21, z), Vector3(1.1, 0.42, 1.6),
			scorched if index % 3 == 0 else rust, float(index % 4) * 0.31)

func _solid_box(label: String, at: Vector3, dimensions: Vector3, surface: Material, yaw: float = 0.0) -> void:
	_box(label, at, dimensions, surface, yaw)
	var body := StaticBody3D.new()
	body.name = "%s%02d" % [label, collision_bounds.size()]
	body.collision_layer = 1
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	shape_node.shape = shape
	body.add_child(shape_node)
	body.position = at
	body.rotation.y = yaw
	body.add_to_group("ruined_city_obstacle")
	add_child(body)
	collision_bounds.append(Transform3D(Basis(Vector3.UP, yaw), at) * AABB(-dimensions * 0.5, dimensions))

func _nature_transform(x: float, z: float, yaw_degrees: float, scale_factor: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)).scaled(Vector3.ONE * scale_factor), Vector3(x, 0.10, z))

func _add_nature_batch(label: String, source: PackedScene, placements: Array) -> void:
	# A single imported mesh and MultiMesh per type share the pack's textures.
	# Decoration has no collision, avoiding changes to combat and spawn timing.
	var prototype := source.instantiate() as Node3D
	var meshes := prototype.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_error("Missing scenery mesh: " + label)
		prototype.free()
		return
	var visual := meshes[0] as MeshInstance3D
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = visual.mesh
	batch.instance_count = placements.size()
	batch.visible_instance_count = placements.size()
	for index in range(placements.size()):
		var placement: Transform3D = placements[index]
		batch.set_instance_transform(index, placement * visual.transform)
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_to_group("nature_scenery_batch")
	add_child(instance)
	prototype.free()

func _build_street(asphalt: Material, concrete: Material, dark_concrete: Material, road_paint: Material) -> void:
	# A cross street and boulevard give the flat fight yard a clear route through it.
	_box("AshenNorthBoulevard", Vector3(0.0, 0.014, -21.0), Vector3(15.2, 0.026, 32.0), asphalt)
	_box("AshenEastWestStreet", Vector3(0.0, 0.016, -22.8), Vector3(46.0, 0.026, 8.2), asphalt)
	_box("AshenSouthExitStreet", Vector3(0.0, 0.014, 10.7), Vector3(15.2, 0.026, 16.0), asphalt)

	var center_dashes: Array[Vector3] = []
	for index in range(5):
		center_dashes.append(Vector3(0.0, 0.032, -19.2 - float(index) * 3.7))
	_box_batch("BoulevardCenterDashes", Vector3(0.0, 0.0, -27.0), Vector3(0.16, 0.014, 1.15), center_dashes, road_paint)

	var crossing_marks: Array[Vector3] = []
	for index in range(7):
		crossing_marks.append(Vector3(-4.2 + float(index) * 1.4, 0.032, -17.8))
	_box_batch("BrokenCrosswalk", Vector3(0.0, 0.0, -17.8), Vector3(0.76, 0.014, 0.18), crossing_marks, concrete)

	var curb_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		curb_positions.append(Vector3(side * 7.86, 0.09, -22.0))
		curb_positions.append(Vector3(side * 7.86, 0.09, -29.0))
	_box_batch("BrokenBoulevardCurbs", Vector3(0.0, 0.0, -25.5), Vector3(0.28, 0.18, 5.4), curb_positions, concrete)

	var asphalt_scars: Array[Vector3] = []
	for index in range(8):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := -12.0 - float(index) * 2.55
		asphalt_scars.append(Vector3(side * (2.8 + float(index % 3) * 1.05), 0.031, z))
	_box_batch("BrokenAsphaltScars", Vector3(0.0, 0.0, -21.0), Vector3(1.25, 0.012, 0.34), asphalt_scars, dark_concrete)

func _build_transit_corner(concrete: Material, dark_concrete: Material, rust: Material, glass: Material, amber: Material) -> void:
	# A handmade derelict train car sits outside the central fighting lane.
	_box("TransitWreckHull", Vector3(-22.0, 1.36, -16.8), Vector3(4.0, 2.7, 7.6), dark_concrete)
	_box("TransitWreckRoof", Vector3(-22.0, 2.76, -16.8), Vector3(4.18, 0.18, 7.8), rust)
	_box("TransitWreckLowerStripe", Vector3(-19.96, 0.79, -16.8), Vector3(0.07, 0.17, 7.05), rust)
	_box("TransitWreckFrontGlass", Vector3(-22.0, 2.03, -12.96), Vector3(1.75, 0.78, 0.07), glass)
	_box("TransitWreckDoor", Vector3(-19.96, 1.42, -20.0), Vector3(0.07, 1.78, 1.2), rust)

	var windows: Array[Vector3] = []
	for index in range(4):
		windows.append(Vector3(-19.955, 2.05, -18.8 + float(index) * 1.75))
	_box_batch("TransitWreckSideWindows", Vector3(-19.955, 0.0, -15.4), Vector3(0.065, 0.76, 1.20), windows, glass)

	# The entrance frame, sign and shallow steps mark the second route through the district.
	_box("MetroPortalRecess", Vector3(-18.72, 1.62, -24.5), Vector3(0.24, 3.2, 5.8), dark_concrete)
	_box("MetroPortalNearPillar", Vector3(-18.08, 1.76, -28.0), Vector3(0.72, 3.5, 0.72), concrete)
	_box("MetroPortalFarPillar", Vector3(-18.08, 1.76, -21.0), Vector3(0.72, 3.5, 0.72), concrete)
	_box("MetroPortalLintel", Vector3(-18.08, 3.48, -24.5), Vector3(0.78, 0.52, 7.7), rust)
	_box("MetroRouteLight", Vector3(-17.64, 3.37, -24.5), Vector3(0.08, 0.20, 5.25), amber)

	var step_positions: Array[Vector3] = []
	for index in range(4):
		step_positions.append(Vector3(-15.9 - float(index) * 0.70, 0.17 - float(index) * 0.03, -24.5))
	_box_batch("MetroApproachSteps", Vector3(-17.0, 0.0, -24.5), Vector3(0.70, 0.12, 5.3), step_positions, concrete)

func _build_memorial_corner(concrete: Material, dark_concrete: Material, rust: Material) -> void:
	# A compact memorial garden balances the transit landmark and frames the open plaza.
	_box("MemorialGateSouthPillar", Vector3(20.0, 1.88, -14.0), Vector3(0.82, 3.76, 0.82), concrete)
	_box("MemorialGateNorthPillar", Vector3(20.0, 1.88, -25.6), Vector3(0.82, 3.76, 0.82), concrete)
	_box("MemorialGateLintel", Vector3(20.0, 3.78, -19.8), Vector3(0.90, 0.52, 12.2), dark_concrete)
	_box("MemorialPlaque", Vector3(19.50, 2.45, -19.8), Vector3(0.10, 0.78, 2.8), rust)

	var marker_positions: Array[Vector3] = []
	var cap_positions: Array[Vector3] = []
	for index in range(8):
		var column := index % 4
		var row := 0 if index < 4 else 1
		var x := 16.2 + float(column) * 2.1
		var z := -15.3 - float(row) * 4.15
		marker_positions.append(Vector3(x, 0.56, z))
		cap_positions.append(Vector3(x, 1.14, z))
	_box_batch("MemorialMarkers", Vector3(20.0, 0.0, -17.4), Vector3(0.52, 1.12, 0.26), marker_positions, concrete)
	_box_batch("MemorialMarkerCaps", Vector3(20.0, 0.0, -17.4), Vector3(0.70, 0.12, 0.34), cap_positions, rust)

func _build_ruined_fronts(concrete: Material, dark_concrete: Material, glass: Material) -> void:
	# Broken facades sit at the edge of the 30 m lit area while leaving a wide center lane.
	_box("WestDistrictFacade", Vector3(-15.5, 4.25, -29.3), Vector3(10.8, 8.5, 1.55), concrete)
	_box("WestDistrictUpperRemnant", Vector3(-16.7, 7.6, -28.4), Vector3(4.8, 1.55, 1.30), dark_concrete)
	_box("EastDistrictFacade", Vector3(15.5, 4.25, -29.3), Vector3(10.8, 8.5, 1.55), concrete)
	_box("EastDistrictUpperRemnant", Vector3(12.6, 7.6, -28.4), Vector3(4.8, 1.55, 1.30), dark_concrete)

	var window_positions: Array[Vector3] = []
	for side in [-1.0, 1.0]:
		for index in range(3):
			window_positions.append(Vector3(side * (12.2 + float(index) * 3.25), 2.65, -28.49))
			if index < 2:
				window_positions.append(Vector3(side * (13.4 + float(index) * 3.25), 5.45, -28.49))
	_box_batch("DistrictFacadeWindows", Vector3(0.0, 0.0, -28.49), Vector3(1.22, 0.92, 0.14), window_positions, glass)

func _build_edge_debris(rust: Material, concrete: Material) -> void:
	var debris_positions: Array[Vector3] = []
	for index in range(12):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := -9.5 - float(index) * 1.75
		var x := side * (9.4 + float(index % 3) * 1.0)
		debris_positions.append(Vector3(x, 0.22, z))
	_box_batch("RoadsideRubble", Vector3(0.0, 0.0, -20.0), Vector3(0.62, 0.42, 0.78), debris_positions, rust)

	var concrete_fragments: Array[Vector3] = []
	for index in range(6):
		var side := -1.0 if index % 2 == 0 else 1.0
		concrete_fragments.append(Vector3(side * 12.8, 0.18, -11.0 - float(index) * 3.1))
	_box_batch("RoadsideConcreteFragments", Vector3(0.0, 0.0, -20.0), Vector3(0.82, 0.32, 0.55), concrete_fragments, concrete)

func _build_southern_checkpoint(concrete: Material, dark_concrete: Material, rust: Material, amber: Material) -> void:
	# The rear route gives the player a readable exit beyond the protected base.
	_box("SouthQuarantineGateWestPillar", Vector3(-9.25, 2.55, 15.5), Vector3(0.92, 5.1, 1.15), concrete)
	_box("SouthQuarantineGateEastPillar", Vector3(9.25, 2.55, 15.5), Vector3(0.92, 5.1, 1.15), concrete)
	_box("SouthQuarantineGateHeader", Vector3(0.0, 5.18, 15.5), Vector3(19.2, 0.72, 1.25), dark_concrete)
	_box("SouthGateWarningStrip", Vector3(0.0, 4.68, 14.83), Vector3(7.6, 0.22, 0.10), amber)
	_box("SouthGateBrokenBarrierWest", Vector3(-12.6, 1.05, 17.4), Vector3(3.8, 2.1, 0.78), rust, -0.12)
	_box("SouthGateBrokenBarrierEast", Vector3(12.6, 1.05, 17.4), Vector3(3.8, 2.1, 0.78), rust, 0.12)

func _box(_label: String, at: Vector3, dimensions: Vector3, surface: Material, yaw: float = 0.0) -> void:
	# Spatial cells keep the expanded city out of near-field GPU batches.
	var cell_x := floori(at.x / CITY_CELL_SIZE)
	var cell_z := floori(at.z / CITY_CELL_SIZE)
	var key := "%d:%d:%d" % [surface.get_instance_id(), cell_x, cell_z]
	var center := Vector3((cell_x + 0.5) * CITY_CELL_SIZE, 0.0,
		(cell_z + 0.5) * CITY_CELL_SIZE)
	var transform := Transform3D(Basis(Vector3.UP, yaw).scaled(dimensions), at - center)
	var bounds := transform * AABB(-Vector3.ONE * 0.5, Vector3.ONE)
	if not _static_box_batches.has(key):
		_static_box_batches[key] = {"material": surface, "center": center,
			"transforms": [], "bounds": bounds}
	var transforms: Array = _static_box_batches[key]["transforms"]
	transforms.append(transform)
	_static_box_batches[key]["bounds"] = (_static_box_batches[key]["bounds"] as AABB).merge(bounds)

func _box_batch(label: String, _center: Vector3, dimensions: Vector3, positions: Array[Vector3], surface: Material) -> void:
	for position in positions:
		_box(label, position, dimensions, surface)

func _flush_static_boxes() -> void:
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var keys := _static_box_batches.keys()
	keys.sort()
	for key in keys:
		var data: Dictionary = _static_box_batches[key]
		var transforms: Array = data["transforms"]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = unit_box
		batch.instance_count = transforms.size()
		batch.visible_instance_count = transforms.size()
		for index in range(transforms.size()):
			batch.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = "DistrictStaticBatch%d" % get_child_count()
		instance.multimesh = batch
		instance.material_override = data["material"]
		instance.position = data["center"]
		instance.custom_aabb = data["bounds"]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.add_to_group("static_map_batch")
		add_child(instance)
	_static_box_batches.clear()

func _surface(color: Color, roughness: float, metallic: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = RUIN_SURFACE_SHADER
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("surface_roughness", roughness)
	material.set_shader_parameter("surface_metallic", metallic)
	return material

func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
