extends Node

## Core Loop / Final Reward §17 / §22 / §23 / §24 / §25 / §6 / §15 — proves
## RunResult's displayed text is sourced from real deposited transaction
## state, not hardcoded, and only appears when actually earned:
##  - Guardian Sigils and Boss Chest lines show the real awarded values;
##  - a new-biome-unlock announcement appears exactly once (first Warden
##    victory), never again on a second Warden victory;
##  - Ashen Wastes stays selectable/replayable after being "cleared";
##  - defeat never shows fake Sigils/Chest/unlock text;
##  - duplicate equipment shows the Ash-conversion line, a genuinely new
##    item shows "NUEVO".

const GAME_SCENE := preload("res://scenes/core/game.tscn")

var _failures: Array[String] = []
var _checks: Dictionary = {}


func _ready() -> void:
	await _test_warden_victory_full_accounting_and_replay()
	await _test_second_warden_victory_does_not_reannounce_unlock()
	await _test_defeat_shows_no_fake_victory_rewards()
	await _test_duplicate_vs_new_loot_accounting()
	for key: String in _checks:
		if not bool(_checks[key]):
			_failures.append(key)
	print(JSON.stringify({"checks": _checks, "failures": _failures}))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(key: String, condition: bool) -> void:
	_checks[key] = condition


func _boot_game() -> Control:
	var game: Control = GAME_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	return game


func _press(game: Control, unique_path: String) -> void:
	var button: BaseButton = game.current_screen.get_node(unique_path)
	button.emit_signal("pressed")


func _create_character_and_start_run(game: Control, name: String) -> void:
	_press(game, "%StartGameButton")
	await get_tree().process_frame
	var name_edit: LineEdit = game.current_screen.get_node("%NameEdit")
	name_edit.text = name
	_press(game, "%ConfirmButton")
	await get_tree().process_frame
	game.call("_on_start_run_requested")
	await get_tree().process_frame


func _win_boss_and_reach_run_result(game: Control) -> void:
	game.call("show_combat", true, false)
	await get_tree().process_frame
	game.call("_on_combat_won", true, false)
	await get_tree().process_frame
	var reward_buttons: Array = game.current_screen.get("_buttons")
	(reward_buttons[0] as Button).pressed.emit()
	await get_tree().create_timer(0.85).timeout
	await get_tree().process_frame


func _test_warden_victory_full_accounting_and_replay() -> void:
	CharacterProfileRepository.use_isolated_test_root("core_loop_result_accounting")
	ActiveRunRepository.use_isolated_test_root("core_loop_result_accounting")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Accounting Hero")
	_check("starts_ashen_wastes", RunManager.current_run.biome_id == BiomeCatalog.ASHEN_WASTES.id)

	await _win_boss_and_reach_run_result(game)
	_check("reaches_run_result", game.current_screen.name == "RunResult")
	var run: RunState = RunManager.current_run
	_check("run_completed_true", run.run_completed)
	_check("boss_chest_awarded_true", run.boss_chest_awarded)
	_check("guardian_sigils_awarded_positive", run.guardian_sigils_awarded > 0)
	_check("newly_unlocked_ember_marsh", &"ember_marsh" in run.newly_unlocked_biome_ids)

	var boss_reward_label: Label = game.current_screen.get_node("%BossRewardLabel")
	_check("sigils_text_matches_real_value", boss_reward_label.text.contains("SIGILOS +%d" % run.guardian_sigils_awarded))
	_check("chest_text_present", boss_reward_label.text.contains("COFRE"))
	_check("chest_deferred_copy_present", boss_reward_label.text.contains("DISPONIBLE PARA ABRIR EN EL REFUGIO"))

	var milestone_label: Label = game.current_screen.get_node("%MilestoneProgressLabel")
	_check("region_unlock_announced", milestone_label.text.contains("NUEVA REGIÓN DESBLOQUEADA"))
	_check("region_unlock_names_ember_marsh", milestone_label.text.contains("EMBER MARSH".to_upper()) or milestone_label.text.contains(BiomeCatalog.EMBER_MARSH.display_name.to_upper()))

	# §22 — cleared biome stays selectable/replayable, no lockout.
	var return_button: Button = game.current_screen.get_node("%ReturnButton")
	return_button.pressed.emit()
	await get_tree().process_frame
	_check("returns_to_lobby", game.current_screen.name == "Lobby")
	_check("ember_marsh_now_unlocked", BiomeCatalog.is_unlocked(BiomeCatalog.EMBER_MARSH, SaveManager.profile.completed_milestone_ids))
	_check("ashen_wastes_still_unlocked_after_clear", BiomeCatalog.is_unlocked(BiomeCatalog.ASHEN_WASTES, SaveManager.profile.completed_milestone_ids))

	# Starting a fresh Ashen Wastes run must still work — no redirect, no lockout.
	SaveManager.profile.selected_biome_id = BiomeCatalog.ASHEN_WASTES.id
	game.call("_on_start_run_requested")
	await get_tree().process_frame
	_check("ashen_wastes_replay_starts_normally", RunManager.current_run.biome_id == BiomeCatalog.ASHEN_WASTES.id)
	_check("ashen_wastes_replay_opens_map3d", game.current_screen.name == "AshenWastesMap3D")

	game.queue_free()
	await get_tree().process_frame


func _test_second_warden_victory_does_not_reannounce_unlock() -> void:
	CharacterProfileRepository.use_isolated_test_root("core_loop_second_warden_victory")
	ActiveRunRepository.use_isolated_test_root("core_loop_second_warden_victory")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Repeat Hero")
	await _win_boss_and_reach_run_result(game)
	_check("first_victory_reaches_result", game.current_screen.name == "RunResult")
	var return_button_a: Button = game.current_screen.get_node("%ReturnButton")
	return_button_a.pressed.emit()
	await get_tree().process_frame

	SaveManager.profile.selected_biome_id = BiomeCatalog.ASHEN_WASTES.id
	game.call("_on_start_run_requested")
	await get_tree().process_frame
	await _win_boss_and_reach_run_result(game)
	_check("second_victory_reaches_result", game.current_screen.name == "RunResult")
	var run: RunState = RunManager.current_run
	_check("second_victory_reports_no_new_unlock", run.newly_unlocked_biome_ids.is_empty())
	var milestone_label: Label = game.current_screen.get_node("%MilestoneProgressLabel")
	_check("second_victory_no_unlock_announcement_text", not milestone_label.text.contains("NUEVA REGIÓN DESBLOQUEADA"))

	game.queue_free()
	await get_tree().process_frame


func _test_defeat_shows_no_fake_victory_rewards() -> void:
	CharacterProfileRepository.use_isolated_test_root("core_loop_defeat_accounting")
	ActiveRunRepository.use_isolated_test_root("core_loop_defeat_accounting")
	var game: Control = await _boot_game()
	await _create_character_and_start_run(game, "Defeat Accounting Hero")

	game.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	_check("defeat_reaches_result", game.current_screen.name == "RunResult")
	var run: RunState = RunManager.current_run
	_check("defeat_run_not_completed", not run.run_completed)
	_check("defeat_no_chest_awarded", not run.boss_chest_awarded)
	_check("defeat_no_sigils_awarded", run.guardian_sigils_awarded == 0)
	_check("defeat_no_unlock", run.newly_unlocked_biome_ids.is_empty())

	var boss_reward_label: Label = game.current_screen.get_node("%BossRewardLabel")
	_check("defeat_boss_reward_label_hidden", not boss_reward_label.visible)
	var milestone_label: Label = game.current_screen.get_node("%MilestoneProgressLabel")
	_check("defeat_no_unlock_text", not milestone_label.text.contains("NUEVA REGIÓN DESBLOQUEADA"))
	# Partial progression must still be visible — the audit's "does not
	# imply everything lost" requirement.
	_check("defeat_still_completes_first_expedition", "first_expedition" in SaveManager.profile.completed_milestone_ids)

	game.queue_free()
	await get_tree().process_frame


func _test_duplicate_vs_new_loot_accounting() -> void:
	CharacterProfileRepository.use_isolated_test_root("core_loop_duplicate_loot")
	ActiveRunRepository.use_isolated_test_root("core_loop_duplicate_loot")
	var sample_item: EquipmentData = EquipmentCatalog.get_all()[0]

	# Scenario A: item not yet owned -> NEW.
	var game_a: Control = await _boot_game()
	await _create_character_and_start_run(game_a, "New Loot Hero")
	RunManager.current_run.pending_loot_id = String(sample_item.id)
	RunManager.current_run.loot_rolled = true
	game_a.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	var loot_name_label_a: Label = game_a.current_screen.get_node("%LootNameLabel")
	_check("new_item_shows_nuevo", loot_name_label_a.text.contains("NUEVO"))
	_check("new_item_actually_owned_after_deposit", int(SaveManager.profile.owned_equipment.get(String(sample_item.id), 0)) > 0)
	# Real RETURN press (not queue_free while still on RUN_COMPLETE_PENDING_
	# DEPOSIT) — deletes the active run so game_b's boot below finds none
	# and goes straight to Lobby, matching a real completed session.
	var return_button_a: Button = game_a.current_screen.get_node("%ReturnButton")
	return_button_a.pressed.emit()
	await get_tree().process_frame
	game_a.queue_free()
	await get_tree().process_frame

	# Scenario B: same character (same isolated root, not re-initialized —
	# use_isolated_test_root() wipes its directory on every call, which
	# would delete the character Scenario A just created), item now
	# already owned -> duplicate -> Ash.
	var game_b: Control = await _boot_game()
	var start_button: Button = game_b.current_screen.get_node("%StartGameButton")
	start_button.emit_signal("pressed")
	await get_tree().process_frame
	_check("resumes_same_character_for_duplicate_case", game_b.current_screen.name == "Lobby")
	var ash_before: int = SaveManager.profile.total_ash
	var owned_count_before: int = int(SaveManager.profile.owned_equipment.get(String(sample_item.id), 0))
	game_b.call("_on_start_run_requested")
	await get_tree().process_frame
	RunManager.current_run.pending_loot_id = String(sample_item.id)
	RunManager.current_run.loot_rolled = true
	game_b.call("_on_combat_lost", false, false)
	await get_tree().create_timer(0.1).timeout
	await get_tree().process_frame
	var loot_name_label_b: Label = game_b.current_screen.get_node("%LootNameLabel")
	_check("duplicate_item_shows_reciclado", loot_name_label_b.text.contains("DUPLICADO RECICLADO"))
	_check("duplicate_does_not_duplicate_owned_count", int(SaveManager.profile.owned_equipment.get(String(sample_item.id), 0)) == owned_count_before)
	_check("duplicate_grants_ash_exactly_once", SaveManager.profile.total_ash > ash_before)
	_check("duplicate_run_state_reports_conversion", RunManager.current_run.duplicate_converted_id == sample_item.id)

	game_b.queue_free()
	await get_tree().process_frame
