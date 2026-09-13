# ASHEN REALM — APPROVED DECISIONS

Este documento contiene decisiones aprobadas.

No debe contener ideas todavía no confirmadas.

---

## GAME

APPROVED:

Ashen Realm es un
dark fantasy RPG / roguelite
mobile-first.

---

## MAP

APPROVED:

La dirección final es Map3D.

Board2D puede mantenerse
durante transición/fallback.

---

## COMBAT

APPROVED DIRECTION:

Turn-based team combat.

Target futuro:
hasta 5v5.

Player:
izquierda.

Enemies:
derecha.

Camera:
lateral 3/4.

Combat3D todavía no se considera implementado
hasta confirmación técnica.

COMBAT DOMAIN M1 (2026-09-12) — APPROVED Y EXTRAÍDO:

CombatTurnController (scripts/combat/combat_turn_controller.gd)
es la única autoridad de secuenciación de turnos
(ronda, bloque de equipo, orden estable, elegibilidad),
presentation-independent, sin _process()/timers/polling.

Orden actual confirmado y preservado:
PLAYER -> COMPANION (si vivo/presente) -> ENEMY 1..N -> próxima ronda.
Sin Speed, sin iniciativa, sin turn meter — orden estable únicamente.

Cooldown bug confirmado y corregido en M1:
el cooldown de skills solo avanzaba en turnos de ataque
básico, nunca al usar otra skill. Ahora avanza en cada
turno del jugador sin importar la acción elegida.

COMBAT DOMAIN M2 (2026-09-12) — APPROVED, IMPLEMENTADO Y
MERGEADO (main @ 835b6f3):

CombatActor.controller_type (PLAYER_CONTROLLED / AI_ALLY /
AI_ENEMY / SCRIPTED) reemplaza la comparación de identidad
contra player_actor/companion_actor como forma de decidir
quién controla a un actor. ActorType/Team no cambiaron de
significado.

CAMBIO DE SEMÁNTICA DE GAMEPLAY APROBADO — DERROTA A NIVEL
DE EQUIPO:
Antes: protagonista en 0 HP = derrota inmediata, sin
importar si el compañero seguía vivo.
Ahora: DERROTA solo cuando NINGÚN actor del Player Team
sigue con vida. Protagonista KO + aliado vivo -> el combate
CONTINÚA automáticamente con el aliado; el protagonista
queda fuera de combate (no revive, no vuelve a actuar ese
combate) pero deja de ser objetivo por las reglas de
is_alive()/is_targetable() ya existentes.

ANTI-SOFTLOCK APROBADO:
si el Player Team gana el combate con el protagonista en
0 HP, se normaliza a exactamente 1 HP antes de volver a
Map3D (nunca vida completa, nunca un porcentaje, nunca en
una derrota real). Sin revive dentro del combate.

Compañero sigue sin persistir HP entre combates — deuda
explícita, no se toca en M2.
CombatSkillController/energía de combate siguen siendo
singulares del protagonista — deuda explícita, no se toca
en M2 (ninguna segunda skill de héroe planeada todavía).

COMBAT DOMAIN M3 (2026-09-12) — APPROVED, IMPLEMENTADO Y
MERGEADO (main @ 19c6ca0):

Los 5 ActiveSkillType.TargetType (SELF, SINGLE_ENEMY,
SINGLE_ALLY, ALL_ENEMIES, ALL_ALLIES) ahora tienen
semántica de dominio real vía CombatTargetResolver — antes
solo SELF/SINGLE_ENEMY funcionaban, el resto no-opeaba en
silencio. Ningún contenido/skill nuevo fue autorado; los
tres TargetTypes restantes se prueban con fixtures
sintéticos, no con loadouts jugables.

SINGLE_ALLY sin selección explícita devuelve
TARGET_SELECTION_REQUIRED — nunca elige "el primer aliado
vivo" en su lugar. No hay UI de selección de aliado
todavía; eso queda para cuando esa UI exista.

El ataque básico del protagonista ya no reapunta en
silencio a otro enemigo si el target comprometido se
invalida entre el commit y la resolución (camino ya
inalcanzable en la arquitectura actual, corregido de todas
formas por corrección a futuro).

No se introdujo una clase ActionIntent genérica — se
mantuvo la convención ya existente del repositorio (clases
anidadas de datos planos: Decision, ActionPlan, TickResult).

CombatMath.calculate_damage() sigue siendo la única fórmula
de daño autoritativa; Boons/Equipment/Synergy siguen
aplicándose solo a las propias estadísticas del
protagonista al atacar, nunca como bonus a un target aliado
o enemigo.

COMBAT DOMAIN M4 (2026-09-13) — APPROVED E IMPLEMENTADO
(local, branch feature/combat-domain-m4, no mergeado):

Se agrega un registro semántico de "qué pasó" en combate,
independiente de presentación: 8 tipos de evento (ActionEvent,
DamageEvent, HealEvent, StatusEvent, ReactionEvent, DeathEvent,
BossPhaseEvent, SummonEvent) emitidos sincrónicamente por un
CombatEventStream nuevo, uno por encuentro, sin historial
retenido (nadie acumula un array de eventos pasados — un
futuro combat log sería su propio consumidor).

CombatTurnController sigue siendo la única autoridad de
round_started/team_block_started/actor_turn_started/
actor_turn_ended/combat_sequence_stopped — esos NO se
duplican como CombatEvent. combat_won/combat_lost y el flujo
de RunResult/recompensas siguen siendo la única autoridad
terminal — no existe VictoryEvent ni DefeatEvent, y
CombatEventStream nunca puede disparar esos caminos (no
conoce CombatTurnController ni _finish_victory/_finish_defeat).
Tampoco se agregaron EnergyChangedEvent ni CooldownChangedEvent.

action_id es un entero monótonamente creciente por encuentro
(empieza en 1); NO_ACTION_ID=0 marca efectos sin acción
causante (p. ej. un tick de estado). Warden's Rebuke recibe
siempre su propio action_id nuevo, nunca el del ataque básico
que lo disparó — es una acción causal distinta. Multi-target
es 1 ActionEvent + N eventos de efecto compartiendo ese mismo
action_id.

DeathEvent se determina por la transición hp_before>0 y
hp_after<=0 (nunca por el flag death_presented, que sigue
siendo responsabilidad exclusiva de presentación/animación).
Acciones inválidas/rechazadas (energía insuficiente, cooldown,
target inválido) no emiten ningún evento — el resto de la
arquitectura de commit-antes-que-resolución de M3 ya lo
garantiza estructuralmente.

ReactionEvent cubre WET+CHILLED (bonus de stacks) y WET+SHOCK
(salto en cadena) reusando exactamente la detección que
CombatStatusController ya tenía (last_reaction, un campo de
"último resultado" consultado por el llamador, mismo patrón
que ActiveSkillController.last_guard_reduction) — sin crear un
detector de reacciones paralelo ni cambiar reglas/stacks/daño/
duración/RNG.

Adaptador de presentación mínimo: Combat2D escucha
event_emitted solo para redibujar el número flotante de un
tick de estado (StatusEvent.kind=TICK) — un único call site
síncrono migrado sin await, sin duplicar el resto de la
coreografía existente (animaciones/impactos siguen totalmente
en combat.gd, sin pasar detrás de un listener genérico).

M5 (5v5 formation), M6 (final Combat2D adapter cleanup)
siguen sin implementar.

---

## EQUIPMENT

APPROVED:

Equipment es un pilar central.

Long-term target incluye:

WEAPON
HEAD
SHOULDERS
CHEST
HANDS
LEGS
FEET
CAPE
RING_1
RING_2
RELIC.

No todos están implementados actualmente.

---

## VISUAL EQUIPMENT

APPROVED:

El equipment debe eventualmente
modificar físicamente al personaje 3D.

Priority visual slots:

Weapon
Head
Shoulders
Chest
Hands
Legs
Feet
Cape.

---

## ITEM DESTRUCTION

APPROVED:

Refinement NO destruye items.

---

## ECONOMY

APPROVED:

Currencies principales:

Ash
Guardian Sigils
Forge Shards.

Evitar moneda por elemento.

---

## AFFINITIES

APPROVED:

Sistema elemental/affinity
con importancia real.

No hard counters obligatorios.

---

## REGIONS

APPROVED:

Múltiples regiones 3D
con identidad propia.

No simples recolors.

APPROVED (2026-09-10, Core Loop / Final Reward):

Región completada = boss de esa región derrotado
(milestone BOSS_DEFEATED específico del boss, no
"cualquier expedición terminada").

Ember Marsh se desbloquea con `warden_defeated`
(Ashen Warden derrotado en Ashen Wastes),
no con `first_expedition` (bug corregido esta sesión —
antes cualquier expedición terminada, incluso por derrota,
desbloqueaba Ember Marsh).

Una región "despejada" sigue siendo rejugable
(farming de set de boss, cofre de boss, Guardian Sigils,
materiales de bioma, botín, build experimentation).
No es "deshabilitada" ni "terminada para siempre".

`first_expedition` (TOTAL_RUNS) y `first_victory`
(TOTAL_VICTORIES) permanecen como hitos genéricos
("completá una expedición" / "ganá una expedición
por primera vez") — ninguno de los dos actúa como
gate de región específica; ese rol es exclusivo
de los hitos BOSS_DEFEATED por boss.

New Game+, tiers de dificultad, prestige o modo
infinito quedan explícitamente fuera de este milestone.

---

## ALLIES

APPROVED DIRECTION:

Temporary allies
y eventualmente permanent/unlockable allies
pueden formar parte del juego.

---

## EVENTS

APPROVED:

Event chains y consecuencias
pueden existir.

---

## BOSSES

APPROVED:

Bosses deben poseer mecánicas
y recompensas propias.

---

## ART

APPROVED:

Dark fantasy stylized.

No hiperrealista.

Mobile readable.

---

## DEVELOPMENT

APPROVED WORKFLOW:

Design
→ implementation
→ tests
→ human playtest
→ report.

No feature gigantesca sin fases.

UPDATE (2026-09-10) — HUMAN PLAYTEST GATE, SCOPE CLARIFIED:

Subjective human visual/feel playtest of placeholder/prototype art
is NO LONGER a merge blocker for logic-development milestones, until
Ashen Realm reaches its Visual Vertical Slice milestone. Reason: repeated
subjective testing of non-representative placeholder visuals does not
provide enough value to justify blocking logic architecture work on it.

This does NOT remove or weaken:

- automated logic test coverage;
- regression coverage;
- non-headless render/functional smoke validation when UI is involved;
- documentation of known UX/feel feedback as backlog.

Workflow for logic milestones until the Visual Vertical Slice becomes:

Design
→ implementation
→ tests (+ real-render smoke where UI is involved)
→ report.

Human playtest resumes as a gate once the project reaches the Visual
Vertical Slice milestone. Do not record deferred human validation as
"HUMAN PASS" in any status doc — use "HUMAN VISUAL ACCEPTANCE: DEFERRED
UNTIL VISUAL VERTICAL SLICE" instead.

---

## PUBLIC REPOSITORY

Official repository:

https://github.com/AxelDzumaga/ASHEN-REALM

Visibility:
PUBLIC.

Nunca subir secretos,
saves personales,
credenciales,
keys,
keystores privados
o perfiles de test.