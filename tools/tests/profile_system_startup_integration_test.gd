extends Node

## Drives the REAL game.gd startup wiring end to end (not just the
## individual screens in isolation): instantiates scenes/core/game.tscn
## itself, with CharacterProfileRepository isolated before it ever
## reaches _ready(), and simulates actual button presses through
## game.gd's own signal connections. Catches wiring mistakes (wrong
## signal name, missing connect()) that testing screens standalone can't.

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}
var _game: Control


func _ready() -> void:
	CharacterProfileRepository.use_isolated_test_root("startup_integration")
	_game = GAME_SCENE.instantiate()
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame

	_check("boots_to_main_menu_zero_characters", _current_screen_name() == "MainMenu")

	# 0 characters: primary button goes straight to character creation.
	_press(_get_unique("%StartGameButton"))
	await get_tree().process_frame
	_check("zero_characters_primary_opens_create", _current_screen_name() == "CharacterCreate")

	var name_edit: LineEdit = _get_unique("%NameEdit")
	name_edit.text = "Integration Hero"
	_press(_get_unique("%ConfirmButton"))
	await get_tree().process_frame
	_check("create_confirm_enters_lobby", _current_screen_name() == "Lobby")
	_check("created_character_is_selected", CharacterProfileRepository.selected_character_id == SaveManager.profile.character_id)

	# Back to the main menu: now exactly 1 character, primary button must
	# go straight to the lobby again (no selector) without an extra click.
	_call_back_to_main_menu()
	await get_tree().process_frame
	_check("returns_to_main_menu", _current_screen_name() == "MainMenu")
	_press(_get_unique("%StartGameButton"))
	await get_tree().process_frame
	_check("one_character_primary_skips_selector", _current_screen_name() == "Lobby")

	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _current_screen_name() -> String:
	var screen: Control = _game.current_screen
	return screen.name if is_instance_valid(screen) else ""


func _get_unique(unique_path: String) -> Node:
	return _game.current_screen.get_node(unique_path)


func _press(button: Node) -> void:
	(button as BaseButton).emit_signal("pressed")


func _call_back_to_main_menu() -> void:
	# Lobby -> Main Menu uses its own back-to-menu affordance; drive it the
	# same way the real UI does, via the lobby screen's public signal.
	var lobby: Control = _game.current_screen
	lobby.emit_signal("main_menu_requested")
