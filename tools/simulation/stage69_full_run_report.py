"""Summarize the matched Stage 69 neutral/focus full-run validation."""

from __future__ import annotations

import json
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "build/stage69/full_run"
ARMS = ["default", "ember", "vigil", "renewal"]
AFFINITY_IDS = {
    "offense": {"burning_strike", "relentless_flame", "pyre_heart"},
    "defense": {"ashen_bulwark", "ashen_reprisal", "cinder_skin"},
    "sustain": {"ember_blood", "last_ember"},
}
FOCUS_SKILLS = {"ember": "ember_slash", "vigil": "ashen_guard", "renewal": "second_wind"}


def load(arm: str) -> list[dict]:
    path = BASE / arm / "runs.jsonl"
    with path.open("r", encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def summarize(rows: list[dict]) -> dict:
    wins = sum(row["outcome"] == "victory" for row in rows)
    reached = [row for row in rows if row.get("boss_outcome") != "not_reached"]
    affinity = Counter()
    augment_skills = Counter()
    for row in rows:
        for boon_id, count in row.get("boons", {}).items():
            for name, ids in AFFINITY_IDS.items():
                if boon_id in ids: affinity[name] += int(count)
        for augment_id, count in row.get("augments", {}).items():
            if augment_id in {"searing_edge", "executioners_ember", "ember_efficiency"}: augment_skills["ember_slash"] += int(count)
            if augment_id in {"reinforced_ash", "counter_guard", "stored_embers"}: augment_skills["ashen_guard"] += int(count)
            if augment_id in {"quick_recovery", "deep_breath", "ashen_renewal"}: augment_skills["second_wind"] += int(count)
    return {
        "runs": len(rows),
        "win_rate": round(100 * wins / len(rows), 2),
        "boss_reach": round(100 * len(reached) / len(rows), 2),
        "hp_at_boss": round(sum(row.get("boss_entry_hp", 0) for row in reached) / max(1, len(reached)), 3),
        "boon_stacks_per_run": {key: round(value / len(rows), 3) for key, value in affinity.items()},
        "augment_stacks_per_run": {key: round(value / len(rows), 3) for key, value in augment_skills.items()},
    }


def main() -> int:
    rows = {arm: load(arm) for arm in ARMS}
    report = {"schema": 1, "arms": {}, "matched": {}, "failures": []}
    for arm in ARMS:
        report["arms"][arm] = {"overall": summarize(rows[arm]), "by_policy": {}}
        grouped = defaultdict(list)
        for row in rows[arm]: grouped[row["policy"]].append(row)
        report["arms"][arm]["by_policy"] = {policy: summarize(values) for policy, values in grouped.items()}
    baseline = rows["default"]
    for arm in ARMS[1:]:
        outcomes = Counter()
        hp_delta = 0
        for old, new in zip(baseline, rows[arm]):
            outcomes[f"{old['outcome']}->{new['outcome']}"] += 1
            hp_delta += int(new["final_hp"]) - int(old["final_hp"])
        report["matched"][arm] = {
            "outcomes": dict(outcomes),
            "mean_final_hp_delta": round(hp_delta / len(baseline), 3),
            "win_rate_delta": round(report["arms"][arm]["overall"]["win_rate"] - report["arms"]["default"]["overall"]["win_rate"], 2),
        }
    output = ROOT / "build/stage69/full_run_comparison.json"
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
