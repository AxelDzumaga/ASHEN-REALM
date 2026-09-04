class_name UpgradeApplier
extends RefCounted


static func apply(upgrade: UpgradeData, run_state: RunState) -> void:
	if upgrade.category == UpgradeData.Category.PASSIVE:
		run_state.add_boon(upgrade.id)
		return
	match upgrade.effect_type:
		UpgradeData.EffectType.MAX_HEALTH_AND_HEAL:
			run_state.max_health += upgrade.primary_value
			run_state.heal_structural(upgrade.secondary_value)
		UpgradeData.EffectType.ATTACK:
			run_state.attack += upgrade.primary_value
		UpgradeData.EffectType.DEFENSE:
			run_state.defense += upgrade.primary_value
		UpgradeData.EffectType.HEAL:
			run_state.heal(upgrade.primary_value)
		UpgradeData.EffectType.ATTACK_AND_HEALTH_COST:
			run_state.attack += upgrade.primary_value
			run_state.current_health = maxi(1, run_state.current_health - upgrade.secondary_value)


static func describe_effect(upgrade: UpgradeData, owned_copies: int = 0) -> String:
	if upgrade.category == UpgradeData.Category.PASSIVE:
		return BoonController.describe_next_copy(upgrade.id, owned_copies)
	match upgrade.effect_type:
		UpgradeData.EffectType.MAX_HEALTH_AND_HEAL:
			return "+%d de Vida máxima y recuperás %d de Vida" % [upgrade.primary_value, upgrade.secondary_value]
		UpgradeData.EffectType.ATTACK:
			return "+%d de Ataque" % upgrade.primary_value
		UpgradeData.EffectType.DEFENSE:
			return "+%d de Defensa" % upgrade.primary_value
		UpgradeData.EffectType.HEAL:
			return "Recuperás %d de Vida" % upgrade.primary_value
		UpgradeData.EffectType.ATTACK_AND_HEALTH_COST:
			return "+%d de Ataque; perdés %d de Vida (mínimo 1)" % [upgrade.primary_value, upgrade.secondary_value]
		_:
			return "Efecto desconocido"
