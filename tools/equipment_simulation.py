#!/usr/bin/env python3
"""Static Equipment 2.0/content and synergy sanity checks. Never invokes Godot."""
from __future__ import annotations

import itertools
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CANONICAL = {
    "critical": "crit", "healing": "heal", "sustain": "heal", "low_health": "low_hp",
    "offense": "attack", "melee": "attack", "regen": "status",
}
ALL_TAGS = {"burn", "ember", "crit", "skill", "heal", "guard", "low_hp", "defense", "status", "companion", "attack", "energy"}
AFFINITY_TAG = {1: "attack", 2: "ember", 3: "heal", 4: "defense"}
PASSIVE_TAGS = {
    "burning_edge": {"burn"}, "bloodbound": {"low_hp"}, "mire_regeneration": {"heal", "status"},
    "warden_first_guard": {"guard", "defense"}, "sundering_edge": {"status", "attack"},
    "guarded_regrowth": {"guard", "heal", "status"},
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def text(body: str, field: str) -> str:
    match = re.search(rf'^{field}\s*=\s*&?"([^"]*)"', body, re.M)
    return match.group(1) if match else ""


def number(body: str, field: str, default: float = 0.0) -> float:
    match = re.search(rf"^{field}\s*=\s*(-?\d+(?:\.\d+)?)", body, re.M)
    return float(match.group(1)) if match else default


def strings(body: str, field: str) -> list[str]:
    match = re.search(rf"^{field}\s*=\s*Array\[[^\]]+\]\(\[(.*?)\]\)", body, re.M | re.S)
    return re.findall(r'&"([^"]+)"', match.group(1)) if match else []


def ints(body: str, field: str) -> list[int]:
    match = re.search(rf"^{field}\s*=\s*Array\[int\]\(\[(.*?)\]\)", body, re.M | re.S)
    return [int(value) for value in re.findall(r"-?\d+", match.group(1))] if match else []


def parse_item(path: Path) -> dict:
    body = read(path)
    values = {field: number(body, field) for field in (
        "attack_bonus", "defense_bonus", "max_health_bonus", "crit_chance", "crit_damage_bonus",
        "ember_gain_bonus", "healing_power_bonus", "skill_damage_bonus",
    )}
    return {
        "path": path.relative_to(ROOT).as_posix(), "id": text(body, "id"), "name": text(body, "display_name"),
        "slot": int(number(body, "slot")), "rarity": int(number(body, "rarity")), "tier": int(number(body, "tier", 1)),
        "passive": text(body, "passive_effect_id"), "affinity": int(number(body, "affinity")),
        "biomes": strings(body, "biome_tags"), "raw_tags": strings(body, "tags"), "visual_id": text(body, "visual_id"),
        **values,
    }


def contribution(item: dict) -> set[str]:
    tags = {CANONICAL.get(tag, tag) for tag in item["raw_tags"]}
    tags &= ALL_TAGS
    if item["attack_bonus"] > 0:
        tags.add("attack")
    if item["affinity"] in AFFINITY_TAG:
        tags.add(AFFINITY_TAG[item["affinity"]])
    if item["crit_chance"] > 0 or item["crit_damage_bonus"] > 0:
        tags.add("crit")
    if item["ember_gain_bonus"] > 0:
        tags.add("energy")
    if item["healing_power_bonus"] > 0:
        tags.add("heal")
    if item["skill_damage_bonus"] > 0:
        tags.add("skill")
    tags |= PASSIVE_TAGS.get(item["passive"], set())
    return tags


def parse_synergies() -> list[dict]:
    result = []
    for path in sorted((ROOT / "data/synergies").glob("*.tres")):
        body = read(path)
        result.append({
            "id": text(body, "synergy_id"), "mode": int(number(body, "activation_mode")),
            "tags": strings(body, "required_tags"), "counts": ints(body, "required_counts"),
            "sources": strings(body, "required_source_ids"), "minimum": int(number(body, "minimum_distinct_sources", 1)),
        })
    return result


def active_synergies(sources: dict[str, set[str]], synergies: list[dict]) -> list[str]:
    counts = Counter(tag for tags in sources.values() for tag in tags)
    active = []
    for synergy in synergies:
        tag_ok = all(counts[tag] >= required for tag, required in zip(synergy["tags"], synergy["counts"]))
        source_ok = bool(synergy["sources"]) and all(source in sources for source in synergy["sources"])
        requirements_ok = (tag_ok or source_ok) if synergy["mode"] == 1 else tag_ok and (not synergy["sources"] or source_ok)
        involved = {source for source, tags in sources.items() if any(tag in tags for tag in synergy["tags"])}
        involved |= {source for source in synergy["sources"] if source in sources}
        if requirements_ok and len(involved) >= synergy["minimum"]:
            active.append(synergy["id"])
    return active


def main() -> int:
    items = [parse_item(path) for path in sorted((ROOT / "data/equipment").rglob("*.tres"))]
    visuals = []
    for path in sorted((ROOT / "data/equipment_visuals").rglob("*.tres")):
        body = read(path)
        visuals.append({"id": text(body, "visual_id"), "slot": int(number(body, "slot")), "path": path.relative_to(ROOT).as_posix()})
    visual_map = {visual["id"]: visual for visual in visuals}
    equipment_catalog = read(ROOT / "scripts/equipment/equipment_catalog.gd")
    visual_catalog = read(ROOT / "scripts/data/equipment_visual_catalog.gd")
    failures = []
    duplicate_ids = sorted(item_id for item_id, count in Counter(item["id"] for item in items).items() if count > 1)
    duplicate_visuals = sorted(visual_id for visual_id, count in Counter(visual["id"] for visual in visuals).items() if count > 1)
    for item in items:
        if item["slot"] not in {0, 1} or item["rarity"] not in {0, 1, 2} or not 1 <= item["tier"] <= 3:
            failures.append(f"enum_or_tier:{item['id']}")
        if item["passive"] and item["passive"] not in PASSIVE_TAGS:
            failures.append(f"unknown_passive:{item['id']}")
        visual = visual_map.get(item["visual_id"])
        if visual is None or visual["slot"] != item["slot"]:
            failures.append(f"visual:{item['id']}")
        if item["path"].replace("data/", "res://data/") not in equipment_catalog:
            failures.append(f"catalog:{item['id']}")
        if visual and visual["path"].replace("data/", "res://data/") not in visual_catalog:
            failures.append(f"visual_catalog:{item['id']}")
        if any(item[field] < 0 for field in ("max_health_bonus", "crit_chance", "crit_damage_bonus", "ember_gain_bonus", "healing_power_bonus", "skill_damage_bonus")):
            failures.append(f"negative_stat:{item['id']}")
        if any(biome not in {"ashen_wastes", "ember_marsh"} for biome in item["biomes"]):
            failures.append(f"biome:{item['id']}")
    failures += [f"duplicate:{value}" for value in duplicate_ids + duplicate_visuals]
    if len(items) != 16 or len(visuals) != 16:
        failures.append("expected_16")

    skill_sources = {}
    for path in sorted((ROOT / "data/skills").glob("*.tres")):
        body = read(path)
        skill_sources[f"skill:{text(body, 'id')}"] = {"skill"} | ({CANONICAL.get(tag, tag) for tag in strings(body, "tags")} & ALL_TAGS)
    synergies = parse_synergies()
    pair_results = []
    weapons = [item for item in items if item["slot"] == 0]
    armors = [item for item in items if item["slot"] == 1]
    for weapon, armor in itertools.product(weapons, armors):
        sources = dict(skill_sources)
        sources[f"equipment:{weapon['id']}"] = contribution(weapon)
        sources[f"equipment:{armor['id']}"] = contribution(armor)
        pair_results.append({"weapon": weapon["id"], "armor": armor["id"], "active": active_synergies(sources, synergies)})
    reachable_by_equipment = sorted({synergy for result in pair_results for synergy in result["active"]})
    new_ids = {"sunder_pike", "vigil_needle", "bloodwoven_mantle", "mireward_harness"}
    old_pair_results = [result for result in pair_results if result["weapon"] not in new_ids and result["armor"] not in new_ids]
    new_pair_results = [result for result in pair_results if result["weapon"] in new_ids or result["armor"] in new_ids]
    output = {
        "equipment_count": len(items), "weapon_count": len(weapons), "armor_count": len(armors),
        "visual_count": len(visuals), "duplicate_ids": duplicate_ids, "duplicate_visual_ids": duplicate_visuals,
        "failures": sorted(set(failures)),
        "items": [{key: item[key] for key in ("id", "name", "slot", "rarity", "tier", "passive", "biomes", "visual_id")} | {"build_tags": sorted(contribution(item))} for item in items],
        "new_item_builds": new_pair_results,
        "synergies_reachable_with_equipment_and_default_skills": reachable_by_equipment,
        "baseline_maximum_simultaneous_synergies": max((len(result["active"]) for result in old_pair_results), default=0),
        "maximum_simultaneous_synergies": max((len(result["active"]) for result in pair_results), default=0),
    }
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
