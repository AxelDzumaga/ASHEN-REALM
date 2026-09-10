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