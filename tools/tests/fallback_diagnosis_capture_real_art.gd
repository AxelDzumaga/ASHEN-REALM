extends Node

## Diagnóstico de solo lectura (no productivo): regresión de arte real tras
## el fix de legibilidad del fallback. Usa el mismo encuentro de referencia
## visual_slice ("normal"/"attack": Ash Crawler + Ember Wretch + Ashbound
## Brute) para confirmar que enemigos CON arte válido no se ven afectados
## por el cambio en CombatCharacterView._draw(). No modifica ningún archivo
## de datos ni de producción.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"fallback_diagnosis_capture_real_art")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	RunManager.start_new_run(770078)
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)

	var frames: int = 0
	while int(combat.get("_phase")) != 1 and frames < 600:
		await get_tree().process_frame
		frames += 1
	await get_tree().create_timer(1.7).timeout

	var output_directory: String = ProjectSettings.globalize_path("res://build/fallback_legibility_fix_2026-09-03")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var image: Image = get_viewport().get_texture().get_image()
	var capture_path: String = output_directory.path_join("real_art_regression.png")
	var capture_error: Error = image.save_png(capture_path)

	var enemies: Array = combat.get("enemy_actors")
	var enemy_report: Array = []
	for actor: CombatActor in enemies:
		var entry: Dictionary = {"name": actor.display_name}
		if is_instance_valid(actor.visual_view):
			var view: CombatCharacterView = actor.visual_view
			entry["animated_mode"] = view.is_animated()
			entry["static_art_visible"] = view.static_art.visible
			entry["static_art_texture_present"] = view.static_art.texture != null
			entry["fallback_label_visible"] = view.fallback_label.visible
		enemy_report.append(entry)

	print("FALLBACK_DIAGNOSIS_REAL_ART " + JSON.stringify({
		"capture_path": capture_path,
		"capture_error": capture_error,
		"enemy_count": enemies.size(),
		"enemies": enemy_report,
	}))
	combat.queue_free()
	await get_tree().process_frame
	RunManager.current_run = null
	get_tree().quit(0 if capture_error == OK else 1)
