extends SceneTree
## Full-scene startup and rooftop/ground render-profile smoke test.
## Complements the elevator and lower-level GPU warmup regression test.

const FOUNDATION_SCENE := preload("res://scenes/foundation.tscn")

var failures: Array[String] = []
var checks := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error("Gameplay smoke: " + description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = FOUNDATION_SCENE.instantiate()
	root.add_child(world)
	await process_frame
	var torch: FlashlightVisibilityManager = world.flashlight_visibility_manager
	var pencil: MeshInstance3D = world._pencil_screen_pass
	var boss: FoundationEnemy = world._boss_enemy
	var horde: HordeFarVisuals = world.horde_far_visuals
	var director: Node = world.spawn_director

	check(is_instance_valid(world.player) and world.player.global_position.y > 19.0, "player starts at rooftop")
	check(is_instance_valid(torch) and is_instance_valid(torch.spotlight), "3D flashlight system instantiates")
	check(is_instance_valid(pencil), "Pencil Sketch screen pass instantiates")
	check(is_instance_valid(boss) and boss.is_boss, "boss remains separate from ordinary population")
	check(director.ordinary_population_count() == 4, "only four stored ordinary zombies on rooftop")
	check(director.dormant_population_count() == 0, "no downstairs dormant actor entries rendered upstairs")
	check(not horde.visible and horde.multimesh.visible_instance_count == 0, "ordinary horde invisible on rooftop")
	check(world._rooftop_sky_active and not torch.spotlight.visible, "rooftop flashlight off")
	check(not pencil.visible, "rooftop pencil effect off")
	check(not torch._composite.visible, "rooftop screen blackout mask off")
	check(not torch.spotlight.shadow_enabled, "spotlight never allocates shadowmap")
	check(horde.rig_budget == 7, "normal zombie animated models capped at seven")
	var sheets = torch.spotlight.get_node_or_null("PlayerFlashlightBeamSheets") as MultiMeshInstance3D
	check(is_instance_valid(sheets) and sheets.multimesh.instance_count == 3, "shared 3D beam still has three crossed sheets")
	var sections = torch.spotlight.get_node_or_null("PlayerFlashlightBeamSections") as MeshInstance3D
	check(is_instance_valid(sections) and (sections.mesh as ArrayMesh).get_surface_count() == 1, "7 beam cross-sections still share one surface")

	# The elevator loading coordinator calls this only when ground preparation
	# reaches the render profile step. Test the full scene's actual instances.
	world._set_rooftop_render_profile(false)
	check(not world._rooftop_sky_active and torch.spotlight.visible, "ground restores 3D flashlight")
	check(pencil.visible, "ground restores Pencil Sketch")
	check(torch._composite.visible, "ground restores blackout mask")
	check(world._environment.sky == world._ground_sky, "ground uses original burning horizon sky")
	check(not torch.spotlight.shadow_enabled, "ground flashlight remains shadow-free")
	check(director.ordinary_population_count() == 4, "render profile alone cannot start zombie spawn")

	world._set_rooftop_render_profile(true)
	check(world._rooftop_sky_active and not torch.spotlight.visible, "return to rooftop disables beam again")
	check(not pencil.visible and not torch._composite.visible, "return to rooftop disables pencil and mask")
	check(world._environment.sky == world._rooftop_city_sky, "return to rooftop restores original panorama")
	check(director.ordinary_population_count() == 4, "profile toggles never create extra zombies")
	check(not world._ground_wave_started, "camera/graphics profile alone cannot trigger ground arrival")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: full gameplay startup and render-profile smoke (%d checks)" % checks)
	else:
		print("FAIL: full gameplay smoke (%d/%d checks)" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
