class_name BiomeModifierResolver
extends RefCounted


static func get_multiplier(biome: BiomeData, effect_type: BiomeModifierData.EffectType) -> float:
	var multiplier: float = 1.0
	if biome == null:
		return multiplier
	for modifier: BiomeModifierData in biome.modifiers:
		if modifier != null and modifier.effect_type == effect_type:
			multiplier *= modifier.value
	return multiplier


static func get_energy_gain_multiplier(biome: BiomeData) -> float:
	return get_multiplier(biome, BiomeModifierData.EffectType.ENERGY_GAIN_MULTIPLIER)


static func get_healing_multiplier(biome: BiomeData) -> float:
	return get_multiplier(biome, BiomeModifierData.EffectType.HEALING_MULTIPLIER)


static func effective_energy_gain(base_amount: int, biome: BiomeData, run_multiplier: float = 1.0) -> int:
	return _effective_positive_value(base_amount, maxf(0.0, run_multiplier) * get_energy_gain_multiplier(biome))


static func effective_healing(base_amount: int, biome: BiomeData, run_multiplier: float = 1.0) -> int:
	return _effective_positive_value(base_amount, maxf(0.0, run_multiplier) * get_healing_multiplier(biome))


static func get_compact_summary(biome: BiomeData) -> String:
	if biome == null or biome.modifiers.is_empty():
		return "SIN MODIFICADORES REGIONALES"
	var parts: Array[String] = []
	for modifier: BiomeModifierData in biome.modifiers:
		if modifier != null:
			parts.append(_compact_modifier_text(modifier))
	return " · ".join(parts)


static func get_detailed_summary(biome: BiomeData) -> String:
	if biome == null or biome.modifiers.is_empty():
		return "Sin reglas regionales."
	var lines: Array[String] = []
	for modifier: BiomeModifierData in biome.modifiers:
		if modifier == null:
			continue
		var category_text: String = category_name(modifier.category)
		lines.append("%s · %s\n%s" % [category_text, modifier.display_name.to_upper(), modifier.description])
	return "\n\n".join(lines)


static func get_labeled_compact_summary(biome: BiomeData) -> String:
	if biome == null or biome.modifiers.is_empty():
		return "REGLA · SIN MODIFICADORES"
	var lines: Array[String] = []
	for modifier: BiomeModifierData in biome.modifiers:
		if modifier != null:
			lines.append("%s · %s" % [category_name(modifier.category), _compact_modifier_text(modifier)])
	return "\n".join(lines)


static func category_name(category: BiomeModifierData.Category) -> String:
	match category:
		BiomeModifierData.Category.BENEFIT:
			return "VENTAJA"
		BiomeModifierData.Category.RISK:
			return "RIESGO"
		_:
			return "REGLA"


static func _effective_positive_value(base_amount: int, multiplier: float) -> int:
	if base_amount <= 0:
		return 0
	return maxi(1, roundi(float(base_amount) * multiplier))


static func _compact_modifier_text(modifier: BiomeModifierData) -> String:
	var delta_percent: int = roundi((modifier.value - 1.0) * 100.0)
	var sign_text: String = "+" if delta_percent >= 0 else ""
	var stat_text: String = "REGLA"
	match modifier.effect_type:
		BiomeModifierData.EffectType.ENERGY_GAIN_MULTIPLIER:
			stat_text = "BRASA"
		BiomeModifierData.EffectType.HEALING_MULTIPLIER:
			stat_text = "CURACIÓN"
		BiomeModifierData.EffectType.STATUS_MAGNITUDE_MULTIPLIER:
			stat_text = "ESTADOS"
		BiomeModifierData.EffectType.COMBAT_XP_MULTIPLIER:
			stat_text = "XP"
		BiomeModifierData.EffectType.TREASURE_BIAS:
			stat_text = "TESOROS"
	return "%s %s%d%%" % [stat_text, sign_text, delta_percent]
