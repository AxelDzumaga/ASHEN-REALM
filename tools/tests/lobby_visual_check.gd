extends Node

const LOBBY_SCENE := preload("res://scenes/lobby/lobby.tscn")


func _ready() -> void:
	var lobby: Control = LOBBY_SCENE.instantiate()
	add_child(lobby)
	await get_tree().process_frame
	await get_tree().process_frame
	var output_path := ProjectSettings.globalize_path("res://build/lobby_visual_check/lobby.png")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(output_path)
	print("LOBBY_VISUAL_CHECK path=%s error=%d" % [output_path, error])
	get_tree().quit(0 if error == OK else 1)
