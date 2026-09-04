class_name SynergyEffectResolver
extends RefCounted

const SUPPORTED_EFFECT_IDS: Array[StringName] = [
	&"inferno_rhythm", &"ashen_vengeance", &"last_stand", &"phoenix_blood",
	&"cinder_precision", &"iron_vigil", &"mire_bloom", &"runic_flow",
]


static func inferno_relentless_bonus(run: RunState) -> int:
	return roundi(SynergyCatalog.INFERNO_RHYTHM.effect_value) if SynergyResolver.is_active(&"inferno_rhythm", run) else 0


static func ashen_vengeance_bonus(run: RunState, defense_bonus: int) -> int:
	return roundi(SynergyCatalog.ASHEN_VENGEANCE.effect_value) if defense_bonus >= 4 and SynergyResolver.is_active(&"ashen_vengeance", run) else 0


static func last_stand_damage_multiplier(run: RunState) -> float:
	return 1.0 - SynergyCatalog.LAST_STAND.effect_value if SynergyResolver.is_active(&"last_stand", run) else 1.0


static func phoenix_blood_attack_bonus(run: RunState) -> int:
	return roundi(SynergyCatalog.PHOENIX_BLOOD.effect_value) if SynergyResolver.is_active(&"phoenix_blood", run) else 0


static func apply_combat_start(run: RunState, player: CombatActor, statuses: CombatStatusController) -> void:
	if not SynergyResolver.is_active(&"mire_bloom", run):
		return
	statuses.apply_status(player, &"regen", player, 1, 3)


static func on_burning_basic_attack(
	run: RunState,
	runtime: SynergyRuntimeState,
	skills: CombatSkillController,
	target_was_burning: bool,
) -> int:
	if not target_was_burning or runtime.inferno_triggered_this_turn or not SynergyResolver.is_active(&"inferno_rhythm", run):
		return 0
	runtime.inferno_triggered_this_turn = true
	return skills.add_energy(roundi(SynergyCatalog.INFERNO_RHYTHM.secondary_value))


static func on_critical_hit(run: RunState, runtime: SynergyRuntimeState, skills: CombatSkillController) -> int:
	if runtime.cinder_precision_triggered_this_turn or not SynergyResolver.is_active(&"cinder_precision", run):
		return 0
	runtime.cinder_precision_triggered_this_turn = true
	return skills.add_energy(roundi(SynergyCatalog.CINDER_PRECISION.effect_value))


static func on_skill_used(run: RunState, runtime: SynergyRuntimeState, skills: CombatSkillController) -> int:
	if runtime.runic_flow_triggered_this_turn or not SynergyResolver.is_active(&"runic_flow", run):
		return 0
	runtime.runic_flow_triggered_this_turn = true
	return skills.add_energy(roundi(SynergyCatalog.RUNIC_FLOW.effect_value))


static func on_guard_consumed(run: RunState, runtime: SynergyRuntimeState, guard_consumed: bool) -> int:
	if not guard_consumed or runtime.iron_vigil_triggered_this_combat or not SynergyResolver.is_active(&"iron_vigil", run):
		return 0
	runtime.iron_vigil_triggered_this_combat = true
	return run.heal(roundi(SynergyCatalog.IRON_VIGIL.effect_value))
