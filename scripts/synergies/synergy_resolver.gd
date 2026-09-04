class_name SynergyResolver
extends RefCounted

static var use_stage62_baseline_rules: bool = false

static func recalculate(run: RunState) -> Array[StringName]:
	var newly_activated: Array[StringName] = []
	if run == null:
		return newly_activated
	var report: BuildTagReport = BuildTagResolver.resolve(run)
	var next_active: Array[StringName] = []
	for synergy: SynergyData in SynergyCatalog.get_all():
		if _matches(synergy, report):
			next_active.append(synergy.synergy_id)
			if synergy.synergy_id not in run.activated_synergy_ids:
				run.activated_synergy_ids.append(synergy.synergy_id)
				run.pending_synergy_announcement_ids.append(synergy.synergy_id)
				newly_activated.append(synergy.synergy_id)
	run.active_synergy_ids = next_active
	return newly_activated


static func is_active(synergy_id: StringName, run: RunState) -> bool:
	return run != null and synergy_id in run.active_synergy_ids


static func get_activated_by_boon(run: RunState, boon_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var boon: UpgradeData = UpgradeCatalog.get_by_id(boon_id)
	if run == null or boon == null or boon.category != UpgradeData.Category.PASSIVE:
		return result
	var report: BuildTagReport = BuildTagResolver.resolve(run, boon)
	for synergy: SynergyData in SynergyCatalog.get_all():
		if synergy.synergy_id not in run.active_synergy_ids and _matches(synergy, report):
			result.append(synergy.synergy_id)
	return result


static func _matches(synergy: SynergyData, report: BuildTagReport) -> bool:
	if synergy == null or not synergy.has_valid_requirements():
		return false
	if use_stage62_baseline_rules:
		if synergy.synergy_id == &"inferno_rhythm":
			return (
				(report.has_source(&"boon:burning_strike") and report.has_source(&"boon:relentless_flame"))
				or (
					report.get_count(&"burn") >= 1
					and report.get_count(&"ember") >= 2
					and report.get_sources_for_tags([&"burn", &"ember"]).size() >= 2
				)
			)
		if synergy.synergy_id == &"iron_vigil":
			return (
				report.get_count(&"guard") >= 2
				and report.get_count(&"defense") >= 2
				and report.get_sources_for_tags([&"guard", &"defense"]).size() >= 2
			)
	elif synergy.synergy_id == &"inferno_rhythm":
		var exact_pair: bool = report.has_source(&"boon:burning_strike") and report.has_source(&"boon:relentless_flame")
		var offensive_boons: int = 0
		for raw_source: Variant in report.source_tags:
			var source_id: StringName = StringName(raw_source)
			if not String(source_id).begins_with("boon:"):
				continue
			var source_tags: Array = report.source_tags[source_id]
			if &"attack" in source_tags or &"burn" in source_tags or &"ember" in source_tags:
				offensive_boons += 1
		return exact_pair or offensive_boons >= 3
	var sources_match: bool = not synergy.required_source_ids.is_empty()
	for source_id: StringName in synergy.required_source_ids:
		if not report.has_source(source_id):
			sources_match = false
			break
	var tags_match: bool = not synergy.required_tags.is_empty()
	for index: int in range(synergy.required_tags.size()):
		if report.get_count(synergy.required_tags[index]) < synergy.required_counts[index]:
			tags_match = false
			break
	if tags_match:
		var contributing_sources: Array[StringName] = report.get_sources_for_tags(synergy.required_tags)
		tags_match = contributing_sources.size() >= synergy.minimum_distinct_sources
	if synergy.activation_mode == SynergyData.ActivationMode.SOURCES_OR_TAGS:
		return sources_match or tags_match
	return (
		(sources_match or synergy.required_source_ids.is_empty())
		and (tags_match or synergy.required_tags.is_empty())
	)
