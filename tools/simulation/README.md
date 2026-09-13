# Simulación full-run (ETAPA 62)

Esta herramienta ejecuta runs completas sin UI ni animaciones. Reutiliza directamente `RunState`, `BoardGenerator`, `EncounterResolver`, `CombatMath`, `EnemyIntentPlanner`, `CombatStatusController`, controllers de skills/boons, fases de boss y catálogos de Resources. No llama `SaveManager.deposit_run`, no escribe telemetría y debe ejecutarse con `APPDATA` redirigido bajo `build/stage62`.

## Cohorte principal

- Nivel permanente 0.
- Sin equipo inicial.
- Loadout de tres skills por defecto.
- Ember Hound equipado; está desbloqueado por defecto.
- Dos biomas y cuatro policies.
- Misma seed de board por índice de muestra en las cuatro policies; el RNG de decisión se deriva de seed + policy.

El equipment obtenido se entrega en Results, igual que en el flujo real, por lo que se registra pero no modifica la run que lo produce.

## Policies auditables

### RANDOM

- Target vivo aleatorio.
- 45% de probabilidad de usar una skill válida; si no, ataque básico.
- Eventos y opciones de recompensa se eligen de forma pseudoaleatoria sembrada.

Es un baseline deliberadamente pobre, no un jugador humano promedio.

### AGGRESSIVE

- Prioriza enemigos con poca vida y ataque alto.
- Usa Ember Slash en cuanto está disponible.
- Favorece upgrades ofensivos y augments de Ember Slash.
- No reserva energía para Guard o Second Wind.

### DEFENSIVE

- Usa Second Wind con 55% de HP o menos.
- Usa Guard si el daño previsto supera un tercio de la vida, al menos 16, o existe intent HIGH/LETHAL.
- Prioriza support y acciones disruptivas.
- Favorece sustain/defensa y augments de Guard.

### TACTICAL

- Lee los `EnemyIntent` realmente planificados.
- Cura si el daño total previsto puede matar o si HP está en 40% o menos.
- Usa Guard ante intent HIGH/LETHAL o presión acumulada relevante.
- Prioriza intent peligroso, support, status/disruptor y summons.
- Usa Ember Slash si no necesita una respuesta defensiva.
- Favorece opciones que completan una sinergia y adapta sustain a HP bajo.

No es una AI perfecta. La comparación Tactical/Aggressive mide el paquete de decisiones informado, no el efecto causal aislado del badge de intent.

## Reproducibilidad

Escena:

```text
res://tools/simulation/full_run_simulation.tscn -- --runs=1000 --seed=620062 --output=res://build/stage62/runs.jsonl
```

Reporte:

```text
python tools/simulation/full_run_report.py --input build/stage62/runs.jsonl --output-dir build/stage62 --base-seed 620062
```

Pruebas internas:

```text
res://tools/simulation/full_run_simulation.tscn -- --mode=test --output=res://build/stage62/test_probe.jsonl
```

## Overrides temporales de balance (ETAPA 64)

El simulador acepta overrides que se copian en memoria y nunca escriben ni mutan
los `Resource` del proyecto:

```text
--disable-effect=iron_skin,iron_vigil
--effect-scale=iron_skin:0.67,burning_strike:1.2
--effect-cap=ashen_bulwark:4
--max-effect-stacks=iron_skin:2
--experiment=nombre_auditable
```

Sin argumentos de override, el contrato oficial es
`BASELINE_64=STATE_AFTER_STAGE63_CANDIDATE_C`. Cada metadata registra el perfil
completo de overrides. Las comparaciones usan el mismo `run_id`, seed, bioma,
policy, board y secuencia determinista de rewards; `stage64_balance_report.py`
rechaza implícitamente pares ausentes al informar la intersección y contabiliza
los `board_mismatches`.

## Telemetría y overrides (ETAPA 65)

El esquema 4 agrega energía perdida al cap/final/reset, oportunidades y
competencia de Ember Slash/Second Wind/Guard, ticks y uptime de Burn, y
Warden's Rebuke. Overrides exclusivamente de simulación:

```text
--skill-cost=ember_slash:75
--basic-energy=30
--status-duration-bonus=burn:1
--boon-rarity=fallback|renormalized
```

El runtime renormaliza Rare/Epic porque el catálogo no contiene boons COMMON.
El modo `fallback` reproduce BASELINE_65 para comparaciones A/B.

ETAPA 66 agrega controles temporales `--disable-companion-burn`,
`--burning-strike-burn=1`, `--inferno-burn-bonus=1`,
`--energy-carryover=0.20`, `--energy-carryover-cap=25` y
`--warden-defense-delta=-1`. El candidato integrado conserva 20% de Brasa tras
victorias no-boss y hace que Burning Strike aplique Quemadura (+1 adicional con
Inferno Rhythm).

## Límites de fidelidad

- Omite presentación, input, hitstop y tiempo real; duración se expresa en tiles, combates y turnos.
- Reproduce la resolución mecánica principal, pero no pretende sustituir el runtime gráfico ni un playtest.
- La cohorte empieza sin equipo; por eso sus pasivos no participan antes del Results.
- Algunas sinergias reactivas no se modelan con toda la riqueza de presentación/runtime. Las activaciones y sus fuentes sí se registran.
- Los RNG que en pantallas UI se inicializan con `randomize()` se reemplazan por RNG derivado para conservar probabilidades con reproducibilidad.
- Win rate condicionado por upgrade/equipment es correlación descriptiva, no causalidad.
- La cohorte nunca entra a combate con arma equipada ni `equipment_crit_chance > 0` (`_cohort_gear_assumption_holds()`, comprobado por autotest) — el simulador no modela afinidad elemental (`AffinityResolver`) ni crítico de equipo. Es matemáticamente neutro solo mientras eso siga siendo cierto; si un futuro cohort equipa gear a mitad de run, ese guard debe fallar en vez de invalidar el balance en silencio.

## Simulator Alignment A (Combat Domain post-M1-M6)

Turn sequencing, target validation, and team-based terminal semantics now
reuse the real production domain directly instead of a hand-rolled
duplicate:

- **Turn sequencing:** `CombatTurnController` (Combat Domain M1) drives
  Player Team → Enemy Team, stable order, dead-actor skipping, and
  next-block-only eligibility for mid-round summons — replacing the old
  hand-written `player → companion → enemy round` loop.
- **Target validation:** `CombatTargetResolver` (Combat Domain M3)
  validates the player policy's chosen target; the policy itself
  (`_choose_target`/`_choose_player_action`) is unchanged and stays
  simulator-owned.
- **Terminal semantics:** `CombatTeamUtils` (Combat Domain M2) decides
  victory/defeat by whole-team liveness, not a protagonist-only check — a
  protagonist KO with the companion still alive no longer ends combat as a
  defeat. An ally-saved victory normalizes the protagonist to 1 HP
  (mirroring `combat.gd`'s `_finish_victory` anti-softlock rule), which
  persists into the rest of the simulated run via `RunState.current_health`.
- **Parity fixtures:** `tools/tests/simulator_domain_parity_test.gd`
  exercises these three seams directly against the real production
  classes, plus two known-seed regression fixtures (`seed=1353165`/
  `policy=random`/`biome=ashen_wastes` for the ally-saved-victory
  correction, `seed=620062` for a Warden's Rebuke counter surviving the
  migration).

**Remaining, explicitly out of scope for Alignment A (see Simulator
Alignment B):** `_execute_player_action`/`_run_enemy_action` still
independently re-sequence the same underlying primitives
(`CombatMath`/`EquipmentEffectResolver`/`BoonController`/
`CombatStatusController`) that `combat.gd`'s own basic-attack/skill/enemy
resolution encodes — there is still no single presentation-independent
callable for "resolve one action" that both consumers share. A future
change to that sequence in `combat.gd` would not automatically propagate
here.
