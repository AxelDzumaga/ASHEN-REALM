"""Auditoría técnica de los SpriteFrames piloto de la Etapa 60B.

No intenta juzgar calidad artística: solo verifica recursos, nombres, dimensiones
de textura, cantidad de frames y alfa en las esquinas del canvas.
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PILOTS = {
    "ashen_wanderer": (ROOT / "data/visuals/player/ashen_wanderer_59b_spriteframes.tres", (512, 512)),
    "ash_crawler": (ROOT / "data/visuals/enemies/ash_crawler_59b_spriteframes.tres", (512, 512)),
    "ashen_warden": (ROOT / "data/visuals/bosses/ashen_warden_59b_spriteframes.tres", (768, 768)),
}


def main() -> int:
    report = {"status": "PASS", "pilots": {}, "failures": []}
    for name, (resource, expected) in PILOTS.items():
        text = resource.read_text(encoding="utf-8") if resource.exists() else ""
        texture_path = next((line.split('path="', 1)[1].split('"', 1)[0] for line in text.splitlines() if 'type="Texture2D"' in line), "")
        texture_file = ROOT / texture_path.removeprefix("res://")
        frame_count = text.count('"texture": SubResource')
        try:
            image = Image.open(texture_file).convert("RGBA")
            corners = [image.getpixel(point)[3] for point in ((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1))]
            has_alpha = min(corners) == 0
            dimensions = [image.width, image.height]
        except Exception as exc:  # pragma: no cover - diagnostic tool
            dimensions, corners, has_alpha = [], [], False
            report["failures"].append(f"{name}: {exc}")
        report["pilots"][name] = {
            "resource": resource.as_posix(),
            "texture": texture_path,
            "frame_count_declared": frame_count,
            "texture_dimensions": dimensions,
            "expected_frame_canvas": list(expected),
            "corner_alpha": corners,
            "transparent_corners": has_alpha,
            "classification": "PROVISIONAL",
        }
        if not resource.exists() or frame_count <= 0:
            report["failures"].append(f"{name}: SpriteFrames ausente o sin frames")
    if report["failures"]:
        report["status"] = "WARN"
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
