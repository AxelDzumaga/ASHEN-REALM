extends Control

## SELECCIONAR PERSONAJE — shows occupied, empty and corrupt slots (up to
## MAX_CHARACTER_SLOTS). Functional UI only: slots are built at runtime
## since the count varies (0-3), not authored per-slot in the scene.
## Deletion requires a two-step confirmation (press once to arm, press
## again to actually delete) rather than final art like hold-to-confirm —
## per the approved design, that's an acceptable placeholder for now.

signal character_selected(character_id: String)
signal create_requested
signal back_requested

@onready var slots_container: VBoxContainer = %SlotsContainer
@onready var back_button: Button = %BackButton

var _pending_delete_id: String = ""


func _ready() -> void:
	back_button.pressed.connect(func() -> void: back_requested.emit())
	CharacterProfileRepository.characters_changed.connect(_on_characters_changed)
	_refresh()


func _on_characters_changed() -> void:
	_pending_delete_id = ""
	_refresh()


## Rebuilds the slot rows from the current repository state. Does NOT
## reset _pending_delete_id itself — it is also called from the "arm"
## step of the delete confirmation to redraw with the new armed state,
## and resetting it here would wipe that state before it's ever shown.
## Callers that need the armed state cleared (an actual deletion
## completing, or CharacterProfileRepository.characters_changed firing
## for any other reason) clear it explicitly before calling this.
func _refresh() -> void:
	for child: Node in slots_container.get_children():
		child.queue_free()
	var characters: Array = CharacterProfileRepository.list_characters()
	for entry: Dictionary in characters:
		slots_container.add_child(_build_occupied_slot(entry))
	var empty_count: int = CharacterProfileRepository.MAX_CHARACTER_SLOTS - characters.size()
	for _i: int in empty_count:
		slots_container.add_child(_build_empty_slot())


func _build_occupied_slot(entry: Dictionary) -> Control:
	var character_id: String = String(entry.get("character_id", ""))
	var corrupt: bool = bool(entry.get("corrupt", false))
	var row := HBoxContainer.new()
	row.set_meta("character_id", character_id)
	row.add_theme_constant_override("separation", 10)

	var select_button := Button.new()
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.custom_minimum_size = Vector2(0, 88)
	if corrupt:
		select_button.text = "RANURA CORRUPTA"
		select_button.disabled = true
	else:
		var display_name: String = String(entry.get("display_name", ""))
		var level: int = int(entry.get("player_level", 1))
		select_button.text = "%s\nNIVEL %d" % [display_name, level]
		select_button.pressed.connect(_on_select_pressed.bind(character_id))
	row.add_child(select_button)

	var delete_button := Button.new()
	delete_button.custom_minimum_size = Vector2(120, 88)
	delete_button.theme_type_variation = &"SecondaryButton"
	var armed: bool = _pending_delete_id == character_id
	delete_button.text = "¿SEGURO?" if armed else "ELIMINAR"
	delete_button.pressed.connect(_on_delete_pressed.bind(character_id))
	row.add_child(delete_button)

	return row


func _build_empty_slot() -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 88)
	button.theme_type_variation = &"TitleSecondaryButton"
	button.text = "RANURA VACÍA\nCREAR PERSONAJE"
	button.pressed.connect(func() -> void: create_requested.emit())
	return button


func _on_select_pressed(character_id: String) -> void:
	character_selected.emit(character_id)


## First press arms deletion (shows a confirm state); a second press on
## the same slot actually deletes. Pressing delete on a different slot
## re-arms on that one instead, so stale armed state can never carry over
## to the wrong character.
func _on_delete_pressed(character_id: String) -> void:
	if _pending_delete_id == character_id:
		_pending_delete_id = ""
		CharacterProfileRepository.delete_character(character_id)
	else:
		_pending_delete_id = character_id
		_refresh()
