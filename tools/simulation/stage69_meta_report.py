"""ETAPA 69: empirical Ash, duplicate sink and horizontal progression simulation."""

from __future__ import annotations

import json
import random
import statistics
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RUNS_PATH = ROOT / "build/stage68/agency/runs.jsonl"
OUTPUT_PATH = ROOT / "build/stage69/meta_simulation.json"
TRAJECTORIES_PER_POLICY = 2000
MAX_RUNS = 120

UNLOCKS = {
    "ember_focus": {"cost": 45, "milestone": None},
    "vigil_focus": {"cost": 90, "milestone": "first_expedition"},
    "renewal_focus": {"cost": 120, "milestone": "first_victory"},
}
POWER_BASE = {"vitality": 30, "might": 40, "guard": 40}
SALVAGE = {0: 10, 1: 20, 2: 35}


def load_runs() -> list[dict]:
    with RUNS_PATH.open("r", encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def percentile(values: list[int], ratio: float) -> float | None:
    clean = sorted(value for value in values if value > 0)
    if not clean:
        return None
    return clean[min(len(clean) - 1, round((len(clean) - 1) * ratio))]


def complete_milestones(state: dict, run: dict) -> int:
    new_rewards = 0
    candidates: list[tuple[str, bool, int]] = [
        ("first_expedition", state["runs"] >= 1, 5),
        ("five_expeditions", state["runs"] >= 5, 10),
        ("companion_expedition", state["runs"] >= 1, 5),
        ("first_victory", state["victories"] >= 1, 10),
        ("ten_combats", state["combats"] >= 10, 10),
        ("first_epic", state["epics"] >= 1, 10),
        ("equipment_collector", len(state["inventory"]) >= 8, 10),
        ("first_synergy", state["synergies"] >= 1, 5),
        ("warden_defeated", state["warden_wins"] >= 1, 10),
        ("pyre_defeated", state["pyre_wins"] >= 1, 10),
    ]
    for milestone_id, eligible, reward in candidates:
        if eligible and milestone_id not in state["milestones"]:
            state["milestones"].add(milestone_id)
            new_rewards += reward
    return new_rewards


def cheapest_power(state: dict) -> tuple[str, int] | None:
    candidates = [
        (branch, base * (state["power"][branch] + 1))
        for branch, base in POWER_BASE.items()
        if state["power"][branch] < 10
    ]
    return min(candidates, key=lambda item: (item[1], item[0])) if candidates else None


def available_unlock(state: dict) -> tuple[str, int] | None:
    for unlock_id, data in UNLOCKS.items():
        if unlock_id in state["unlocks"]:
            continue
        required = data["milestone"]
        if required is None or required in state["milestones"]:
            return unlock_id, data["cost"]
    return None


def purchase(state: dict, policy: str) -> bool:
    power = cheapest_power(state)
    unlock = available_unlock(state)
    order: list[str]
    if policy == "POWER_FIRST":
        order = ["power", "unlock"] if power is not None else ["unlock"]
    elif policy == "UNLOCK_FIRST":
        order = ["unlock", "power"] if unlock is not None else ["power"]
    else:
        preferred = "unlock" if state["last_purchase"] != "unlock" else "power"
        order = [preferred, "power" if preferred == "unlock" else "unlock"]
    for category in order:
        if category == "power" and power is not None and state["ash"] >= power[1]:
            state["ash"] -= power[1]
            state["power"][power[0]] += 1
            state["power_purchases"] += 1
            state["last_purchase"] = "power"
            return True
        if category == "unlock" and unlock is not None and state["ash"] >= unlock[1]:
            state["ash"] -= unlock[1]
            state["unlocks"].add(unlock[0])
            state["unlock_purchases"] += 1
            state["last_purchase"] = "unlock"
            return True
    return False


def simulate_trajectory(records: list[dict], policy: str, seed: int) -> dict:
    rng = random.Random(seed)
    state = {
        "ash": 0, "runs": 0, "victories": 0, "combats": 0,
        "epics": 0, "synergies": 0, "warden_wins": 0, "pyre_wins": 0,
        "inventory": set(), "milestones": set(), "unlocks": set(),
        "power": {key: 0 for key in POWER_BASE}, "last_purchase": "",
        "power_purchases": 0, "unlock_purchases": 0,
        "duplicates": 0, "loot": 0, "salvage_ash": 0,
    }
    result = {"first_power": 0, "first_unlock": 0, "three_unlocks": 0, "medium_power": 0, "catalog_complete": 0}
    for run_index in range(1, MAX_RUNS + 1):
        run = records[rng.randrange(len(records))]
        state["runs"] += 1
        state["ash"] += max(0, int(run.get("ash", 0)))
        state["combats"] += max(0, int(run.get("combat_wins", 0)))
        won = run.get("outcome") == "victory"
        state["victories"] += int(won)
        state["synergies"] += int(bool(run.get("synergies")))
        if won and run.get("biome") == "ashen_wastes": state["warden_wins"] += 1
        if won and run.get("biome") == "ember_marsh": state["pyre_wins"] += 1
        loot_id = str(run.get("loot_id", ""))
        if loot_id:
            state["loot"] += 1
            rarity = int(run.get("loot_rarity", 0))
            state["epics"] += int(rarity == 2)
            if loot_id in state["inventory"]:
                value = SALVAGE.get(rarity, 10)
                state["duplicates"] += 1
                state["salvage_ash"] += value
                state["ash"] += value
            else:
                state["inventory"].add(loot_id)
        state["ash"] += complete_milestones(state, run)
        while purchase(state, policy):
            pass
        if not result["first_power"] and sum(state["power"].values()) > 0: result["first_power"] = run_index
        if not result["first_unlock"] and state["unlocks"]: result["first_unlock"] = run_index
        if not result["three_unlocks"] and len(state["unlocks"]) == 3: result["three_unlocks"] = run_index
        if not result["medium_power"] and max(state["power"].values()) >= 5: result["medium_power"] = run_index
        if not result["catalog_complete"] and len(state["unlocks"]) == len(UNLOCKS): result["catalog_complete"] = run_index
        if result["catalog_complete"] and result["medium_power"]:
            break
    result.update({
        "runs_simulated": state["runs"],
        "duplicates": state["duplicates"], "loot": state["loot"],
        "salvage_ash": state["salvage_ash"], "final_ash": state["ash"],
        "power_purchases": state["power_purchases"], "unlock_purchases": state["unlock_purchases"],
    })
    return result


def summarize_trajectories(values: list[dict]) -> dict:
    def summary(key: str) -> dict:
        entries = [int(value[key]) for value in values if int(value[key]) > 0]
        return {"median": percentile(entries, .5), "p25": percentile(entries, .25), "p75": percentile(entries, .75), "completion_rate": round(100 * len(entries) / len(values), 2)}
    loot = sum(value["loot"] for value in values)
    duplicates = sum(value["duplicates"] for value in values)
    return {
        "trajectories": len(values),
        "first_power_upgrade_runs": summary("first_power"),
        "first_horizontal_unlock_runs": summary("first_unlock"),
        "three_unlocks_runs": summary("three_unlocks"),
        "medium_power_branch_runs": summary("medium_power"),
        "pilot_catalog_complete_runs": summary("catalog_complete"),
        "duplicate_rate_percent": round(100 * duplicates / max(1, loot), 2),
        "dead_reward_rate_percent": 0.0,
        "mean_salvage_ash": round(statistics.mean(value["salvage_ash"] for value in values), 2),
        "mean_power_purchases": round(statistics.mean(value["power_purchases"] for value in values), 2),
        "mean_unlock_purchases": round(statistics.mean(value["unlock_purchases"] for value in values), 2),
    }


def main() -> int:
    records = load_runs()
    victories = [int(run["ash"]) for run in records if run["outcome"] == "victory"]
    defeats = [int(run["ash"]) for run in records if run["outcome"] != "victory"]
    event_ash = sum(int(run.get("event_choices", {}).get("wanderer_return:b", 0)) * 30 + int(run.get("event_choices", {}).get("sunken_cache:a", 0)) * 25 for run in records)
    treasure_ash = sum(int(run.get("treasure_reward_types", {}).get("ash", 0)) * 25 for run in records)
    trajectories = {}
    for policy_index, policy in enumerate(["POWER_FIRST", "UNLOCK_FIRST", "BALANCED"]):
        values = [simulate_trajectory(records, policy, 690069 + policy_index * 10_000_019 + index * 104729) for index in range(TRAJECTORIES_PER_POLICY)]
        trajectories[policy] = summarize_trajectories(values)
    report = {
        "schema": 1,
        "source_runs": len(records),
        "source": "Stage68 EVENT_TREASURE_AGENCY empirical runs",
        "ash_economy": {
            "mean_per_run": round(statistics.mean(int(run["ash"]) for run in records), 3),
            "mean_per_victory": round(statistics.mean(victories), 3),
            "mean_per_defeat": round(statistics.mean(defeats), 3),
            "event_ash_per_run": round(event_ash / len(records), 3),
            "treasure_ash_per_run": round(treasure_ash / len(records), 3),
            "boss_victory_base_ash": 50,
        },
        "unlock_costs": {key: value["cost"] for key, value in UNLOCKS.items()},
        "power_costs": {key: [base * level for level in range(1, 11)] for key, base in POWER_BASE.items()},
        "trajectories_per_policy": TRAJECTORIES_PER_POLICY,
        "total_trajectories": TRAJECTORIES_PER_POLICY * 3,
        "policies": trajectories,
        "save_or_profile_written": False,
        "failures": [],
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
