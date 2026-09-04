#!/usr/bin/env python3
"""Exhaustive static simulation of normal encounters. Never invokes Godot."""
from __future__ import annotations

import itertools
import json
import random
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BANDS = {"early": 20, "mid": 50, "late": 80}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def scalar(body: str, field: str, default: int = 0) -> int:
    match = re.search(rf"^{field}\s*=\s*(-?\d+)", body, re.M)
    return int(match.group(1)) if match else default


def name(body: str, field: str) -> str:
    match = re.search(rf'^{field}\s*=\s*&?"([^"]+)"', body, re.M)
    return match.group(1) if match else ""


def ext_map(body: str) -> dict[str, Path]:
    result = {}
    for path, ext_id in re.findall(r'\[ext_resource[^\]]*path="res://([^"]+)"[^\]]*id="([^"]+)"', body):
        result[ext_id] = ROOT / path
    return result


def ext_array(body: str, field: str) -> list[str]:
    match = re.search(rf"^{field}\s*=\s*Array\[[^\]]+\]\(\[(.*?)\]\)", body, re.M | re.S)
    return re.findall(r'ExtResource\("([^"]+)"\)', match.group(1)) if match else []


def int_array(body: str, field: str) -> list[int]:
    match = re.search(rf"^{field}\s*=\s*Array\[int\]\(\[(.*?)\]\)", body, re.M | re.S)
    return [int(value) for value in re.findall(r"-?\d+", match.group(1))] if match else []


def parse_enemy(path: Path) -> dict:
    body = read(path)
    exts = ext_map(body)
    ai_match = re.search(r'^ai_profile\s*=\s*ExtResource\("([^"]+)"\)', body, re.M)
    ai_path = exts[ai_match.group(1)] if ai_match else None
    ai_body = read(ai_path) if ai_path else ""
    ai_exts = ext_map(ai_body)
    actions = []
    for action_ext in ext_array(ai_body, "actions"):
        action_path = ai_exts.get(action_ext)
        if action_path:
            action_body = read(action_path)
            actions.append({"id": name(action_body, "action_id"), "status": name(action_body, "status_id")})
    return {
        "id": name(body, "id"), "cost": scalar(body, "encounter_cost"),
        "hp": scalar(body, "max_health"), "attack": scalar(body, "attack"), "defense": scalar(body, "defense"),
        "ai_id": name(ai_body, "ai_id"), "role": scalar(ai_body, "role"),
        "target": scalar(ai_body, "default_target_policy"), "actions": actions,
        "disruptive": any(action["status"] in {"weaken", "armor_break"} for action in actions),
        "burn_pressure": any(action["status"] == "burn" for action in actions),
    }


def parse_biome(path: Path) -> tuple[str, list[dict]]:
    body = read(path)
    exts = ext_map(body)
    enemies = [parse_enemy(exts[key]) for key in ext_array(body, "normal_enemy_pool")]
    return name(body, "id"), enemies


def parse_templates() -> list[dict]:
    templates = []
    for path in sorted((ROOT / "data/encounter_templates").glob("*.tres")):
        body = read(path)
        templates.append({
            "id": name(body, "id"), "roles": int_array(body, "roles"),
            "min_progress": scalar(body, "minimum_progress_percent"),
            "max_progress": scalar(body, "maximum_progress_percent", 100),
            "min_budget": scalar(body, "minimum_budget", 1),
            "weight": scalar(body, "weight", 100),
            "allow_duplicates": scalar(body, "duplicate_policy") == 1,
        })
    return templates


def budget(progress: int) -> int:
    return max(3, min(8, 3 + int(progress * 5.0 / 100.0)))


def fair(enemies: tuple[dict, ...], progress: int) -> bool:
    if not enemies or len(enemies) > 3 or (len(enemies) >= 3 and progress < 65):
        return False
    support = sum(enemy["role"] == 3 for enemy in enemies)
    hunters = sum(enemy["target"] == 3 for enemy in enemies)
    disruptive = sum(enemy["disruptive"] for enemy in enemies)
    return not (support > 1 or hunters > 1 or (progress < 45 and disruptive > 1) or (progress < 70 and hunters and support))


def plans_for(enemies: list[dict], templates: list[dict], progress: int) -> list[dict]:
    result = []
    current_budget = budget(progress)
    for template in templates:
        if progress < template["min_progress"] or progress > template["max_progress"] or current_budget < template["min_budget"]:
            continue
        pools = [[enemy for enemy in enemies if enemy["role"] == role] for role in template["roles"]]
        if any(not pool for pool in pools):
            continue
        seen = set()
        for composition in itertools.product(*pools):
            if not template["allow_duplicates"] and len({enemy["id"] for enemy in composition}) != len(composition):
                continue
            total_cost = sum(enemy["cost"] for enemy in composition)
            signature = "|".join(sorted(enemy["id"] for enemy in composition))
            if total_cost > current_budget or signature in seen or not fair(composition, progress):
                continue
            seen.add(signature)
            result.append({"template": template["id"], "signature": signature, "cost": total_cost, "enemies": composition, "weight": template["weight"] * max(1, 4 - abs(current_budget - total_cost))})
    return result


def sample(plans: list[dict], seed_count: int = 4000) -> dict:
    if not plans:
        return {"dominant_share": 0.0, "never_selected": []}
    counts = Counter()
    weights = [plan["weight"] for plan in plans]
    for seed in range(seed_count):
        rng = random.Random(seed ^ 0x48EC02)
        chosen = rng.choices(plans, weights=weights, k=1)[0]
        counts[chosen["signature"]] += 1
    signatures = {plan["signature"] for plan in plans}
    return {
        "dominant_share": round(max(counts.values()) / seed_count, 4),
        "never_selected": sorted(signatures - set(counts)),
    }


def main() -> int:
    templates = parse_templates()
    output = {"template_count": len(templates), "biomes": {}}
    failures = []
    all_pool_ids = []
    for biome_path in (ROOT / "data/biomes/ashen_wastes.tres", ROOT / "data/biomes/ember_marsh.tres"):
        biome_id, enemies = parse_biome(biome_path)
        enemy_ids = [enemy["id"] for enemy in enemies]
        all_pool_ids.extend(enemy_ids)
        forbidden_ids = sorted(enemy["id"] for enemy in enemies if enemy["id"] in {"ember_spawn", "ashen_warden", "sunken_pyre"})
        biome_report = {
            "enemy_count": len(enemies), "enemy_ids": enemy_ids,
            "role_counts": {
                "assault": sum(enemy["role"] == 0 for enemy in enemies),
                "brute": sum(enemy["role"] == 1 for enemy in enemies),
                "defender": sum(enemy["role"] == 2 for enemy in enemies),
                "support": sum(enemy["role"] == 3 for enemy in enemies),
            },
            "forbidden_normal_ids": forbidden_ids, "bands": {},
        }
        used_all_bands = set()
        for band, progress in BANDS.items():
            plans = plans_for(enemies, templates, progress)
            used = {enemy["id"] for plan in plans for enemy in plan["enemies"]}
            used_all_bands.update(used)
            impossible = sorted(template["id"] for template in templates if template["min_progress"] <= progress <= template["max_progress"] and budget(progress) >= template["min_budget"] and not any(plan["template"] == template["id"] for plan in plans))
            unique = {plan["signature"] for plan in plans}
            sampling = sample(plans)
            biome_report["bands"][band] = {
                "progress": progress, "budget": budget(progress), "plans": len(plans),
                "unique_compositions": len(unique), "impossible_eligible_templates": impossible,
                "unused_enemies": sorted(set(biome_report["enemy_ids"]) - used),
                "early_trios": sum(len(plan["enemies"]) >= 3 for plan in plans) if band == "early" else 0,
                "support_overflow": sum(sum(enemy["role"] == 3 for enemy in plan["enemies"]) > 1 for plan in plans),
                "hunter_overflow": sum(sum(enemy["target"] == 3 for enemy in plan["enemies"]) > 1 for plan in plans),
                "disruptive_overflow": sum(sum(enemy["disruptive"] for enemy in plan["enemies"]) > 1 and progress < 45 for plan in plans),
                "maximum_burn_sources": max((sum(enemy["burn_pressure"] for enemy in plan["enemies"]) for plan in plans), default=0),
                **sampling,
            }
        biome_report["never_used_any_band"] = sorted(set(biome_report["enemy_ids"]) - used_all_bands)
        output["biomes"][biome_id] = biome_report
        if biome_report["never_used_any_band"]:
            failures.append(f"unused:{biome_id}")
        if forbidden_ids:
            failures.append(f"forbidden:{biome_id}")
        if len(enemy_ids) != len(set(enemy_ids)):
            failures.append(f"duplicate_in_pool:{biome_id}")
    duplicate_cross_biome = sorted(enemy_id for enemy_id, count in Counter(all_pool_ids).items() if count > 1)
    output["normal_enemy_count"] = len(all_pool_ids)
    output["cross_biome_duplicates"] = duplicate_cross_biome
    if len(all_pool_ids) != 16:
        failures.append("expected_16_normal_enemies")
    if duplicate_cross_biome:
        failures.append("cross_biome_duplicates")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
