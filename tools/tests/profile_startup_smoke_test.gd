extends Node

## Non-visual smoke test for the Profile System UI wiring: instantiates
## MainMenu/CharacterCreate/CharacterSelect scenes directly (catches
## missing @onready nodes / signal wiring mistakes that a pure headless
## --check-only pass wouldn't reliably catch) and drives the 0/1/2-3
## character startup branches through game.gd's actual entry points.

const MAIN_MENU_SCENE := preload("res://scenes/lobby/main_menu.tscn")
const CHARACTER_CREATE_SCENE := preload("res://scenes/lobby/character_create.tscn")
const CHARACTER_SELECT_SCENE := preload("res://scenes/lobby/character_select.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	CharacterProfileRepository.use_isolated_test_root("startup_smoke")
	_test_main_menu_zero_characters()
	_test_character_create_flow()
	_test_main_menu_one_character()
	await _test_character_select_flow()
	_test_main_menu_multi_characters()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _test_main_menu_zero_characters() -> void:
	var characters: Array = CharacterProfileRepository.startup()
	var main_menu := MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	main_menu.configure_for_characters(characters)
	var start_button: Button = main_menu.get_node("%StartGameButton")
	var new_character_button: Button = main_menu.get_node("%NewCharacterButton")
	_check("zero_characters_start_text", start_button.text == "NUEVA PARTIDA")
	_check("zero_characters_new_character_hidden", not new_character_button.visible)
	main_menu.queue_free()


func _test_character_create_flow() -> void:
	var character_create := CHARACTER_CREATE_SCENE.instantiate()
	add_child(character_create)
	var name_edit: LineEdit = character_create.get_node("%NameEdit")
	var confirm_button: Button = character_create.get_node("%ConfirmButton")
	var error_label: Label = character_create.get_node("%ErrorLabel")

	name_edit.text = "   "
	confirm_button.emit_signal("pressed")
	_check("create_rejects_blank_name", error_label.visible)

	# GDScript lambdas capture outer locals by value, not by reference — use
	# a single-element Array as a mutable box so the connected callback's
	# assignment is actually observable after emit_signal() returns.
	var captured_id: Array = [""]
	character_create.created.connect(func(id: String) -> void: captured_id[0] = id)
	name_edit.text = "Smoke Hero"
	error_label.visible = false
	confirm_button.emit_signal("pressed")
	_check("create_succeeds_with_valid_name", not String(captured_id[0]).is_empty())
	_check("create_selected_repository_matches", CharacterProfileRepository.selected_character_id == String(captured_id[0]))
	character_create.queue_free()


func _test_main_menu_one_character() -> void:
	var characters: Array = CharacterProfileRepository.list_characters()
	_check("one_character_after_create", characters.size() == 1)
	var main_menu := MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	main_menu.configure_for_characters(characters)
	var start_button: Button = main_menu.get_node("%StartGameButton")
	var new_character_button: Button = main_menu.get_node("%NewCharacterButton")
	var summary_label: Label = main_menu.get_node("%CharacterSummaryLabel")
	_check("one_character_continue_text", start_button.text == "CONTINUAR")
	_check("one_character_new_character_visible", new_character_button.visible)
	_check("one_character_summary_shows_name", summary_label.text.find("Smoke Hero") >= 0)
	main_menu.queue_free()

	CharacterProfileRepository.create_character("Second Hero")


func _test_character_select_flow() -> void:
	var character_select := CHARACTER_SELECT_SCENE.instantiate()
	add_child(character_select)
	var slots_container: VBoxContainer = character_select.get_node("%SlotsContainer")
	_check("select_shows_max_slots_rows", slots_container.get_child_count() == CharacterProfileRepository.MAX_CHARACTER_SLOTS)

	var characters: Array = CharacterProfileRepository.list_characters()
	_check("select_lists_two_characters", characters.size() == 2)
	var second_id: String = ""
	for entry: Dictionary in characters:
		if String(entry.get("display_name", "")) == "Second Hero":
			second_id = String(entry.get("character_id", ""))
	var captured_id: Array = [""]
	character_select.character_selected.connect(func(id: String) -> void: captured_id[0] = id)
	character_select.emit_signal("character_selected", second_id)
	_check("select_emits_chosen_id", String(captured_id[0]) == second_id)

	await _test_two_step_delete_confirmation(character_select, second_id)
	character_select.queue_free()


## Regression coverage for a real bug caught during development: the
## first press must arm the confirmation (show it, NOT delete yet); only
## a second press on the same slot must actually delete.
func _test_two_step_delete_confirmation(character_select: Control, character_id: String) -> void:
	var row: HBoxContainer = _find_slot_row(character_select, character_id)
	if row == null:
		_check("delete_confirmation_row_found", false)
		return
	var delete_button: Button = row.get_child(1)

	delete_button.emit_signal("pressed")
	_check("delete_first_press_does_not_delete_yet", CharacterProfileRepository.character_exists(character_id))
	# _refresh() rebuilds rows with new Node instances; the old ones are
	# only queue_free()'d (removal deferred to frame end), so a frame must
	# pass before re-querying by character_id resolves to the new row
	# instead of the stale about-to-be-freed one.
	await get_tree().process_frame
	var armed_row: HBoxContainer = _find_slot_row(character_select, character_id)
	var armed_delete_button: Button = armed_row.get_child(1)
	_check("delete_first_press_shows_confirm_state", armed_delete_button.text != "ELIMINAR")

	armed_delete_button.emit_signal("pressed")
	_check("delete_second_press_actually_deletes", not CharacterProfileRepository.character_exists(character_id))

	CharacterProfileRepository.create_character("Second Hero")


func _find_slot_row(character_select: Control, character_id: String) -> HBoxContainer:
	var slots_container: VBoxContainer = character_select.get_node("%SlotsContainer")
	for child: Node in slots_container.get_children():
		if child is HBoxContainer and String(child.get_meta("character_id", "")) == character_id:
			return child
	return null


func _test_main_menu_multi_characters() -> void:
	CharacterProfileRepository.create_character("Third Hero")
	var characters: Array = CharacterProfileRepository.list_characters()
	_check("three_characters_present", characters.size() == 3)
	var main_menu := MAIN_MENU_SCENE.instantiate()
	add_child(main_menu)
	main_menu.configure_for_characters(characters)
	var start_button: Button = main_menu.get_node("%StartGameButton")
	var new_character_button: Button = main_menu.get_node("%NewCharacterButton")
	_check("multi_character_select_text", start_button.text == "SELECCIONAR PERSONAJE")
	_check("multi_character_new_character_hidden", not new_character_button.visible)
	main_menu.queue_free()
