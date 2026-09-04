extends Node

## Diagnóstico de solo lectura (no productivo): reproduce el combate
## intent_support (Ember Acolyte, sin arte real) y captura una imagen fresca
## para confirmar si el fallback de silueta procedural se dibuja en ejecución.
## No modifica ningún archivo de datos ni de producción. Salida propia,
## fuera de build/visual_slice/, para no pisar capturas existentes.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")

var _early_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"fallback_diagnosis_capture")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	RunManager.start_new_run(770077)
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)

	await get_tree().process_frame
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	var early_view: CombatCharacterView = enemy_actor.visual_view if enemy_actor != null else null
	if early_view != null:
		_early_size = early_view.size

	var frames: int = 0
	while int(combat.get("_phase")) != 1 and frames < 600:
		await get_tree().process_frame
		frames += 1

	await get_tree().create_timer(1.7).timeout

	var output_directory: String = ProjectSettings.globalize_path("res://build/fallback_legibility_fix_2026-09-03")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var image: Image = get_viewport().get_texture().get_image()
	var capture_path: String = output_directory.path_join("single_fallback_after.png")
	var capture_error: Error = image.save_png(capture_path)

	var report: Dictionary = {
		"capture_path": capture_path,
		"capture_error": capture_error,
		"phase_reached_player_input": int(combat.get("_phase")) == 1,
		"frames_waited": frames,
		"enemy_display_name": enemy_actor.display_name if enemy_actor != null else "null",
	}

	if enemy_actor != null and is_instance_valid(enemy_actor.visual_view):
		var view: CombatCharacterView = enemy_actor.visual_view
		var visual_data: CharacterVisualData = enemy_actor.visual_data
		report["view_size_early_frame1"] = _early_size
		report["view_size_at_capture"] = view.size
		report["view_global_position"] = view.global_position
		report["fallback_presence_enabled"] = view.get("_fallback_presence_enabled")
		report["fallback_kind"] = view.get("_fallback_kind")
		report["fallback_accent"] = view.get("_fallback_accent")
		report["ambient_accent"] = view.get("_ambient_accent")
		report["animated_mode"] = view.is_animated()
		report["static_art_visible"] = view.static_art.visible
		report["static_art_texture"] = view.static_art.texture
		report["fallback_label_visible"] = view.fallback_label.visible
		report["fallback_label_modulate"] = view.fallback_label.modulate
		report["visual_data_present"] = visual_data != null
		if visual_data != null:
			report["visual_accent"] = visual_data.accent
			report["portrait_path"] = visual_data.portrait_path
			report["combat_texture_path"] = visual_data.combat_texture_path
			report["sprite_frames_path"] = visual_data.sprite_frames_path
		report["background_color"] = combat.get_node("Background").color if combat.has_node("Background") else null

	print("FALLBACK_DIAGNOSIS " + JSON.stringify(report))
	combat.queue_free()
	await get_tree().process_frame
	RunManager.current_run = null
	get_tree().quit(0 if capture_error == OK else 1)
