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

UPDATE (2026-09-06 to 2026-09-08, branch feature/map3d-true-routing):

MAP3D-HUMAN-004 (A/B routing) — addressed. Deterministic pre-generated
branches replaced the old dynamic base+1/gate mechanism (see ROUTING below).
First human retest (2026-09-06, build
`map3d_true_routing_bossfix_v14_2026-09-06`) came back PASS WITH ISSUES:
fork/choice/movement/return-flow all confirmed working, but branch length (4
tiles) felt too short — "se sentía como pocas casillas". Fixed 2026-09-08:
`RouteBranchData.BRANCH_LENGTH` 4 -> 6 (with D4 as the movement cap, no
single roll can now cross an entire branch — this was mathematically
possible at length 4). Biome `empty_min` (ashen_wastes.tres/ember_marsh.tres)
lowered by 2 to compensate for the larger reserved fork window, verified by
hand that board generation succeeds as reliably as before (was: sum-of-
minimums exactly filled the available slots at length 6 without this
adjustment, which would have made generation fall back to the fixed
no-fork board most of the time). STILL HUMAN RETEST REQUIRED — new build
`build/map3d_true_routing_finalcheck_v14_2026-09-08/`, not yet played by a
human. Do not mark MAP3D-HUMAN-004 CLOSED until that retest comes back.

Boss Victory black-screen bug (root cause: AshenBackdrop z-order, fixed in
`1629304`) — HUMAN-VERIFIED FIXED (2026-09-06 retest, "BLACK SCREEN: NO").
Not re-investigated this session; regression test
(`map3d_boss_result_visibility_test`) still green after the routing-depth
and visual-semantics changes.

New gameplay bug reported during the same retest: player HP showed 121
before combat, 100 at combat start. Audited exhaustively (full RunState ->
CombatActor pipeline trace, plus a real in-engine reproduction script) — the
pipeline itself is correct: a scripted repro setting `current_health=121,
max_health=140` immediately before `Combat.configure()` renders 121/140
correctly in both a normal run and the `--map3d-prototype` sandbox path, and
damage/heal applied in combat write back to `RunManager.current_run`
correctly. The exact "121 -> 100" sequence could not be reproduced with the
information available. One real, confirmed, adjacent defect was found and
fixed: `MapSandboxContext.create_run()` (used by every current playtest
build, since `--map3d-prototype` is the launcher's mode) set
`equipped_weapon_id`/`equipped_armor_id` as raw strings without ever calling
`RunState._apply_equipped_item()` — the sandbox's "equipped" weapon/armor
never actually contributed their `max_health_bonus`/`attack_bonus`/
`defense_bonus` for the whole session. Fixed to reuse the same helper real
runs use. Covered by a new regression test,
`tools/tests/combat_hp_continuity_test.gd` (non-default HP cases: 121/140,
73/100, 1/100, full HP, plus the sandbox-equipment-bonus case). If the
121->100 symptom still reproduces on the new build, it needs a precise
repro (seed, whether the prototype was restarted, what was picked on any
upgrade screen) to keep auditing — see HUMAN_PLAYTEST.md's HP section on the
new build.

Visual semantics (human UX observation, same retest): route A/B choice panel
was plain text only (no color/icon beyond the "A"/"B" letter) — now colored
by danger tier (`VisualTheme.difficulty_color`, same system used elsewhere)
with a focus icon (`combat`/`heal`/`treasure`/`route`, all pre-existing
`AshenIcon` ids). Shop equipment offers showed rarity as plain text with no
relation to the color/border/icon system already used in Equipment/
Inventory/Run Result — now reuses `VisualTheme.rarity_color`/
`rarity_card_style` directly. Map3D tile markers (per-type 3D shape/silhouette
in `map_tile_3d.gd`) were audited and found to already be well-differentiated
(distinct platform geometry + a distinct 3D detail mesh per tile type, not
color-only) — no change needed there.

Full audit trail, exact math for the branch-length/empty_min interaction,
and file:line citations for all of the above: see the implementation
session that produced commit(s) on `feature/map3d-true-routing` dated
2026-09-08, after `51b3013`.

UPDATE (2026-09-10, L0 CLOSURE):

TECHNICAL STATUS:
PASS

AUTOMATED/RENDER VALIDATION:
PASS — full regression subset (board_turn_contract_test,
board_generator_fork_test, board2d_true_routing_test,
board_presentations_contract_test, ashen_wastes_map_3d_test,
map3d_route_mouse_input_test, map3d_layout_test, map3d_long_session_test,
map3d_return_flow_test, map3d_complete_run_test, map3d_defeat_flow_test,
map3d_defeat_inside_branch_test, map3d_boss_result_visibility_test,
combat_hp_continuity_test, save_isolation_regression_test,
equipment2_phase1_test, stage78_economy_runtime_test,
combined_progression_runtime_test) re-run headless against commit `983a20d`
— 18/18 green, zero attributable regressions.

HUMAN VISUAL ACCEPTANCE:
DEFERRED UNTIL VISUAL VERTICAL SLICE. Product decision (2026-09-10):
prototype/placeholder graphics do not yet represent target presentation
closely enough for repeated subjective visual/feel playtesting to be worth
the cost. This does not weaken bug/regression/render-smoke requirements —
only subjective human "does it feel right" sign-off is deferred. The final
build under this branch (`build/map3d_true_routing_finalcheck_v14_2026-09-08/`)
was never human-played and MUST NOT be recorded as "HUMAN PASS".

MAP3D-HUMAN-004 (branch length / route feel):
Its underlying technical routing defect (deterministic A/B fork, D4-safe
BRANCH_LENGTH 6, mandatory fork interception, reconvergence, Boss excluded)
is solved and automated-test-covered. Remaining subjective branch
feel/presentation is explicitly deferred to the Visual Vertical Slice
milestone — do not classify it as human-approved.

KNOWN UX FEEDBACK (backlog, unchanged, still open):
MAP3D-HUMAN-005 (no clear final reward after boss) — DESIGN ISSUE /
CONTENT GAP, not addressed this session.

SAVE_VERSION: 14 (unchanged).

NEXT MILESTONE: Profile System (`feature/profile-system`, branched from
`main` after this merge) — see `docs/claude_context/ASHEN_REALM_DECISIONS.md`
for the approved design.

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
has grown to approximately 2360 lines
in the latest audit (2026-09-07).

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

Latest audit (2026-09-07) confirmed Biome Material
has NO shop purchase path at all: ShopOfferData.RewardType
has no biome-material entry. Materials are earned only via
run events and spent only in refinement. This is a CONTENT
GAP (no offer authored), not a partially-broken integration.

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