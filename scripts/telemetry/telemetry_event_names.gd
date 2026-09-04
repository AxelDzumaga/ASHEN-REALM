class_name TelemetryEventNames
extends RefCounted

const APP_STARTED := &"app_started"
const SESSION_STARTED := &"session_started"
const SESSION_ENDED := &"session_ended"
const UNCLEAN_EXIT_DETECTED := &"unclean_exit_detected"
const RUN_STARTED := &"run_started"
const RUN_FINISHED := &"run_finished"
const RUN_ABANDONED := &"run_abandoned"
const ROUTE_CHOICE_SHOWN := &"route_choice_shown"
const ROUTE_CHOICE_SELECTED := &"route_choice_selected"
const EVENT_CHOICE_SHOWN := &"event_choice_shown"
const EVENT_CHOICE_SELECTED := &"event_choice_selected"
const TREASURE_CHOICE_SHOWN := &"treasure_choice_shown"
const TREASURE_CHOICE_SELECTED := &"treasure_choice_selected"
const COMBAT_STARTED := &"combat_started"
const COMBAT_FINISHED := &"combat_finished"
const ENEMY_INTENT_SHOWN := &"enemy_intent_shown"
const PLAYER_TARGET_CHANGED_AFTER_INTENT := &"player_target_changed_after_intent"
const GUARD_USED_AGAINST_ATTACK_INTENT := &"guard_used_against_attack_intent"
const SKILL_USED_AGAINST_HIGH_THREAT := &"skill_used_against_high_threat"
const ENEMY_KILLED_BEFORE_INTENT_EXECUTION := &"enemy_killed_before_intent_execution"
const BOSS_STARTED := &"boss_started"
const BOSS_FINISHED := &"boss_finished"
const BOSS_PHASE_REACHED := &"boss_phase_reached"
const SYNERGY_ACTIVATED := &"synergy_activated"
const MILESTONE_COMPLETED := &"milestone_completed"
const META_UNLOCK_PURCHASED := &"meta_unlock_purchased"
const META_LOADOUT_SELECTED := &"meta_loadout_selected"
const DUPLICATE_CONVERTED := &"duplicate_converted"
const ERROR_REPORTED := &"error_reported"

const ALL: Array[StringName] = [
	APP_STARTED, SESSION_STARTED, SESSION_ENDED, UNCLEAN_EXIT_DETECTED,
	RUN_STARTED, RUN_FINISHED, RUN_ABANDONED,
	ROUTE_CHOICE_SHOWN, ROUTE_CHOICE_SELECTED,
	EVENT_CHOICE_SHOWN, EVENT_CHOICE_SELECTED,
	TREASURE_CHOICE_SHOWN, TREASURE_CHOICE_SELECTED,
	COMBAT_STARTED, COMBAT_FINISHED,
	ENEMY_INTENT_SHOWN, PLAYER_TARGET_CHANGED_AFTER_INTENT,
	GUARD_USED_AGAINST_ATTACK_INTENT, SKILL_USED_AGAINST_HIGH_THREAT,
	ENEMY_KILLED_BEFORE_INTENT_EXECUTION,
	BOSS_STARTED, BOSS_FINISHED, BOSS_PHASE_REACHED,
	SYNERGY_ACTIVATED, MILESTONE_COMPLETED,
	META_UNLOCK_PURCHASED, META_LOADOUT_SELECTED, DUPLICATE_CONVERTED,
	ERROR_REPORTED,
]
