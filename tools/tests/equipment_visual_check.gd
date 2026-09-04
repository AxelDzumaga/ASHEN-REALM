extends Node

const EQUIPMENT_SCENE := preload("res://scenes/lobby/equipment.tscn")


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"equipment_visual_check")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	SaveManager.profile.player_level = 6
	SaveManager.profile.player_xp = 40
	SaveManager.profile.owned_equipment = {
		"ashen_blade": 1, "ember_fang": 2, "wardens_edge": 1,
		"worn_ashmail": 1, "warden_plate": 1, "mire_vest": 1,
	}
	SaveManager.profile.equipped_weapon_id = "ember_fang"
	SaveManager.profile.equipped_armor_id = "warden_plate"
	SaveManager.profile.equipment_refinement = {"ember_fang": 5, "warden_plate": 13}
	# "warden_plate" queda auto-bloqueada (equipada + set de boss) sin marcarla a mano.
	# "ashen_blade" se marca bloqueada manualmente para probar ese camino.
	SaveManager.profile.locked_equipment_ids = ["ashen_blade"]
	# Todo menos "mire_vest" ya está "visto" -> mire_vest debería mostrar NUEVO.
	SaveManager.profile.seen_equipment_ids = ["ashen_blade", "ember_fang", "wardens_edge", "worn_ashmail", "warden_plate"]
	var screen: Control = EQUIPMENT_SCENE.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--only-set" in args:
		screen.set("_only_set", true)
		screen.call("_refresh")
		await get_tree().process_frame
	if "--confirm-salvage" in args:
		screen.call("_on_salvage_pressed", "ember_fang")
		await get_tree().process_frame

	var output_path := ProjectSettings.globalize_path("res://build/equipment_visual_check/equipment.png")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(output_path)
	print("EQUIPMENT_VISUAL_CHECK path=%s error=%d" % [output_path, error])
	get_tree().quit(0 if error == OK else 1)
