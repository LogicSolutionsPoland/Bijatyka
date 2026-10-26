extends Node3D
## Original low-poly environment dressing for the quarantine combat map.
## All geometry is procedural, has no collision, and uses the existing weathering shader.

const RUIN_SURFACE_SHADER := preload("res://shaders/ruined_surface.gdshader")
const PENCIL := preload("res://scripts/pencil.gd")
var _static_box_batches: Dictionary = {}

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

	_build_street(asphalt, concrete, dark_concrete, road_paint)
	_build_transit_corner(concrete, dark_concrete, rust, glass, amber)
	_build_memorial_corner(concrete, dark_concrete, rust)
	_build_ruined_fronts(concrete, dark_concrete, glass)
	_build_edge_debris(rust, concrete)
	_build_southern_checkpoint(concrete, dark_concrete, rust, amber)
	_flush_static_boxes()

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
	# A scaled unit box keeps all static scenery with one material in one draw.
	# The shader's world-space weathering still uses the per-instance transform.
	var key := surface.get_instance_id()
	if not _static_box_batches.has(key):
		_static_box_batches[key] = {"material": surface, "transforms": []}
	var transforms: Array = _static_box_batches[key]["transforms"]
	transforms.append(Transform3D(Basis(Vector3.UP, yaw).scaled(dimensions), at))

func _box_batch(label: String, _center: Vector3, dimensions: Vector3, positions: Array[Vector3], surface: Material) -> void:
	for position in positions:
		_box(label, position, dimensions, surface)

func _flush_static_boxes() -> void:
	var unit_box := BoxMesh.new()
	for key in _static_box_batches:
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
	material.next_pass = PENCIL.make_outline(2.8, Color(0.09, 0.09, 0.12))
	return material

func _glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
