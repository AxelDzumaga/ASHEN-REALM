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
  STATUS: DONE (2026-09-06) — PASS WITH ISSUES.
  5 design/presentation/content issues registered
  (MAP3D-HUMAN-001 through 005), see
  ASHEN_REALM_TECHNICAL_HANDOFF.md and
  build/map3d_human_playtest_v14_2026-09-06/HUMAN_PLAYTEST.md.
  Not yet fixed/implemented.
- human economy playtest;
- update technical documentation;
- confirm current outstanding elemental content decisions.

UPDATE (2026-09-10): Map3D is now the production expedition default
(`feature/map3d-production-runtime`, merged to `main`). Core Loop /
Final Reward completion audited and implemented
(`feature/core-loop-final-rewards`, not yet merged) — region-unlock
gating fixed (Ember Marsh now requires defeating Ashen Warden, not
merely finishing any expedition), RunResult reward accounting
completed (Guardian Sigils, Boss Chest, new-region-unlock all
correctly shown once and only when earned). FUNCTIONAL reward flow is
complete; human economy/feel playtest remains a separate, still-open
goal of this tier, deferred to the Visual Vertical Slice policy like
every other subjective-feel sign-off this session.

Do not start major 3D production yet.

Do not jump to Combat3D or Character3D
based on this result alone; the Map3D issues
are a design/polish pass, not an architecture
blocker, but they have not been scheduled yet.

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

M1 (turn sequencing extraction only):
MERGED 2026-09-12 (main).
CombatTurnController is the round/team-block/
actor-turn authority; combat.gd no longer runs
its own manual while-loop or per-enemy for-loop
for sequencing. Cooldown-tied-to-basic-attack bug
found during the extraction and fixed.

M2 (generic team/controller cleanup):
MERGED 2026-09-12 (main). CombatActor.controller_type
(PLAYER_CONTROLLED/AI_ALLY/AI_ENEMY/SCRIPTED) replaces
identity-based dispatch. CombatTeamUtils is the single
team-alive/team-defeated definition. Approved gameplay
change: Player Team defeat now requires the WHOLE team
down; a protagonist-saved-by-ally victory normalizes HP
to exactly 1 before returning to Map3D.

M3 (action/target resolution):
MERGED 2026-09-12 (main @ 19c6ca0).
CombatTargetResolver gives all 5 ActiveSkillData.TargetType
values (SELF/SINGLE_ENEMY/SINGLE_ALLY/ALL_ENEMIES/
ALL_ALLIES) real domain semantics instead of the three
non-SELF/SINGLE_ENEMY types silently no-op'ing; no new
skill content authored, the new types are proven with
synthetic test fixtures only. Player basic-attack/skill
target resolution now happens before cost/cooldown
commitment (matching the DECIDE-then-RESOLVE shape AI
actions already had), and no longer silently retargets a
stale committed target to a different enemy. Existing
single-target skill behavior (100% of current authored
content) left byte-identical — verified via
ashen_warden_phase3_curse_test matching the established
baseline exactly. No ActionIntent framework introduced;
CombatMath and the protagonist-only Boons/Equipment/Synergy
layers are unchanged. See ASHEN_REALM_DECISIONS.md and the
TECHNICAL_HANDOFF COMBAT section for the exact contract.

M4 (structured combat events):
IMPLEMENTED 2026-09-13, local branch
feature/combat-domain-m4, NOT MERGED.
CombatEventStream (one per encounter, no retained history)
emits 8 presentation-independent event types synchronously —
ActionEvent/DamageEvent/HealEvent/StatusEvent/ReactionEvent/
DeathEvent/BossPhaseEvent/SummonEvent — reporting what already
happened without recalculating any formula (damage, healing,
reactions all reuse the exact already-computed values). No
VictoryEvent/DefeatEvent/EnergyChangedEvent/CooldownChangedEvent
were added — CombatTurnController and combat_won/combat_lost
remain the sole lifecycle/terminal authorities, unchanged.
DeathEvent uses the hp_before>0/hp_after<=0 transition, not the
death_presented presentation flag. Warden's Rebuke gets its own
new action_id, never the triggering basic attack's. A single
minimal Combat2D listener (_on_combat_event) migrated one
inline status-tick damage-number call behind event_emitted;
every other animation/choreography call site is unchanged. See
ASHEN_REALM_DECISIONS.md and the TECHNICAL_HANDOFF COMBAT
section for the exact contract.

Still ahead: M5 (5v5 formation), M6 (final Combat2D adapter
cleanup) — none started.

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