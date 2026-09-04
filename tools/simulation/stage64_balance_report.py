#!/usr/bin/env python3
"""Agrega ablations matched-seed de ETAPA 64 sin escribir saves ni Resources."""
from __future__ import annotations

import argparse
import csv
import json
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


METRICS = (
    "damage_dealt", "damage_taken", "combat_turns", "enemies_killed_before_intent",
    "enemy_intents_executed", "boss_entry_hp", "boss_damage_dealt", "healing",
    "healing_ember_blood", "healing_iron_vigil", "healing_second_wind", "guard_uses",
    "second_wind_uses", "ember_slash_uses", "energy_generated", "energy_spent",
    "energy_wasted_at_cap", "energy_unspent_combat_end", "turns_without_usable_skill", "burn_damage", "boss_burn_damage",
    "burn_applications", "burn_waste_stacks", "damage_mitigated_cinder",
    "damage_mitigated_guard", "max_temporary_defense",
)


def mean(values: Iterable[float]) -> float:
    clean = [float(value) for value in values if value is not None]
    return round(statistics.fmean(clean), 4) if clean else 0.0


def pct(numerator: int, denominator: int) -> float:
    return round(100.0 * numerator / denominator, 2) if denominator else 0.0


def load(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            if line.strip():
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError as exc:
                    raise SystemExit(f"JSON inválido en {path}:{number}: {exc}") from exc
    return rows


def grouped(rows: list[dict[str, Any]], keys: tuple[str, ...]) -> list[dict[str, Any]]:
    buckets: dict[tuple[str, ...], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        buckets[tuple(str(row.get(key, "")) for key in keys)].append(row)
    result = []
    for identity, group in sorted(buckets.items()):
        reached = [row for row in group if row.get("boss_outcome") != "not_reached"]
        item: dict[str, Any] = dict(zip(keys, identity))
        item.update({
            "runs": len(group),
            "wins": sum(row["outcome"] == "victory" for row in group),
            "win_rate_pct": pct(sum(row["outcome"] == "victory" for row in group), len(group)),
            "boss_reach_pct": pct(len(reached), len(group)),
            "boss_win_when_reached_pct": pct(sum(row.get("boss_outcome") == "victory" for row in reached), len(reached)),
        })
        for metric in METRICS:
            values = (row.get(metric, 0) for row in group)
            if metric == "boss_entry_hp":
                values = (row.get(metric, -1) for row in group if row.get(metric, -1) >= 0)
            item[f"avg_{metric}"] = mean(values)
        item["avg_damage_per_combat"] = mean(row.get("damage_dealt", 0) / max(1, row.get("combats", 0)) for row in group)
        item["avg_received_per_combat"] = mean(row.get("damage_taken", 0) / max(1, row.get("combats", 0)) for row in group)
        item["avg_net_hp_cost_per_combat"] = mean((row.get("damage_taken", 0) - row.get("healing", 0)) / max(1, row.get("combats", 0)) for row in group)
        result.append(item)
    return result


def paired(baseline: list[dict[str, Any]], candidate: list[dict[str, Any]]) -> dict[str, Any]:
    left = {row["run_id"]: row for row in baseline}
    right = {row["run_id"]: row for row in candidate}
    keys = sorted(left.keys() & right.keys())
    outcomes = Counter()
    hp_deltas = []
    board_mismatches = 0
    metric_deltas: dict[str, list[float]] = defaultdict(list)
    by_policy: dict[str, list[str]] = defaultdict(list)
    for key in keys:
        before, after = left[key], right[key]
        outcomes[f"{before['outcome']}->{after['outcome']}"] += 1
        hp_deltas.append(after["final_hp"] - before["final_hp"])
        board_mismatches += before["board_hash"] != after["board_hash"]
        by_policy[before["policy"]].append(key)
        for metric in METRICS:
            metric_deltas[metric].append(float(after.get(metric, 0)) - float(before.get(metric, 0)))
    policies = {}
    for policy, policy_keys in sorted(by_policy.items()):
        base_wins = sum(left[key]["outcome"] == "victory" for key in policy_keys)
        cand_wins = sum(right[key]["outcome"] == "victory" for key in policy_keys)
        policies[policy] = {
            "pairs": len(policy_keys), "baseline_win_pct": pct(base_wins, len(policy_keys)),
            "candidate_win_pct": pct(cand_wins, len(policy_keys)),
            "delta_pp": round(100.0 * (cand_wins - base_wins) / len(policy_keys), 2),
        }
    return {
        "pairs": len(keys), "board_mismatches": board_mismatches, "outcomes": dict(outcomes),
        "avg_final_hp_delta": mean(hp_deltas), "metric_deltas": {key: mean(values) for key, values in metric_deltas.items()},
        "by_policy": policies,
    }


def curves(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    targets = (5, 10, 15, 20, 29)
    buckets: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if not row.get("curve"):
            continue
        for target in targets:
            point = min(row["curve"], key=lambda value: abs(int(value["tile"]) - target))
            if abs(int(point["tile"]) - target) <= 3:
                buckets[(row["primary_build"], target)].append(point)
    output = []
    for (build, target), points in sorted(buckets.items()):
        output.append({
            "build": build, "target_tile": target, "samples": len(points),
            "avg_hp": mean(point["hp"] for point in points), "avg_attack": mean(point["attack"] for point in points),
            "avg_defense": mean(point["defense"] for point in points), "avg_level": mean(point["level"] for point in points),
        })
    return output


def catalogs(rows: list[dict[str, Any]]) -> dict[str, Any]:
    rarity = Counter()
    fallbacks = 0
    effects: dict[str, dict[str, Any]] = {}
    relevant = (
        "iron_skin", "ashen_bulwark", "ashen_reprisal", "cinder_skin", "ember_blood",
        "burning_strike", "relentless_flame", "pyre_heart", "last_ember", "burning_resolve",
    )
    for row in rows:
        rarity.update({key: int(value) for key, value in row.get("rarity_rolls", {}).items()})
        fallbacks += int(row.get("rarity_fallbacks", 0))
    for effect in relevant:
        owners = [row for row in rows if int(row.get("upgrade_picks", {}).get(effect, 0)) > 0]
        triggered = [row for row in owners if int(row.get("effect_triggers", {}).get(effect, 0)) > 0]
        effects[effect] = {
            "owners": len(owners), "owner_pct": pct(len(owners), len(rows)),
            "owner_win_pct": pct(sum(row["outcome"] == "victory" for row in owners), len(owners)),
            "triggered_owner_pct": pct(len(triggered), len(owners)),
            "avg_triggers_when_triggered": mean(row["effect_triggers"].get(effect, 0) for row in triggered),
        }
    common = rarity.get("0", 0)
    return {
        "rarity_rolls": dict(rarity), "common_rolls": common, "fallbacks": fallbacks,
        "common_fallback_pct": pct(fallbacks, common), "effects": effects,
    }


def combinations(rows: list[dict[str, Any]]) -> dict[str, Any]:
    definitions = {
        "defense_core_3": {"iron_skin", "ashen_bulwark", "cinder_skin"},
        "defense_full": {"iron_skin", "ashen_bulwark", "cinder_skin"},
        "sustain_core": {"ember_blood"},
        "low_hp_pair": {"last_ember", "cinder_skin"},
    }
    output = {}
    for name, required in definitions.items():
        group = []
        for row in rows:
            owned = set(row.get("upgrade_picks", {}))
            synergies = set(row.get("synergies", []))
            extra_match = name != "defense_full" or "iron_vigil" in synergies
            extra_match = extra_match and (name != "sustain_core" or row.get("second_wind_uses", 0) > 0)
            if required <= owned and extra_match:
                group.append(row)
        output[name] = {
            "runs": len(group), "frequency_pct": pct(len(group), len(rows)),
            "win_rate_pct": pct(sum(row["outcome"] == "victory" for row in group), len(group)),
            "avg_boss_entry_hp": mean(row.get("boss_entry_hp", -1) for row in group if row.get("boss_entry_hp", -1) >= 0),
            "avg_damage_taken": mean(row.get("damage_taken", 0) for row in group),
            "avg_healing": mean(row.get("healing", 0) for row in group),
        }
    low_hp = [row for row in rows if int(row.get("first_low_hp_tile", -1)) >= 0]
    output["low_hp_activated"] = {
        "runs": len(low_hp), "frequency_pct": pct(len(low_hp), len(rows)),
        "survival_pct": pct(sum(row["outcome"] == "victory" for row in low_hp), len(low_hp)),
        "avg_activation_tile": mean(row["first_low_hp_tile"] for row in low_hp),
    }
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--experiments-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--final-candidate", default="")
    args = parser.parse_args()
    baseline = load(args.baseline)
    experiments: dict[str, list[dict[str, Any]]] = {}
    for path in sorted(args.experiments_root.glob("*/runs.jsonl")):
        if path.resolve() != args.baseline.resolve():
            experiments[path.parent.name] = load(path)
    comparisons = {name: paired(baseline, rows) for name, rows in experiments.items()}
    evidence = {
        "baseline_contract": "BASELINE_64=STATE_AFTER_STAGE63_CANDIDATE_C",
        "baseline_runs": len(baseline), "baseline_by_policy_biome": grouped(baseline, ("biome", "policy")),
        "baseline_by_policy": grouped(baseline, ("policy",)), "baseline_by_build": grouped(baseline, ("primary_build",)),
        "baseline_by_boss_build": grouped([row for row in baseline if row.get("boss_id")], ("boss_id", "primary_build")),
        "time_to_power": curves(baseline), "catalog_audit": catalogs(baseline), "combinations": combinations(baseline),
        "experiments": {name: {"runs": len(rows), "paired": comparisons[name]} for name, rows in experiments.items()},
    }
    if args.final_candidate and args.final_candidate in experiments:
        evidence["final_candidate"] = {
            "name": args.final_candidate, "runs": len(experiments[args.final_candidate]),
            "by_policy_biome": grouped(experiments[args.final_candidate], ("biome", "policy")),
            "by_policy": grouped(experiments[args.final_candidate], ("policy",)),
            "by_build": grouped(experiments[args.final_candidate], ("primary_build",)),
            "by_boss_build": grouped([row for row in experiments[args.final_candidate] if row.get("boss_id")], ("boss_id", "primary_build")),
            "paired": comparisons[args.final_candidate], "catalog_audit": catalogs(experiments[args.final_candidate]),
        }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "stage64_evidence.json").write_text(json.dumps(evidence, indent=2, ensure_ascii=False), encoding="utf-8")
    with (args.output_dir / "ablation_summary.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["experiment", "pairs", "policy", "baseline_win_pct", "candidate_win_pct", "delta_pp", "hp_delta", "board_mismatches"])
        for name, comparison in sorted(comparisons.items()):
            for policy, values in comparison["by_policy"].items():
                writer.writerow([name, comparison["pairs"], policy, values["baseline_win_pct"], values["candidate_win_pct"], values["delta_pp"], comparison["avg_final_hp_delta"], comparison["board_mismatches"]])
    print(json.dumps({"baseline_runs": len(baseline), "experiments": len(experiments), "output": str(args.output_dir), "final_candidate": args.final_candidate}))


if __name__ == "__main__":
    main()
