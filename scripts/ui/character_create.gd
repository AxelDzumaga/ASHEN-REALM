extends Control

## Name-only character creation (approved design: no class/race/appearance/
## stat allocation at creation). On success the new character becomes the
## selected character (CharacterProfileRepository.create_character() already
## does that) and this screen reports success so game.gd can enter the lobby.

signal created(character_id: String)
signal back_requested

@onready var name_edit: LineEdit = %NameEdit
@onready var error_label: Label = %ErrorLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var back_button: Button = %BackButton


func _ready() -> void:
	name_edit.max_length = CharacterProfileRepository.MAX_DISPLAY_NAME_LENGTH
	name_edit.text_submitted.connect(func(_text: String) -> void: _on_confirm_pressed())
	confirm_button.pressed.connect(_on_confirm_pressed)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	error_label.visible = false
	name_edit.grab_focus()


func _on_confirm_pressed() -> void:
	var result: Dictionary = CharacterProfileRepository.create_character(name_edit.text)
	if not bool(result.get("success", false)):
		error_label.text = _error_text(String(result.get("error", "")))
		error_label.visible = true
		return
	created.emit(String(result.get("character_id", "")))


func _error_text(error_code: String) -> String:
	match error_code:
		"empty_name":
			return "Escribe un nombre para tu personaje."
		"slots_full":
			return "Ya tienes el máximo de personajes."
		_:
			return "No se pudo crear el personaje. Intenta de nuevo."
