extends SceneTree
## Headless structural/regression checks. Visual equivalence and real GPU
## savings still require the final mobile A/B build.

const Flashlight := preload("res://scripts/flashlight_visibility.gd")
const Pencil := preload("res://scripts/pencil.gd")
const Foundation := preload("res://scripts/foundation.gd")
const PENCIL_SHADER := preload("res://shaders/pencil_screen.gdshader")
const VOLUME_SHADER := preload("res://shaders/flashlight_beam_volume.gdshader")

# Exercise inherited visibility logic in a live SceneTree without starting
# the entire tower, player combat and elevator during this micro-test.
class LightOnlyWorld:
	extends "res://scripts/foundation.gd"
	func _ready() -> void:
		pass

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok:
		failures.append(reason)

func _run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var player := Node3D.new()
	fixture.add_child(player)
	var camera := Camera3D.new()
	fixture.add_child(camera)
	camera.current = true
	var manager := Flashlight.new() as FlashlightVisibilityManager
	manager.player = player
	manager.camera = camera
	manager.enabled = true
	fixture.add_child(manager)
	manager._build_beam_light()
	var spot := manager.spotlight
	check(is_instance_valid(spot) and not spot.shadow_enabled, "original unshadowed spotlight retained")
	check(is_equal_approx(spot.spot_range, 30.0) and is_equal_approx(spot.spot_angle, 25.0), "original beam range and cone angle retained")
	var sheet := spot.get_node_or_null("PlayerFlashlightBeamSheets") as MultiMeshInstance3D
	check(is_instance_valid(sheet), "three crossed beam sheets share a single draw object")
	if sheet != null:
		check(sheet.multimesh.instance_count == 3, "crossing beam still has three sheets")
		check(sheet.multimesh.mesh is QuadMesh, "beam keeps original QuadMesh and vertex shader")
		check(sheet.material_override is ShaderMaterial and (sheet.material_override as ShaderMaterial).shader == VOLUME_SHADER, "all instances use unchanged beam shader")
		check(sheet.custom_aabb.position.z <= -30.0 and sheet.custom_aabb.end.z >= 0.0, "batch culling covers full 30m cone")
	check(spot.get_node_or_null("PlayerFlashlightBeamSheet0") == null, "individual beam draw objects are removed")
	var sections := spot.get_node_or_null("PlayerFlashlightBeamSections") as MeshInstance3D
	check(is_instance_valid(sections) and (sections.mesh as ArrayMesh).get_surface_count() == 1, "seven transverse sections stay in one draw mesh")
	check(spot.get_child_count() == 2, "visible shaft now uses two geometry nodes instead of four")

	manager.set_rooftop_sky_visible(true)
	check(not spot.visible, "rooftop disables entire flashlight beam")
	manager.set_rooftop_sky_visible(false)
	check(spot.visible, "ground enables unchanged flashlight")

	var shader_code := PENCIL_SHADER.code
	check(shader_code.contains("if (fade > 0.0)") and shader_code.contains("silhouette < 1.0"), "screen graphite skips provably invisible crease work")
	check(shader_code.contains("float fibre = 0.9") and shader_code.contains("ALBEDO = OUT_RGB(mix(c, line_color.rgb * fibre, line));"), "original paper texture and graphite compositing retained")
	check(Pencil.shader_for_screen(false, "gl_compatibility") == Pencil.SCREEN, "Android Compatibility keeps optimized screen shader")
	var original_light := spot.light_energy
	check(is_equal_approx(original_light, 1.6), "original spotlight intensity retained")

	# No-op visibility updates leave both local light and map mesh states
	# unchanged and still respond to explicit profiler light toggles.
	var world := LightOnlyWorld.new()
	fixture.add_child(world)
	var actor := preload("res://scripts/player_controller.gd").new() as FoundationPlayer
	world.player = actor
	world._local_lights_enabled = true
	world.add_child(actor)
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.0, -4.0)
	world.add_child(light)
	var wall := MeshInstance3D.new()
	wall.position = Vector3(0.0, 0.0, -4.0)
	world.add_child(wall)
	world._apply_distance_visibility(light)
	world._apply_distance_visibility(wall)
	check(light.visible and wall.visible, "nearby light and mesh remain visible")
	world._local_lights_enabled = false
	world._apply_distance_visibility(light)
	check(not light.visible and wall.visible, "mobile light disable does not hide emissive meshes")
	world._local_lights_enabled = true
	world._apply_distance_visibility(light)
	check(light.visible, "developer light profile can restore local lights")
	world.free()
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: GPU stage 3 beam pencil light (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: GPU stage 3 beam pencil light (%d/%d)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
