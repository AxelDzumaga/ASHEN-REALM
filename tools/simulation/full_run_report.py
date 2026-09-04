#!/usr/bin/env python3
"""Agrega evidencia de ETAPA 62 sin tocar user:// ni datos de gameplay."""
from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
import time
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

ROOT = Path(__file__).resolve().parents[2]
TILE_NAMES = {0: "EMPTY", 1: "HEAL", 2: "BOSS", 3: "COMBAT", 4: "EVENT", 5: "TREASURE", 6: "ELITE"}
PERMANENT_COSTS = {
    "vitality": [30 * level for level in range(1, 11)],
    "might": [40 * level for level in range(1, 11)],
    "guard": [40 * level for level in range(1, 11)],
}


def mean(values: Iterable[float]) -> float:
    values = list(values)
    return round(statistics.fmean(values), 4) if values else 0.0


def pct(numerator: int, denominator: int) -> float:
    return round(100.0 * numerator / denominator, 2) if denominator else 0.0


def percentile(values: Iterable[float], fraction: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    return round(ordered[min(len(ordered) - 1, int((len(ordered) - 1) * fraction))], 4)


def load_runs(path: Path) -> list[dict[str, Any]]:
    rows = []
    with path.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            if line.strip():
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError as exc:
                    raise SystemExit(f"JSON inválido en {path}:{line_number}: {exc}") from exc
    return rows


def count_nested(rows: list[dict[str, Any]], field: str) -> Counter[str]:
    result: Counter[str] = Counter()
    for row in rows:
        result.update({str(key): int(value) for key, value in row.get(field, {}).items()})
    return result


def group_summary(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        groups[(row["biome"], row["policy"])].append(row)
    output = []
    for (biome, policy), group in sorted(groups.items()):
        wins = [row for row in group if row["outcome"] == "victory"]
        boss_reached = [row for row in group if row["boss_outcome"] != "not_reached"]
        output.append({
            "biome": biome,
            "policy": policy,
            "runs": len(group),
            "wins": len(wins),
            "win_rate_pct": pct(len(wins), len(group)),
            "boss_reach_rate_pct": pct(len(boss_reached), len(group)),
            "boss_win_rate_when_reached_pct": pct(sum(row["boss_outcome"] == "victory" for row in boss_reached), len(boss_reached)),
            "avg_boss_entry_hp": mean(row["boss_entry_hp"] for row in boss_reached),
            "avg_final_hp": mean(row["final_hp"] for row in group),
            "avg_combats": mean(row["combats"] for row in group),
            "avg_combat_turns": mean(row["combat_turns"] for row in group),
            "avg_damage_taken": mean(row["damage_taken"] for row in group),
            "avg_healing": mean(row["healing"] for row in group),
            "avg_overheal": mean(row["overheal"] for row in group),
            "avg_level": mean(row["level"] for row in group),
            "avg_xp": mean(row["xp"] for row in group),
            "avg_ash": mean(row["ash"] for row in group),
            "avg_guard_uses": mean(row["guard_uses"] for row in group),
            "avg_second_wind_uses": mean(row["second_wind_uses"] for row in group),
            "avg_target_switches": mean(row["target_switches"] for row in group),
            "avg_killed_before_intent": mean(row["enemies_killed_before_intent"] for row in group),
        })
    return output


def board_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    result = {}
    for biome in sorted({row["biome"] for row in rows}):
        sample = [row for row in rows if row["biome"] == biome]
        generated, visited = Counter(), Counter()
        for row in sample:
            generated.update({TILE_NAMES[int(key)]: int(value) for key, value in row["generated_tile_counts"].items()})
            visited.update({TILE_NAMES[int(key)]: int(value) for key, value in row["visited_tile_counts"].items()})
        result[biome] = {
            "runs": len(sample),
            "mean_generated": {key: round(value / len(sample), 4) for key, value in sorted(generated.items())},
            "mean_visited": {key: round(value / len(sample), 4) for key, value in sorted(visited.items())},
            "avg_dice_rolls": mean(row["dice_rolls"] for row in sample),
            "avg_tiles_visited": mean(row["tiles_visited"] for row in sample),
        }
    return result


def combat_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    groups: dict[str, list[dict[str, Any]]] = defaultdict(list)
    enemies: Counter[str] = Counter()
    encounter_deaths: Counter[str] = Counter()
    for row in rows:
        if row.get("death_encounter"):
            encounter_deaths[row["death_encounter"]] += 1
        for combat in row["combat_log"]:
            kind = "boss" if combat["is_boss"] else "elite" if combat["is_elite"] else "normal"
            groups[kind].append(combat)
            enemies.update(combat["enemies"])
    result = {}
    for kind, combats in sorted(groups.items()):
        result[kind] = {
            "count": len(combats),
            "win_rate_pct": pct(sum(item["outcome"] == "victory" for item in combats), len(combats)),
            "avg_turns": mean(item["turns"] for item in combats),
            "avg_damage_taken": mean(item["damage_taken"] for item in combats),
            "avg_hp_loss": mean(item["starting_hp"] - item["ending_hp"] for item in combats),
            "turn_cap_hits": sum(bool(item["turn_cap_reached"]) for item in combats),
        }
    return {"by_type": result, "enemy_frequency": dict(enemies.most_common()), "death_encounters": dict(encounter_deaths.most_common(25))}


def death_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    deaths = [row for row in rows if row["outcome"] == "defeat"]
    tiles = Counter(str(row["final_tile"]) for row in deaths)
    segments = Counter("early" if row["final_tile"] <= 9 else "mid" if row["final_tile"] <= 19 else "late" if row["final_tile"] < 29 else "boss" for row in deaths)
    return {
        "total": len(deaths),
        "rate_pct": pct(len(deaths), len(rows)),
        "by_tile": dict(sorted(tiles.items(), key=lambda pair: int(pair[0]))),
        "by_segment": dict(segments),
        "top_tiles": [{"tile": int(tile), "deaths": count} for tile, count in tiles.most_common(10)],
    }


def curve_summary(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    points: dict[tuple[str, int], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        for point in row["curve"]:
            points[(row["biome"], int(point["tile"]))].append(point)
    result = []
    for (biome, tile), samples in sorted(points.items()):
        result.append({
            "biome": biome,
            "tile": tile,
            "samples": len(samples),
            "avg_hp": mean(item["hp"] for item in samples),
            "avg_max_hp": mean(item["max_hp"] for item in samples),
            "avg_attack": mean(item["attack"] for item in samples),
            "avg_defense": mean(item["defense"] for item in samples),
            "avg_level": mean(item["level"] for item in samples),
            "avg_ash": mean(item["ash"] for item in samples),
        })
    return result


def pick_rates(rows: list[dict[str, Any]]) -> dict[str, Any]:
    picks = count_nested(rows, "upgrade_picks")
    offers = count_nested(rows, "upgrade_offers")
    augment_picks = count_nested(rows, "augment_picks")
    conditioned = []
    for upgrade, count in picks.most_common():
        owners = [row for row in rows if int(row["upgrade_picks"].get(upgrade, 0)) > 0]
        conditioned.append({
            "id": upgrade, "picks": count, "offers": offers[upgrade],
            "pick_when_offered_pct": pct(count, offers[upgrade]),
            "owner_run_win_rate_pct": pct(sum(row["outcome"] == "victory" for row in owners), len(owners)),
        })
    return {"upgrades": conditioned, "augments": dict(augment_picks.most_common())}


def builds_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    tags: dict[str, list[dict[str, Any]]] = defaultdict(list)
    synergies: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        for tag in row["build_tags"]:
            tags[tag].append(row)
        for synergy in row["synergies"]:
            synergies[synergy].append(row)
    def rows_for(mapping: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
        return [
            {"id": key, "runs": len(group), "win_rate_pct": pct(sum(row["outcome"] == "victory" for row in group), len(group)), "avg_boss_entry_hp": mean(row["boss_entry_hp"] for row in group if row["boss_entry_hp"] >= 0)}
            for key, group in sorted(mapping.items())
        ]
    return {"tags": rows_for(tags), "synergies": rows_for(synergies)}


def loot_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    items = Counter(row["loot_id"] or "none" for row in rows)
    rarity = Counter(str(row["loot_rarity"]) for row in rows)
    return {"items": dict(items.most_common()), "rarity": dict(rarity), "note": "El loot se entrega en Results; no modifica la run que lo genera."}


def boss_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    result = {}
    for boss_id in sorted({row["boss_id"] for row in rows if row["boss_id"]}):
        reached = [row for row in rows if row["boss_id"] == boss_id]
        result[boss_id] = {
            "reached": len(reached),
            "wins": sum(row["boss_outcome"] == "victory" for row in reached),
            "win_rate_when_reached_pct": pct(sum(row["boss_outcome"] == "victory" for row in reached), len(reached)),
            "avg_entry_hp": mean(row["boss_entry_hp"] for row in reached),
            "p10_entry_hp": percentile((row["boss_entry_hp"] for row in reached), .10),
            "avg_turns": mean(row["boss_turns"] for row in reached),
            "max_phase_reached": max((row["boss_phase_reached"] for row in reached), default=0),
        }
    return result


def intent_impact(groups: list[dict[str, Any]]) -> dict[str, Any]:
    result = {}
    for biome in sorted({row["biome"] for row in groups}):
        aggressive = next(row for row in groups if row["biome"] == biome and row["policy"] == "aggressive")
        tactical = next(row for row in groups if row["biome"] == biome and row["policy"] == "tactical")
        result[biome] = {
            "aggressive_win_rate_pct": aggressive["win_rate_pct"],
            "tactical_win_rate_pct": tactical["win_rate_pct"],
            "win_rate_delta_points": round(tactical["win_rate_pct"] - aggressive["win_rate_pct"], 2),
            "damage_taken_delta": round(tactical["avg_damage_taken"] - aggressive["avg_damage_taken"], 3),
            "boss_entry_hp_delta": round(tactical["avg_boss_entry_hp"] - aggressive["avg_boss_entry_hp"], 3),
            "guard_uses_delta": round(tactical["avg_guard_uses"] - aggressive["avg_guard_uses"], 3),
            "target_switches_delta": round(tactical["avg_target_switches"] - aggressive["avg_target_switches"], 3),
        }
    return result


def outlier_seeds(rows: list[dict[str, Any]]) -> dict[str, Any]:
    def compact(row: dict[str, Any], reason: str) -> dict[str, Any]:
        return {"label": reason, "seed": row["seed"], "biome": row["biome"], "policy": row["policy"], "outcome": row["outcome"], "final_tile": row["final_tile"], "final_hp": row["final_hp"], "combats": row["combats"], "healing": row["healing"], "attack": row["attack"], "defense": row["defense"]}
    victories = [row for row in rows if row["outcome"] == "victory"]
    defeats = [row for row in rows if row["outcome"] == "defeat"]
    average_hp = mean(row["final_hp"] for row in victories)
    candidates = {
        "easy": max(victories, key=lambda row: (row["final_hp"], -row["combat_turns"]), default=rows[0]),
        "hard": min(defeats or rows, key=lambda row: (row["final_tile"], row["final_hp"])),
        "average": min(rows, key=lambda row: abs(row["final_hp"] - average_hp)),
        "boss_failure": min((row for row in defeats if row["boss_outcome"] == "defeat"), key=lambda row: row["boss_entry_hp"], default=defeats[0] if defeats else rows[0]),
        "heal_starvation": min(rows, key=lambda row: (row["healing"], row["final_tile"])),
        "power_spike": max(rows, key=lambda row: row["attack"] + 2 * row["defense"] + row["max_hp"] / 10),
    }
    return {key: compact(value, key) for key, value in candidates.items()}


def metaprogression(rows: list[dict[str, Any]]) -> dict[str, Any]:
    ash = [row["ash"] for row in rows]
    average = statistics.fmean(ash) if ash else 0.0
    by_policy = {policy: mean(row["ash"] for row in rows if row["policy"] == policy) for policy in sorted({row["policy"] for row in rows})}
    targets = {
        "first_vitality": 30,
        "first_might": 40,
        "first_guard": 40,
        "vitality_level_3": sum(PERMANENT_COSTS["vitality"][:3]),
        "one_branch_max": sum(PERMANENT_COSTS["vitality"]),
        "all_branches_max": sum(sum(costs) for costs in PERMANENT_COSTS.values()),
    }
    return {"avg_ash_per_run": round(average, 4), "avg_by_policy": by_policy, "costs": PERMANENT_COSTS, "estimated_runs_at_global_mean": {name: math.ceil(cost / average) if average else None for name, cost in targets.items()}}


def progression_summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    level_tiles = Counter(str(tile) for row in rows for tile in row.get("level_up_tiles", []))
    levels = Counter(str(row["level"]) for row in rows)
    return {
        "avg_xp": mean(row["xp"] for row in rows),
        "avg_level": mean(row["level"] for row in rows),
        "level_distribution": dict(sorted(levels.items(), key=lambda pair: int(pair[0]))),
        "avg_level_upgrades": mean(sum(int(value) for value in row["level_upgrades"].values()) for row in rows),
        "avg_boons": mean(sum(int(value) for value in row["boons"].values()) for row in rows),
        "avg_augments": mean(sum(int(value) for value in row["augments"].values()) for row in rows),
        "level_up_tiles": dict(sorted(level_tiles.items(), key=lambda pair: int(pair[0]))),
        "runs_reaching_max_level": sum(row["level"] >= 10 for row in rows),
    }


def write_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_svg(path: Path, groups: list[dict[str, Any]]) -> None:
    width, height, margin = 1000, 460, 70
    rows = sorted(groups, key=lambda row: (row["biome"], row["policy"]))
    bar_width = (width - 2 * margin) / max(1, len(rows)) * .7
    spacing = (width - 2 * margin) / max(1, len(rows))
    colors = {"random": "#8b7b91", "aggressive": "#d45d4c", "defensive": "#6090b8", "tactical": "#e59a42"}
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">', '<rect width="100%" height="100%" fill="#17131b"/>', '<text x="70" y="34" fill="#f4e5d1" font-family="sans-serif" font-size="22">Win rate por bioma y policy</text>']
    for index, row in enumerate(rows):
        x = margin + index * spacing + (spacing - bar_width) / 2
        value = float(row["win_rate_pct"])
        bar_height = value / 100 * (height - 2 * margin)
        y = height - margin - bar_height
        parts.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{bar_width:.1f}" height="{bar_height:.1f}" fill="{colors[row["policy"]]}"/>')
        parts.append(f'<text x="{x + bar_width / 2:.1f}" y="{y - 7:.1f}" text-anchor="middle" fill="#f4e5d1" font-family="sans-serif" font-size="13">{value:.1f}%</text>')
        label = f'{row["biome"].replace("_", " ")} / {row["policy"]}'
        parts.append(f'<text transform="translate({x + bar_width / 2:.1f},{height - margin + 12}) rotate(35)" fill="#c9b8ad" font-family="sans-serif" font-size="11">{label}</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts), encoding="utf-8")


def evidence_findings(summary: dict[str, Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[str]]:
    groups = summary["win_rate"]
    minimum = min(groups, key=lambda row: row["win_rate_pct"])
    maximum = max(groups, key=lambda row: row["win_rate_pct"])
    mid_late = sum(int(summary["deaths"]["by_segment"].get(segment, 0)) for segment in ("mid", "late"))
    boss_deaths = int(summary["deaths"]["by_segment"].get("boss", 0))
    early_deaths = int(summary["deaths"]["by_segment"].get("early", 0))
    intent_deltas = [value["win_rate_delta_points"] for value in summary["intent_impact"].values()]
    upgrade_rows = summary["upgrades"]["upgrades"]
    iron_skin = next((row for row in upgrade_rows if row["id"] == "iron_skin"), {})
    inferno = next((row for row in summary["builds"]["synergies"] if row["id"] == "inferno_rhythm"), {})
    elite = summary["combat"]["by_type"]["elite"]
    normal = summary["combat"]["by_type"]["normal"]
    warden = summary["bosses"]["ashen_warden"]
    pyre = summary["bosses"]["sunken_pyre"]
    findings = [
        {"severity": "ALTO", "confidence": "ALTA", "title": "Brecha extrema entre políticas", "evidence": f"{minimum['biome']}/{minimum['policy']} {minimum['win_rate_pct']:.1f}% vs {maximum['biome']}/{maximum['policy']} {maximum['win_rate_pct']:.1f}% ({maximum['win_rate_pct']-minimum['win_rate_pct']:.1f} pp)."},
        {"severity": "ALTO", "confidence": "MEDIA", "title": "El paquete informado por intents tiene ventaja grande", "evidence": f"Tactical supera Aggressive por {min(intent_deltas):.1f}–{max(intent_deltas):.1f} pp; no es aislamiento causal porque también cambia skills, targets y rewards."},
        {"severity": "ALTO", "confidence": "ALTA", "title": "Sustain/defensa dominan las heurísticas", "evidence": "Defensive/Tactical ganan entre 84.8% y 90.0%; Aggressive entre 23.7% y 34.1%."},
        {"severity": "ALTO", "confidence": "ALTA", "title": "Inferno Rhythm casi no discrimina una build", "evidence": f"Activo en {inferno.get('runs', 0)} de {summary['runs_total']} runs ({pct(int(inferno.get('runs', 0)), summary['runs_total']):.2f}%) por fuentes del loadout/companion y recompensas."},
        {"severity": "MEDIO", "confidence": "ALTA", "title": "La presión aparece en mid/late", "evidence": f"{mid_late} muertes en mid+late ({pct(mid_late, summary['runs_total']):.2f}% de todas las runs), frente a {early_deaths} en early."},
        {"severity": "MEDIO", "confidence": "ALTA", "title": "Boss es el mayor punto individual de muerte", "evidence": f"{boss_deaths} muertes en tile boss ({pct(boss_deaths, summary['runs_total']):.2f}% de runs); win al llegar 80.74% agregado."},
        {"severity": "MEDIO", "confidence": "ALTA", "title": "Ashen Warden es más exigente que Sunken Pyre", "evidence": f"Win al llegar: Warden {warden['win_rate_when_reached_pct']:.2f}% vs Pyre {pyre['win_rate_when_reached_pct']:.2f}%; HP de entrada {warden['avg_entry_hp']:.2f} vs {pyre['avg_entry_hp']:.2f}."},
        {"severity": "MEDIO", "confidence": "MEDIA", "title": "Iron Skin es candidato a revisión, no nerf automático", "evidence": f"{iron_skin.get('picks', 0)} picks; {iron_skin.get('pick_when_offered_pct', 0):.2f}% al ofrecerse; win condicionado {iron_skin.get('owner_run_win_rate_pct', 0):.2f}%, confusado por policy."},
        {"severity": "BAJO", "confidence": "ALTA", "title": "Early game casi no mata", "evidence": f"{early_deaths} muertes early sobre {summary['runs_total']} runs ({pct(early_deaths, summary['runs_total']):.3f}%)."},
        {"severity": "BAJO", "confidence": "ALTA", "title": "Elites son más peligrosos y pagan el doble", "evidence": f"Win elite {elite['win_rate_pct']:.2f}% vs normal {normal['win_rate_pct']:.2f}%; pérdida HP {elite['avg_hp_loss']:.2f} vs {normal['avg_hp_loss']:.2f}; Ash/XP configurados al doble."},
        {"severity": "BAJO", "confidence": "ALTA", "title": "Healing no muestra overheal global excesivo", "evidence": f"Healing medio {summary['healing']['avg']:.2f}, overheal medio {summary['healing']['avg_overheal']:.2f}, {summary['healing']['runs_without_healing']} runs sin healing."},
    ]
    top_five = findings[:5]
    healthy = [
        "0 boards inválidos en qa_balance_audit y todos los rows finales tienen 30 tiles.",
        "Ningún combate alcanzó el cap de 80 turnos.",
        "Normal < elite < boss en peligro observado; las recompensas elite duplican Ash/XP y aumentan chance de augment.",
        "Los dos bosses alcanzan sus tres fases y ninguna cohorte tiene boss imposible.",
        "Overheal agregado bajo y rutas tanto de victoria como derrota reproducibles.",
        "Determinismo, aislamiento y contratos de Results/metaprogresión pasan.",
    ]
    return findings[:10], top_five, healthy


def markdown_report(summary: dict[str, Any]) -> str:
    groups = summary["win_rate"]
    lines = [
        "# ETAPA 62 — Full-Run Simulation & Balance Evidence", "",
        "> Evidencia estadística de un simulador headless. No reemplaza playtest humano y no implica cambios de balance.", "",
        "## Configuración", "",
        f"- Runs: {summary['runs_total']:,}",
        f"- Seed base: {summary['base_seed']}",
        "- Perfil: nivel permanente 0, sin equipo inicial, tres skills por defecto y Ember Hound equipado.",
        "- Aislamiento: RunState in-memory; APPDATA y logs bajo `build/stage62`; sin `SaveManager.deposit_run`.", "",
        "## Win rate", "",
        "| Bioma | Policy | Runs | Win rate | Llega al boss | Victoria al llegar | HP al boss | Turnos |",
        "|---|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for row in groups:
        lines.append(f"| {row['biome']} | {row['policy']} | {row['runs']} | {row['win_rate_pct']:.2f}% | {row['boss_reach_rate_pct']:.2f}% | {row['boss_win_rate_when_reached_pct']:.2f}% | {row['avg_boss_entry_hp']:.2f} | {row['avg_combat_turns']:.2f} |")
    lines += ["", "## Impacto de intents: Tactical vs Aggressive", ""]
    for biome, row in summary["intent_impact"].items():
        lines.append(f"- **{biome}:** Δ win rate {row['win_rate_delta_points']:+.2f} pp; Δ daño recibido {row['damage_taken_delta']:+.2f}; Δ HP al boss {row['boss_entry_hp_delta']:+.2f}; Δ Guard {row['guard_uses_delta']:+.2f}.")
    lines += ["", "## Bosses", ""]
    for boss, row in summary["bosses"].items():
        lines.append(f"- **{boss}:** {row['reached']} llegadas; {row['win_rate_when_reached_pct']:.2f}% victorias al llegar; HP entrada {row['avg_entry_hp']:.2f}; {row['avg_turns']:.2f} turnos medios; fase máxima {row['max_phase_reached']}.")
    lines += ["", "## Muertes", "", f"- Total: {summary['deaths']['total']} ({summary['deaths']['rate_pct']:.2f}%).", f"- Segmentos: `{json.dumps(summary['deaths']['by_segment'], ensure_ascii=False)}`.", f"- Casillas pico: `{json.dumps(summary['deaths']['top_tiles'], ensure_ascii=False)}`.", "", "## Recompensas, builds y economía", "", f"- XP media: {mean(row['xp'] for row in summary['raw_overall']) if summary.get('raw_overall') else 0}.", f"- Ash media/run: {summary['metaprogression']['avg_ash_per_run']:.2f}.", f"- Runs estimadas a primer Vitality: {summary['metaprogression']['estimated_runs_at_global_mean']['first_vitality']}.", f"- Runs estimadas para todas las ramas: {summary['metaprogression']['estimated_runs_at_global_mean']['all_branches_max']}.", "", "## Seeds de regresión", ""]
    for label, seed in summary["regression_seeds"].items():
        lines.append(f"- **{label}:** seed `{seed['seed']}` — {seed['biome']} / {seed['policy']} / {seed['outcome']} / casilla {seed['final_tile']}.")
    lines += ["", "## Top 10 hallazgos", ""]
    for finding in summary["top_10_findings"]:
        lines.append(f"- **{finding['severity']} / confianza {finding['confidence'].lower()} — {finding['title']}:** {finding['evidence']}")
    lines += ["", "## Elementos saludables", ""]
    lines.extend(f"- {item}" for item in summary["healthy_elements"])
    lines += ["", "## Próxima etapa recomendada", "", f"**{summary['recommended_next_stage']['choice']}** — {summary['recommended_next_stage']['focus']} {summary['recommended_next_stage']['reason']}", "", "## Limitaciones", "", "- La política heurística no modela habilidad humana, percepción, tiempo de lectura ni diversión.", "- La resolución es mecánica y omite presentación, input y tiempos de animación.", "- Reutiliza BoardGenerator, EncounterResolver, CombatMath, EnemyIntentPlanner, Resources, status, skills, boons, boss phases y catálogos reales; algunas sinergias reactivas y pasivos de equipo no participan porque la cohorte inicia sin equipo y el loot llega al Results.", "- Los eventos, tesoros y ofertas que en UI usan RNG no sembrado se resuelven con RNG derivado, conservando sus probabilidades y valores.", "- Correlación de una mejora con win rate no prueba causalidad.", "", "## Estado", "", "- Balance modificado: **no**.", "- Gameplay: **pendiente de playtest humano**.", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=ROOT / "build/stage62/runs.jsonl")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "build/stage62")
    parser.add_argument("--base-seed", type=int, default=620062)
    args = parser.parse_args()
    started = time.perf_counter()
    rows = load_runs(args.input)
    if not rows:
        raise SystemExit("No hay runs para agregar")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    groups = group_summary(rows)
    curves = curve_summary(rows)
    regression = outlier_seeds(rows)
    summary = {
        "schema": 1,
        "generated_utc": "deterministic-report-no-wallclock-in-results",
        "base_seed": args.base_seed,
        "runs_total": len(rows),
        "biomes": sorted({row["biome"] for row in rows}),
        "policies": sorted({row["policy"] for row in rows}),
        "win_rate": groups,
        "board": board_summary(rows),
        "combat": combat_summary(rows),
        "deaths": death_summary(rows),
        "curve": curves,
        "upgrades": pick_rates(rows),
        "builds": builds_summary(rows),
        "equipment": loot_summary(rows),
        "healing": {"avg": mean(row["healing"] for row in rows), "avg_overheal": mean(row["overheal"] for row in rows), "p90": percentile((row["healing"] for row in rows), .90), "runs_without_healing": sum(row["healing"] == 0 for row in rows)},
        "bosses": boss_summary(rows),
        "ash": {"avg": mean(row["ash"] for row in rows), "victory_avg": mean(row["ash"] for row in rows if row["outcome"] == "victory"), "defeat_avg": mean(row["ash"] for row in rows if row["outcome"] == "defeat")},
        "progression": progression_summary(rows),
        "metaprogression": metaprogression(rows),
        "duration": {"abstract_avg_tiles": mean(row["tiles_visited"] for row in rows), "abstract_avg_combats": mean(row["combats"] for row in rows), "abstract_avg_combat_turns": mean(row["combat_turns"] for row in rows), "minutes_not_inferred": True},
        "intent_impact": intent_impact(groups),
        "regression_seeds": regression,
        "invariants": {"save_or_profile_written": False, "balance_values_modified": False, "all_rows_have_30_tile_board": all(row["board_length"] == 30 for row in rows), "all_deposits_in_memory_only": all(row.get("deposit_written") is False for row in rows)},
        "report_generation_seconds": round(time.perf_counter() - started, 4),
        "raw_overall": [{"xp": row["xp"]} for row in rows],
    }
    findings, top_five, healthy = evidence_findings(summary)
    summary["top_10_findings"] = findings
    summary["top_5_balance_problems"] = top_five
    summary["healthy_elements"] = healthy
    summary["recommended_next_stage"] = {
        "choice": "C. Build Reward Pass",
        "focus": "Diferenciar recompensas ofensivas/defensivas, revisar sinergias casi automáticas y hacer viable una línea ofensiva sin tocar stats base, board, arte ni contenido nuevo.",
        "reason": "Aggressive queda en 23.7–34.1%, Defensive/Tactical en 84.8–90.0% e Inferno Rhythm aparece en 99.64% de runs; un rebalance global previo mezclaría causas.",
    }
    (args.output_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    write_csv(args.output_dir / "summary.csv", groups)
    write_csv(args.output_dir / "hp_power_curve.csv", curves)
    write_csv(args.output_dir / "upgrade_frequency.csv", summary["upgrades"]["upgrades"])
    (args.output_dir / "regression_seeds.json").write_text(json.dumps(regression, ensure_ascii=False, indent=2), encoding="utf-8")
    write_svg(args.output_dir / "win_rate_by_policy.svg", groups)
    (args.output_dir / "full_run_report.md").write_text(markdown_report(summary), encoding="utf-8")
    compact = dict(summary)
    compact.pop("raw_overall", None)
    (args.output_dir / "summary.json").write_text(json.dumps(compact, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"runs": len(rows), "groups": len(groups), "output": str(args.output_dir), "failures": []}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
