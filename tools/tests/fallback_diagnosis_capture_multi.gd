extends Node

## Diagnóstico de solo lectura (no productivo): reproduce un combate NORMAL
## real (sin flags de visual-slice, mismo camino que un run real de
## jugador) contra Ashen Wastes, para confirmar el comportamiento del
## fallback en el formation path (EnemyCombatSlot, 2-3 enemigos) en vez del
## enemy_view único. No modifica ningún archivo de datos ni de producción.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")


const KNOWN_WORKING: Array[String] = ["Ash Crawler", "Ember Wretch"]


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"fallback_diagnosis_capture_multi")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	var output_directory: String = ProjectSettings.globalize_path("res://build/fallback_legibility_fix_2026-09-03")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var found_target: bool = false
	var last_capture_error: Error = OK
	for board_position: int in range(12, 40):
		RunManager.start_new_run(424242 + board_position)
		RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
		RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
		RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
		RunManager.current_run.board_position = board_position
		var combat: Control = COMBAT_SCENE.instantiate()
		combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
		add_child(combat)

		var frames: int = 0
		while int(combat.get("_phase")) != 1 and frames < 600:
			await get_tree().process_frame
			frames += 1
		await get_tree().create_timer(1.7).timeout

		var enemies: Array = combat.get("enemy_actors")
		var enemy_report: Array = []
		var has_broken_enemy: bool = false
		for actor: CombatActor in enemies:
			var entry: Dictionary = {"name": actor.display_name}
			if is_instance_valid(actor.visual_view):
				var view: CombatCharacterView = actor.visual_view
				entry["fallback_presence_enabled"] = view.get("_fallback_presence_enabled")
				entry["animated_mode"] = view.is_animated()
				entry["static_art_visible"] = view.static_art.visible
				entry["view_size"] = view.size
			enemy_report.append(entry)
			if actor.display_name not in KNOWN_WORKING:
				has_broken_enemy = true

		var should_capture: bool = enemies.size() > 1 and has_broken_enemy
		var capture_path: String = ""
		var capture_error: Error = OK
		if should_capture:
			var image: Image = get_viewport().get_texture().get_image()
			capture_path = output_directory.path_join("multi_fallback_after.png")
			capture_error = image.save_png(capture_path)
			last_capture_error = capture_error
			found_target = true

		print("FALLBACK_DIAGNOSIS_MULTI " + JSON.stringify({
			"board_position": board_position,
			"capture_path": capture_path,
			"capture_error": capture_error,
			"enemy_count": enemies.size(),
			"enemies": enemy_report,
			"captured": should_capture,
		}))
		combat.queue_free()
		await get_tree().process_frame
		RunManager.current_run = null
		if found_target:
			break
	get_tree().quit(0 if (found_target and last_capture_error == OK) else 1)
