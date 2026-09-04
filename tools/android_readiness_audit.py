#!/usr/bin/env python3
"""Auditoria estatica reproducible de preparacion Android. No ejecuta Godot."""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKIP_DIRS = {".godot", "build", "__pycache__"}
RUNTIME_TEXT = {".gd", ".tscn", ".tres", ".res", ".godot", ".cfg"}
SUSPICIOUS_SUFFIXES = {".exe", ".dll", ".bat", ".cmd", ".ps1", ".html", ".css", ".descarga"}
ABSOLUTE_PATTERN = re.compile(r"(?i)(?<!\w)(?:[A-Z]:[\\/]|Users[\\/]|Ashen Realm[\\/])")
RES_PATTERN = re.compile(r"res://[^\"'\s,)\]]+")


def files() -> list[Path]:
    return [p for p in ROOT.rglob("*") if p.is_file() and not any(part in SKIP_DIRS for part in p.relative_to(ROOT).parts)]


def source(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace")


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> int:
    all_files = files()
    exact_paths = {relative(p): p for p in all_files}
    folded: dict[str, list[str]] = defaultdict(list)
    for name in exact_paths:
        folded[name.casefold()].append(name)

    collisions = [names for names in folded.values() if len(names) > 1]
    missing_refs: list[dict[str, object]] = []
    optional_missing_refs: list[dict[str, object]] = []
    case_mismatches: list[dict[str, object]] = []
    absolute_runtime_paths: list[dict[str, object]] = []
    reference_count = 0
    runtime_sources = [p for p in all_files if p.suffix.lower() in RUNTIME_TEXT or p.name == "project.godot"]
    for path in runtime_sources:
        body = source(path)
        if path.parts[0] != "tools":
            for match in ABSOLUTE_PATTERN.finditer(body):
                absolute_runtime_paths.append({"file": relative(path), "line": body.count("\n", 0, match.start()) + 1})
        for match in RES_PATTERN.finditer(body):
            reference_count += 1
            ref = match.group(0).rstrip(";:")
            target = ref.removeprefix("res://")
            # Las herramientas headless escriben artefactos reproducibles bajo
            # build/. No son recursos runtime ni se exportan al APK.
            if relative(path).startswith("tools/") and target.startswith("build/"):
                continue
            if target in exact_paths:
                continue
            alternatives = folded.get(target.casefold(), [])
            item = {"file": relative(path), "line": body.count("\n", 0, match.start()) + 1, "ref": ref}
            if alternatives:
                item["actual"] = alternatives[0]
                case_mismatches.append(item)
            else:
                line_start = body.rfind("\n", 0, match.start()) + 1
                line_end = body.find("\n", match.end())
                line = body[line_start:line_end if line_end >= 0 else len(body)]
                required = path.suffix == ".gd" or path.name == "project.godot" or line.lstrip().startswith("[ext_resource")
                (missing_refs if required else optional_missing_refs).append(item)

    project = source(ROOT / "project.godot")
    export_path = ROOT / "export_presets.cfg"
    export_body = source(export_path) if export_path.exists() else ""
    gd_body = "\n".join(source(p) for p in all_files if p.suffix == ".gd" and "tools" not in p.parts)

    class_files: dict[str, list[str]] = defaultdict(list)
    for path in (p for p in all_files if p.suffix == ".gd"):
        match = re.search(r"^class_name\s+(\w+)", source(path), re.M)
        if match:
            class_files[match.group(1)].append(relative(path))
    duplicate_classes = {name: paths for name, paths in class_files.items() if len(paths) > 1}

    suspicious = []
    odd_names = []
    for path in all_files:
        rel = relative(path)
        if path.suffix.lower() in SUSPICIOUS_SUFFIXES:
            suspicious.append(rel)
        if any(ord(char) < 32 for char in path.name) or path.name != path.name.strip() or "  " in path.name:
            odd_names.append(rel)

    user_paths = sorted(set(re.findall(r"user://[^\"'\s]+", gd_body)))
    desktop_apis = []
    for pattern in (r"\bOS\.execute\s*\(", r"\bShell\b", r"\bSubprocess\b"):
        if re.search(pattern, gd_body):
            desktop_apis.append(pattern)

    input_report = {
        "screen_touch_handlers": len(re.findall(r"InputEventScreenTouch", gd_body)),
        "screen_drag_handlers": len(re.findall(r"InputEventScreenDrag", gd_body)),
        "mouse_handlers": len(re.findall(r"InputEventMouse", gd_body)),
        "ui_cancel_handlers": len(re.findall(r'ui_cancel', gd_body)),
        "emulate_mouse_from_touch": re.search(r"pointing/emulate_mouse_from_touch\s*=\s*(\w+)", project).group(1) if re.search(r"pointing/emulate_mouse_from_touch\s*=\s*(\w+)", project) else "default",
        "emulate_touch_from_mouse": re.search(r"pointing/emulate_touch_from_mouse\s*=\s*(\w+)", project).group(1) if re.search(r"pointing/emulate_touch_from_mouse\s*=\s*(\w+)", project) else "default",
    }
    performance = {
        "process_methods": len(re.findall(r"^func\s+_process\s*\(", gd_body, re.M)),
        "physics_process_methods": len(re.findall(r"^func\s+_physics_process\s*\(", gd_body, re.M)),
        "timers_created": len(re.findall(r"create_timer\s*\(", gd_body)),
        "tweens_created": len(re.findall(r"create_tween\s*\(", gd_body)),
        "queue_redraw_calls": len(re.findall(r"queue_redraw\s*\(", gd_body)),
        "draw_methods": len(re.findall(r"^func\s+_draw\s*\(", gd_body, re.M)),
        "audio_player_mentions": len(re.findall(r"AudioStreamPlayer", gd_body)),
        "shader_files": sum(1 for p in all_files if p.suffix.lower() in {".gdshader", ".shader"}),
        "particle_nodes": sum(len(re.findall(r'type="(?:GPU|CPU)Particles', source(p))) for p in all_files if p.suffix == ".tscn"),
    }
    scene_nodes = {}
    for path in (p for p in all_files if p.suffix == ".tscn"):
        scene_nodes[relative(path)] = len(re.findall(r"^\[node ", source(path), re.M))

    checks = {
        "app_name": 'config/name="Ashen Realm"' in project,
        "base_resolution_720x1280": "viewport_width=720" in project and "viewport_height=1280" in project,
        "portrait": "window/handheld/orientation=1" in project,
        "canvas_items_expand": 'window/stretch/mode="canvas_items"' in project and 'window/stretch/aspect="expand"' in project,
        "mobile_renderer": 'renderer/rendering_method="mobile"' in project,
        "safe_area_autoload": 'SafeAreaManager="*res://scripts/platform/safe_area_manager.gd"' in project,
        "lifecycle_pause_resume": "NOTIFICATION_APPLICATION_PAUSED" in gd_body and "NOTIFICATION_APPLICATION_RESUMED" in gd_body,
        "resume_input_guard": "ResumeInputGuard" in gd_body,
        "save_version_12": bool(re.search(r"SAVE_VERSION\s*:\s*int\s*=\s*12", gd_body)),
        "debug_tools_disabled": bool(re.search(r"DEBUG_TOOLS_ENABLED\s*:?[^=]*=\s*false", gd_body)),
        "user_storage_only": bool(user_paths) and not absolute_runtime_paths,
        "android_preset": bool(re.search(r'platform="Android"', export_body)),
    }
    critical = {
        "missing_refs": missing_refs,
        "case_mismatches": case_mismatches,
        "case_insensitive_collisions": collisions,
        "absolute_runtime_paths": absolute_runtime_paths,
        "duplicate_class_name": duplicate_classes,
        "required_checks_failed": [name for name, passed in checks.items() if not passed and name != "android_preset"],
    }
    report = {
        "status": "PASS" if not any(critical.values()) else "FAIL",
        "root": str(ROOT),
        "checks": checks,
        "critical": critical,
        "references_scanned": reference_count,
        "optional_missing_refs": optional_missing_refs,
        "input": input_report,
        "performance": performance,
        "scene_nodes": dict(sorted(scene_nodes.items(), key=lambda item: item[1], reverse=True)),
        "save_paths": user_paths,
        "desktop_only_apis": desktop_apis,
        "suspicious_files": suspicious,
        "suspicious_file_count": len(suspicious),
        "odd_filenames": odd_names,
        "export_preset_present": export_path.exists(),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
