#!/usr/bin/env python3
"""Informe matched-seed de ETAPA 63. No escribe saves ni modifica gameplay."""
from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def pct(value: int, total: int) -> float:
    return round(value * 100.0 / total, 2) if total else 0.0


def mean(values: Iterable[float]) -> float:
    values = list(values)
    return round(statistics.fmean(values), 4) if values else 0.0


def groups(rows: list[dict[str, Any]]) -> dict[tuple[str, str], list[dict[str, Any]]]:
    result: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        result[(row["biome"], row["policy"])].append(row)
    return result


def group_metrics(rows: list[dict[str, Any]]) -> dict[str, Any]:
    wins = sum(row["outcome"] == "victory" for row in rows)
    reached = [row for row in rows if row["boss_outcome"] != "not_reached"]
    return {
        "runs": len(rows), "wins": wins, "win_rate_pct": pct(wins, len(rows)),
        "boss_reach_pct": pct(len(reached), len(rows)),
        "boss_win_when_reached_pct": pct(sum(row["boss_outcome"] == "victory" for row in reached), len(reached)),
        "avg_boss_entry_hp": mean(row["boss_entry_hp"] for row in reached),
        "avg_damage_taken": mean(row["damage_taken"] for row in rows),
        "avg_healing": mean(row["healing"] for row in rows),
        "avg_guard_uses": mean(row["guard_uses"] for row in rows),
        "avg_second_wind_uses": mean(row["second_wind_uses"] for row in rows),
        "avg_ember_slash_uses": mean(row["ember_slash_uses"] for row in rows),
    }


def nested(rows: list[dict[str, Any]], field: str) -> Counter[str]:
    result: Counter[str] = Counter()
    for row in rows:
        result.update({str(key): int(value) for key, value in row.get(field, {}).items()})
    return result


def synergy_metrics(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    all_ids = sorted({item for row in rows for item in row.get("synergies", [])} | {
        "inferno_rhythm", "ashen_vengeance", "last_stand", "phoenix_blood",
        "cinder_precision", "iron_vigil", "mire_bloom", "runic_flow",
    })
    result = []
    for synergy_id in all_ids:
        owners = [row for row in rows if synergy_id in row.get("synergies", [])]
        tiles = [int(row["synergy_activation_tiles"][synergy_id]) for row in owners if synergy_id in row.get("synergy_activation_tiles", {})]
        result.append({
            "id": synergy_id, "runs": len(owners), "frequency_pct": pct(len(owners), len(rows)),
            "owner_win_rate_pct": pct(sum(row["outcome"] == "victory" for row in owners), len(owners)),
            "avg_activation_tile": mean(tiles), "timing_samples": len(tiles),
        })
    return result


def offer_metrics(rows: list[dict[str, Any]]) -> dict[str, Any]:
    quality = nested(rows, "offer_quality")
    sets = nested(rows, "offer_sets")
    total_options = sum(quality.values())
    total_sets = sum(sets.values())
    return {
        "options": {key: {"count": quality[key], "pct": pct(quality[key], total_options)} for key in sorted(quality)},
        "sets": {key: {"count": sets[key], "pct": pct(sets[key], total_sets)} for key in sorted(sets)},
        "total_options": total_options, "total_sets": total_sets,
    }


def build_metrics(rows: list[dict[str, Any]]) -> dict[str, Any]:
    counts = Counter(row.get("primary_build", "unknown") for row in rows)
    proportions = [count / len(rows) for count in counts.values()] if rows else []
    entropy = -sum(p * math.log(p, 2) for p in proportions if p > 0)
    simpson = 1.0 - sum(p * p for p in proportions)
    return {
        "distribution": {key: {"runs": count, "pct": pct(count, len(rows))} for key, count in counts.most_common()},
        "shannon_entropy_bits": round(entropy, 4), "simpson_diversity": round(simpson, 4),
    }


def pick_metrics(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    offers, picks = nested(rows, "upgrade_offers"), nested(rows, "upgrade_picks")
    result = []
    for item_id in sorted(set(offers) | set(picks)):
        owners = [row for row in rows if int(row.get("upgrade_picks", {}).get(item_id, 0)) > 0]
        result.append({
            "id": item_id, "offers": offers[item_id], "picks": picks[item_id],
            "pick_per_offer_pct": pct(picks[item_id], offers[item_id]),
            "owner_win_rate_pct": pct(sum(row["outcome"] == "victory" for row in owners), len(owners)),
        })
    return result


def matched_reward_strata(baseline: dict[str, dict[str, Any]], candidate: dict[str, dict[str, Any]], reward_id: str) -> dict[str, Any]:
    strata: dict[str, list[tuple[dict[str, Any], dict[str, Any]]]] = defaultdict(list)
    for run_id in sorted(baseline):
        left, right = baseline[run_id], candidate[run_id]
        left_has = int(left.get("upgrade_picks", {}).get(reward_id, 0)) > 0
        right_has = int(right.get("upgrade_picks", {}).get(reward_id, 0)) > 0
        key = "both" if left_has and right_has else "baseline_only" if left_has else "candidate_only" if right_has else "neither"
        strata[key].append((left, right))
    return {
        key: {
            "pairs": len(pairs),
            "baseline_win_pct": pct(sum(a["outcome"] == "victory" for a, _ in pairs), len(pairs)),
            "candidate_win_pct": pct(sum(b["outcome"] == "victory" for _, b in pairs), len(pairs)),
            "candidate_minus_baseline_win_pp": round(
                pct(sum(b["outcome"] == "victory" for _, b in pairs), len(pairs))
                - pct(sum(a["outcome"] == "victory" for a, _ in pairs), len(pairs)), 2),
            "avg_final_hp_delta": mean(b["final_hp"] - a["final_hp"] for a, b in pairs),
        }
        for key, pairs in sorted(strata.items())
    }


def death_segments(rows: list[dict[str, Any]]) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for row in rows:
        if row["outcome"] == "victory":
            continue
        tile = int(row["final_tile"])
        counts["early" if tile <= 9 else "mid" if tile <= 19 else "late" if tile < 29 else "boss"] += 1
    return dict(counts)


def regression_seed_results(baseline: dict[str, dict[str, Any]], candidate: dict[str, dict[str, Any]], path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    definitions = json.loads(path.read_text(encoding="utf-8"))
    output = []
    for label, definition in definitions.items():
        matches = [key for key, row in baseline.items() if row["seed"] == definition["seed"] and row["biome"] == definition["biome"] and row["policy"] == definition["policy"]]
        if not matches:
            output.append({"label": label, "seed": definition["seed"], "status": "not_in_final_cohort"})
            continue
        key = matches[0]
        left, right = baseline[key], candidate[key]
        output.append({
            "label": label, "seed": definition["seed"], "biome": definition["biome"], "policy": definition["policy"],
            "baseline_outcome": left["outcome"], "candidate_outcome": right["outcome"],
            "baseline_final_hp": left["final_hp"], "candidate_final_hp": right["final_hp"],
            "baseline_synergies": left.get("synergies", []), "candidate_synergies": right.get("synergies", []),
        })
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    baseline_rows, candidate_rows = load_jsonl(args.baseline), load_jsonl(args.candidate)
    baseline = {row["run_id"]: row for row in baseline_rows}
    candidate = {row["run_id"]: row for row in candidate_rows}
    if baseline.keys() != candidate.keys():
        raise SystemExit("Baseline y candidate no contienen los mismos run_id/seeds")
    board_mismatches = sum(baseline[key]["board_hash"] != candidate[key]["board_hash"] for key in baseline)
    group_rows = []
    baseline_groups, candidate_groups = groups(baseline_rows), groups(candidate_rows)
    for key in sorted(baseline_groups):
        left, right = group_metrics(baseline_groups[key]), group_metrics(candidate_groups[key])
        group_rows.append({
            "biome": key[0], "policy": key[1], "baseline": left, "candidate": right,
            "win_delta_pp": round(right["win_rate_pct"] - left["win_rate_pct"], 2),
        })
    changed = Counter()
    hp_deltas = []
    for key in baseline:
        left, right = baseline[key], candidate[key]
        changed[f'{left["outcome"]}_to_{right["outcome"]}'] += 1
        hp_deltas.append(right["final_hp"] - left["final_hp"])
    summary = {
        "stage": 63, "method": "matched_seed_same_biome_same_policy",
        "baseline_runs": len(baseline_rows), "candidate_runs": len(candidate_rows),
        "matched_pairs": len(baseline), "board_hash_mismatches": board_mismatches,
        "groups": group_rows,
        "overall": {
            "baseline": group_metrics(baseline_rows), "candidate": group_metrics(candidate_rows),
            "outcome_transitions": dict(changed), "avg_final_hp_delta": mean(hp_deltas),
        },
        "synergies": {"baseline": synergy_metrics(baseline_rows), "candidate": synergy_metrics(candidate_rows)},
        "offer_quality": {"baseline": offer_metrics(baseline_rows), "candidate": offer_metrics(candidate_rows)},
        "build_diversity": {"baseline": build_metrics(baseline_rows), "candidate": build_metrics(candidate_rows)},
        "upgrade_picks": {"baseline": pick_metrics(baseline_rows), "candidate": pick_metrics(candidate_rows)},
        "death_segments": {"baseline": death_segments(baseline_rows), "candidate": death_segments(candidate_rows)},
        "regression_seeds": regression_seed_results(baseline, candidate, Path("build/stage62/regression_seeds.json")),
        "matched_reward_analysis": {
            "iron_skin": matched_reward_strata(baseline, candidate, "iron_skin"),
            "ashen_bulwark": matched_reward_strata(baseline, candidate, "ashen_bulwark"),
            "caveat": "Estratos matched-seed descriptivos; las ofertas completas también cambian, por lo que no prueban causalidad aislada.",
        },
        "invariants": {
            "combat_math_changed": False, "base_stats_changed": False, "board_rules_changed": False,
            "save_or_profile_written": False, "save_version": 9, "debug_tools_enabled": False,
        },
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "comparison.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    with (args.output_dir / "win_rate_comparison.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["biome", "policy", "baseline_win_pct", "candidate_win_pct", "delta_pp", "baseline_boss_reach_pct", "candidate_boss_reach_pct"])
        for row in group_rows:
            writer.writerow([row["biome"], row["policy"], row["baseline"]["win_rate_pct"], row["candidate"]["win_rate_pct"], row["win_delta_pp"], row["baseline"]["boss_reach_pct"], row["candidate"]["boss_reach_pct"]])
    lines = ["# ETAPA 63 — Baseline vs Candidate", "", f"Pares matched-seed: **{len(baseline):,}**. Board mismatches: **{board_mismatches}**.", "", "| Bioma | Policy | Baseline | Candidate | Δ pp |", "|---|---:|---:|---:|---:|"]
    for row in group_rows:
        lines.append(f'| {row["biome"]} | {row["policy"]} | {row["baseline"]["win_rate_pct"]:.2f}% | {row["candidate"]["win_rate_pct"]:.2f}% | {row["win_delta_pp"]:+.2f} |')
    lines += ["", "La simulación aporta evidencia estadística; no sustituye el playtest humano."]
    (args.output_dir / "build_reward_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"matched_pairs": len(baseline), "board_mismatches": board_mismatches, "output": str(args.output_dir)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
