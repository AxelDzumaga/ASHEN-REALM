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

COMBAT DOMAIN M2 (2026-09-12) — APPROVED E IMPLEMENTADO
(local, branch feature/combat-domain-m2, no mergeado):

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

M3 (action resolution), M4 (structured combat events),
M5 (5v5 formation) siguen sin implementar.

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