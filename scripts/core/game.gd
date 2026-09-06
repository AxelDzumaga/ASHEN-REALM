extends Control

const MAIN_MENU_SCENE := preload("res://scenes/lobby/main_menu.tscn")
const LOBBY_SCENE := preload("res://scenes/lobby/lobby.tscn")
const PERMANENT_UPGRADES_SCENE := preload("res://scenes/lobby/permanent_upgrades.tscn")
const EQUIPMENT_SCENE := preload("res://scenes/lobby/equipment.tscn")
const REGION_SELECTION_SCENE := preload("res://scenes/lobby/region_selection.tscn")
const SKILL_SELECTION_SCENE := preload("res://scenes/lobby/skill_selection.tscn")
const COMPANION_SELECTION_SCENE := preload("res://scenes/lobby/companion_selection.tscn")
const CODEX_SCENE := preload("res://scenes/lobby/codex.tscn")
const HOW_TO_PLAY_SCENE := preload("res://scenes/lobby/how_to_play.tscn")
const SETTINGS_SCENE := preload("res://scenes/lobby/settings.tscn")
const SHOP_SCENE := preload("res://scenes/lobby/shop.tscn")
const REFINEMENT_SCENE := preload("res://scenes/lobby/refinement.tscn")
const TUTORIAL_OVERLAY_SCENE := preload("res://scenes/ui/tutorial_overlay.tscn")
const EVENT_SCENE := preload("res://scenes/events/event_screen.tscn")
const TREASURE_SCENE := preload("res://scenes/treasure/treasure_screen.tscn")
const BOARD_SCENE := preload("res://scenes/board/board.tscn")
const MAP3D_SCENE := preload("res://scenes/board3d/ashen_wastes_map_3d.tscn")
const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const UPGRADE_SELECTION_SCENE := preload("res://scenes/upgrades/upgrade_selection.tscn")
const SKILL_AUGMENT_SELECTION_SCENE := preload("res://scenes/upgrades/skill_augment_selection.tscn")
const BOSS_REWARD_SCENE := preload("res://scenes/rewards/boss_reward.tscn")
const RUN_RESULT_SCENE := preload("res://scenes/results/run_result.tscn")
const FeatureFlagsSource = preload("res://scripts/core/feature_flags.gd")
const MapSandboxContextSource = preload("res://scripts/board3d/map_sandbox_context.gd")

var current_screen: Control
var board_screen: Control
var transition_overlay: ColorRect
var codex_toast: Label
var codex_toast_tween: Tween
var pause_button: Button
var pause_overlay: Control
var pause_panel: PanelContainer
var pause_content: VBoxContainer
var _settings_return: Callable
var _pause_source_screen: Control
var _pause_buttons: Array[Button] = []
var _pause_confirmation_visible: bool = false
var _pause_return_focus_index: int = 0
var _pending_post_combat_is_elite: bool = false
var _resume_input_guard: Control
var _tutorial_input_guard: Control
var _tutorial_input_guard_generation: int = 0
var _paused_by_lifecycle: bool = false
var _exit_overlay: Control
var _tutorial_overlay: TutorialOverlay
var _map3d_prototype_mode: bool = false
var _run_terminal_transition_started: bool = false


func _ready() -> void:
	theme = VisualTheme.create_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	transition_overlay = ColorRect.new()
	transition_overlay.color = VisualTheme.BACKGROUND_DEEP
	transition_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_overlay.z_index = 100
	add_child(transition_overlay)
	codex_toast = Label.new()
	codex_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	codex_toast.position = Vector2(-180, 24)
	codex_toast.size = Vector2(360, 72)
	codex_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	codex_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	codex_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	codex_toast.add_theme_font_size_override("font_size", 18)
	codex_toast.add_theme_stylebox_override("normal", VisualTheme.panel_style(VisualTheme.CARD, VisualTheme.EMBER_BRIGHT, 2, 10))
	codex_toast.visible = false
	codex_toast.z_index = 110
	add_child(codex_toast)
	_build_pause_ui()
	_build_exit_confirmation()
	_build_resume_input_guard()
	_build_tutorial_input_guard()
	_tutorial_overlay = TUTORIAL_OVERLAY_SCENE.instantiate()
	_tutorial_overlay.z_index = 200
	add_child(_tutorial_overlay)
	_tutorial_overlay.input_guard_requested.connect(_guard_tutorial_input)
	SafeAreaManager.register_screen(_tutorial_overlay)
	SaveManager.codex_discovered.connect(_on_codex_discovered)
	if OS.is_debug_build() and "--map3d-prototype" in OS.get_cmdline_user_args():
		_launch_map3d_prototype.call_deferred()
		return
	var visual_slice_mode: StringName = DebugConfig.get_visual_slice_mode()
	if visual_slice_mode.is_empty():
		show_main_menu()
	else:
		_launch_visual_slice.call_deferred(visual_slice_mode)


func _launch_visual_slice(mode: StringName) -> void:
	var capture_mode: StringName = mode
	var stage74_scenarios: Dictionary[StringName, StringName] = {
		&"stage74_refuge": &"stage72_refuge",
		&"stage74_equipment": &"stage72_equipment",
		&"stage74_item_locked": &"stage72_equipment",
		&"stage74_results": &"stage72_results",
		&"stage74_combat": &"normal",
		&"stage74_statuses": &"stage72_statuses",
		&"stage74_region": &"stage72_region",
		&"stage74_event": &"event_risk_reward",
		&"stage74_treasure": &"treasure_choice",
		&"stage74_boss": &"boss",
		&"stage75_main_menu_before": &"stage75_main_menu",
		&"stage75_refuge_before": &"stage72_refuge",
		&"stage75_main_menu_after": &"stage75_main_menu",
		&"stage75_refuge_after": &"stage72_refuge",
		&"stage75_equipment_context": &"stage72_equipment",
		&"stage76_main_menu": &"stage75_main_menu",
		&"stage76_refuge": &"stage72_refuge",
		&"stage76_region": &"stage72_region",
		&"stage76_equipment": &"stage72_equipment",
		&"stage76_results": &"stage72_results",
		&"stage76_combat": &"normal",
		&"stage76_boss": &"boss",
		&"stage76_event": &"event_risk_reward",
		&"stage76_treasure": &"treasure_choice",
	}
	mode = stage74_scenarios.get(mode, mode)
	RunManager.start_new_run(590059)
	var slice_biome: BiomeData = BiomeCatalog.get_or_default(DebugConfig.get_visual_slice_biome())
	RunManager.current_run.biome_data = slice_biome
	RunManager.current_run.biome_id = slice_biome.id
	BoardGenerator.generate_for_run(RunManager.current_run, slice_biome, 590059)
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	RunManager.current_run.active_skill_id = ActiveSkillCatalog.EMBER_SLASH.id
	RunManager.current_run.equipped_companion_id = CompanionCatalog.EMBER_HOUND_ID
	RunManager.current_run.recalculate_synergies()
	if String(mode).begins_with("meta_") or String(mode).begins_with("stage72_"):
		SaveManager.profile.completed_tutorials = [
			String(TutorialCatalog.PERMANENT_UPGRADES),
			String(TutorialCatalog.EQUIPMENT_SCREEN),
			String(TutorialCatalog.RUN_RESULTS),
		]
	if mode == &"stage75_main_menu":
		show_main_menu()
	elif mode == &"stage72_refuge":
		SaveManager.profile.player_level = 3
		SaveManager.profile.player_xp = 74
		show_lobby()
	elif mode == &"stage72_equipment":
		SaveManager.profile.player_level = 3
		SaveManager.profile.owned_equipment = {"ashen_blade": 1, "wardens_edge": 1, "warden_plate": 1}
		SaveManager.profile.equipped_weapon_id = "ashen_blade"
		show_equipment()
	elif mode == &"stage72_region":
		SaveManager.profile.player_level = 4
		SaveManager.profile.completed_milestone_ids = ["first_expedition"]
		SaveManager.profile.selected_biome_id = &"ember_marsh"
		show_region_selection()
	elif mode == &"stage72_results":
		RunManager.current_run.pending_loot_id = "wardens_edge"
		RunManager.current_run.loot_rolled = true
		RunManager.current_run.rewards_deposited = true
		RunManager.current_run.player_xp_earned = 118
		RunManager.current_run.player_level_before = 3
		RunManager.current_run.player_level_after = 4
		RunManager.current_run.player_xp_after = 22
		RunManager.current_run.player_levels_gained = 1
		show_run_result(false)
	elif mode == &"stage72_affinity":
		show_codex()
		await get_tree().process_frame
		if current_screen != null and current_screen.has_method("debug_show_entry"):
			current_screen.call("debug_show_entry", CodexCatalog.BOSSES, &"ashen_warden")
	elif mode == &"stage72_statuses":
		show_combat(false, false)
		await get_tree().create_timer(0.25).timeout
		if current_screen != null and current_screen.has_method("debug_prepare_stage72_statuses"):
			current_screen.call("debug_prepare_stage72_statuses")
	elif mode == &"meta_unlocks":
		SaveManager.profile.total_ash = 180
		SaveManager.profile.completed_milestone_ids = ["first_expedition", "first_victory"]
		SaveManager.profile.owned_meta_unlock_ids = [MetaUnlockCatalog.EMBER_FOCUS]
		SaveManager.profile.selected_starting_option_id = MetaUnlockCatalog.EMBER_FOCUS
		show_permanent_upgrades()
	elif mode == &"meta_duplicates":
		SaveManager.profile.owned_equipment["ashen_blade"] = 3
		SaveManager.profile.equipped_weapon_id = "ashen_blade"
		show_equipment()
	elif mode == &"meta_results":
		RunManager.current_run.pending_loot_id = "ashen_blade"
		RunManager.current_run.loot_rolled = true
		RunManager.current_run.rewards_deposited = true
		RunManager.current_run.duplicate_converted_id = &"ashen_blade"
		RunManager.current_run.duplicate_ash_awarded = 10
		RunManager.current_run.starting_option_id = MetaUnlockCatalog.EMBER_FOCUS
		show_run_result(false)
	elif String(mode).begins_with("event_"):
		var event_screen := EVENT_SCENE.instantiate()
		var event_pool: Array[EventData] = []
		if mode == &"event_chain":
			RunManager.current_run.add_event_flag(&"helped_lost_wanderer")
			for event: EventData in slice_biome.event_pool:
				if event.id == &"wanderer_return": event_pool.append(event)
		else:
			var wanted_id: StringName = &"ashen_shrine" if mode == &"event_risk_reward" else &"ember_well"
			for event: EventData in slice_biome.event_pool:
				if event.id == wanted_id: event_pool.append(event)
		event_screen.configure(event_pool if not event_pool.is_empty() else slice_biome.event_pool)
		event_screen.event_resolved.connect(_on_event_resolved)
		_set_screen(event_screen, true)
	elif String(mode).begins_with("treasure_"):
		if mode == &"treasure_build": RunManager.current_run.add_boon(&"burning_strike")
		show_treasure()
	elif String(mode).begins_with("route_"):
		show_board()
		await get_tree().create_timer(0.45).timeout
		if current_screen != null and current_screen.has_method("debug_prepare_route_visual"):
			current_screen.call("debug_prepare_route_visual", mode)
	else:
		show_combat(mode in [&"boss", &"intent_boss"], mode == &"elite")
	if String(mode).begins_with("attack") and current_screen != null and current_screen.has_method("debug_trigger_visual_attack"):
		await current_screen.call("debug_trigger_visual_attack")
	if mode == &"ember" and current_screen != null and current_screen.has_method("debug_trigger_visual_skill"):
		await current_screen.call("debug_trigger_visual_skill", &"ember_slash")
	if DebugConfig.should_capture_visual_slice():
		var capture_delay: float = 1.7
		if mode == &"attack_start":
			capture_delay = 0.12
		elif mode == &"attack" or mode == &"attack_contact":
			capture_delay = 0.34
		elif mode == &"attack_recovery":
			capture_delay = 0.55
		elif mode == &"ember":
			capture_delay = 0.34
		elif String(mode).begins_with("route_"):
			capture_delay = 1.6
		elif String(mode).begins_with("event_") or String(mode).begins_with("treasure_") or String(mode).begins_with("meta_"):
			capture_delay = 1.0
		await get_tree().create_timer(capture_delay).timeout
		_capture_visual_slice(capture_mode)


func _capture_visual_slice(mode: StringName) -> void:
	# Keep the development capture output outside export dependency scans.
	var output_directory: String = ProjectSettings.globalize_path("res://" + "build").path_join("visual_slice")
	DirAccess.make_dir_recursive_absolute(output_directory)
	var image: Image = get_viewport().get_texture().get_image()
	var capture_names: Dictionary[StringName, String] = {
		&"intent_multi": "61_multi_enemy_intents.png",
		&"intent_support": "61_support_intent.png",
		&"intent_boss": "61_boss_intent.png",
		&"intent_detail": "61_target_detail.png",
		&"route_choice": "67_route_choice.png",
		&"route_elite_heal": "67_elite_vs_heal.png",
		&"route_treasure": "67_treasure_choice.png",
		&"route_single": "67_single_destination.png",
		&"event_choice": "68_event_choice.png",
		&"event_risk_reward": "68_event_risk_reward.png",
		&"event_chain": "68_event_chain.png",
		&"treasure_choice": "68_treasure_choice.png",
		&"treasure_build": "68_treasure_build.png",
		&"meta_unlocks": "69_meta_unlocks.png",
		&"meta_duplicates": "69_duplicate_sink.png",
		&"meta_results": "69_meta_results.png",
		&"stage72_refuge": "01_refuge_level.png",
		&"stage72_equipment": "02_equipment_requirement.png",
		&"stage72_region": "03_region_level.png",
		&"stage72_statuses": "04_combat_statuses.png",
		&"stage72_affinity": "05_enemy_affinity.png",
		&"stage72_results": "06_results_xp.png",
		&"stage74_refuge": "01_refuge.png",
		&"stage74_equipment": "02_equipment.png",
		&"stage74_item_locked": "03_item_locked.png",
		&"stage74_results": "04_loot_results.png",
		&"stage74_combat": "05_combat.png",
		&"stage74_statuses": "06_statuses.png",
		&"stage74_region": "07_region.png",
		&"stage74_event": "08_event.png",
		&"stage74_treasure": "09_treasure.png",
		&"stage74_boss": "10_boss.png",
		&"stage75_main_menu_before": "01_main_menu_before.png",
		&"stage75_refuge_before": "02_refuge_before.png",
		&"stage75_main_menu_after": "01_main_menu_after.png",
		&"stage75_refuge_after": "02_refuge_after.png",
		&"stage75_equipment_context": "03_equipment_context.png",
		&"stage76_main_menu": "01_main_menu.png",
		&"stage76_refuge": "02_refuge.png",
		&"stage76_region": "03_regions.png",
		&"stage76_equipment": "04_equipment_preview.png",
		&"stage76_results": "05_results_loot.png",
		&"stage76_combat": "06_combat.png",
		&"stage76_boss": "07_boss.png",
		&"stage76_event": "08_event.png",
		&"stage76_treasure": "09_treasure.png",
	}
	var output_name: String = capture_names.get(mode, "60d_%s.png" % String(mode))
	if mode == &"route_choice" and RunManager.current_run.biome_id == &"ember_marsh":
		output_name = "67_route_choice_ember_marsh.png"
	if String(mode).begins_with("stage72_"):
		output_directory = ProjectSettings.globalize_path("res://" + "build/stage72/visual")
		DirAccess.make_dir_recursive_absolute(output_directory)
	elif String(mode).begins_with("stage74_"):
		output_directory = ProjectSettings.globalize_path("res://" + "build/stage74/visual")
		DirAccess.make_dir_recursive_absolute(output_directory)
	elif mode in [&"stage75_main_menu_before", &"stage75_refuge_before"]:
		output_directory = ProjectSettings.globalize_path("res://" + "build/stage75/before")
		DirAccess.make_dir_recursive_absolute(output_directory)
	elif String(mode).begins_with("stage75_"):
		output_directory = ProjectSettings.globalize_path("res://" + "build/stage75/after")
		DirAccess.make_dir_recursive_absolute(output_directory)
	elif String(mode).begins_with("stage76_"):
		output_directory = ProjectSettings.globalize_path("res://" + "build/stage76/visual")
		DirAccess.make_dir_recursive_absolute(output_directory)
	var output_path: String = output_directory.path_join(output_name)
	var error: Error = image.save_png(output_path)
	print("VISUAL_SLICE_CAPTURE mode=%s path=%s error=%d" % [mode, output_path, error])
	# Las sesiones de captura son harnesses de desarrollo aislados: cerrar aquí
	# evita dejar procesos GPU abiertos después de escribir la imagen.
	get_tree().quit(0 if error == OK else 1)


func _on_codex_discovered(display_name: String) -> void:
	if DebugConfig.is_visual_slice_enabled():
		return
	if codex_toast_tween != null and codex_toast_tween.is_valid():
		codex_toast_tween.kill()
	codex_toast.text = "ARCHIVO ACTUALIZADO\n%s" % display_name
	codex_toast.modulate.a = 0.0
	codex_toast.visible = true
	move_child(codex_toast, get_child_count() - 1)
	codex_toast_tween = create_tween()
	codex_toast_tween.tween_property(codex_toast, "modulate:a", 1.0, 0.16)
	codex_toast_tween.tween_interval(1.15)
	codex_toast_tween.tween_property(codex_toast, "modulate:a", 0.0, 0.2)
	codex_toast_tween.finished.connect(func() -> void: codex_toast.visible = false)


func show_main_menu() -> void:
	_run_terminal_transition_started = false
	_map3d_prototype_mode = false
	AudioManager.set_music_state(AudioManager.MusicState.LOBBY)
	RunManager.end_run()
	_discard_board()
	var main_menu := MAIN_MENU_SCENE.instantiate()
	main_menu.start_game_requested.connect(show_lobby)
	main_menu.settings_requested.connect(show_settings.bind(show_main_menu))
	main_menu.how_to_play_requested.connect(show_how_to_play_from_main)
	_set_screen(main_menu)


func show_lobby() -> void:
	_run_terminal_transition_started = false
	_map3d_prototype_mode = false
	AudioManager.set_music_state(AudioManager.MusicState.LOBBY)
	RunManager.end_run()
	_discard_board()
	var lobby := LOBBY_SCENE.instantiate()
	lobby.start_run_requested.connect(_on_start_run_requested)
	lobby.permanent_upgrades_requested.connect(show_permanent_upgrades)
	lobby.equipment_requested.connect(show_equipment)
	lobby.region_selection_requested.connect(show_region_selection)
	lobby.skill_selection_requested.connect(show_skill_selection)
	lobby.companion_selection_requested.connect(show_companion_selection)
	lobby.codex_requested.connect(show_codex)
	lobby.how_to_play_requested.connect(show_how_to_play)
	lobby.settings_requested.connect(show_settings.bind(show_lobby))
	lobby.shop_requested.connect(show_shop)
	lobby.refinement_requested.connect(show_refinement)
	lobby.main_menu_requested.connect(show_main_menu)
	_set_screen(lobby)


func show_permanent_upgrades() -> void:
	var permanent_upgrades := PERMANENT_UPGRADES_SCENE.instantiate()
	permanent_upgrades.back_requested.connect(show_lobby)
	_set_screen(permanent_upgrades)


func show_equipment() -> void:
	var equipment := EQUIPMENT_SCENE.instantiate()
	equipment.back_requested.connect(show_lobby)
	_set_screen(equipment)


func show_shop() -> void:
	var shop := SHOP_SCENE.instantiate()
	shop.back_requested.connect(show_lobby)
	_set_screen(shop)


func show_refinement() -> void:
	var refinement := REFINEMENT_SCENE.instantiate()
	refinement.back_requested.connect(show_lobby)
	_set_screen(refinement)


func show_region_selection() -> void:
	var region_selection := REGION_SELECTION_SCENE.instantiate()
	region_selection.back_requested.connect(show_lobby)
	_set_screen(region_selection)


func show_skill_selection() -> void:
	var skill_selection := SKILL_SELECTION_SCENE.instantiate()
	skill_selection.back_requested.connect(show_lobby)
	_set_screen(skill_selection)


func show_companion_selection() -> void:
	var companion_selection := COMPANION_SELECTION_SCENE.instantiate()
	companion_selection.back_requested.connect(show_lobby)
	_set_screen(companion_selection)


func show_codex() -> void:
	var codex := CODEX_SCENE.instantiate()
	codex.back_requested.connect(show_lobby)
	_set_screen(codex)


func show_how_to_play() -> void:
	var help_screen := HOW_TO_PLAY_SCENE.instantiate()
	help_screen.back_requested.connect(show_lobby)
	_set_screen(help_screen)


func show_how_to_play_from_main() -> void:
	var help_screen := HOW_TO_PLAY_SCENE.instantiate()
	help_screen.back_requested.connect(show_main_menu)
	_set_screen(help_screen)


func show_settings(return_action: Callable = Callable()) -> void:
	_settings_return = return_action if return_action.is_valid() else show_main_menu
	var settings := SETTINGS_SCENE.instantiate()
	settings.back_requested.connect(_on_settings_back_requested)
	_set_screen(settings)


func show_board() -> void:
	AudioManager.set_music_state(AudioManager.MusicState.BOARD)
	if not is_instance_valid(board_screen):
		board_screen = MAP3D_SCENE.instantiate() if FeatureFlagsSource.USE_3D_BOARD or _map3d_prototype_mode else BOARD_SCENE.instantiate()
		if _map3d_prototype_mode and board_screen.has_method("configure_playtest_mode"):
			board_screen.call("configure_playtest_mode", true)
		_connect_board_screen(board_screen)
	_set_screen(board_screen)


func _connect_board_screen(screen: Control) -> void:
	screen.pause_requested.connect(_open_pause)
	screen.combat_requested.connect(show_combat)
	screen.event_requested.connect(show_event)
	screen.treasure_requested.connect(show_treasure)


func _launch_map3d_prototype() -> void:
	_run_terminal_transition_started = false
	_map3d_prototype_mode = true
	TelemetryManager.analytics_enabled = false
	RunManager.current_run = MapSandboxContextSource.create_run()
	_discard_board()
	show_board()


func show_combat(is_boss: bool = false, is_elite: bool = false) -> void:
	if _run_terminal_transition_started or not RunManager.has_active_run():
		return
	AudioManager.set_music_state(AudioManager.MusicState.BOSS if is_boss else AudioManager.MusicState.COMBAT)
	var combat := COMBAT_SCENE.instantiate()
	combat.configure(RunManager.current_run.biome_data, is_boss, is_elite)
	combat.combat_won.connect(_on_combat_won)
	combat.combat_lost.connect(_on_combat_lost)
	_set_screen(combat, true)


func show_event() -> void:
	AudioManager.set_music_state(AudioManager.MusicState.BOARD)
	var event_screen := EVENT_SCENE.instantiate()
	event_screen.configure(RunManager.current_run.biome_data.event_pool)
	event_screen.event_resolved.connect(_on_event_resolved)
	_set_screen(event_screen, true)


func show_treasure() -> void:
	AudioManager.set_music_state(AudioManager.MusicState.BOARD)
	var treasure_screen := TREASURE_SCENE.instantiate()
	treasure_screen.continue_requested.connect(_on_treasure_continue_requested)
	_set_screen(treasure_screen, true)


func show_upgrade_selection(context: UpgradeRewardContext.Type = UpgradeRewardContext.Type.NORMAL) -> void:
	AudioManager.set_music_state(AudioManager.MusicState.BOARD)
	var upgrade_selection := UPGRADE_SELECTION_SCENE.instantiate()
	upgrade_selection.configure(context)
	upgrade_selection.upgrade_selected.connect(_on_upgrade_selected)
	_set_screen(upgrade_selection)


func show_level_up_selection() -> void:
	AudioManager.set_music_state(AudioManager.MusicState.BOARD)
	var run: RunState = RunManager.current_run
	var options: Array[UpgradeData] = []
	if not run.pending_level_up_option_ids.is_empty():
		for upgrade_id: StringName in run.pending_level_up_option_ids:
			var stored_upgrade: UpgradeData = UpgradeCatalog.get_by_id(upgrade_id)
			if stored_upgrade != null:
				options.append(stored_upgrade)
	else:
		options = RunLevelConfig.generate_options(run)
		run.level_up_choices_generated += 1
		for upgrade: UpgradeData in options:
			run.pending_level_up_option_ids.append(upgrade.id)
	if options.is_empty():
		run.pending_level_ups = 0
		_continue_post_combat_rewards()
		return
	var level_up_selection := UPGRADE_SELECTION_SCENE.instantiate()
	level_up_selection.configure_level_up(options)
	level_up_selection.upgrade_selected.connect(_on_level_up_upgrade_selected)
	_set_screen(level_up_selection)


func show_skill_augment_selection() -> void:
	AudioManager.set_music_state(AudioManager.MusicState.BOARD)
	var augment_selection := SKILL_AUGMENT_SELECTION_SCENE.instantiate()
	augment_selection.augment_selected.connect(_on_skill_augment_selected)
	_set_screen(augment_selection)


func show_boss_reward() -> void:
	AudioManager.set_music_state(AudioManager.MusicState.BOSS)
	var boss_reward := BOSS_REWARD_SCENE.instantiate()
	boss_reward.reward_selected.connect(_on_boss_reward_selected)
	_set_screen(boss_reward)


func show_run_result(is_victory: bool) -> void:
	AudioManager.set_music_state(AudioManager.MusicState.RESULTS)
	var run_result := RUN_RESULT_SCENE.instantiate()
	run_result.configure(is_victory)
	run_result.return_to_lobby_requested.connect(_on_run_result_return_requested)
	_set_screen(run_result)


func _set_screen(next_screen: Control, preserve_current: bool = false) -> void:
	# Set the destination before add_child(), because screen _ready() methods may
	# request tutorials synchronously. This also cancels stale requests first.
	TutorialManager.set_context(_tutorial_context_for_screen(next_screen), next_screen)
	if is_instance_valid(current_screen) and current_screen != next_screen:
		if current_screen.has_method("set_hud_suspended"):
			current_screen.call("set_hud_suspended", true)
		if preserve_current:
			current_screen.hide()
		else:
			current_screen.queue_free()

	current_screen = next_screen
	current_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if current_screen.get_parent() == null:
		add_child(current_screen)
	_add_screen_backdrop(current_screen)
	SafeAreaManager.register_screen(current_screen)
	current_screen.show()
	if current_screen.has_method("set_hud_suspended"):
		current_screen.call("set_hud_suspended", false)
	_update_pause_button()
	move_child(transition_overlay, get_child_count() - 1)
	# GUI hit-testing follows sibling order even when CanvasItem z-index draws the
	# tutorial above the transition blocker. Tutorials are requested synchronously
	# from screen _ready(), so keep the visible modal last as well as visually above.
	if is_instance_valid(_tutorial_overlay):
		move_child(_tutorial_overlay, get_child_count() - 1)
	_play_screen_fade()


func _tutorial_context_for_screen(screen: Control) -> StringName:
	match screen.name:
		"MainMenu":
			return TutorialManager.CONTEXT_MAIN_MENU
		"Lobby":
			return TutorialManager.CONTEXT_LOBBY
		"RegionSelection":
			return TutorialManager.CONTEXT_REGION
		"Board":
			return TutorialManager.CONTEXT_BOARD
		"AshenWastesMap3D":
			return TutorialManager.CONTEXT_BOARD
		"Combat":
			return TutorialManager.CONTEXT_COMBAT
		"RunResult":
			return TutorialManager.CONTEXT_RESULTS
		"UpgradeSelection":
			return TutorialManager.CONTEXT_UPGRADE
		"SkillAugmentSelection":
			return TutorialManager.CONTEXT_SKILL_AUGMENT
		"BossReward":
			return TutorialManager.CONTEXT_BOSS_REWARD
		"Equipment":
			return TutorialManager.CONTEXT_EQUIPMENT
		"CompanionSelection":
			return TutorialManager.CONTEXT_COMPANION
		"PermanentUpgrades":
			return TutorialManager.CONTEXT_PERMANENT_UPGRADES
		"Codex":
			return TutorialManager.CONTEXT_CODEX
		_:
			return TutorialManager.CONTEXT_OTHER


func _add_screen_backdrop(screen: Control) -> void:
	if screen.name == "AshenWastesMap3D":
		return
	if not screen.has_node("AshenBackdrop"):
		var backdrop := AshenBackdrop.new()
		backdrop.name = "AshenBackdrop"
		backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		backdrop.configure(screen.name)
		screen.add_child(backdrop)
		# AshenBackdrop pinta bandas de fondo opacas a pantalla completa
		# (PresentationBackdrop._draw_depth_bands): siempre debe quedar
		# detrás de todo el contenido real de la screen, sin importar cuántos
		# hijos ya tenía. "mini(1, count-1)" asumía varios hijos previos y
		# terminaba insertando el backdrop DESPUÉS (encima) del único hijo
		# real en screens armadas con pocos nodos (p.ej. Map3DPrototypeResult),
		# tapando el contenido por completo.
		screen.move_child(backdrop, 0)
	_add_biome_environment(screen)


func _add_biome_environment(screen: Control) -> void:
	if screen.has_node("BiomeEnvironment") or not RunManager.has_active_run():
		return
	var context: StringName = &""
	match screen.name:
		"Board":
			context = BiomeEnvironmentLayer.CONTEXT_BOARD
		"Combat":
			context = BiomeEnvironmentLayer.CONTEXT_COMBAT
		"EventScreen", "TreasureScreen":
			context = BiomeEnvironmentLayer.CONTEXT_AMBIENT
		"RunResult":
			context = BiomeEnvironmentLayer.CONTEXT_RESULT
		_:
			return
	var layer := BiomeEnvironmentLayer.new()
	layer.name = "BiomeEnvironment"
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boss: bool = bool(screen.get_meta(&"biome_environment_boss", false))
	layer.configure(RunManager.current_run.biome_data, context, boss)
	screen.add_child(layer)
	screen.move_child(layer, mini(2, screen.get_child_count() - 1))


func _play_screen_fade() -> void:
	if SettingsManager.reduce_motion:
		transition_overlay.modulate.a = 0.0
		transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	transition_overlay.modulate.a = 1.0
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void: transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _discard_board() -> void:
	if not is_instance_valid(board_screen):
		board_screen = null
		return
	if current_screen == board_screen:
		current_screen = null
	board_screen.queue_free()
	board_screen = null


func _on_start_run_requested() -> void:
	_run_terminal_transition_started = false
	RunManager.start_new_run()
	show_board()


func _on_combat_won(is_boss: bool, is_elite: bool) -> void:
	if _run_terminal_transition_started:
		return
	if is_boss:
		RunManager.current_run.record_boss_victory()
		RunManager.current_run.add_run_xp(RunLevelConfig.BOSS_COMBAT_XP)
		show_boss_reward()
		return

	if is_elite:
		RunManager.current_run.record_elite_combat_victory()
		RunManager.current_run.add_run_xp(RunLevelConfig.ELITE_COMBAT_XP)
	else:
		RunManager.current_run.record_normal_combat_victory()
		RunManager.current_run.add_run_xp(RunLevelConfig.NORMAL_COMBAT_XP)
	_pending_post_combat_is_elite = is_elite
	if RunManager.current_run.pending_level_ups > 0:
		show_level_up_selection()
		return
	_continue_post_combat_rewards()


func _continue_post_combat_rewards() -> void:
	var is_elite: bool = _pending_post_combat_is_elite
	var reward_type: RunRewardResolver.Type = RunRewardResolver.choose(is_elite, RunManager.current_run)
	if reward_type == RunRewardResolver.Type.SKILL_AUGMENT:
		show_skill_augment_selection()
	else:
		show_upgrade_selection(UpgradeRewardContext.Type.ELITE if is_elite else UpgradeRewardContext.Type.NORMAL)


func _on_level_up_upgrade_selected(_upgrade: UpgradeData) -> void:
	if RunManager.current_run.pending_level_ups > 0:
		show_level_up_selection()
	else:
		_continue_post_combat_rewards()


func _on_combat_lost(_is_boss: bool, _is_elite: bool) -> void:
	if _run_terminal_transition_started:
		return
	_run_terminal_transition_started = true
	if is_instance_valid(board_screen) and board_screen.has_method("terminate_after_defeat"):
		board_screen.call("terminate_after_defeat")
	_discard_board()
	show_run_result(false)


func _on_event_resolved() -> void:
	show_board()
	board_screen.resume_after_interaction("La decisión está tomada. Seguí adelante.")


func _on_treasure_continue_requested() -> void:
	show_board()
	board_screen.resume_after_interaction("Tesoro reclamado. Seguí adelante.")


func _on_upgrade_selected(_upgrade: UpgradeData) -> void:
	RunManager.current_run.upgrades_obtained += 1
	show_board()
	board_screen.resume_after_combat()


func _on_skill_augment_selected(_augment: SkillAugmentData) -> void:
	show_board()
	board_screen.resume_after_combat()


func _on_boss_reward_selected(_reward: BossRewardData) -> void:
	RunManager.current_run.prepare_loot(true)
	if _map3d_prototype_mode:
		_show_map3d_prototype_result(true)
		return
	show_run_result(true)


func _show_map3d_prototype_result(victory: bool) -> void:
	AudioManager.set_music_state(AudioManager.MusicState.RESULTS)
	var result := Control.new()
	result.name = "Map3DPrototypeResult"
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 420)
	panel.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(VisualTheme.CARD, VisualTheme.EMBER, 3, 16))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)
	var title := Label.new()
	title.text = "PROTOTIPO COMPLETADO" if victory else "PROTOTIPO FINALIZADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	content.add_child(title)
	var detail := Label.new()
	detail.text = "THE ASHEN WASTES · MAPA 3D\nNo se depositaron recompensas ni se modificó el perfil."
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(detail)
	var restart := Button.new()
	restart.theme_type_variation = &"PrimaryButton"
	restart.text = "REINICIAR PROTOTIPO"
	restart.pressed.connect(_restart_map3d_prototype)
	content.add_child(restart)
	_set_screen(result)


func _restart_map3d_prototype() -> void:
	_run_terminal_transition_started = false
	RunManager.current_run = MapSandboxContextSource.create_run()
	_discard_board()
	show_board()


func _on_run_result_return_requested() -> void:
	var earned_ash: bool = (
		RunManager.has_active_run()
		and RunManager.current_run.run_ash + RunManager.current_run.milestone_ash_awarded > 0
	)
	show_lobby()
	if earned_ash:
		TutorialManager.request(TutorialCatalog.ASH_CURRENCY, TutorialManager.CONTEXT_LOBBY, current_screen)


func _unhandled_input(event: InputEvent) -> void:
	if _resume_input_guard != null and _resume_input_guard.visible:
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed(&"ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _exit_overlay.visible:
		_close_exit_confirmation()
		return
	if pause_overlay.visible:
		if _pause_confirmation_visible:
			_cancel_abandon_confirmation()
		else:
			_close_pause()
		return
	if is_instance_valid(current_screen) and current_screen.name == "RunResult":
		_on_run_result_return_requested()
		return
	if RunManager.has_active_run():
		_open_pause()
		return
	if is_instance_valid(current_screen) and current_screen.name == "MainMenu":
		_open_exit_confirmation()
		return
	if is_instance_valid(current_screen) and current_screen.name == "Lobby":
		show_main_menu()
		return
	if _settings_return.is_valid() and is_instance_valid(current_screen) and current_screen.name == "Settings":
		_on_settings_back_requested()
		return
	show_lobby()


func _build_pause_ui() -> void:
	pause_button = Button.new()
	pause_button.name = "PauseButton"
	pause_button.text = "PAUSA"
	pause_button.theme_type_variation = &"SecondaryButton"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-142, 24)
	pause_button.size = Vector2(118, 58)
	pause_button.z_index = 150
	pause_button.visible = false
	pause_button.pressed.connect(_open_pause)
	add_child(pause_button)

	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	pause_overlay.z_index = 300
	pause_overlay.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.025, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 72)
	pause_overlay.add_child(margin)
	SafeAreaManager.register_control(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	pause_panel = PanelContainer.new()
	pause_panel.theme_type_variation = &"EmberPanel"
	pause_panel.custom_minimum_size = Vector2(0, 480)
	center.add_child(pause_panel)
	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 28)
	inner.add_theme_constant_override("margin_top", 28)
	inner.add_theme_constant_override("margin_right", 28)
	inner.add_theme_constant_override("margin_bottom", 28)
	pause_panel.add_child(inner)
	pause_content = VBoxContainer.new()
	pause_content.add_theme_constant_override("separation", 16)
	inner.add_child(pause_content)
	_populate_pause_menu()
	add_child(pause_overlay)


func _build_resume_input_guard() -> void:
	_resume_input_guard = Control.new()
	_resume_input_guard.name = "ResumeInputGuard"
	_resume_input_guard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resume_input_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_input_guard.process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_input_guard.z_index = 1000
	_resume_input_guard.visible = false
	add_child(_resume_input_guard)


func _build_tutorial_input_guard() -> void:
	_tutorial_input_guard = Control.new()
	_tutorial_input_guard.name = "TutorialInputGuard"
	_tutorial_input_guard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tutorial_input_guard.mouse_filter = Control.MOUSE_FILTER_STOP
	_tutorial_input_guard.process_mode = Node.PROCESS_MODE_ALWAYS
	_tutorial_input_guard.z_index = 210
	_tutorial_input_guard.visible = false
	add_child(_tutorial_input_guard)


func _guard_tutorial_input(frame_count: int) -> void:
	if _tutorial_input_guard == null:
		return
	_tutorial_input_guard_generation += 1
	var generation: int = _tutorial_input_guard_generation
	_tutorial_input_guard.visible = true
	# The guard must also be last in GUI sibling order; z-index alone controls
	# drawing but does not guarantee that it wins hit-testing over screen controls.
	move_child(_tutorial_input_guard, get_child_count() - 1)
	if OS.is_debug_build():
		print("[TUTORIAL_TRACE] INPUT_GUARD_START %s" % JSON.stringify({
			"guard_instance_id": _tutorial_input_guard.get_instance_id(),
			"node_path": String(_tutorial_input_guard.get_path()),
			"frame_count": frame_count,
			"child_count": _tutorial_input_guard.get_child_count(),
		}))
	_wait_tutorial_input_guard(maxi(frame_count, 1), generation)


func _wait_tutorial_input_guard(frames_remaining: int, generation: int) -> void:
	if generation != _tutorial_input_guard_generation:
		return
	if frames_remaining <= 0:
		_tutorial_input_guard.visible = false
		if OS.is_debug_build():
			print("[TUTORIAL_TRACE] INPUT_GUARD_END %s" % JSON.stringify({
				"guard_instance_id": _tutorial_input_guard.get_instance_id(),
				"node_path": String(_tutorial_input_guard.get_path()),
				"visible": _tutorial_input_guard.visible,
			}))
		return
	get_tree().process_frame.connect(
		_wait_tutorial_input_guard.bind(frames_remaining - 1, generation),
		CONNECT_ONE_SHOT,
	)


func _build_exit_confirmation() -> void:
	_exit_overlay = Control.new()
	_exit_overlay.name = "ExitConfirmation"
	_exit_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_exit_overlay.z_index = 350
	_exit_overlay.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.025, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_exit_overlay.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 72)
	_exit_overlay.add_child(margin)
	SafeAreaManager.register_control(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"EmberPanel"
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	var title := Label.new()
	title.text = "¿SALIR DE ASHEN REALM?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var cancel := _create_exit_button("SEGUIR JUGANDO", &"PrimaryButton", _close_exit_confirmation)
	content.add_child(cancel)
	content.add_child(_create_exit_button("SALIR", &"DangerButton", get_tree().quit))
	_exit_overlay.set_meta(&"cancel_button", cancel)
	add_child(_exit_overlay)


func _create_exit_button(label: String, variation: StringName, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(420, 66)
	button.pressed.connect(action)
	return button


func _open_exit_confirmation() -> void:
	_exit_overlay.visible = true
	get_tree().paused = true
	AudioManager.set_background_paused(true)
	var cancel := _exit_overlay.get_meta(&"cancel_button") as Button
	cancel.grab_focus.call_deferred()


func _close_exit_confirmation() -> void:
	_exit_overlay.visible = false
	get_tree().paused = false
	AudioManager.set_background_paused(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_on_application_paused()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_on_application_resumed()


func _on_application_paused() -> void:
	if _resume_input_guard != null:
		_resume_input_guard.visible = true
	_paused_by_lifecycle = not get_tree().paused
	get_tree().paused = true
	AudioManager.set_background_paused(true)
	SaveManager.save_profile()
	SettingsManager.save_settings()
	TelemetryManager.flush()


func _on_application_resumed() -> void:
	if _paused_by_lifecycle:
		get_tree().paused = false
	_paused_by_lifecycle = false
	AudioManager.set_background_paused(get_tree().paused)
	_release_resume_input_guard.call_deferred()


func _release_resume_input_guard() -> void:
	# Descarta eventos sintetizados por la interrupcion y libera tras dos frames limpios.
	await get_tree().process_frame
	await get_tree().process_frame
	if _resume_input_guard != null:
		_resume_input_guard.visible = false


func _populate_pause_menu(focus_index: int = 0) -> void:
	_clear_pause_content()
	_pause_confirmation_visible = false
	pause_panel.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(Color("231d1b"), VisualTheme.EMBER_DARK, 3, 14))
	var title := Label.new()
	title.text = "—  PAUSA  —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	pause_content.add_child(title)
	_pause_buttons.append(_add_pause_button("REANUDAR", &"PrimaryButton", _close_pause))
	_pause_buttons.append(_add_pause_button("CÓMO JUGAR", &"SecondaryButton", _open_help_from_pause))
	_pause_buttons.append(_add_pause_button("AJUSTES", &"SecondaryButton", _open_settings_from_pause))
	_pause_buttons.append(_add_pause_button("ABANDONAR PARTIDA", &"DangerButton", _show_abandon_confirmation))
	_configure_pause_focus(focus_index)


func _show_abandon_confirmation() -> void:
	_clear_pause_content()
	_pause_confirmation_visible = true
	pause_panel.add_theme_stylebox_override("panel", VisualTheme.elevated_panel_style(Color("211416"), VisualTheme.DANGER_DARK, 3, 14))
	var title := Label.new()
	title.text = "¿ABANDONAR PARTIDA?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	pause_content.add_child(title)
	var warning := Label.new()
	warning.text = "Perderás las mejoras temporales, la Ceniza de partida y las recompensas que todavía no hayan sido depositadas."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_content.add_child(warning)
	_pause_buttons.append(_add_pause_button("CANCELAR", &"PrimaryButton", _cancel_abandon_confirmation))
	_pause_buttons.append(_add_pause_button("ABANDONAR", &"DangerButton", _confirm_abandon))
	_configure_pause_focus(0)


func _add_pause_button(label: String, variation: StringName, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.theme_type_variation = variation
	button.custom_minimum_size = Vector2(0, 66)
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	pause_content.add_child(button)
	return button


func _clear_pause_content() -> void:
	_pause_buttons.clear()
	for child: Node in pause_content.get_children():
		pause_content.remove_child(child)
		child.queue_free()


func _open_pause() -> void:
	_open_pause_with_focus(0)


func _open_pause_with_focus(focus_index: int) -> void:
	if pause_overlay.visible or not RunManager.has_active_run():
		return
	_populate_pause_menu(focus_index)
	if is_instance_valid(current_screen) and current_screen.has_method("set_hud_suspended"):
		current_screen.call("set_hud_suspended", true)
	pause_overlay.visible = true
	pause_button.visible = false
	get_tree().paused = true
	AudioManager.set_background_paused(true)
	_grab_pause_focus(focus_index)


func _close_pause() -> void:
	get_tree().paused = false
	AudioManager.set_background_paused(false)
	pause_overlay.visible = false
	if is_instance_valid(current_screen) and current_screen.has_method("set_hud_suspended"):
		current_screen.call("set_hud_suspended", false)
	_pause_confirmation_visible = false
	_update_pause_button()
	_restore_screen_focus.call_deferred()


func _confirm_abandon() -> void:
	_close_pause()
	show_lobby()


func _open_help_from_pause() -> void:
	_pause_source_screen = current_screen
	_pause_return_focus_index = 1
	_hide_pause_for_subscreen()
	var help_screen := HOW_TO_PLAY_SCENE.instantiate()
	help_screen.back_requested.connect(_return_to_pause_source)
	_set_screen(help_screen, true)


func _open_settings_from_pause() -> void:
	_pause_source_screen = current_screen
	_pause_return_focus_index = 2
	_hide_pause_for_subscreen()
	var settings := SETTINGS_SCENE.instantiate()
	settings.back_requested.connect(_return_to_pause_source)
	_set_screen(settings, true)


func _return_to_pause_source() -> void:
	if not is_instance_valid(_pause_source_screen):
		get_tree().paused = false
		show_board()
		_open_pause_with_focus.call_deferred(0)
		return
	var source := _pause_source_screen
	_pause_source_screen = null
	_set_screen(source)
	_open_pause_with_focus.call_deferred(_pause_return_focus_index)


func _hide_pause_for_subscreen() -> void:
	pause_overlay.visible = false
	_pause_confirmation_visible = false
	pause_button.visible = false


func _on_settings_back_requested() -> void:
	var return_action := _settings_return
	_settings_return = Callable()
	if return_action.is_valid():
		return_action.call()


func _update_pause_button() -> void:
	if pause_button == null:
		return
	pause_button.visible = RunManager.has_active_run() and is_instance_valid(current_screen) and current_screen.name in ["Combat", "UpgradeSelection"] and not pause_overlay.visible


func _cancel_abandon_confirmation() -> void:
	_populate_pause_menu(3)
	_grab_pause_focus(3)


func _configure_pause_focus(focus_index: int) -> void:
	for index: int in _pause_buttons.size():
		var button: Button = _pause_buttons[index]
		button.focus_neighbor_top = button.get_path_to(_pause_buttons[index - 1]) if index > 0 else NodePath()
		button.focus_neighbor_bottom = button.get_path_to(_pause_buttons[index + 1]) if index + 1 < _pause_buttons.size() else NodePath()
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom
	_grab_pause_focus.call_deferred(focus_index)


func _grab_pause_focus(index: int) -> void:
	if not pause_overlay.visible or _pause_buttons.is_empty():
		return
	var safe_index: int = clampi(index, 0, _pause_buttons.size() - 1)
	_pause_buttons[safe_index].grab_focus()


func _restore_screen_focus() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and pause_overlay.is_ancestor_of(focused):
		focused.release_focus()
	if not is_instance_valid(current_screen):
		return
	var target: Button = current_screen.get_node_or_null("%RollButton") as Button
	if target == null:
		target = current_screen.get_node_or_null("%AttackButton") as Button
	if target == null:
		target = current_screen.get_node_or_null("%SkillButton") as Button
	if target != null and target.visible and not target.disabled:
		target.grab_focus()
