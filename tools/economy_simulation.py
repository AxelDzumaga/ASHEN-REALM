"""Simulación reproducible de la economía base de Etapa 78 (sin tocar saves)."""
from __future__ import annotations

import random
import statistics
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "stage78" / "economy_simulation.md"
TRAJECTORIES = 2000
MAX_RUNS = 250


@dataclass(frozen=True)
class Cohort:
    name: str
    victory_chance: float
    combat_mean: float
    prefer_shards: bool


COHORTS = [
    Cohort("CASUAL", 0.22, 3.5, False),
    Cohort("NORMAL", 0.36, 5.0, True),
    Cohort("DEDICATED", 0.52, 6.0, True),
]


def refinement_cost(level: int, rarity_multiplier: int = 1, tier: int = 1) -> tuple[int, int, int]:
    target = level + 1
    ash = (18 + target * target * 4 + tier * 6) * rarity_multiplier
    shards = 0 if target <= 3 else ((target - 1) // 2) * rarity_multiplier
    sigils = 0 if target <= 7 else (target - 7) * max(1, rarity_multiplier // 2)
    return ash, shards, sigils


def percentile(values: list[int], p: float) -> int:
    ordered = sorted(values)
    return ordered[min(len(ordered) - 1, round((len(ordered) - 1) * p))]


def simulate(cohort: Cohort, seed: int) -> dict[str, int | None]:
    rng = random.Random(seed)
    ash = sigils = shards = 0
    have_common = have_rare = have_epic = False
    boss_pieces: set[int] = set()
    refinement = 0
    first_rare = first_epic = first_boss = first_max = None
    boss_pity = 0

    for run in range(1, MAX_RUNS + 1):
        victory = rng.random() < cohort.victory_chance
        combats = max(1, round(rng.gauss(cohort.combat_mean, 1.2)))
        elite = 1 if combats >= 5 and rng.random() < 0.65 else 0
        ash += combats * 5 + elite * 5 + (50 if victory else 0)

        # Botín de Results existente.
        roll = rng.random()
        rarity = None
        if victory:
            rarity = 0 if roll < 0.55 else 1 if roll < 0.90 else 2
        elif roll < 0.40:
            rarity = 0 if roll < 0.30 else 1
        if rarity == 0:
            have_common = True
        elif rarity == 1:
            have_rare = True
        elif rarity == 2:
            have_epic = True

        if victory:
            warden = (run // 3) % 2 == 0
            sigils += 4 if warden else 6
            shards += rng.randint(1, 2)
            epic_chance = 0.30 if warden else 0.50
            boss_pity += 1
            epic = rng.random() < epic_chance or boss_pity >= (4 if warden else 3)
            boss_pity = 0 if epic else boss_pity
            have_rare = True
            if epic:
                have_epic = True
                if warden and rng.random() < 0.35:
                    missing = [piece for piece in (0, 1) if piece not in boss_pieces]
                    boss_pieces.add(rng.choice(missing or [0, 1]))

        # Compra determinista de una pieza faltante: la moneda evita bloqueo RNG.
        if run >= 12 and 0 not in boss_pieces and sigils >= 18:
            sigils -= 18
            boss_pieces.add(0)
        if run >= 15 and 1 not in boss_pieces and sigils >= 20:
            sigils -= 20
            boss_pieces.add(1)

        # Objetivo de forja conservador: maximizar una pieza Common primero.
        if have_common and refinement < 10:
            cost_ash, cost_shards, cost_sigils = refinement_cost(refinement)
            if cohort.prefer_shards and shards < cost_shards and ash >= 70:
                purchasable = min(cost_shards - shards, ash // 70)
                shards += purchasable
                ash -= purchasable * 70
            if ash >= cost_ash and shards >= cost_shards and sigils >= cost_sigils:
                ash -= cost_ash
                shards -= cost_shards
                sigils -= cost_sigils
                refinement += 1

        if have_rare and first_rare is None:
            first_rare = run
        if have_epic and first_epic is None:
            first_epic = run
        if boss_pieces and first_boss is None:
            first_boss = run
        if refinement == 10 and first_max is None:
            first_max = run
    return {"rare": first_rare, "epic": first_epic, "boss": first_boss, "max": first_max}


def summarize(values: list[int | None]) -> str:
    reached = [value for value in values if value is not None]
    if not reached:
        return "no alcanzado"
    return f"mediana {round(statistics.median(reached))} · P90 {percentile(reached, .90)} · alcance {len(reached) / len(values):.1%}"


def main() -> None:
    lines = [
        "# Etapa 78 — Simulación económica",
        "",
        f"{TRAJECTORIES:,} trayectorias por cohorte, hasta {MAX_RUNS} runs, semilla reproducible. Modelo de validación, no balance final.",
        "",
        "| Cohorte | Primer Rare | Primer Epic | Primera pieza boss | Primer +10 |",
        "|---|---:|---:|---:|---:|",
    ]
    for index, cohort in enumerate(COHORTS):
        rows = [simulate(cohort, 780000 + index * TRAJECTORIES + seed) for seed in range(TRAJECTORIES)]
        lines.append(
            f"| {cohort.name} | {summarize([r['rare'] for r in rows])} | "
            f"{summarize([r['epic'] for r in rows])} | {summarize([r['boss'] for r in rows])} | "
            f"{summarize([r['max'] for r in rows])} |"
        )
    common_total = tuple(sum(refinement_cost(level)[i] for level in range(10)) for i in range(3))
    rare_total = tuple(sum(refinement_cost(level, 2, 2)[i] for level in range(10)) for i in range(3))
    epic_total = tuple(sum(refinement_cost(level, 4, 3)[i] for level in range(10)) for i in range(3))
    lines += [
        "",
        "## Coste acumulado +0→+10",
        "",
        f"- Common T1: {common_total[0]} Ceniza, {common_total[1]} Fragmentos, {common_total[2]} Sigilos.",
        f"- Rare T2: {rare_total[0]} Ceniza, {rare_total[1]} Fragmentos, {rare_total[2]} Sigilos.",
        f"- Epic T3: {epic_total[0]} Ceniza, {epic_total[1]} Fragmentos, {epic_total[2]} Sigilos.",
        "",
        "## Lectura",
        "",
        "- Rare aparece temprano sin ser automático; Epic conserva valor.",
        "- Una pieza de boss tiene ruta RNG y ruta determinista por Sigilos (18–20).",
        "- +10 es alcanzable pero de largo plazo; Epic +10 queda sustancialmente más caro.",
        "- Ninguna trayectoria depende de reloj, servidor o pérdida destructiva del ítem.",
    ]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"PASS: {TRAJECTORIES * len(COHORTS)} trajectories -> {OUT}")


if __name__ == "__main__":
    main()
