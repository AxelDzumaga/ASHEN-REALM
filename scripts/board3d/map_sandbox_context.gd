class_name MapSandboxContext
extends RefCounted

const SANDBOX_SEED := 230030


static func create_run(seed: int = SANDBOX_SEED) -> RunState:
	var run := RunState.new()
	var biome: BiomeData = BiomeCatalog.ASHEN_WASTES
	run.biome_id = biome.id
	run.biome_data = biome
	run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	run.active_skill_id = ActiveSkillCatalog.DEFAULT_SKILL_ID
	# Antes esto solo guardaba el id sin pasar por _apply_equipped_item(), así
	# que max_health_bonus/attack_bonus/defense_bonus de EMBER_FANG/EMBERGUARD_ARMOR
	# nunca se sumaban — el sandbox quedaba fijo en BASE_MAX_HEALTH/BASE_ATTACK/
	# BASE_DEFENSE toda la sesión pese a "llevar equipo puesto". Mismo helper que
	# usa apply_permanent_upgrades() para runs reales, así no hay una segunda
	# fuente de verdad para "qué aporta un item equipado".
	run._apply_equipped_item(EquipmentCatalog.EMBER_FANG.id)
	run._apply_equipped_item(EquipmentCatalog.EMBERGUARD_ARMOR.id)
	run.current_health = maxi(1, run.max_health - RunState.BASE_CURRENT_HEALTH_OFFSET)
	BoardGenerator.generate_for_run(run, biome, seed)
	return run

