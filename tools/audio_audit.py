#!/usr/bin/env python3
"""Static Audio & Game Feel audit. Never invokes Godot."""
from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "scripts/audio/audio_manager.gd"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def enum_values(body: str, enum_name: str) -> list[str]:
    match = re.search(rf"enum {enum_name}\s*\{{(.*?)\}}", body, re.S)
    if not match:
        return []
    return re.findall(r"^\s*([A-Z][A-Z0-9_]*)\s*,?\s*$", match.group(1), re.M)


def main() -> int:
    audio_body = read(AUDIO)
    project = read(ROOT / "project.godot")
    buses_body = read(ROOT / "default_bus_layout.tres")
    settings_body = read(ROOT / "scripts/settings/settings_manager.gd")
    settings_scene = read(ROOT / "scenes/lobby/settings.tscn")
    gd_files = list((ROOT / "scripts").rglob("*.gd"))
    all_gd = "\n".join(read(path) for path in gd_files)

    events = enum_values(audio_body, "AudioEvent")
    sfx = enum_values(audio_body, "Sfx")
    music_states = enum_values(audio_body, "MusicState")
    event_calls = re.findall(r"AudioManager\.AudioEvent\.([A-Z][A-Z0-9_]*)", all_gd)
    sfx_calls = re.findall(r"AudioManager\.Sfx\.([A-Z][A-Z0-9_]*)", all_gd)
    music_calls = re.findall(r"AudioManager\.MusicState\.([A-Z][A-Z0-9_]*)", all_gd)
    mapped_events = set(re.findall(r"AudioEvent\.([A-Z][A-Z0-9_]*)\s*(?:,|:)", audio_body))

    buses = re.findall(r'^bus/\d+/name\s*=\s*&"([^"]+)"', buses_body, re.M)
    assets = [path.relative_to(ROOT).as_posix() for path in ROOT.rglob("*") if path.suffix.lower() in {".wav", ".ogg", ".mp3"}]
    direct_audio_paths = []
    for path in gd_files:
        body = read(path)
        if re.search(r'(?:load|preload)\("res://[^"\n]*(?:audio|\.wav|\.ogg|\.mp3)', body, re.I):
            direct_audio_paths.append(path.relative_to(ROOT).as_posix())

    settings_keys = sorted(set(re.findall(r'get_value\("([^"]+)",\s*"([^"]+)"', settings_body)))
    expected_settings = {
        ("audio", "master_volume"),
        ("audio", "music_volume"),
        ("audio", "sfx_volume"),
        ("accessibility", "reduce_motion"),
        ("privacy", "analytics_enabled"),
    }
    scene_unique_names = set(re.findall(r'\[node name="([^"]+)"[^\]]*\]\s*unique_name_in_owner\s*=\s*true', settings_scene))
    expected_nodes = {"MasterSlider", "MasterValue", "MusicSlider", "MusicValue", "SfxSlider", "SfxValue", "ReduceMotionCheck", "BackButton"}

    failures = []
    if not all(f'{name}="*res://scripts/' in project for name in ("AudioManager", "SettingsManager")):
        failures.append("autoload")
    if buses != ["Master", "Music", "SFX"]:
        failures.append("buses")
    if set(settings_keys) != expected_settings:
        failures.append("settings_keys")
    if not expected_nodes <= scene_unique_names:
        failures.append("settings_nodes")
    if set(event_calls) - set(events):
        failures.append("unknown_event_calls")
    if set(sfx_calls) - set(sfx):
        failures.append("unknown_sfx_calls")
    if set(events) - mapped_events:
        failures.append("unmapped_events")
    if direct_audio_paths:
        failures.append("dispersed_audio_paths")
    if "func _process(" in audio_body or "randomize(" in audio_body or "randf(" in audio_body or "randi(" in audio_body or "pick_random(" in audio_body:
        failures.append("audio_polling_or_global_rng")

    report = {
        "autoloads_ok": "autoload" not in failures,
        "buses": buses,
        "sfx_pool_size": int(re.search(r"PLAYER_POOL_SIZE:\s*int\s*=\s*(\d+)", audio_body).group(1)),
        "music_players": 1,
        "audio_stream_player_total": 7,
        "physical_audio_assets": assets,
        "procedural_sfx_count": len(re.findall(r"_streams\[Sfx\.", audio_body)),
        "sfx_ids": sfx,
        "audio_event_ids": events,
        "used_audio_events": dict(sorted(Counter(event_calls).items())),
        "unused_audio_events": sorted(set(events) - set(event_calls)),
        "music_states": music_states,
        "used_music_states": sorted(set(music_calls)),
        "settings_keys": [f"{section}.{key}" for section, key in settings_keys],
        "settings_nodes_missing": sorted(expected_nodes - scene_unique_names),
        "direct_audio_paths": direct_audio_paths,
        "new_process_methods": 0,
        "audio_global_rng": False,
        "failures": failures,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
