# ASHEN REALM — PRODUCTION ROADMAP

## PHILOSOPHY

No producir contenido masivo
sobre sistemas inestables.

Framework
→ Pilot
→ Test
→ Playtest
→ Scale.

---

# TIER 0 — PROJECT SAFETY

Priority:
NOW.

Goals:

- verify/install Git;
- initialize/sync official repository;
- secure .gitignore;
- establish baseline;
- protect public repo from secrets.

Repository:

https://github.com/AxelDzumaga/ASHEN-REALM

Definition of Done:

- local Git operational;
- origin configured;
- baseline committed;
- no secrets;
- rollback available.

---

# TIER 1 — CLOSE CURRENT FOUNDATIONS

Goals:

- complete formal Map3D human playtest;
- human economy playtest;
- update technical documentation;
- confirm current outstanding elemental content decisions.

Do not start major 3D production yet.

---

# TIER 2 — ORIENTATION / UX SPIKE

Decide:

Portrait
vs
Landscape
vs
controlled hybrid if justified.

Must be decided
before final Combat3D UI composition.

Validate:

- 3v3;
- 5v5;
- HUD;
- targeting;
- skill buttons;
- mobile readability.

---

# TIER 3 — COMBAT ARCHITECTURE

Goal:

separate combat domain/orchestration
from Combat2D presentation.

Desired result conceptually:

CombatTurnController
→ Combat2D
→ future Combat3D.

Do not duplicate 2000+ lines
into Combat3D.

Definition of Done:

existing Combat2D behavior preserved
and regression-tested.

---

# TIER 4 — EQUIPMENT 2.0 CONTINUATION

Current Phase 1 already exists.

Continue only after design review.

Potential future slots:

Shoulders
Hands
Legs
Feet
Ring1
Ring2.

Do not necessarily implement all at once.

Validate:

- migration;
- inventory;
- compare;
- set bonuses;
- shop;
- visual IDs.

---

# TIER 5 — CHARACTER3D + VISUAL EQUIPMENT PILOT

Create ONE technical character pilot.

Use placeholder/cheap assets if needed.

Minimum visual modules:

Base
Weapon
Head
Chest
Cape.

Validate:

- skeleton;
- attachments;
- mesh swapping;
- materials;
- clipping;
- animation compatibility;
- Godot import;
- mobile cost.

Do not produce dozens of equipment pieces.

---

# TIER 6 — COMBAT3D TECHNICAL PROTOTYPE

Progression:

1v1
→ 2v2
→ 3v3
→ technical 5v5 stress test.

Validate:

- camera;
- formation;
- targeting;
- skills;
- damage;
- status;
- movement;
- animation events;
- boss presentation;
- performance.

No final art required.

---

# TIER 7 — VERTICAL SLICE

Create one small but representative
piece of final Ashen Realm.

Recommended:

Ashen Wastes

+
Map3D

+
Ashen Wanderer 3D

+
visible Equipment

+
Combat3D

+
Affinity/Status

+
Event

+
Treasure

+
Elite

+
Boss

+
Loot

+
Shop/Forge

+
Results

+
Refuge.

Definition of Done:

not merely technically functional;
must be human-playtested
and visually representative.

---

# TIER 8 — CONTENT PIPELINES

Validate repeatable pipelines for:

- regions;
- enemies;
- bosses;
- equipment;
- events;
- allies;
- environments;
- animations;
- VFX;
- audio.

Only after pipelines are stable
should mass content production begin.

---

# TIER 9 — CONTENT PRODUCTION

Produce:

additional regions;
enemy rosters;
elites;
bosses;
equipment;
sets;
events;
loot;
audio;
art.

Do not decide final quantities
before Vertical Slice results.

---

# TIER 10 — ALPHA

Core systems complete.

Content partially complete.

No critical architecture rewrites pending.

Test:

full progression.

save migrations.

Android hardware.

long sessions.

economy.

---

# TIER 11 — CONTENT COMPLETE

All planned 1.0 content exists.

No new major features.

Focus:

balance
bugs
performance
presentation.

---

# TIER 12 — BETA

Feature complete.

Content complete.

Heavy human playtesting.

Device matrix.

Economy tuning.

Onboarding.

Localization.

Accessibility.

---

# TIER 13 — RELEASE CANDIDATE

No known critical bugs.

Production:

AAB

release signing

versioning

store assets

privacy

data safety

age rating

closed testing.

---

# TIER 14 — 1.0

Production release.

Only approved launch scope.

---

## CURRENT NEXT ACTIONS

Recommended immediate order:

1. Source-control baseline.
2. Map3D human playtest.
3. Human economy playtest.
4. Orientation decision.
5. Combat architecture extraction.

Only after those:

Character3D
+
Combat3D.

---

## DO NOT DO YET

Do not:

- produce dozens of final 3D characters;
- create many final regions;
- produce 100 equipment meshes;
- rewrite Combat;
- remove Board2D;
- add endgame systems;
- add many currencies;
- create full 5v5 content roster;
- invest heavily in final 2D enemy art;
- prepare launch marketing before Vertical Slice.

---

## REPORTING RULE

Every major stage must end with:

IMPLEMENTATION
→ TESTS
→ HUMAN PLAYTEST when relevant
→ STAGE REPORT
→ TECHNICAL HANDOFF UPDATE.

This prevents documentation from becoming stale.