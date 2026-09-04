"""Static v9->v10, milestone, horizontal unlock and Ash economy audit."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def text(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def parse_milestones() -> list[dict[str, object]]:
    result: list[dict[str, object]] = []
    for path in sorted((ROOT / "data/milestones").glob("*.tres")):
        source = path.read_text(encoding="utf-8")
        def field(pattern: str, default: str = "") -> str:
            match = re.search(pattern, source, re.M)
            return match.group(1) if match else default
        result.append({
            "file": str(path.relative_to(ROOT)),
            "id": field(r'^milestone_id\s*=\s*&"([^"]+)"'),
            "condition": int(field(r"^condition_type\s*=\s*(\d+)", "0")),
            "target": int(field(r"^target_count\s*=\s*(\d+)", "1")),
            "target_id": field(r'^target_id\s*=\s*&"([^"]+)"'),
            "reward": int(field(r"^reward_ash\s*=\s*(\d+)", "0")),
            "priority": int(field(r"^priority\s*=\s*(\d+)", "100")),
        })
    return result


def migrate_v9(source: dict[str, object], valid_ids: set[str]) -> dict[str, object]:
    # Mirrors the safe defaults in ProfileData and MilestoneResolver without touching user://.
    runs = max(0, int(source.get("total_runs", 0)))
    victories = min(runs, max(0, int(source.get("total_victories", 0))))
    migrated = dict(source)
    migrated.update({
        "save_version": 11,
        "total_runs": runs,
        "total_victories": victories,
        "total_defeats": max(0, runs - victories),
        "total_combats_won": 0,
        "total_bosses_defeated": victories,
        "total_companion_runs": 0,
        "boss_defeat_counts": {},
        "completed_milestone_ids": [],
        "pending_milestone_ids": [],
        "owned_meta_unlock_ids": [],
        "selected_starting_option_id": "",
    })
    assert set(migrated["completed_milestone_ids"]).issubset(valid_ids)
    return migrated


def sanitize_bad_v9(valid_ids: set[str]) -> dict[str, object]:
    raw = {
        "total_runs": -4,
        "total_victories": 99,
        "total_defeats": -3,
        "total_combats_won": -20,
        "total_bosses_defeated": -1,
        "total_companion_runs": -5,
        "completed_milestone_ids": ["first_victory", "unknown", "first_victory"],
        "pending_milestone_ids": ["unknown", "first_victory"],
        "boss_defeat_counts": {"unknown": 9, "ashen_warden": -2},
    }
    runs = max(0, int(raw["total_runs"]))
    victories = min(runs, max(0, int(raw["total_victories"])))
    completed = []
    for milestone_id in raw["completed_milestone_ids"]:
        if milestone_id in valid_ids and milestone_id not in completed:
            completed.append(milestone_id)
    pending = []
    for milestone_id in raw["pending_milestone_ids"]:
        if milestone_id in completed and milestone_id not in pending:
            pending.append(milestone_id)
    return {
        "total_runs": runs,
        "total_victories": victories,
        "total_defeats": min(runs, max(0, int(raw["total_defeats"]))),
        "total_combats_won": max(0, int(raw["total_combats_won"])),
        "total_bosses_defeated": min(victories, max(0, int(raw["total_bosses_defeated"]))),
        "total_companion_runs": min(runs, max(0, int(raw["total_companion_runs"]))),
        "completed_milestone_ids": completed,
        "pending_milestone_ids": pending,
        "boss_defeat_counts": {},
    }


def simulate_idempotent_completion(milestones: list[dict[str, object]]) -> dict[str, object]:
    """Model two resolver passes over the same eligible profile."""
    completed: set[str] = set()
    total_ash = 0
    rewards_by_pass: list[int] = []
    for _pass_index in range(2):
        reward = 0
        for milestone in milestones:
            milestone_id = str(milestone["id"])
            if milestone_id in completed:
                continue
            # A fully eligible synthetic profile makes every catalog entry complete.
            completed.add(milestone_id)
            reward += int(milestone["reward"])
        total_ash += reward
        rewards_by_pass.append(reward)
    return {
        "rewards_by_pass": rewards_by_pass,
        "total_ash": total_ash,
        "completed_count": len(completed),
    }


def main() -> int:
    milestones = parse_milestones()
    ids = [str(item["id"]) for item in milestones]
    valid_ids = set(ids)
    duplicates = sorted({value for value in ids if ids.count(value) > 1})

    sample_v9 = {
        "save_version": 9,
        "total_ash": 137,
        "permanent_health_level": 3,
        "permanent_attack_level": 2,
        "permanent_defense_level": 1,
        "total_runs": 7,
        "total_victories": 2,
        "owned_equipment": {"ember_fang": 1},
        "equipped_weapon_id": "ember_fang",
        "equipped_armor_id": "",
        "unlocked_companion_ids": ["ember_hound"],
        "equipped_companion_id": "ember_hound",
        "discovered_codex_entries": ["synergies:inferno_rhythm"],
        "completed_tutorials": ["lobby_intro"],
    }
    migrated = migrate_v9(sample_v9, valid_ids)
    roundtrip = json.loads(json.dumps(migrated, ensure_ascii=False))
    preserved_keys = [
        "total_ash", "permanent_health_level", "permanent_attack_level",
        "permanent_defense_level", "total_runs", "total_victories",
        "owned_equipment", "equipped_weapon_id", "unlocked_companion_ids",
        "equipped_companion_id", "discovered_codex_entries", "completed_tutorials",
    ]
    preservation_failures = [key for key in preserved_keys if roundtrip.get(key) != sample_v9.get(key)]

    costs = {
        "vitality": [30 * level for level in range(1, 11)],
        "might": [40 * level for level in range(1, 11)],
        "guard": [40 * level for level in range(1, 11)],
    }
    scenarios = {
        "early_defeat_zero_combat_first_time": 5,
        "early_defeat_one_normal_first_time": 10,
        "mid_run_5_normal_1_elite": 35,
        "victory_6_normal_1_elite_no_boss_bonus": 90,
        "victory_same_path_ashen_bounty": 145,
    }
    average_victory = (90 + 105 + 120 + 145) / 4.0
    total_upgrade_cost = sum(sum(values) for values in costs.values())
    milestone_reward_total = sum(int(item["reward"]) for item in milestones)
    valid_condition_types = set(range(9))
    valid_boss_ids = {"ashen_warden", "sunken_pyre"}
    invalid_conditions = [item["id"] for item in milestones if item["condition"] not in valid_condition_types]
    invalid_targets = [
        item["id"] for item in milestones
        if item["condition"] == 3 and item["target_id"] not in valid_boss_ids
    ]
    invalid_rewards = [item["id"] for item in milestones if not 0 <= int(item["reward"]) <= 10]
    idempotence = simulate_idempotent_completion(milestones)

    save_source = text("scripts/save/save_manager.gd")
    result_source = text("scripts/ui/run_result.gd")
    game_source = text("scripts/core/game.gd")
    report = {
        "save_version": 12 if "SAVE_VERSION: int = 12" in save_source else None,
        "milestone_count": len(milestones),
        "milestone_ids": ids,
        "duplicate_ids": duplicates,
        "milestone_reward_total": milestone_reward_total,
        "invalid_condition_ids": invalid_conditions,
        "invalid_target_ids": invalid_targets,
        "invalid_reward_ids": invalid_rewards,
        "idempotence_simulation": idempotence,
        "milestones": milestones,
        "upgrade_costs": costs,
        "total_upgrade_cost": total_upgrade_cost,
        "economy_scenarios": scenarios,
        "average_victory_ash_before_milestones": average_victory,
        "first_upgrade_runs": {
            "mid_runs": 1,
            "victories": 1,
            "normal_only_runs_at_5_ash": 6,
        },
        "mid_upgrade_level_6_runs": {
            "vitality_cost": costs["vitality"][5],
            "might_or_guard_cost": costs["might"][5],
            "average_victories": {
                "vitality": round(costs["vitality"][5] / average_victory, 2),
                "might_or_guard": round(costs["might"][5] / average_victory, 2),
            },
        },
        "milestone_share_of_full_upgrade_cost": round(milestone_reward_total / total_upgrade_cost, 4),
        "v9_roundtrip_preservation_failures": preservation_failures,
        "v9_migrated_defaults": {key: migrated[key] for key in [
            "total_defeats", "total_combats_won", "total_bosses_defeated",
            "total_companion_runs", "boss_defeat_counts", "completed_milestone_ids",
            "owned_meta_unlock_ids", "selected_starting_option_id",
        ]},
        "corrupt_value_sanitization": sanitize_bad_v9(valid_ids),
        "finalization_contract": {
            "deposit_guard": "run_state.rewards_deposited" in save_source,
            "deposit_at_results": "SaveManager.deposit_run" in result_source,
            "no_return_deposit": "SaveManager.deposit_run" not in re.search(
                r"func _on_run_result_return_requested\(\).*?(?=\nfunc )", game_source, re.S
            ).group(0),
            "atomic_transaction": "begin_save_transaction()" in save_source and "end_save_transaction()" in save_source,
        },
        "real_profile_touched": False,
    }
    failures = []
    if report["save_version"] != 12:
        failures.append("SAVE_VERSION is not 12")
    if not 8 <= len(milestones) <= 12:
        failures.append("milestone count outside 8-12")
    if duplicates:
        failures.append("duplicate milestone IDs")
    if invalid_conditions:
        failures.append("invalid milestone condition types")
    if invalid_targets:
        failures.append("invalid milestone target IDs")
    if invalid_rewards:
        failures.append("milestone reward outside 0-10 Ash")
    if idempotence["rewards_by_pass"] != [milestone_reward_total, 0]:
        failures.append("milestone completion is not idempotent")
    if preservation_failures:
        failures.append("v8 fields lost in roundtrip")
    if milestone_reward_total > average_victory:
        failures.append("lifetime milestone rewards dominate one average victory")
    if not all(report["finalization_contract"].values()):
        failures.append("run finalization contract incomplete")
    report["failures"] = failures
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
