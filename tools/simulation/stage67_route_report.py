#!/usr/bin/env python3
"""Resumen pareado de BOARD_OLD vs BOARD_AGENCY para ETAPA 67."""
from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from statistics import mean


def load(path: Path) -> list[dict]:
    with path.open("r", encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def avg(rows: list[dict], key: str) -> float:
    return mean(float(row.get(key, 0)) for row in rows) if rows else 0.0


def summary(rows: list[dict]) -> dict:
    chosen, avoided, visited = Counter(), Counter(), Counter()
    for row in rows:
        chosen.update(row.get("route_chosen_tile_types", {}))
        avoided.update(row.get("route_avoided_tile_types", {}))
        visited.update(row.get("visited_tile_counts", {}))
    boss_rows = [row for row in rows if row.get("boss_outcome") != "not_reached"]
    return {
        "runs": len(rows),
        "win_rate": round(100 * sum(r.get("outcome") == "victory" for r in rows) / max(1, len(rows)), 2),
        "boss_reach": round(100 * len(boss_rows) / max(1, len(rows)), 2),
        "boss_win": round(100 * sum(r.get("boss_outcome") == "victory" for r in boss_rows) / max(1, len(boss_rows)), 2),
        "hp_at_boss": round(avg(boss_rows, "boss_entry_hp"), 2),
        "choices_per_run": round(avg(rows, "route_choice_count"), 3),
        "meaningful_choice_rate": round(100 * sum(r.get("route_meaningful_choices", 0) for r in rows) / max(1, sum(r.get("route_choice_count", 0) for r in rows)), 2),
        "combat_turns": round(avg(rows, "combat_turns"), 2),
        "damage_dealt": round(avg(rows, "damage_dealt"), 2),
        "damage_taken": round(avg(rows, "damage_taken"), 2),
        "xp": round(avg(rows, "xp"), 2),
        "ash": round(avg(rows, "ash"), 2),
        "heal_tiles": round(avg(rows, "heal_tiles"), 3),
        "elites": round(avg(rows, "elites"), 3),
        "events": round(avg(rows, "events"), 3),
        "treasures": round(avg(rows, "treasures"), 3),
        "chosen_types": dict(chosen),
        "avoided_types": dict(avoided),
        "visited_types": dict(visited),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--old", type=Path, required=True)
    parser.add_argument("--agency", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    old, agency = load(args.old), load(args.agency)
    old_map = {(r["biome"], r["policy"], r["seed"]): r for r in old}
    agency_map = {(r["biome"], r["policy"], r["seed"]): r for r in agency}
    paired = Counter()
    hp_delta = []
    for key in sorted(old_map.keys() & agency_map.keys()):
        before, after = old_map[key], agency_map[key]
        pair = ("victory" if before["outcome"] == "victory" else "defeat", "victory" if after["outcome"] == "victory" else "defeat")
        paired["->".join(pair)] += 1
        hp_delta.append(float(after.get("final_hp", 0)) - float(before.get("final_hp", 0)))
    by_policy = {}
    by_biome_policy = {}
    for policy in ["random", "aggressive", "defensive", "tactical"]:
        by_policy[policy] = {
            "old": summary([r for r in old if r["policy"] == policy]),
            "agency": summary([r for r in agency if r["policy"] == policy]),
        }
        for biome in ["ashen_wastes", "ember_marsh"]:
            by_biome_policy[f"{biome}/{policy}"] = {
                "old": summary([r for r in old if r["policy"] == policy and r["biome"] == biome]),
                "agency": summary([r for r in agency if r["policy"] == policy and r["biome"] == biome]),
            }
    report = {
        "schema": 1,
        "old": summary(old),
        "agency": summary(agency),
        "by_policy": by_policy,
        "by_biome_policy": by_biome_policy,
        "matched_outcomes": dict(paired),
        "matched_final_hp_delta_mean": round(mean(hp_delta), 3),
        "paired_runs": len(hp_delta),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
