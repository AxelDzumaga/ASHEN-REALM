extends Node

## Core Loop / Final Reward §41 — real (non-headless) engineering render
## smoke. Not a Human Visual Playtest. Validates, under a real GPU
## rendering context (this project's --headless dummy renderer cannot
## produce real frames):
##  A. defeat first expedition -> Refuge -> Ember Marsh remains locked.
##  B. Warden victory -> RunResult shows XP/Ash/loot/Boss Reward/Sigils/
##     Boss Chest/new milestone/Ember Marsh unlocked.
##  C. Return Refuge -> Ember Marsh available, Ashen Wastes still selectable.
##  D. Second Warden victory -> no duplicate "new region unlocked" text.

const GAME_SCENE := preload("res://scenes/core/game.tscn")
const OUTPUT_DIR := "res://build/core_loop_render_smoke"

var _game: Control
var _shots: Array[String] = []


func _ready() -> void:
	CharacterProfileRepository.use_isolated_test_root("core_loop_render_smoke")
	ActiveRunRepository.use_isolated_test_root("core_loop_render_smoke")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_game = GAME_SCENE.instantiate()
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- A: defeat first expedition ---
	_press("%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = _game.current_screen.get_node("%NameEdit")
	name_edit.text = "Smoke Hero"
	_press("%ConfirmButton")
	await get_tree().process_frame
	_game.call("_on_start_run_requested")
	await get_tree().process_frame
	await _capture("01_map3d_first_expedition")

	_game.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.15).timeout
	await get_tree().process_frame
	await _capture("02_defeat_result")
	print("A_first_expedition_completed=%s" % ("first_expedition" in SaveManager.profile.completed_milestone_ids))
	print("A_ember_marsh_locked_after_defeat=%s" % (not BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids)))

	var return_button_a: Button = _game.current_screen.get_node("%ReturnButton")
	return_button_a.pressed.emit()
	await get_tree().process_frame
	await _capture("03_refuge_after_defeat")

	# --- B: Warden victory, full accounting ---
	_game.call("_on_start_run_requested")
	await get_tree().process_frame
	await _capture("04_map3d_second_expedition")
	_game.call("show_combat", true, false)
	await get_tree().process_frame
	await _capture("05_boss_combat")
	_game.call("_on_combat_won", true, false)
	await get_tree().process_frame
	await _capture("06_boss_reward_choice")
	var reward_buttons: Array = _game.current_screen.get("_buttons")
	(reward_buttons[0] as Button).pressed.emit()
	await get_tree().create_timer(0.9).timeout
	await get_tree().process_frame
	await _capture("07_warden_victory_result")
	var boss_reward_label: Label = _game.current_screen.get_node("%BossRewardLabel")
	var milestone_label: Label = _game.current_screen.get_node("%MilestoneProgressLabel")
	print("B_boss_reward_text=%s" % boss_reward_label.text.replace("\n", " | "))
	print("B_milestone_text=%s" % milestone_label.text.replace("\n", " | "))
	print("B_ember_marsh_unlocked=%s" % BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))

	# --- C: Refuge, both regions selectable ---
	var return_button_b: Button = _game.current_screen.get_node("%ReturnButton")
	return_button_b.pressed.emit()
	await get_tree().process_frame
	await _capture("08_refuge_after_warden_victory")
	print("C_ember_marsh_selectable=%s" % BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))
	print("C_ashen_wastes_still_selectable=%s" % BiomeCatalog.is_unlocked(BiomeCatalog.ASHEN_WASTES, SaveManager.profile.completed_milestone_ids))

	# --- D: second Warden victory, no duplicate unlock announcement ---
	SaveManager.profile.selected_biome_id = BiomeCatalog.ASHEN_WASTES.id
	_game.call("_on_start_run_requested")
	await get_tree().process_frame
	_game.call("show_combat", true, false)
	await get_tree().process_frame
	_game.call("_on_combat_won", true, false)
	await get_tree().process_frame
	var reward_buttons_2: Array = _game.current_screen.get("_buttons")
	(reward_buttons_2[0] as Button).pressed.emit()
	await get_tree().create_timer(0.9).timeout
	await get_tree().process_frame
	await _capture("09_second_warden_victory_result")
	var milestone_label_2: Label = _game.current_screen.get_node("%MilestoneProgressLabel")
	print("D_milestone_text=%s" % milestone_label_2.text.replace("\n", " | "))
	print("D_no_duplicate_unlock_announcement=%s" % (not milestone_label_2.text.contains("NUEVA REGIÓN DESBLOQUEADA")))

	print(JSON.stringify({"shots": _shots, "done": true}))
	get_tree().quit(0)


func _press(unique_path: String) -> void:
	var button: BaseButton = _game.current_screen.get_node(unique_path)
	button.emit_signal("pressed")


func _capture(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [OUTPUT_DIR, label]
	var error: Error = image.save_png(path)
	print("CAPTURE %s -> %s error=%d" % [label, ProjectSettings.globalize_path(path), error])
	_shots.append(label)
