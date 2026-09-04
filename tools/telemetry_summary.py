#!/usr/bin/env python3
"""Summarize local Ashen Realm JSONL telemetry without contacting a network."""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("telemetry_dir", type=Path)
    parser.add_argument("--clean", action="store_true", help="Remove only telemetry JSONL/marker files after summarizing")
    args = parser.parse_args()
    directory = args.telemetry_dir.resolve()
    if not directory.is_dir():
        parser.error("telemetry_dir must be an existing directory")
    events = []
    invalid_lines = 0
    files = sorted(directory.glob("events_*.jsonl"))
    for path in files:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                item = json.loads(line)
                if isinstance(item, dict): events.append(item)
                else: invalid_lines += 1
            except json.JSONDecodeError:
                invalid_lines += 1
    names = Counter(item.get("event_name", "invalid") for item in events)
    run_results = Counter(); biomes = Counter(); bosses = Counter(); templates = Counter(); enemies = Counter(); weapons = Counter(); armors = Counter(); synergies = Counter(); errors = Counter()
    for item in events:
        name = item.get("event_name"); props = item.get("properties", {})
        if name == "run_started":
            biomes[props.get("biome_id", "unknown")] += 1; weapons[props.get("equipped_weapon_id") or "none"] += 1; armors[props.get("equipped_armor_id") or "none"] += 1
        elif name == "run_finished":
            run_results[props.get("result", "unknown")] += 1
            for synergy in props.get("active_synergy_ids", []): synergies[synergy] += 1
        elif name == "run_abandoned": run_results["abandoned"] += 1
        elif name == "combat_started":
            if props.get("template_id"): templates[props["template_id"]] += 1
            for enemy_id in props.get("enemy_ids", []): enemies[enemy_id] += 1
        elif name == "boss_finished": bosses[f"{props.get('boss_id', 'unknown')}:{props.get('result', 'unknown')}:phase_{props.get('phase_reached', 0)}"] += 1
        elif name == "error_reported": errors[props.get("error_code", "unknown")] += 1
    finished = sum(run_results[result] for result in ("victory", "defeat"))
    report = {
        "files": len(files), "events": len(events), "invalid_lines": invalid_lines,
        "event_counts": dict(names), "runs_started": names["run_started"], "run_results": dict(run_results),
        "win_rate_finished": round(run_results["victory"] / finished, 4) if finished else None,
        "biomes": dict(biomes), "boss_progress": dict(bosses), "templates": dict(templates), "enemies": dict(enemies),
        "weapons": dict(weapons), "armors": dict(armors), "synergies": dict(synergies), "errors": dict(errors),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if args.clean:
        for path in files: path.unlink()
        marker = directory / "session_open.marker"
        if marker.is_file(): marker.unlink()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
