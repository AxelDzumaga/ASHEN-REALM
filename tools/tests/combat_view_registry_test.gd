extends Node

## Combat Domain M6 — secciones 32/33 del handoff: pureza de dominio de
## CombatActor (sin visual_view/set_visual_view/death_presented) y el
## registro actor_id -> CombatCharacterView de Combat2D. Mismo patrón que
## combat_rules_test.gd (M5): la mitad no necesita Combat2D en absoluto, la
## otra mitad usa reflexión sobre una escena real ya establecida en M1-M5.

const COMBAT_SCENE := preload("res://scenes/combat/combat.tscn")

var _failures: Array[String] = []
var _seed: int = 970001


func _ready() -> void:
	SaveManager.use_isolated_test_profile(&"combat_view_registry")
	for tutorial_id: StringName in TutorialCatalog.ALL_IDS:
		SaveManager.profile.completed_tutorials.append(String(tutorial_id))
	_test_combat_actor_has_no_visual_view_property()
	_test_combat_actor_has_no_set_visual_view_method()
	_test_combat_actor_has_no_death_presented_property()
	_test_combat_actor_constructible_and_usable_standalone()
	await _test_registry_register_and_lookup()
	await _test_registry_unknown_actor_is_null_safe()
	await _test_registry_rebuild_removes_stale_mapping()
	await _test_registry_no_actor_has_two_active_mappings()
	print("[VIEW_REGISTRY_TEST] failures=%s" % JSON.stringify(_failures))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(label: String, condition: bool) -> void:
	print("[VIEW_REGISTRY_TEST] %s=%s" % [label, condition])
	if not condition:
		_failures.append(label)


func _next_seed() -> int:
	_seed += 1
	return _seed


func _actor(id: String) -> CombatActor:
	return CombatActor.new(StringName(id), id, CombatActor.Team.PLAYER, CombatActor.ActorType.PLAYER, 10, 10, 5, 1)


func _has_property(instance: Object, property_name: String) -> bool:
	for property: Dictionary in instance.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


## §32 — CombatActor ya no tiene ningún campo/método de presentación viva.
func _test_combat_actor_has_no_visual_view_property() -> void:
	var actor: CombatActor = _actor("p")
	_check("combat_actor_has_no_visual_view_property", not _has_property(actor, "visual_view"))


func _test_combat_actor_has_no_set_visual_view_method() -> void:
	var actor: CombatActor = _actor("p")
	_check("combat_actor_has_no_set_visual_view_method", not actor.has_method("set_visual_view"))


func _test_combat_actor_has_no_death_presented_property() -> void:
	var actor: CombatActor = _actor("p")
	_check("combat_actor_has_no_death_presented_property", not _has_property(actor, "death_presented"))


## §32 — construible y usable (HP, statuses, is_alive) sin ningún nodo de
## escena ni Combat2D — condición necesaria para un futuro Combat3D.
func _test_combat_actor_constructible_and_usable_standalone() -> void:
	var actor: CombatActor = _actor("p")
	_check("combat_actor_standalone_is_alive", actor.is_alive())
	actor.apply_damage(5)
	_check("combat_actor_standalone_hp_mutates", actor.get_current_hp() == 5)
	_check("combat_actor_standalone_targetable", actor.is_targetable())


func _start_combat() -> Control:
	RunManager.start_new_run(_next_seed())
	RunManager.current_run.biome_data = BiomeCatalog.ASHEN_WASTES
	RunManager.current_run.biome_id = BiomeCatalog.ASHEN_WASTES.id
	RunManager.current_run.equipped_skill_ids = ActiveSkillCatalog.get_default_loadout()
	var combat: Control = COMBAT_SCENE.instantiate()
	combat.configure(BiomeCatalog.ASHEN_WASTES, false, false)
	add_child(combat)
	var frames: int = 0
	while int(combat.get("_phase")) != 1 and frames < 800:
		await get_tree().process_frame
		frames += 1
	return combat


func _end_combat(combat: Control) -> void:
	combat.queue_free()
	await get_tree().process_frame
	RunManager.current_run = null


## §33 — registrar y consultar.
func _test_registry_register_and_lookup() -> void:
	var combat: Control = await _start_combat()
	var player_actor: CombatActor = combat.get("player_actor")
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	var player_view: CombatCharacterView = combat.call("_get_actor_view", player_actor)
	var enemy_view: CombatCharacterView = combat.call("_get_actor_view", enemy_actor)
	_check("registry_player_view_registered", is_instance_valid(player_view))
	_check("registry_enemy_view_registered", is_instance_valid(enemy_view))
	_check("registry_player_and_enemy_views_differ", player_view != enemy_view)
	await _end_combat(combat)


## §33 — actor desconocido/null: lookup seguro, sin crash.
func _test_registry_unknown_actor_is_null_safe() -> void:
	var combat: Control = await _start_combat()
	var unknown_actor: CombatActor = _actor("unknown")
	_check("registry_unknown_actor_returns_null", combat.call("_get_actor_view", unknown_actor) == null)
	_check("registry_null_actor_returns_null", combat.call("_get_actor_view", null) == null)
	await _end_combat(combat)


## §33 — reconstruir la formación de enemigos (p. ej. tras un boss summon)
## reemplaza la vista anterior en vez de acumular una segunda.
func _test_registry_rebuild_removes_stale_mapping() -> void:
	var combat: Control = await _start_combat()
	var enemy_actor: CombatActor = combat.get("enemy_actor")
	var enemy_actors: Array = combat.get("enemy_actors")
	# El camino de UN solo enemigo usa el nodo fijo %EnemyCharacterView, que
	# _build_enemy_slots() nunca toca — para probar el reemplazo real hace
	# falta que la vista vieja ya venga de un EnemyCombatSlot dinámico. Se
	# agregan dos enemigos sintéticos y se arma la formación dos veces.
	var extra_1: CombatActor = CombatActor.from_enemy(&"enemy_synthetic_0", preload("res://data/enemies/ash_crawler.tres"), CombatActor.ActorType.NORMAL_ENEMY)
	extra_1.formation_slot = 1
	enemy_actors.append(extra_1)
	combat.call("_build_enemy_slots")
	var view_before_rebuild: CombatCharacterView = combat.call("_get_actor_view", enemy_actor)
	_check("registry_first_build_registers_dynamic_view", is_instance_valid(view_before_rebuild))
	var extra_2: CombatActor = CombatActor.from_enemy(&"enemy_synthetic_1", preload("res://data/enemies/ash_crawler.tres"), CombatActor.ActorType.NORMAL_ENEMY)
	extra_2.formation_slot = 2
	enemy_actors.append(extra_2)
	combat.call("_build_enemy_slots")
	# queue_free() difiere la liberación real al final del frame — hay que
	# dejar pasar al menos un frame antes de que is_instance_valid() refleje
	# que el nodo viejo efectivamente se liberó.
	await get_tree().process_frame
	await get_tree().process_frame
	var view_after_rebuild: CombatCharacterView = combat.call("_get_actor_view", enemy_actor)
	_check("registry_rebuild_still_resolves", is_instance_valid(view_after_rebuild))
	_check("registry_rebuild_replaces_old_view", view_after_rebuild != view_before_rebuild)
	_check("registry_stale_view_no_longer_valid", not is_instance_valid(view_before_rebuild))
	await _end_combat(combat)


## §33/§17 — cada actor vivo tiene como mucho UNA entrada activa (no dos
## vistas simultáneamente registradas para el mismo actor_id).
func _test_registry_no_actor_has_two_active_mappings() -> void:
	var combat: Control = await _start_combat()
	var actor_views: Dictionary = combat.get("_actor_views")
	var player_actors: Array = combat.get("player_actors")
	var enemy_actors: Array = combat.get("enemy_actors")
	var all_actor_ids: Array[StringName] = []
	for actor: CombatActor in player_actors:
		all_actor_ids.append(actor.actor_id)
	for actor: CombatActor in enemy_actors:
		all_actor_ids.append(actor.actor_id)
	var unique_ids: Array[StringName] = []
	for id: StringName in actor_views.keys():
		if id not in unique_ids:
			unique_ids.append(id)
	_check("registry_no_duplicate_keys", unique_ids.size() == actor_views.keys().size())
	_check("registry_covers_every_live_actor", all_actor_ids.size() == actor_views.keys().size())
	await _end_combat(combat)
