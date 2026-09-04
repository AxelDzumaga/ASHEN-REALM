#!/usr/bin/env python3
"""Static audit and deterministic 1,000-session telemetry simulation."""
from __future__ import annotations

import argparse
import json
import random
import re
import tempfile
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "data/telemetry/event_schema.json"
FORBIDDEN_PROPERTIES = {"name", "email", "username", "device_id", "ip", "path", "password", "token", "location"}
NETWORK_APIS = ("HTTPClient", "HTTPRequest", "TCPServer", "StreamPeerTCP", "PacketPeerUDP", "WebSocketPeer")
MAX_STRING = 64
MAX_ARRAY = 8
MAX_FILE = 512 * 1024
MAX_TOTAL = 2 * 1024 * 1024
MAX_FILES = 3


def valid_value(value: object, expected: str) -> bool:
    if expected == "bool":
        return isinstance(value, bool)
    if expected == "int":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "float":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "string":
        return isinstance(value, str) and len(value) <= MAX_STRING and not unsafe_string(value)
    if expected == "string_array":
        return isinstance(value, list) and len(value) <= MAX_ARRAY and all(isinstance(item, str) and len(item) <= MAX_STRING and not unsafe_string(item) for item in value)
    return False


def unsafe_string(value: str) -> bool:
    lowered = value.lower()
    return any(term in lowered for term in ("\\", "/", "@", "user:", "res:", "appdata", "password", "token"))


def validate_event(schema: dict, event: dict) -> list[str]:
    errors: list[str] = []
    contract = schema["events"].get(event.get("event_name"))
    if contract is None:
        return ["unknown_event"]
    properties = event.get("properties")
    if not isinstance(properties, dict):
        return ["properties_not_dictionary"]
    allowed = contract["properties"]
    for required in contract["required"]:
        if required not in properties:
            errors.append(f"missing:{required}")
    for key, value in properties.items():
        if key not in allowed:
            errors.append(f"unknown_property:{key}")
        elif not valid_value(value, allowed[key]):
            errors.append(f"invalid_value:{key}")
    return errors


def event(name: str, properties: dict, session: int) -> dict:
    return {"schema_version": 1, "event_name": name, "timestamp_utc": "2026-08-23T12:00:00Z", "session_id": f"session_{session:04d}", "properties": properties}


def simulate(schema: dict, sessions: int, seed: int) -> tuple[list[dict], Counter]:
    rng = random.Random(seed)
    events: list[dict] = []
    counts = Counter()
    for session in range(sessions):
        session_events = [
            event("app_started", {"environment": "development"}, session),
            event("session_started", {"previous_session_unclean": session % 97 == 0}, session),
        ]
        if session % 97 == 0:
            session_events.append(event("unclean_exit_detected", {}, session))
        biome = "ashen_wastes" if session % 2 == 0 else "ember_marsh"
        session_events.append(event("run_started", {
            "biome_id": biome, "equipped_weapon_id": rng.choice(["ember_fang", "ashen_blade", "runic_edge"]),
            "equipped_armor_id": rng.choice(["warden_plate", "mire_vest", ""]),
            "companion_id": rng.choice(["ember_hound", ""]), "skill_loadout_ids": ["ember_slash", "ashen_guard", "second_wind"],
        }, session))
        abandoned = rng.random() < .18
        combats = rng.randint(1, 5) if abandoned else rng.randint(7, 11)
        for combat in range(combats):
            encounter_type = "elite" if combat == 5 else "normal"
            template = rng.choice(["solo_assault", "duo_assault", "defender_assault_support"])
            enemy_ids = [rng.choice(["ash_stalker", "ashen_mirecaller", "ember_wretch"])]
            if "duo" in template: enemy_ids.append("ember_wretch")
            if template == "defender_assault_support": enemy_ids.extend(["hollow_guard", "ember_acolyte"])
            session_events.append(event("combat_started", {"encounter_type": encounter_type, "enemy_count": len(enemy_ids), "enemy_ids": enemy_ids, "template_id": template, "biome_id": biome, "board_progress_bucket": "early" if combat < 3 else "mid"}, session))
            session_events.append(event("combat_finished", {"result": "victory", "turn_count": rng.randint(2, 8), "player_hp_bucket": "high", "companion_alive": True, "enemy_count": 1 if "solo" in template else 2 if "duo" in template else 3, "encounter_type": encounter_type}, session))
        if abandoned:
            session_events.append(event("run_abandoned", {"biome_id": biome, "board_position": combats * 2, "run_level": min(10, 1 + combats // 2), "combats_won": combats, "board_progress_bucket": "mid"}, session))
        else:
            boss = "ashen_warden" if biome == "ashen_wastes" else "sunken_pyre"
            session_events.extend([
                event("boss_started", {"boss_id": boss, "biome_id": biome}, session),
                event("boss_phase_reached", {"boss_id": boss, "phase": 2}, session),
                event("boss_finished", {"boss_id": boss, "result": "victory", "phase_reached": 3}, session),
                event("run_finished", {"result": "victory", "biome_id": biome, "run_level": 8, "combats_won": combats, "board_progress_bucket": "boss", "boss_id": boss, "active_synergy_count": 1, "active_synergy_ids": ["inferno_rhythm"], "loot_rarity": "rare", "duration_bucket": "10_to_20m", "ash_earned_bucket": "75_plus", "ember_slash_uses": 3, "ashen_guard_uses": 2, "second_wind_uses": 1, "reason": "boss_defeated"}, session),
            ])
        session_events.append(event("session_ended", {"reason": "clean_shutdown"}, session))
        events.extend(session_events)
        counts["events"] += len(session_events)
        counts["runs"] += 1
        counts["abandoned"] += abandoned
    return events, counts


def rotation_simulation(events: list[dict]) -> dict:
    with tempfile.TemporaryDirectory(prefix="ashen_telemetry_") as temp:
        directory = Path(temp)
        current: Path | None = None
        for index, item in enumerate(events):
            line = json.dumps(item, separators=(",", ":"), ensure_ascii=False) + "\n"
            if current is None or current.stat().st_size + len(line.encode()) > MAX_FILE:
                current = directory / f"events_{index:08d}.jsonl"
                current.touch()
            with current.open("a", encoding="utf-8") as handle:
                handle.write(line)
            files = sorted(directory.glob("events_*.jsonl"))
            total = sum(path.stat().st_size for path in files)
            while files and (len(files) > MAX_FILES or total > MAX_TOTAL):
                oldest = files.pop(0); total -= oldest.stat().st_size; oldest.unlink()
        files = sorted(directory.glob("events_*.jsonl"))
        return {"files": len(files), "total_bytes": sum(path.stat().st_size for path in files), "largest_bytes": max((path.stat().st_size for path in files), default=0)}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sessions", type=int, default=1000)
    parser.add_argument("--seed", type=int, default=570057)
    args = parser.parse_args()
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    manager = (ROOT / "scripts/telemetry/telemetry_manager.gd").read_text(encoding="utf-8")
    constants = (ROOT / "scripts/telemetry/telemetry_event_names.gd").read_text(encoding="utf-8")
    event_ids = list(schema["events"])
    constants_ids = re.findall(r'^const [A-Z_]+ := &"([a-z0-9_]+)"', constants, re.M)
    duplicate_ids = sorted({item for item in event_ids if event_ids.count(item) > 1})
    property_names = {key for contract in schema["events"].values() for key in contract["properties"]}
    events, counts = simulate(schema, args.sessions, args.seed)
    validation_errors = Counter(error for item in events for error in validate_event(schema, item))
    invalid_envelopes = sum(item.get("schema_version") != 1 or not item.get("session_id") for item in events)
    pii_properties = sorted(property_names & FORBIDDEN_PROPERTIES)
    source = "\n".join(path.read_text(encoding="utf-8", errors="replace") for path in (ROOT / "scripts").rglob("*.gd"))
    network_hits = {api: source.count(api) for api in NETWORK_APIS if api in source}
    hooks = {
        "autoload": 'TelemetryManager="*res://scripts/telemetry/telemetry_manager.gd"' in (ROOT / "project.godot").read_text(encoding="utf-8"),
        "run_start": "TelemetryManager.track_run_started" in (ROOT / "scripts/core/run_manager.gd").read_text(encoding="utf-8"),
        "run_finish": "TelemetryManager.track_run_finished" in (ROOT / "scripts/ui/run_result.gd").read_text(encoding="utf-8"),
        "run_abandon": "TelemetryManager.track_run_abandoned" in (ROOT / "scripts/core/run_manager.gd").read_text(encoding="utf-8"),
        "combat": all(value in (ROOT / "scripts/combat/combat.gd").read_text(encoding="utf-8") for value in ("track_combat_started", "track_combat_finished", "track_boss_started", "track_boss_finished", "track_boss_phase")),
        "pause_flush": "TelemetryManager.flush()" in (ROOT / "scripts/core/game.gd").read_text(encoding="utf-8"),
        "milestone": "track_milestone_completed" in (ROOT / "scripts/save/save_manager.gd").read_text(encoding="utf-8"),
    }
    rotation = rotation_simulation(events)
    report = {
        "schema_version": schema.get("schema_version"), "event_count": len(event_ids), "event_ids": event_ids,
        "duplicate_ids": duplicate_ids, "constants_match_schema": set(constants_ids) == set(event_ids),
        "property_count": len(property_names), "pii_property_violations": pii_properties,
        "network_api_hits": network_hits, "runtime_hooks": hooks,
        "limits": {"string": MAX_STRING, "array": MAX_ARRAY, "file_bytes": MAX_FILE, "total_bytes": MAX_TOTAL, "files": MAX_FILES},
        "simulation": {"sessions": args.sessions, "events": len(events), "average_events_per_session": round(len(events) / args.sessions, 3), "abandoned_runs": counts["abandoned"], "schema_errors": dict(validation_errors), "invalid_envelopes": invalid_envelopes},
        "rotation": rotation, "real_user_data_touched": False,
        "no_process": "func _process(" not in manager and "func _physics_process(" not in manager,
        "no_threads": "Thread.new" not in manager,
        "storage_separate_from_profile": "profile.json" not in manager,
        "production_default_false": all(value in manager for value in ('PRODUCTION_ENVIRONMENT := "production"', 'DEVELOPMENT_ENVIRONMENT := "development"', 'OS.has_feature("editor")', "LOCAL_DEVELOPMENT_TELEMETRY_ENABLED := true")) and "DEFAULT_ANALYTICS_ENABLED := false" in (ROOT / "scripts/settings/settings_manager.gd").read_text(encoding="utf-8"),
    }
    failures = []
    if report["schema_version"] != 1 or duplicate_ids or not report["constants_match_schema"]: failures.append("taxonomy")
    if pii_properties or validation_errors or invalid_envelopes: failures.append("validation_or_privacy")
    if network_hits or not all(hooks.values()): failures.append("network_or_hooks")
    if rotation["files"] > MAX_FILES or rotation["total_bytes"] > MAX_TOTAL or rotation["largest_bytes"] > MAX_FILE: failures.append("rotation")
    if not report["no_process"] or not report["no_threads"] or not report["storage_separate_from_profile"]: failures.append("architecture")
    report["failures"] = failures
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
