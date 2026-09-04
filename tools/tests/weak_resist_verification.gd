extends Node

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")
const CHARRED_HOUND: EnemyData = preload("res://data/enemies/charred_hound.tres")


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"weak_resist_verification")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	RunManager.start_new_run(610061)
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	RunManager.current_run.equipped_weapon_id = &"ember_fang"
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and frames < 600:
		await get_tree().process_frame
		frames += 1

	var player_actor: CombatActor = combat.get("player_actor")
	var target: CombatActor = combat.get("enemy_actor")
	var weapon: EquipmentData = EquipmentCatalog.get_by_id("ember_fang")
	var attack: int = player_actor.get_attack()
	var defense: int = target.get_defense()
	var base_damage: int = CombatMath.calculate_damage(attack, defense)

	var neutral_enemy := EnemyData.new()
	target.source_data = neutral_enemy
	var neutral_damage: int = int(combat.call("_resolve_elemental_damage", base_damage, player_actor, target))

	var weak_enemy := EnemyData.new()
	weak_enemy.weakness_tags = [&"ember"]
	target.source_data = weak_enemy
	var weak_damage: int = int(combat.call("_resolve_elemental_damage", base_damage, player_actor, target))

	var resist_enemy := EnemyData.new()
	resist_enemy.resistance_tags = [&"ember"]
	target.source_data = resist_enemy
	var resist_damage: int = int(combat.call("_resolve_elemental_damage", base_damage, player_actor, target))

	var immune_enemy := EnemyData.new()
	immune_enemy.immunity_tags = [&"ember"]
	target.source_data = immune_enemy
	var immune_damage: int = int(combat.call("_resolve_elemental_damage", base_damage, player_actor, target))

	# Dato real del catálogo (no sintético): charred_hound ya viene resistance_tags=[ember] de Fase 1.
	target.source_data = CHARRED_HOUND
	var real_resist_damage: int = int(combat.call("_resolve_elemental_damage", base_damage, player_actor, target))

	var failures: Array[String] = []
	if weak_damage != roundi(float(base_damage) * 1.25):
		failures.append("weak_damage_mismatch")
	if resist_damage != roundi(float(base_damage) * 0.75):
		failures.append("resist_damage_mismatch")
	if immune_damage != 0:
		failures.append("immune_damage_mismatch")
	if neutral_damage != base_damage:
		failures.append("neutral_damage_mismatch")
	if real_resist_damage != resist_damage:
		failures.append("real_catalog_resist_mismatch")

	print(JSON.stringify({
		"weapon": String(weapon.id), "weapon_element": String(weapon.element_type),
		"attack": attack, "defense": defense, "base_damage": base_damage,
		"neutral_damage": neutral_damage,
		"weak_damage": weak_damage, "weak_ratio": float(weak_damage) / float(base_damage),
		"resist_damage": resist_damage, "resist_ratio": float(resist_damage) / float(base_damage),
		"immune_damage": immune_damage,
		"real_catalog_target": "charred_hound", "real_catalog_resist_damage": real_resist_damage,
		"failures": failures,
	}))
	combat.queue_free()
	RunManager.current_run = null
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
