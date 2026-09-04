#!/usr/bin/env python3
"""Static integrity and Stage 49 checks. Never invokes Godot."""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEXT_SUFFIXES = {".gd", ".tscn", ".tres"}
CANONICAL_TAGS = {
    "burn", "ember", "crit", "skill", "heal", "guard", "low_hp",
    "defense", "status", "companion", "attack", "energy",
}


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def string_name_array(body: str, field: str) -> list[str]:
    match = re.search(rf"^{re.escape(field)}\s*=\s*Array\[StringName\]\(\[(.*?)\]\)", body, re.M | re.S)
    return re.findall(r'&"([^"]+)"', match.group(1)) if match else []


def scalar(body: str, field: str, default: str = "") -> str:
    match = re.search(rf'^{re.escape(field)}\s*=\s*(?:&)?"([^"]*)"', body, re.M)
    return match.group(1) if match else default


def ints(body: str, field: str) -> list[int]:
    match = re.search(rf"^{re.escape(field)}\s*=\s*Array\[int\]\(\[(.*?)\]\)", body, re.M | re.S)
    return [int(value) for value in re.findall(r"-?\d+", match.group(1))] if match else []


def parse_synergies() -> list[dict]:
    result = []
    for path in sorted((ROOT / "data/synergies").glob("*.tres")):
        body = text(path)
        mode_match = re.search(r"^activation_mode\s*=\s*(\d+)", body, re.M)
        minimum_match = re.search(r"^minimum_distinct_sources\s*=\s*(\d+)", body, re.M)
        result.append({
            "id": scalar(body, "synergy_id"),
            "effect": scalar(body, "effect_id"),
            "required_tags": string_name_array(body, "required_tags"),
            "required_counts": ints(body, "required_counts"),
            "required_sources": string_name_array(body, "required_source_ids"),
            "minimum_sources": int(minimum_match.group(1)) if minimum_match else 1,
            "mode": int(mode_match.group(1)) if mode_match else 0,
            "file": str(path.relative_to(ROOT)),
        })
    return result


def matches(synergy: dict, sources: dict[str, set[str]]) -> bool:
    if synergy["id"] == "inferno_rhythm":
        exact_pair = {"boon:burning_strike", "boon:relentless_flame"}.issubset(sources)
        offensive_boons = sum(
            source.startswith("boon:") and bool(tags & {"attack", "burn", "ember"})
            for source, tags in sources.items()
        )
        return exact_pair or offensive_boons >= 3
    source_match = bool(synergy["required_sources"]) and all(key in sources for key in synergy["required_sources"])
    tag_sources = defaultdict(set)
    for source, tags in sources.items():
        for tag in tags:
            tag_sources[tag].add(source)
    tags = synergy["required_tags"]
    counts = synergy["required_counts"]
    tag_match = bool(tags) and len(tags) == len(counts)
    if tag_match:
        tag_match = all(len(tag_sources[tag]) >= count for tag, count in zip(tags, counts))
        contributors = set().union(*(tag_sources[tag] for tag in tags))
        tag_match = tag_match and len(contributors) >= synergy["minimum_sources"]
    return source_match or tag_match if synergy["mode"] == 1 else (source_match or not synergy["required_sources"]) and (tag_match or not tags)


def build_simulations(synergies: list[dict]) -> list[dict]:
    builds = {
        "A Burn/Ember": {
            "equipment:ember_fang": {"attack", "ember", "burn", "energy"},
            "companion:ember_hound": {"companion", "ember", "burn", "attack"},
            "skill:ember_slash": {"skill", "attack", "ember"},
            "boon:burning_strike": {"ember", "burn", "attack"},
            "boon:relentless_flame": {"ember", "attack"},
            "boon:pyre_heart": {"ember", "attack"},
        },
        "B Crit": {
            "equipment:cinder_knife": {"attack", "crit", "ember"},
            "skill:ember_slash": {"skill", "attack"},
        },
        "C Guard/Defense": {
            "equipment:warden_plate": {"defense", "guard"},
            "skill:ashen_guard": {"skill", "guard", "defense"},
            "augment:reinforced_ash": {"skill", "guard", "defense"},
        },
        "D Sustain": {
            "equipment:mire_vest": {"heal", "status"},
            "skill:second_wind": {"skill", "heal"},
        },
        "E Skill": {
            "equipment:runic_edge": {"attack", "skill"},
            "skill:ember_slash": {"skill", "attack"},
            "skill:ashen_guard": {"skill", "guard"},
            "skill:second_wind": {"skill", "heal"},
        },
        "F Historical Ashen": {
            "boon:ashen_bulwark": {"defense", "guard"},
            "boon:ashen_reprisal": {"defense", "attack"},
        },
        "G Historical Last": {
            "boon:last_ember": {"low_hp", "attack", "ember"},
            "boon:cinder_skin": {"low_hp", "defense"},
        },
        "H Historical Phoenix": {
            "boon:ember_blood": {"heal", "ember"},
            "boon:pyre_heart": {"ember", "attack"},
        },
    }
    result = []
    for name, sources in builds.items():
        active = [item["id"] for item in synergies if matches(item, sources)]
        result.append({
            "build": name,
            "tags": dict(sorted(Counter(tag for tags in sources.values() for tag in tags).items())),
            "active": active,
        })
    return result


def main() -> int:
    all_files = [path for path in ROOT.rglob("*") if path.is_file() and ".godot" not in path.parts]
    source_files = [path for path in all_files if path.suffix in TEXT_SUFFIXES or path.name == "project.godot"]
    missing_refs = []
    optional_missing_refs = []
    ref_count = 0
    for path in source_files:
        body = text(path)
        for ref_match in re.finditer(r"res://[^\"'\s)\]]+", body):
            ref = ref_match.group(0)
            ref_count += 1
            clean = ref.rstrip(",;:")
            if not (ROOT / clean.removeprefix("res://")).exists():
                line_start = body.rfind("\n", 0, ref_match.start()) + 1
                line_end = body.find("\n", ref_match.end())
                line = body[line_start:line_end if line_end >= 0 else len(body)]
                entry = {"file": str(path.relative_to(ROOT)), "ref": clean}
                is_required = path.suffix == ".gd" or path.name == "project.godot" or line.lstrip().startswith("[ext_resource")
                (missing_refs if is_required else optional_missing_refs).append(entry)

    classes = defaultdict(list)
    for path in ROOT.rglob("*.gd"):
        if ".godot" in path.parts:
            continue
        match = re.search(r"^class_name\s+(\w+)", text(path), re.M)
        if match:
            classes[match.group(1)].append(str(path.relative_to(ROOT)))

    synergies = parse_synergies()
    ids = [item["id"] for item in synergies]
    effect_body = text(ROOT / "scripts/synergies/synergy_effect_resolver.gd")
    effect_match = re.search(r"SUPPORTED_EFFECT_IDS[^=]*=\s*\[(.*?)\]", effect_body, re.S)
    effects = set(re.findall(r'&"([a-z0-9_]+)"', effect_match.group(1))) if effect_match else set()
    synergy_errors = []
    for item in synergies:
        if not item["id"] or item["id"] != item["effect"]:
            synergy_errors.append(f"ID/effect inválido: {item['file']}")
        if len(item["required_tags"]) != len(item["required_counts"]):
            synergy_errors.append(f"tags/counts incompatibles: {item['id']}")
        unknown = set(item["required_tags"]) - CANONICAL_TAGS
        if unknown:
            synergy_errors.append(f"tags desconocidos en {item['id']}: {sorted(unknown)}")
        if item["effect"] not in effects:
            synergy_errors.append(f"effect sin resolver: {item['effect']}")

    scenes = list(ROOT.rglob("*.tscn"))
    suspicious_unique = []
    suspicious_callbacks = []
    suspicious_nodepaths = []
    for scene in scenes:
        body = text(scene)
        unique_names = []
        node_matches = list(re.finditer(r'^\[node name="([^"]+)"[^\]]*\]$', body, re.M))
        for index, node_match in enumerate(node_matches):
            block_end = node_matches[index + 1].start() if index + 1 < len(node_matches) else len(body)
            if re.search(r"^unique_name_in_owner\s*=\s*true$", body[node_match.end():block_end], re.M):
                unique_names.append(node_match.group(1))
        for name, count in Counter(unique_names).items():
            if count > 1:
                suspicious_unique.append(f"{scene.relative_to(ROOT)}:%{name}")
        script_paths = re.findall(r'\[ext_resource type="Script" path="res://([^"]+)"', body)
        if script_paths:
            script_body = text(ROOT / script_paths[0])
            for required_name in sorted(set(re.findall(r"^@onready[^\n]*%([A-Za-z0-9_]+)", script_body, re.M))):
                if required_name not in unique_names:
                    suspicious_nodepaths.append(f"{scene.relative_to(ROOT)}:%{required_name}")
        for method in re.findall(r'method="([^"]+)"', body):
            if not any(re.search(rf"^func\s+{re.escape(method)}\b", text(path), re.M) for path in ROOT.rglob("*.gd")):
                suspicious_callbacks.append(f"{scene.relative_to(ROOT)}:{method}")

    resource_ids = defaultdict(list)
    id_fields = ("synergy_id", "action_id", "template_id", "boss_id", "phase_id", "companion_id", "modifier_id", "status_id", "visual_id", "id")
    for path in ROOT.rglob("*.tres"):
        body = text(path)
        class_match = re.search(r'script_class="([^"]+)"', body)
        resource_class = class_match.group(1) if class_match else str(path.parent.relative_to(ROOT))
        for field in id_fields:
            value = scalar(body, field)
            if value:
                resource_ids[(resource_class, field, value)].append(str(path.relative_to(ROOT)))
                break
    resource_duplicates = {
        f"{resource_class}.{field}:{value}": paths
        for (resource_class, field, value), paths in resource_ids.items() if len(paths) > 1
    }

    simulations = build_simulations(synergies)
    reached_synergies = {synergy_id for simulation in simulations for synergy_id in simulation["active"]}
    report = {
        "files": len(all_files),
        "gd": len(list(ROOT.rglob("*.gd"))),
        "tscn": len(scenes),
        "tres": len(list(ROOT.rglob("*.tres"))),
        "res_references": ref_count,
        "missing_references": missing_refs,
        "optional_missing_references": optional_missing_refs,
        "class_name_duplicates": {key: value for key, value in classes.items() if len(value) > 1},
        "synergy_count": len(synergies),
        "synergy_duplicate_ids": [key for key, count in Counter(ids).items() if count > 1],
        "synergy_errors": synergy_errors,
        "resource_id_records": len(resource_ids),
        "resource_id_duplicates": resource_duplicates,
        "suspicious_unique_names": suspicious_unique,
        "suspicious_nodepaths": suspicious_nodepaths,
        "suspicious_scene_callbacks": suspicious_callbacks,
        "unreachable_synergies": sorted(set(ids) - reached_synergies),
        "build_simulations": simulations,
    }
    if "--summary" in sys.argv:
        report = {
            "files": report["files"], "gd": report["gd"], "tscn": report["tscn"], "tres": report["tres"],
            "res_references": report["res_references"],
            "missing_references": len(report["missing_references"]),
            "optional_missing_references": len(report["optional_missing_references"]),
            "class_name_duplicates": report["class_name_duplicates"],
            "synergy_count": report["synergy_count"],
            "synergy_duplicate_ids": report["synergy_duplicate_ids"],
            "synergy_errors": report["synergy_errors"],
            "resource_id_records": report["resource_id_records"],
            "resource_id_duplicates": report["resource_id_duplicates"],
            "suspicious_unique_names": report["suspicious_unique_names"],
            "suspicious_nodepaths": report["suspicious_nodepaths"],
            "suspicious_scene_callbacks": report["suspicious_scene_callbacks"],
            "unreachable_synergies": report["unreachable_synergies"],
            "build_simulations": report["build_simulations"],
        }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if missing_refs or report["class_name_duplicates"] or synergy_errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
