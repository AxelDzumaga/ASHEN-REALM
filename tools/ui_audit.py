"""Static UI audit for Godot text scenes. Never invokes Godot."""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENE_ROOT = ROOT / "scenes"
TARGETS = [(540, 960), (720, 1280), (800, 1200), (900, 1600), (720, 1440)]
BASE_VIEWPORT = (720.0, 1280.0)
INTERACTIVE_TYPES = {"Button", "CheckButton", "OptionButton", "HSlider", "VSlider"}
CONTAINER_TYPES = {
    "BoxContainer", "VBoxContainer", "HBoxContainer", "GridContainer",
    "MarginContainer", "PanelContainer", "ScrollContainer", "CenterContainer",
}


def parse_nodes(source: str) -> list[dict[str, object]]:
    nodes: list[dict[str, object]] = []
    current: dict[str, object] | None = None
    header = re.compile(r'^\[node name="([^"]+)" type="([^"]+)"(?: parent="([^"]+)")?.*\]$')
    for raw_line in source.splitlines():
        match = header.match(raw_line)
        if match:
            current = {"name": match.group(1), "type": match.group(2), "parent": match.group(3) or "", "props": {}}
            nodes.append(current)
            continue
        if current is None or " = " not in raw_line:
            continue
        key, value = raw_line.split(" = ", 1)
        current["props"][key] = value
    return nodes


def vector2(value: str) -> tuple[float, float] | None:
    match = re.fullmatch(r"Vector2\(([-\d.]+), ([-\d.]+)\)", value)
    return (float(match.group(1)), float(match.group(2))) if match else None


def virtual_viewport(width: int, height: int) -> tuple[float, float]:
    base_w, base_h = BASE_VIEWPORT
    target_aspect = width / height
    base_aspect = base_w / base_h
    if target_aspect > base_aspect:
        return (base_h * target_aspect, base_h)
    return (base_w, base_w / target_aspect)


def main() -> int:
    font_sizes: Counter[int] = Counter()
    tiny_fonts: list[dict[str, object]] = []
    touch_undersized: list[dict[str, object]] = []
    touch_without_explicit_size: list[dict[str, object]] = []
    nested_scrolls: list[dict[str, str]] = []
    clipped_controls: list[dict[str, str]] = []
    fixed_size_frames: list[dict[str, object]] = []
    counts: Counter[str] = Counter()
    scene_reports: dict[str, dict[str, int]] = {}

    for path in sorted(SCENE_ROOT.rglob("*.tscn")):
        relative = str(path.relative_to(ROOT)).replace("\\", "/")
        nodes = parse_nodes(path.read_text(encoding="utf-8"))
        by_path: dict[str, dict[str, object]] = {}
        scene_counts: Counter[str] = Counter()
        for node in nodes:
            parent = str(node["parent"])
            full_path = str(node["name"]) if parent in ("", ".") else f"{parent}/{node['name']}"
            by_path[full_path] = node
            props: dict[str, str] = node["props"]
            node_type = str(node["type"])
            counts["nodes"] += 1
            scene_counts[node_type] += 1

            raw_font = props.get("theme_override_font_sizes/font_size")
            if raw_font and raw_font.isdigit():
                size = int(raw_font)
                font_sizes[size] += 1
                if size < 12 and props.get("visible") != "false":
                    tiny_fonts.append({"scene": relative, "node": full_path, "size": size})

            if node_type in INTERACTIVE_TYPES and props.get("visible") != "false":
                counts["interactive"] += 1
                minimum = vector2(props.get("custom_minimum_size", ""))
                if minimum and minimum[1] > 0:
                    if minimum[1] < 48:
                        touch_undersized.append({"scene": relative, "node": full_path, "height": minimum[1]})
                else:
                    top = props.get("offset_top")
                    bottom = props.get("offset_bottom")
                    if top is not None and bottom is not None:
                        height = float(bottom) - float(top)
                        if 0 < height < 48:
                            touch_undersized.append({"scene": relative, "node": full_path, "height": height})
                    else:
                        parent_node = by_path.get(parent)
                        if parent_node is None or str(parent_node["type"]) not in CONTAINER_TYPES:
                            touch_without_explicit_size.append({"scene": relative, "node": full_path})

            if node_type == "ScrollContainer":
                counts["scrolls"] += 1
                if any(segment in parent.lower() for segment in ("scrollcontainer", "/scroll/", "scroll/")):
                    nested_scrolls.append({"scene": relative, "node": full_path})
            if props.get("clip_contents") == "true":
                clipped_controls.append({"scene": relative, "node": full_path})

            left = props.get("offset_left")
            right = props.get("offset_right")
            top = props.get("offset_top")
            bottom = props.get("offset_bottom")
            if all(value is not None for value in (left, right, top, bottom)):
                width = float(right) - float(left)
                height = float(bottom) - float(top)
                if width >= 500 and height >= 900:
                    fixed_size_frames.append({"scene": relative, "node": full_path, "size": [width, height]})

        scene_reports[relative] = {
            "nodes": len(nodes),
            "buttons": scene_counts["Button"] + scene_counts["CheckButton"],
            "scrolls": scene_counts["ScrollContainer"],
        }

    dynamic_font_pattern = re.compile(r'add_theme_font_size_override\("font_size",\s*(\d+)\)')
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        relative = str(path.relative_to(ROOT)).replace("\\", "/")
        for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = dynamic_font_pattern.search(line)
            if match and int(match.group(1)) < 12:
                tiny_fonts.append({"scene": relative, "node": f"line {line_number}", "size": int(match.group(1))})

    viewport_checks = [
        {"target": f"{w}x{h}", "virtual": [round(v, 1) for v in virtual_viewport(w, h)], "base_frame_fits": virtual_viewport(w, h)[0] >= 720 and virtual_viewport(w, h)[1] >= 1280}
        for w, h in TARGETS
    ]
    failures: list[str] = []
    if tiny_fonts:
        failures.append("visible fonts below 12 px")
    if touch_undersized:
        failures.append("explicit interactive targets below 48 px")
    if nested_scrolls:
        failures.append("nested ScrollContainers")
    if not all(item["base_frame_fits"] for item in viewport_checks):
        failures.append("720x1280 base frame does not fit a target aspect")

    report = {
        "scene_count": len(scene_reports),
        "node_count": counts["nodes"],
        "interactive_count": counts["interactive"],
        "scroll_count": counts["scrolls"],
        "font_distribution": dict(sorted(font_sizes.items())),
        "visible_fonts_below_12": tiny_fonts,
        "touch_targets_below_48": touch_undersized,
        "touch_targets_without_static_size": touch_without_explicit_size,
        "nested_scrolls": nested_scrolls,
        "clip_contents": clipped_controls,
        "fixed_large_frames": fixed_size_frames,
        "viewport_checks": viewport_checks,
        "scenes": scene_reports,
        "failures": failures,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
