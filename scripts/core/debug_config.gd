class_name DebugConfig
extends RefCounted

const DEBUG_TOOLS_ENABLED := false
const FORCED_BOARD_SEED := -1
const DEBUG_BOON_GRANTS: Dictionary[StringName, int] = {
	&"burning_strike": 1,
}
const DEBUG_UPGRADE_REROLLS: int = 2
const DEBUG_UPGRADE_REWARD_CONTEXT: int = -1
const DEBUG_FORCED_BOSS_REWARD_ID: StringName = &""
const DEBUG_SKILL_AUGMENT_GRANTS: Dictionary[StringName, int] = {
	&"searing_edge": 2,
	&"executioners_ember": 1,
}
const DEBUG_FORCE_NEXT_REWARD_TYPE: int = -1


static func get_visual_slice_mode() -> StringName:
	if not OS.is_debug_build():
		return &""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-slice="):
			var mode := argument.trim_prefix("--visual-slice=").to_lower()
			if mode in ["normal", "attack", "attack_start", "attack_contact", "attack_recovery", "ember", "elite", "boss", "intent_multi", "intent_support", "intent_boss", "intent_detail", "route_choice", "route_elite_heal", "route_treasure", "route_single", "event_choice", "event_risk_reward", "event_chain", "treasure_choice", "treasure_build", "meta_unlocks", "meta_results", "meta_duplicates", "stage72_refuge", "stage72_equipment", "stage72_region", "stage72_statuses", "stage72_affinity", "stage72_results", "stage74_refuge", "stage74_equipment", "stage74_item_locked", "stage74_results", "stage74_combat", "stage74_statuses", "stage74_region", "stage74_event", "stage74_treasure", "stage74_boss", "stage75_main_menu_before", "stage75_refuge_before", "stage75_main_menu_after", "stage75_refuge_after", "stage75_equipment_context", "stage76_main_menu", "stage76_refuge", "stage76_region", "stage76_equipment", "stage76_results", "stage76_combat", "stage76_boss", "stage76_event", "stage76_treasure"]:
				return StringName(mode)
	return &""


static func is_visual_slice_enabled() -> bool:
	return not get_visual_slice_mode().is_empty()


static func should_capture_visual_slice() -> bool:
	return OS.is_debug_build() and "--capture-visual-slice" in OS.get_cmdline_user_args()


static func get_visual_slice_biome() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--visual-biome="):
			return StringName(argument.trim_prefix("--visual-biome=").to_lower())
	return &"ashen_wastes"
