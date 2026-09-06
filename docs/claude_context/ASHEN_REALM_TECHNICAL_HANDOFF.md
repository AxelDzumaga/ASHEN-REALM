# ASHEN REALM — TECHNICAL HANDOFF

## SNAPSHOT

REFERENCE DATE:
2026-09-04

PROJECT ROOT:
D:\Ashen Realm\ashen-realm

OFFICIAL REPOSITORY:
https://github.com/AxelDzumaga/ASHEN-REALM

REPOSITORY:
PUBLIC.

IMPORTANT:
The repository/code is the technical source of truth.
This document is only a snapshot.

---

## ENGINE

Godot:
4.7.x / 4.7.1 project environment.

Renderer:
Mobile.

Windows backend:
D3D12.

Physics:
Jolt.

Primary target:
Android.

Base portrait target:
720×1280.

---

## SAVE

SAVE_VERSION:
14.

Migration chain currently includes
legacy migrations through v14.

Save architecture includes:

TEMP
→ MAIN
with BACKUP.

Runtime test profile isolation exists.

---

## TEST PROFILE ISOLATION

IMPLEMENTED + TESTED.

Central API:

SaveManager.use_isolated_test_profile(test_name)

Automated runtime tests capable
of persisting progression
must not write to the normal:

user://profile.json.

Preserve this invariant.

---

## FEATURE FLAGS

Confirmed:

FeatureFlags.USE_3D_BOARD = false.

Board2D remains default.

Map3D exists in parallel.

---

## BOARD

Logical board remains functional.

Known structure:

30 positions.

D4.

Routing.

Deterministic systems.

BoardTurnController exists
to separate logical turn flow
from presentation.

Do not duplicate board logic
for Map3D.

---

## BOARD2D

CURRENT:

Default presentation.

Still functional.

Do not remove
until an explicit migration decision
is approved.

---

## MAP3D

CURRENT:

Technically functional.

Includes:

- deterministic routing;
- movement;
- camera;
- A/B routing;
- Combat transition;
- Event transition;
- Treasure transition;
- boss flow;
- defeat flow protection.

Defeat-flow regression:
PASS in recent testing.

Formal human Map3D playtest:
COMPLETED 2026-09-06.

Build used:
build/map3d_human_playtest_v14_2026-09-06/
(SAVE_VERSION 14, baseline commit 56ced61).

Both previously existing playtest builds
(map3d_playtest, map3d_playtest_v13_2026-09-03)
were confirmed stale before this session
(SAVE_VERSION 12 and 13 respectively, baked
into their PCKs) and were not reused.

Human-validated flows (all PASS):

- movement;
- routing A/B (functional, see design issue below);
- Combat return;
- Elite;
- Event;
- Treasure;
- Boss flow;
- Defeat flow (human-confirmed, matches automated
  map3d_defeat_flow_test).

Therefore:

MAP3D TECHNICAL:
PASS.

MAP3D HUMAN VALIDATION:
PASS WITH ISSUES (2026-09-06).

Full results:
build/map3d_human_playtest_v14_2026-09-06/HUMAN_PLAYTEST.md

5 open design/presentation/content issues registered
(MAP3D-HUMAN-001 through 005), none of them technical
stability bugs:

MAP3D-HUMAN-001 — map feels too empty.
ART DEBT / DESIGN ISSUE. Severity HIGH.

MAP3D-HUMAN-002 — no temporary progress/overview
visualization for how much of the run remains.
UX ISSUE. Severity MEDIUM.

MAP3D-HUMAN-003 — dice is functional but lacks a
satisfying visual representation (roll/animation/face).
UX / PRESENTATION. Severity MEDIUM.

MAP3D-HUMAN-004 — A/B routing does not feel like two
meaningfully different paths.
DESIGN ISSUE. Severity HIGH.

MAP3D-HUMAN-005 — no clear final reward after
completing the run/boss.
DESIGN ISSUE / CONTENT GAP. Severity HIGH.

None of these issues have been implemented/fixed yet.
Do not treat Map3D as presentation-final.

---

## COMBAT

CURRENT:

Combat2D.

No Combat3D.

Current Combat presentation
is vertical:

enemy above,
player/companion below.

Important:

scripts/combat/combat.gd
has grown to approximately 2148 lines
in the latest audit.

This is the largest architectural risk
for future Combat3D.

Future recommended direction:

extract presentation-independent
combat orchestration/domain
before building Combat3D.

Do not duplicate Combat logic
into a second full 3D implementation.

---

## ELEMENTAL SYSTEM

Mechanical foundation:
IMPLEMENTED.

Latest repository audit reports
7 affinity/element types supported mechanically.

Current authored content includes:

WET-related mechanics.

Miasma / Decay.

Ash / Curse.

FROST:
not yet assigned to actual enemy/item content.

STORM:
not yet assigned to actual enemy/item content.

Do not treat Frost/Storm content
as implemented.

---

## EQUIPMENT

Equipment 2.0 Phase 1:
IMPLEMENTED + TESTED.

CURRENT REAL SLOTS:

WEAPON
CHEST
HEAD
CAPE
RELIC.

Historical:
ARMOR was migrated/renamed to CHEST.

Set bonus foundation exists.

Pilot:
ashen_warden_set.

SAVE migration:
v14.

IMPORTANT:

Target architecture contains more slots,
but currently implemented slots
must not be confused with future targets.

---

## TARGET EQUIPMENT SLOTS

NOT ALL IMPLEMENTED.

Future target:

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

---

## REFINEMENT

CURRENT:

Supports up to +20.

Latest audit:
complete / tested.

Older documents saying +10
are obsolete.

No item destruction remains
the intended invariant.

---

## ECONOMY

Foundation:
implemented.

Includes:

- chests;
- shop;
- refinement;
- currencies;
- pity;
- boss rewards.

Prices/tuning:
still considered provisional
until human economy playtesting closes them.

Current currencies:

ASH

GUARDIAN SIGILS

FORGE SHARDS.

---

## SHOP

Shop exists.

Latest audit identified
Biome Material purchasing
as a partially connected area.

Do not assume shop is unfinished globally;
audit the specific requested behavior first.

---

## BIOMES

Current implemented complete biomes:

The Ashen Wastes

Ember Marsh.

Biome authoring architecture
for additional regions exists.

A third biome has not yet
been fully authored.

---

## ART

Much of the current presentation remains:

procedural
placeholder
technical
or provisional.

Hooks exist for final art.

Enemy visual fallback:
legibility fix implemented/tested.

Most normal enemy roster
still lacks final combat art.

Do not invest heavily
in final 2D enemy production
without checking Combat3D roadmap.

---

## ANDROID

Current:

Debug APK.

arm64-v8a.

Android readiness work exists.

Latest audit:

use_gradle_build = false.

No production AAB pipeline yet.

No final Release preset/signing flow
confirmed.

Therefore:

ANDROID DEVELOPMENT:
functional.

GOOGLE PLAY RELEASE:
NOT READY.

---

## TELEMETRY

Current:

local-only.

analytics_enabled = false
by default.

No remote analytics backend.

Privacy-first behavior.

Remote telemetry would require
separate product/privacy decision.

---

## TESTING

Project has extensive automated testing:

- runtime tests;
- board tests;
- progression tests;
- economy tests;
- Map3D tests;
- combat tests;
- save tests.

Recent suites have been strong.

Do not claim PASS
without executing or having fresh evidence.

---

## SOURCE CONTROL

Official public repository now exists:

https://github.com/AxelDzumaga/ASHEN-REALM

Latest repository audit before this decision
reported no local Git installation/.git.

Therefore:

LOCAL GIT INITIALIZATION / SYNC
MUST BE VERIFIED.

Do not assume it is already configured.

---

## CURRENT HIGH-RISK TECHNICAL AREAS

1. No verified local Git/source-control workflow.
2. Combat architecture is too presentation-coupled for clean Combat3D migration.
3. Map3D presentation/design polish pending (5 open issues from 2026-09-06 human playtest: empty map density, no run-progress overview, dice presentation, A/B route differentiation, missing final reward).
4. Android production/AAB pipeline not ready.
5. Final 3D character/equipment pipeline not yet implemented.

---

## DO NOT BREAK

Preserve:

- save compatibility;
- SAVE_VERSION migration chain;
- isolated runtime test profiles;
- BoardTurnController shared logic;
- deterministic board behavior;
- Board2D fallback until explicit removal;
- economy transaction safety;
- no item destruction;
- current Equipment migration integrity;
- public-repository secret hygiene.

---

## SOURCE-OF-TRUTH ORDER

When information conflicts:

1. current repository code;
2. fresh tests;
3. latest audit/stage report;
4. this Technical Handoff;
5. older docs.

Never override newer code
using an older context document.