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
	run.equipped_weapon_id = EquipmentCatalog.EMBER_FANG.id
	run.equipped_armor_id = EquipmentCatalog.EMBERGUARD_ARMOR.id
	BoardGenerator.generate_for_run(run, biome, seed)
	return run

