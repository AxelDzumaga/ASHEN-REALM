extends Node

## Real-render smoke for the Profile System startup screens (engineering
## validation, not subjective human approval — see the deferred human
## visual acceptance policy). Captures actual rendered frames so layout/
## overlap/text-rendering problems are visible, not just logic-correct.

const MAIN_MENU_SCENE := preload("res://scenes/lobby/main_menu.tscn")
const CHARACTER_CREATE_SCENE := preload("res://scenes/lobby/character_create.tscn")
const CHARACTER_SELECT_SCENE := preload("res://scenes/lobby/character_select.tscn")

var _current: Control


func _ready() -> void:
	CharacterProfileRepository.use_isolated_test_root("visual_capture")

	await _capture_main_menu("01_main_menu_zero_characters")

	CharacterProfileRepository.create_character("Ashen Wanderer")
	await _capture_main_menu("02_main_menu_one_character")

	CharacterProfileRepository.create_character("Second Hero")
	await _capture_character_select("03_character_select_two_slots")

	CharacterProfileRepository.create_character("Third Hero")
	await _capture_main_menu("04_main_menu_three_characters")
	await _capture_character_select("05_character_select_full")

	await _capture_character_create("06_character_create_empty")

	print("PROFILE_SYSTEM_VISUAL_CAPTURE done")
	get_tree().quit(0)


func _swap(screen: Control) -> void:
	if is_instance_valid(_current):
		_current.queue_free()
	_current = screen
	add_child(screen)


func _save(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var output_path: String = ProjectSettings.globalize_path("res://build/profile_system_visual_capture/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(output_path)
	print("CAPTURE %s path=%s error=%d" % [name, output_path, error])


func _capture_main_menu(name: String) -> void:
	var main_menu := MAIN_MENU_SCENE.instantiate()
	_swap(main_menu)
	await get_tree().process_frame
	main_menu.configure_for_characters(CharacterProfileRepository.list_characters())
	await _save(name)


func _capture_character_select(name: String) -> void:
	var character_select := CHARACTER_SELECT_SCENE.instantiate()
	_swap(character_select)
	await _save(name)


func _capture_character_create(name: String) -> void:
	var character_create := CHARACTER_CREATE_SCENE.instantiate()
	_swap(character_create)
	await _save(name)
