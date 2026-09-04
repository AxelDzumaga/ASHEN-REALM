#!/usr/bin/env python3
"""Deterministic, external QA/balance simulations for Ashen Realm.

This tool never invokes Godot and never reads or writes user://.  Its scores are
diagnostic heuristics: they identify candidates for review, not automatic nerfs.
"""
from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import random
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import content_simulation as encounters  # noqa: E402
import equipment_simulation as equipment  # noqa: E402

TILE_NAMES = {0: "EMPTY", 1: "HEAL", 2: "BOSS", 3: "COMBAT", 4: "EVENT", 5: "TREASURE", 6: "ELITE"}
DANGEROUS = {3, 6}


def combat_damage(attack: float, defense: float) -> int:
    return max(1, math.ceil(attack * 100.0 / (100.0 + defense * 10.0)))


def percentile(values: list[float], fraction: float) -> float:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, int(fraction * len(ordered)))]


def parse_biome_board(path: Path) -> dict:
    body = encounters.read(path)
    defaults = {
        "board_length": 30, "empty_min": 6, "empty_max": 9,
        "combat_min": 7, "combat_max": 9, "event_min": 3, "event_max": 5,
        "treasure_min": 2, "treasure_max": 3, "heal_min": 2, "heal_max": 3,
        "elite_min": 1, "elite_max": 2, "empty_weight": 6, "combat_weight": 4,
        "event_weight": 3, "treasure_weight": 2, "heal_weight": 2, "elite_weight": 1,
    }
    for key, default in list(defaults.items()):
        defaults[key] = encounters.scalar(body, key, default)
    defaults["id"] = encounters.name(body, "id")
    return defaults


def board_valid(tiles: list[int], cfg: dict) -> bool:
    if len(tiles) != cfg["board_length"] or tiles[0] != 0 or tiles[-1] != 2:
        return False
    counts = Counter(tiles)
    combat_streak = danger_streak = 0
    previous = 0
    for index, tile in enumerate(tiles):
        combat_streak = combat_streak + 1 if tile == 3 else 0
        danger_streak = danger_streak + 1 if tile in DANGEROUS else 0
        if combat_streak > 2 or danger_streak > 2:
            return False
        if tile == 6 and (index < math.ceil((len(tiles) - 1) * .20) or index == len(tiles) - 2 or previous == 6):
            return False
        previous = tile
    for name, tile in (("empty", 0), ("combat", 3), ("event", 4), ("treasure", 5), ("heal", 1), ("elite", 6)):
        if not cfg[f"{name}_min"] <= counts[tile] <= cfg[f"{name}_max"]:
            return False
    return counts[2] == 1


def board_allowed(tile: int, index: int, length: int, tiles: list[int]) -> bool:
    previous = tiles[-1]
    previous_two = tiles[-2] if len(tiles) >= 2 else 0
    if tile == 6 and (index < math.ceil((length - 1) * .20) or index == length - 2 or previous == 6):
        return False
    if tile == 3 and previous == tile and previous_two == tile:
        return False
    return not (tile in DANGEROUS and previous in DANGEROUS and previous_two in DANGEROUS)


def generate_board(cfg: dict, rng: random.Random) -> tuple[list[int], bool]:
    mapping = {3: "combat", 4: "event", 5: "treasure", 1: "heal", 6: "elite"}
    for _ in range(16):
        counts = None
        for _ in range(16):
            candidate = {tile: rng.randint(cfg[f"{name}_min"], cfg[f"{name}_max"]) for tile, name in mapping.items()}
            empty_total = cfg["board_length"] - 1 - sum(candidate.values())
            if cfg["empty_min"] <= empty_total <= cfg["empty_max"]:
                candidate[0] = empty_total - 1  # start tile is the remaining EMPTY.
                counts = candidate
                break
        if counts is None:
            continue
        tiles = [0]
        for index in range(1, cfg["board_length"] - 1):
            candidates = [tile for tile, left in counts.items() if left > 0 and board_allowed(tile, index, cfg["board_length"], tiles)]
            if not candidates:
                break
            weights = [max(1, cfg[f"{mapping.get(tile, 'empty')}_weight"]) * counts[tile] for tile in candidates]
            chosen = rng.choices(candidates, weights=weights, k=1)[0]
            tiles.append(chosen)
            counts[chosen] -= 1
        if len(tiles) == cfg["board_length"] - 1:
            tiles.append(2)
            if board_valid(tiles, cfg):
                return tiles, False
    # Exact 30-tile safe fallback shared by both current biome count ranges.
    if cfg["board_length"] == 30:
        tiles = [0, 3, 4, 0, 1, 3, 5, 6, 0, 3, 4, 0, 1, 3, 5, 0, 3, 4, 6, 0, 3, 5, 1, 3, 0, 4, 3, 0, 3, 2]
    else:
        pattern = [3, 4, 0, 1, 3, 5, 0, 3, 4, 0]
        tiles = [0] + [pattern[(i - 1) % len(pattern)] for i in range(1, cfg["board_length"] - 1)] + [2]
    return tiles, True


def simulate_boards(seed: int, count_per_biome: int) -> dict:
    result = {}
    for offset, filename in enumerate(("ashen_wastes.tres", "ember_marsh.tres")):
        cfg = parse_biome_board(ROOT / "data/biomes" / filename)
        rng = random.Random(seed ^ (offset + 1) * 0xB04D)
        totals, fallback, invalid = Counter(), 0, 0
        combat_max = danger_max = 0
        for _ in range(count_per_biome):
            tiles, used_fallback = generate_board(cfg, rng)
            fallback += int(used_fallback)
            invalid += int(not board_valid(tiles, cfg))
            totals.update(TILE_NAMES[tile] for tile in tiles)
            current_combat = current_danger = 0
            for tile in tiles:
                current_combat = current_combat + 1 if tile == 3 else 0
                current_danger = current_danger + 1 if tile in DANGEROUS else 0
                combat_max, danger_max = max(combat_max, current_combat), max(danger_max, current_danger)
        result[cfg["id"]] = {
            "boards": count_per_biome,
            "mean_tiles": {name: round(totals[name] / count_per_biome, 4) for name in TILE_NAMES.values()},
            "fallbacks": fallback, "invalid": invalid,
            "max_combat_streak": combat_max, "max_danger_streak": danger_max,
        }
    return result


def simulate_encounters(seed: int, total: int) -> dict:
    templates = encounters.parse_templates()
    biome_paths = [ROOT / "data/biomes/ashen_wastes.tres", ROOT / "data/biomes/ember_marsh.tres"]
    bands = {"early": 20, "mid": 50, "late": 80}
    allocations = [(path, band, progress) for path in biome_paths for band, progress in bands.items()]
    base, remainder = divmod(total, len(allocations))
    report, global_templates, global_enemies = {}, Counter(), Counter()
    size_counts, costs, role_counts = Counter(), [], Counter()
    duplicate_compositions = status_pressure = 0
    for index, (path, band, progress) in enumerate(allocations):
        biome_id, enemies = encounters.parse_biome(path)
        plans = encounters.plans_for(enemies, templates, progress)
        rng = random.Random(seed ^ (index + 1) * 0x48EC02)
        count = base + int(index < remainder)
        last_signature = ""
        selected_templates, selected_enemies = Counter(), Counter()
        band_costs = []
        for _ in range(count):
            candidates = [plan for plan in plans if plan["signature"] != last_signature] or plans
            plan = rng.choices(candidates, weights=[item["weight"] for item in candidates], k=1)[0]
            last_signature = plan["signature"]
            selected_templates[plan["template"]] += 1
            global_templates[plan["template"]] += 1
            size_counts[len(plan["enemies"])] += 1
            band_costs.append(plan["cost"]); costs.append(plan["cost"])
            ids = [enemy["id"] for enemy in plan["enemies"]]
            duplicate_compositions += int(len(ids) != len(set(ids)))
            status_pressure += sum(enemy["disruptive"] or enemy["burn_pressure"] for enemy in plan["enemies"])
            for enemy in plan["enemies"]:
                selected_enemies[enemy["id"]] += 1; global_enemies[enemy["id"]] += 1
                role_counts[str(enemy["role"])] += 1
        key = f"{biome_id}:{band}"
        report[key] = {
            "samples": count, "plans": len(plans), "mean_cost": round(statistics.mean(band_costs), 4),
            "templates": dict(sorted(selected_templates.items())), "enemies": dict(sorted(selected_enemies.items())),
        }
    return {
        "total": total, "bands": report, "template_frequencies": dict(sorted(global_templates.items())),
        "enemy_frequencies": dict(sorted(global_enemies.items())), "size_frequencies": dict(sorted(size_counts.items())),
        "mean_cost": round(statistics.mean(costs), 4), "max_cost": max(costs), "role_frequencies": dict(sorted(role_counts.items())),
        "status_sources_per_encounter": round(status_pressure / total, 4), "duplicate_compositions": duplicate_compositions,
        "dead_templates": sorted({item["id"] for item in templates} - set(global_templates)),
        "dead_enemies": sorted({enemy_id for path in biome_paths for enemy_id in [e["id"] for e in encounters.parse_biome(path)[1]]} - set(global_enemies)),
    }


PASSIVE_SCORE = {
    "": 0.0, "burning_edge": 7.0, "bloodbound": 4.0, "mire_regeneration": 5.0,
    "warden_first_guard": 6.0, "sundering_edge": 4.5, "guarded_regrowth": 4.0,
}


def equipment_report() -> dict:
    items = [equipment.parse_item(path) for path in sorted((ROOT / "data/equipment").rglob("*.tres"))]
    # One point roughly equals one base attack. Defensive/secondary coefficients
    # are declared here so reviewers can challenge them rather than treating the score as fact.
    coefficients = {"attack_bonus": 1.0, "defense_bonus": 1.6, "max_health_bonus": .12,
                    "crit_chance": 24.0, "crit_damage_bonus": 8.0, "ember_gain_bonus": 18.0,
                    "healing_power_bonus": 12.0, "skill_damage_bonus": 14.0}
    scored = []
    for item in items:
        score = sum(item[field] * coefficient for field, coefficient in coefficients.items()) + PASSIVE_SCORE.get(item["passive"], 0.0)
        scored.append({"id": item["id"], "slot": item["slot"], "rarity": item["rarity"], "score": round(score, 3), "passive": item["passive"]})
    groups = defaultdict(list)
    for item in scored:
        groups[(item["slot"], item["rarity"])].append(item["score"])
    outliers = []
    for item in scored:
        median = statistics.median(groups[(item["slot"], item["rarity"])])
        deviation = 0.0 if median == 0 else item["score"] / median - 1.0
        if abs(deviation) > .25:
            outliers.append({"id": item["id"], "vs_group_median": round(deviation, 3), "review_only": True})
    return {"count": len(scored), "coefficients": coefficients, "items": scored, "outliers_25pct": outliers}


def enemy_report() -> dict:
    paths = [ROOT / "data/biomes/ashen_wastes.tres", ROOT / "data/biomes/ember_marsh.tres"]
    enemies = [enemy for path in paths for enemy in encounters.parse_biome(path)[1]]
    scored = []
    by_cost = defaultdict(list)
    for enemy in enemies:
        utility = 7 * enemy["disruptive"] + 4 * enemy["burn_pressure"] + (4 if enemy["target"] == 3 else 0)
        score = enemy["hp"] / 10.0 + enemy["attack"] * .9 + enemy["defense"] * .7 + utility
        per_cost = score / enemy["cost"]
        row = {"id": enemy["id"], "cost": enemy["cost"], "threat": round(score, 3), "threat_per_cost": round(per_cost, 3)}
        scored.append(row); by_cost[enemy["cost"]].append(per_cost)
    mismatches = []
    for row in scored:
        median = statistics.median(by_cost[row["cost"]])
        deviation = row["threat_per_cost"] / median - 1.0
        if abs(deviation) > .25:
            mismatches.append({"id": row["id"], "deviation": round(deviation, 3), "review_only": True})
    return {"count": len(scored), "formula": "HP/10 + ATQ*0.9 + DEF*0.7 + utility, divided by cost", "enemies": scored, "cost_mismatches_25pct": mismatches}


def combat_report() -> dict:
    defense_curve = {str(defense): {str(attack): combat_damage(attack, defense) for attack in (10, 15, 20, 25)} for defense in (0, 5, 10, 15, 20, 25, 30)}
    crit = {}
    base = combat_damage(20, 5)
    for chance in (0, .10, .25, .50, .75):
        crit[str(int(chance * 100))] = {str(mult): round(base * ((1 - chance) + chance * mult), 3) for mult in (1.5, 1.75, 2.0)}
    energy = {}
    for biome, multiplier in (("ashen_wastes", 1.15), ("ember_marsh", .90)):
        for build, equipment_bonus in (("base", 0.0), ("max_equipment", .22)):
            basic = round(25 * multiplier * (1 + equipment_bonus))
            received = round(10 * multiplier * (1 + equipment_bonus))
            energy[f"{biome}:{build}"] = {
                "basic_gain": basic, "received_gain": received,
                "turns_basic_only": {skill: math.ceil(cost / basic) for skill, cost in (("ember_slash", 100), ("ashen_guard", 70), ("second_wind", 90))},
                "turns_basic_plus_one_hit": {skill: math.ceil(cost / (basic + received)) for skill, cost in (("ember_slash", 100), ("ashen_guard", 70), ("second_wind", 90))},
            }
    return {
        "player": {"max_hp": 100, "run_start_hp": 80, "attack": 20, "defense": 5},
        "formula": "max(1, ceil(attack*100/(100+defense*10)))", "defense_curve": defense_curve,
        "crit_cap": .75, "crit_expected_damage_base_14": crit,
        "energy": energy, "energy_clamp": [0, 100],
        "burn": {"damage_per_stack": 2, "max_stacks": 3, "duration": 2, "max_tick": 6, "fresh_max_total": 12},
        "healing": {"second_wind": "30% max HP, once/combat; max augment 40%", "regen": "5/turn for 2 turns; Mire Bloom 3", "heal_tile": 20},
        "free_energy_loop_found": False,
        "loop_reason": "All synergy gains are once/turn or conditional; Stored Embers is bounded and skills still have positive net cost.",
    }


def simulate_loot(seed: int, samples: int) -> dict:
    rng = random.Random(seed ^ 0x1007)
    victory, defeat = Counter(), Counter()
    for _ in range(samples):
        roll = rng.random()
        victory["common" if roll < .55 else "rare" if roll < .90 else "epic"] += 1
        roll = rng.random()
        defeat["common" if roll < .30 else "rare" if roll < .40 else "none"] += 1
    return {"samples_each": samples, "victory": dict(victory), "defeat": dict(defeat)}


def collection_estimate(seed: int, trials: int = 5000) -> dict:
    rng = random.Random(seed ^ 0xC011EC7)
    checkpoints = (4, 8, 12, 16)
    observations = {checkpoint: [] for checkpoint in checkpoints}
    # The real roller preferentially selects unseen candidates of the rolled rarity.
    rarity_sizes = {0: 5, 1: 6, 2: 5}
    for _ in range(trials):
        owned = {rarity: set() for rarity in rarity_sizes}
        run = 0
        reached = set()
        while len(reached) < len(checkpoints) and run < 10000:
            run += 1
            roll = rng.random(); rarity = 0 if roll < .55 else 1 if roll < .90 else 2
            unseen = set(range(rarity_sizes[rarity])) - owned[rarity]
            choice = rng.choice(tuple(unseen) if unseen else tuple(range(rarity_sizes[rarity])))
            owned[rarity].add(choice)
            total = sum(map(len, owned.values()))
            for checkpoint in checkpoints:
                if total >= checkpoint and checkpoint not in reached:
                    observations[checkpoint].append(run); reached.add(checkpoint)
    return {f"{checkpoint}/16": {"mean_runs": round(statistics.mean(values), 2), "p90_runs": percentile(values, .90)} for checkpoint, values in observations.items()}


def progression_report() -> dict:
    requirements = [round(50 * 1.12 ** (level - 1)) for level in range(1, 10)]
    cumulative = list(itertools.accumulate(requirements))
    upgrades = {
        "vitality": [30 * level for level in range(1, 11)],
        "might": [40 * level for level in range(1, 11)],
        "guard": [40 * level for level in range(1, 11)],
    }
    profiles = {"casual": 30, "average": 95, "strong": 125}
    targets = {"first_vitality": 30, "vitality_level_3": sum(upgrades["vitality"][:3]),
               "vitality_level_5": sum(upgrades["vitality"][:5]), "max_one_vitality": sum(upgrades["vitality"]),
               "max_all": sum(sum(values) for values in upgrades.values())}
    runs = {profile: {target: math.ceil(cost / ash) for target, cost in targets.items()} for profile, ash in profiles.items()}
    return {
        "xp_requirements": requirements, "xp_cumulative": cumulative,
        "typical_full_run_xp": 525, "typical_level": max(index + 1 for index, xp in enumerate([0] + cumulative) if xp <= 525),
        "level_10_xp": cumulative[-1], "upgrade_costs": upgrades, "total_upgrade_cost": targets["max_all"],
        "milestone_ash_once": 85, "economy_profiles_ash_per_run": profiles, "estimated_runs": runs,
        "permanent_curve": {str(level): {"hp": 100 + 5 * level, "attack": 20 + level, "defense": 5 + level} for level in (0, 3, 5, 10)},
    }


def boss_and_build_report() -> dict:
    bosses = {"ashen_warden": {"hp": 145, "attack": 15, "defense": 11}, "sunken_pyre": {"hp": 135, "attack": 20, "defense": 5}}
    builds = {
        "burn": {"attack": 25, "defense": 9, "crit": .04, "skill_mult": 2.0, "dot": 6},
        "crit": {"attack": 28, "defense": 9, "crit": .06, "crit_mult": 1.75, "skill_mult": 2.0},
        "defense": {"attack": 24, "defense": 15, "crit": 0, "skill_mult": 2.0},
        "sustain": {"attack": 20, "defense": 7, "crit": 0, "skill_mult": 2.0, "healing_per_4_turns": 40},
        "skill": {"attack": 29, "defense": 9, "crit": 0, "skill_mult": 2.3},
        "low_hp": {"attack": 28, "defense": 9, "crit": .06, "skill_mult": 2.0, "basic_mult": 1.2},
        "generalist": {"attack": 24, "defense": 9, "crit": .03, "skill_mult": 2.0},
    }
    rows = {}
    for build_id, build in builds.items():
        rows[build_id] = {}
        for boss_id, boss in bosses.items():
            basic = combat_damage(build["attack"], boss["defense"]) * build.get("basic_mult", 1.0)
            expected_basic = basic * (1 + build.get("crit", 0) * (build.get("crit_mult", 1.5) - 1)) + build.get("dot", 0)
            skill = combat_damage(build["attack"], boss["defense"]) * build["skill_mult"]
            rows[build_id][boss_id] = {
                "expected_basic": round(expected_basic, 2), "skill_hit": round(skill, 2),
                "basic_actions_to_kill": math.ceil(boss["hp"] / expected_basic),
                "incoming_basic": combat_damage(boss["attack"], build["defense"]),
            }
    return {"method": "transparent static heuristic; excludes AI sequence and is not a graphical/full-run benchmark", "bosses": bosses, "builds": rows,
            "all_archetypes_have_positive_damage": all(row[boss]["expected_basic"] >= 1 for row in rows.values() for boss in bosses)}


def simulate_d4(seed: int, samples: int = 100000) -> dict:
    rng = random.Random(seed ^ 0xD4)
    rolls = []
    for _ in range(samples):
        position = count = 0
        while position < 29:
            position = min(29, position + rng.randint(1, 4)); count += 1
        rolls.append(count)
    return {"samples": samples, "mean_rolls": round(statistics.mean(rolls), 4), "p10": percentile(rolls, .10), "p90": percentile(rolls, .90)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=560056)
    parser.add_argument("--encounters", type=int, default=120000)
    parser.add_argument("--boards-per-biome", type=int, default=50000)
    parser.add_argument("--loot", type=int, default=100000)
    args = parser.parse_args()
    report = {
        "schema": 1, "seed": args.seed, "combat": combat_report(),
        "equipment": equipment_report(), "enemies": enemy_report(),
        "encounters": simulate_encounters(args.seed, args.encounters),
        "boards": simulate_boards(args.seed, args.boards_per_biome),
        "d4": simulate_d4(args.seed), "loot_100k": simulate_loot(args.seed, args.loot),
        "loot_10k": simulate_loot(args.seed ^ 10_000, 10_000),
        "collection": collection_estimate(args.seed), "progression": progression_report(),
        "bosses_and_builds": boss_and_build_report(),
        "thresholds": {"equipment": "review beyond +/-25% of same slot+rarity median", "enemy": "review threat/cost beyond +/-25% of same-cost median"},
    }
    failures = []
    if report["encounters"]["dead_templates"] or report["encounters"]["dead_enemies"]:
        failures.append("dead encounter content")
    if any(row["invalid"] for row in report["boards"].values()):
        failures.append("invalid generated board")
    report["failures"] = failures
    canonical = json.dumps(report, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    report["deterministic_sha256"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
