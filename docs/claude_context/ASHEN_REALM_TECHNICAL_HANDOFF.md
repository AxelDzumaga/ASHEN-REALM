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

## PROFILE SYSTEM (character slots)

STATUS (2026-09-10, branch `feature/profile-system`):
IMPLEMENTED, TESTED, NOT MERGED. Local commits only, not pushed
(explicitly withheld pending a separate engineering report/review — see
`ASHEN_REALM_DECISIONS.md` workflow).

3 local character slots (`CharacterProfileRepository.MAX_CHARACTER_SLOTS`).
Name-only creation. `character_id` is generated
(`char_<unix_timestamp>_<random_hex>`), never derived from the display
name, never reused after deletion.

Domain layer:
`scripts/save/character_profile_repository.gd` (autoload
`CharacterProfileRepository`). Owns enumeration, slot-count
enforcement, id generation, index repair, legacy migration, safe
deletion. Does NOT reimplement ProfileData serialization — every
character profile read/write is still done by repointing
`SaveManager.save_path`/`.profile` and calling its existing
load_profile()/save_profile() (same TEMP→MAIN→BACKUP pipeline as
before, now also applying per-character since
`SaveManager._write_text_file()` now creates the parent directory
first, needed for the one-level-deeper character paths).

File layout:
`user://profiles/index.json` (cache/listing only — index_version,
per-character character_id/display_name/player_level/
selected_biome_id/last_played_at) +
`user://profiles/<character_id>/profile.json` (authoritative,
its own `.tmp`/`.bak`/`.corrupt.<timestamp>.json` siblings). Character
profile files are always authoritative: `list_characters()`/`refresh()`
rebuild from a directory scan every time and self-heal `index.json`
from it — a stale, missing, corrupt, or duplicate-referencing index
never loses or hides a valid character. A directory whose profile.json
(and .bak) are both unreadable is reported as a CORRUPT slot (still
occupies a cap slot, still deletable) rather than silently dropped, so
one corrupted character can never hide/damage its siblings.

`ProfileData` gained additive `character_id`/`display_name`/
`created_at`/`last_played_at` fields, safely defaulted for older
saves. SAVE_VERSION intentionally stayed at 14 — no migration was
required.

Legacy migration:
old `user://profile.json` → Slot 1 (`display_name` "Ashen Wanderer" if
it was empty). Interruption-safe: migration only ever runs while
neither `index.json` nor its backup exists AND a directory scan finds
zero valid characters — a crash after the character file was written
but before the index existed is recovered as "already migrated," never
duplicated. The legacy file is never deleted by this milestone.

Startup UX (`scripts/core/game.gd`, `scripts/ui/main_menu.gd`,
`scenes/lobby/character_select.tscn`, `scenes/lobby/character_create.tscn`):
Main Menu's primary button branches on character count — 0 → NUEVA
PARTIDA (opens character creation directly), 1 → CONTINUAR (selects
that character and enters the lobby directly, no selector), 2-3 →
SELECCIONAR PERSONAJE. `--map3d-prototype` and visual-slice debug
launch paths are untouched (still bypass this entirely, by design).
Deletion uses a two-step press-to-arm/press-to-confirm interaction as
an interim stand-in for hold-to-confirm (not built this milestone —
"do not build final art for it" was explicit in the approved design).

Test isolation: `SaveManager.use_isolated_test_profile()` is untouched
and still fully decoupled from the repository — synthetic test
profiles never need to register in `profiles/index.json`.
`CharacterProfileRepository.use_isolated_test_root(name)` is the
repository's own symmetric isolation entry point for tests that need
the domain layer itself, including a dedicated
`legacy_path_override` so migration tests can never accidentally read
a real developer's real `user://profile.json`.

Real bug caught during development (see commit `b4525f5`): the delete
confirmation's "arm" step called the same `_refresh()` used for a real
post-deletion rebuild, which unconditionally cleared the pending-delete
id — the first ELIMINAR press silently did nothing. Fixed; now has
explicit regression coverage. Caught by real-render smoke capture, not
by the logic-only test suite alone — a reminder that this class of "UI
state gets clobbered by its own redraw" bug does not show up in
headless dummy-renderer runs that never actually inspect button text.

Not built this milestone (explicitly out of scope, see approved
design): online login/account, cloud save. Active Run Persistence
(`active_run.json`) was a deliberately separate follow-up milestone —
see its own section below; it is now implemented, on its own branch,
not this one.

---

## ACTIVE RUN PERSISTENCE (expedition resume)

STATUS (2026-09-10, branch `feature/active-run-persistence`):
IMPLEMENTED, TESTED, NOT MERGED. Local commits only, not pushed.

Encounter Checkpoint Resume: APPROVED / IMPLEMENTED. Mid-combat exact
resume: NOT IMPLEMENTED (deliberately — see design rationale below).
Safe checkpoints: IMPLEMENTED. Reward deposit idempotency:
IMPLEMENTED. `ACTIVE_RUN_VERSION`: 1. `SAVE_VERSION`: 14 (unchanged).
Human visual playtest: NOT REQUIRED for this logic milestone, per the
same deferred-until-Visual-Vertical-Slice policy as Profile System.

File: `user://profiles/<character_id>/active_run.json` (+ `.tmp`/
`.bak`/`.corrupt.<timestamp>.json` siblings), one per character,
completely separate from `profile.json` — permanent progression and
an in-progress expedition never share a file or a write.

Domain layer: `scripts/save/active_run_repository.gd` (autoload
`ActiveRunRepository`). Every method takes `character_id` explicitly
(no cached "currently selected" state, unlike `CharacterProfileRepository`
which does cache it) — this was a deliberate choice to make
character-scoping trivially provable rather than trusted. Reuses
`AtomicJsonStore` (see below) for MAIN/TEMP/BACKUP safety, not a
second hand-rolled writer.

`scripts/save/atomic_json_store.gd` (new): the MAIN/TEMP/BACKUP write-
validate-rotate-promote algorithm `SaveManager` already had, extracted
as a domain-agnostic primitive. `SaveManager.load_profile()`/
`_write_profile_safely()` now delegate to it — proven behaviorally
identical by running the full pre-existing save/profile regression
suite unchanged afterward (13/13 green). One real parity bug was
caught and fixed during that extraction itself (see commit `bb0591c`):
the backup-restore path always reported the corrupt-MAIN flag as
cleared regardless of whether the physical restore actually succeeded.

`RunState` gained `run_id` (generated once per run in
`RunManager.start_new_run()`, `char_<timestamp>_<random_hex>`-style,
never regenerated by deserialization) and full `to_dictionary()`/
`from_dictionary()`. `RouteBranchData` also gained serialization, with
`from_dictionary()` rejecting any structurally invalid input outright
(wrong route length, tile type outside the valid enum, negative fork
index) rather than substituting a guessed default. The legacy dynamic-
fork fields (`route_choice_count`/`route_option_a`/`route_option_b`/
`chosen_destination`/`chosen_tile_type`/`route_choice_cooldown`) are
deliberately not serialized — confirmed dead, superseded by the
deterministic fork system. `biome_data` is re-derived from `biome_id`
on load (not JSON-safe, and a `biome_id` that no longer resolves is
handled as content drift, not a crash).

Checkpoint policy: SAFE CHECKPOINTS ONLY (never per animation frame,
never per combat action). `BoardTurnController` gained an optional
injected checkpoint `Callable`, fired at its own existing state-
machine transitions (fork reached, movement completed, route choice
committed, tile landing committed) — deliberately using plain string
phase literals rather than importing `ActiveRunRepository`, to keep
that presentation-independent domain controller decoupled from the
persistence autoload. `game.gd`/`run_result.gd` checkpoint at
encounter entry, each reward-mutation commit, and the terminal
pre-/post-deposit boundary.

Combat resume policy: **Encounter Checkpoint Resume**, not full
mid-combat state serialization — closing during a fight restarts that
same encounter from its pre-encounter checkpoint. This was not chosen
blindly: `combat.gd`'s own RNG (`_encounter_rng()`, `_enemy_ai_rng()`,
`_equipment_rng`) is already seeded from stable, already-persisted
RunState fields (`board_seed`, `board_position`, `combats_won`), so
restarting an encounter reproduces the identical roster and opening
crit sequence for free — no new combat-specific serialization needed
at all. This also means nothing about the upcoming `CombatTurnController`
extraction (see Party Combat Turn System design) needs to be revisited
because of this milestone.

Reward-deposit idempotency (P0 correctness): `ProfileData` gained
`last_deposited_run_id`, written in the SAME transaction as the reward
mutations it guards. `SaveManager.deposit_run()` refuses to re-apply
permanent rewards for a `run_id` that already matches it — this closes
the exact crash window the original design audit flagged (profile
saved successfully, then the process dies before `active_run.json` is
updated to reflect it).

Real bugs caught during development, both fixed at the source:
(1) the same delete-confirmation-shaped bug class as Profile System —
here, a resumed RunState sitting exactly on an unresolved FORK was
falling into `IDLE` instead of re-offering the A/B choice, meaning the
next roll would silently move past the fork without ever asking
again; fixed via `BoardTurnController._detect_resumed_fork_pause()`.
(2) the backup-restore parity bug in the `AtomicJsonStore` extraction,
above.

Test isolation: `ActiveRunRepository.use_isolated_test_root()`,
symmetric with `CharacterProfileRepository`'s own, fully decoupled
(each repository has its own default root constant; isolating one does
not require isolating the other unless a test specifically wants both
aligned).

Not built this milestone (explicitly out of scope, see approved
design): full mid-combat resume, an explicit `active_run_id` field on
`ProfileData` (the file's existence at a known path is sufficient
signal), automatic content-update compensation for a stale active run
beyond "fails safely, never touches the profile."

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

UPDATE (2026-09-10, Map3D Production Runtime):

FeatureFlags.USE_3D_BOARD = true.

Map3D is now the production default expedition presentation.
Board2D is retained temporarily as a debug/fallback and domain-parity
regression adapter (see BOARD2D below) — flip the constant to false
locally for Board2D triage; there is no user-facing selector.

show_board()'s selector now reads FeatureFlags.USE_3D_BOARD alone.
It previously also OR'd in an ephemeral --map3d-prototype session flag
(_map3d_prototype_mode), which show_main_menu()/show_lobby() silently
cleared on every menu transition — the exact, traced root cause of a
previously observed bug where a first expedition in Map3D, followed by
a defeat/Refuge/second-expedition sequence, silently fell back to
Board2D. Regression-locked by map3d_production_entry_test.gd
(second-expedition-after-defeat/victory both assert Map3D).

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

UPDATE (2026-09-10, MAP3D PRODUCTION RUNTIME):

Map3D is now the production expedition presentation
(FeatureFlags.USE_3D_BOARD = true). Normal flow: Main Menu -> selected
character -> Refuge -> Start Expedition -> Map3D -> encounters -> Map3D
-> Boss -> Results -> Refuge, with no --map3d-prototype launcher
involved. Active Run resume (CONTINUAR EXPEDICIÓN) dispatches into
Map3D the same way, via game.gd's existing presentation-neutral
_resume_active_run() — that dispatcher required no changes; it was
already presentation-neutral before this milestone.

PRODUCTION MAP3D vs MAP3D PROTOTYPE SANDBOX — now explicitly separated:
- Production Map3D always consumes RunManager.current_run, created via
  RunManager.start_new_run() (real character/profile loadout) or
  restored via ActiveRunRepository. AshenWastesMap3D._resolve_context()
  only falls back to MapSandboxContext when RunManager.has_active_run()
  is false (isolated tests/tools that instantiate the scene directly).
- --map3d-prototype (debug-build-only CLI launcher) remains QA/visual-
  iteration tooling — never a production entry path. It still bypasses
  CharacterProfileRepository/RunManager.start_new_run()/
  ActiveRunRepository (no character selected, no active-run checkpoint
  ever written — the checkpoint guard already no-ops on an empty
  selected_character_id).

P0 DATA-SAFETY FIX (this session): a defeat during --map3d-prototype
used to fall through to the real show_run_result(false) ->
SaveManager.deposit_run(), writing XP/Ash/equipment/milestones into
whichever profile SaveManager currently had loaded (victory already
avoided this via its own _show_map3d_prototype_result() screen; defeat
had no equivalent branch). Fixed in two layers: (1) _on_combat_lost()
now branches to _show_map3d_prototype_result(false) exactly like
victory when _map3d_prototype_mode is set; (2)
_launch_map3d_prototype() now isolates SaveManager itself
(SaveManager.use_isolated_test_profile(), the same primitive existing
runtime tests already rely on) before creating the sandbox run — this
closes the whole class of incidental writes at the source, not just
reward deposit. It also caught a second, independent leak the same
mechanism fixes: DiscoveryTracker.discover() (codex/bestiary entries)
writes to SaveManager.profile immediately on encountering an
enemy/boss, unconditionally, regardless of victory/defeat/deposit —
previously reached the real/currently-loaded profile from a prototype
combat encounter too. Regression-locked with a full permanent-
ProfileData snapshot (before/after, both outcomes) in
map3d_prototype_data_safety_test.gd.

BOARD2D LIFECYCLE: KEEP TEMPORARILY as a debug fallback (FeatureFlags
override) and domain-parity regression adapter
(board_presentations_contract_test.gd proves BoardTurnController stays
identical between Board2D and Map3D given the same seed). Removal
trigger: Map3D reaches real (non-headless) device/human validation
equivalent to what Board2D already has, AND the domain-parity
guarantee is preserved another way, AND product confirms no
accessibility/fallback need — not before.

DEVICE VALIDATION GATES (not yet performed, do not block this
milestone):
MAP3D-DEVICE-001 — real Android touch/raycast input validation.
MAP3D-DEVICE-002 — real Android GPU/node/draw-call profiling
(structural note: up to ~54 tiles are NOT multimesh-batched — each is
an independent StaticBody3D/MeshInstance3D pair with a unique
material, ~200-270 nodes and 100+ unique-material draw calls from
tiles alone at a full board+2-fork layout — terrain/connections ARE
already MultiMesh-batched).

HUMAN VISUAL ACCEPTANCE: DEFERRED (same 2026-09-10 product decision as
L0 — placeholder/prototype visuals do not yet represent target
presentation closely enough to be worth repeated subjective
playtesting). This is a runtime-architecture milestone, not a visual
one — see PHASE 21/27 audit notes: no new functional readability
blocker, only pre-existing visual debt (MAP3D-HUMAN-001/003/005),
explicitly out of scope here.

NEXT MILESTONE: Profile System and Active Run Persistence are both
merged to `main` as of this session. See
`docs/claude_context/ASHEN_REALM_DECISIONS.md` for design history.

---

## CORE LOOP / FINAL REWARD

STATUS (2026-09-10, branch `feature/core-loop-final-rewards`):
IMPLEMENTED, TESTED, NOT MERGED. Local commits only, not pushed.

EMBER MARSH GATE: `warden_defeated` (BOSS_DEFEATED, target
`ashen_warden`) — was `first_expedition` (TOTAL_RUNS, i.e. any
completed run including a defeat), a bug this milestone fixes.
`ember_marsh.tres`'s `required_milestone_id` is the single source of
truth; `BiomeCatalog.is_unlocked()` reads it, unchanged.

`first_expedition` (TOTAL_RUNS): generic "finished an expedition"
milestone — win or lose. Unchanged behavior, no longer a region gate.
`first_victory` (TOTAL_VICTORIES): generic "won an expedition"
milestone — any boss, not region-specific. Copy corrected this session
("Ganá una expedición por primera vez", previously implied a
region-completion meaning it never had in code). Neither is used as a
gate anywhere in the current 2-biome catalog; only a boss's own
BOSS_DEFEATED milestone is.

BIOME CLEAR: boss-defeat-derived, not a separate persisted bool — a
cleared biome remains fully replayable (no lockout, no redirect).
Verified live: `RunManager.start_new_run()` for an already-cleared
biome works identically to a fresh one.

DEFEAT REWARDS (unchanged from audit, confirmed intentional): partial
progression is always kept — accumulated run Ash, player/run XP
(`PlayerProgressionConfig.calculate_run_xp()` grants a flat baseline
even at zero combats won), biome materials, a (worse-odds) loot roll,
and non-victory milestones (`first_expedition`) all deposit normally
on defeat. Only boss-exclusive rewards (total_victories, boss_defeat
count, Boss Chest, Guardian Sigils, `BOSS_COMBAT_XP`, Boss Reward card
effects) require an actual win — enforced by the existing
`if run_state.run_completed: ... else: ...` branch in
`SaveManager.deposit_run()`, untouched by this milestone.

NEW-BIOME-UNLOCK TRACKING: `RunState.newly_unlocked_biome_ids` (new
field, included in `to_dictionary()`/`from_dictionary()` like every
other RunState field) — computed as a before/after diff of
`BiomeCatalog.is_unlocked()` across the exact same milestone-evaluation
call inside `SaveManager.deposit_run()`'s existing transaction, not a
second save and not a duplicated "unlocked" bool. Answers "did THIS
run unlock it", which a direct `is_unlocked()` re-check cannot (that
stays true on every later run too). RunResult announces it once
(`milestone_progress_label`, "NUEVA REGIÓN DESBLOQUEADA"); a second
Warden victory reports an empty list and shows nothing extra —
verified live via `core_loop_render_smoke.gd`.

RUNRESULT ACCOUNTING: Guardian Sigils and Boss Chest were already
displayed pre-session (folded into `boss_reward_label`, sourced from
`run.guardian_sigils_awarded`/`run.boss_chest_awarded`/
`run.boss_chest_id` — real transaction fields, not hardcoded); this
session added the explicit "DISPONIBLE PARA ABRIR EN EL REFUGIO" copy
so the chest's deferral reads as intentional, plus the new-biome-unlock
line. Boss Chest remains unopened at RunResult — opening stays a
separate Refuge/meta-progression action (`SaveManager.open_chest()`),
not auto-resolved here.

BOSS SET (`ashen_warden_set` = `wardens_edge` + `warden_plate`):
unchanged this session. Existing 35% soft-bias + missing-piece
preference in `ChestResolver._roll_item()` is now regression-locked
(`core_loop_boss_set_loot_test.gd`, seeded/deterministic). No hard pity
— explicitly deferred (BALANCE/TUNING debt, not Core Loop correctness).
`EquipmentData.boss_source_id` remains authored-but-unused — a content
seam for a future acquisition system, not touched this milestone.

FIRST-CLEAR REWARD: none added. The existing victory package (Boss
Reward choice + loot + Boss Chest + Guardian Sigils + XP/Ash +
milestones + next-biome unlock, now all correctly gated and
communicated) is the approved 1.0 package — this milestone fixed
gating and accounting, not reward quantity.

SIMULATOR PARITY: `tools/simulation/full_run_simulation.gd` still does
not call `deposit_run()`/`BoardTurnController`/`ActiveRunRepository` —
confirmed unchanged, intentionally out of scope (KNOWN DEBT, a future
Balance/Simulation milestone's concern).

FUNCTIONAL REWARD FLOW: COMPLETE (verified by automated tests +
non-headless real-render smoke). VISUAL/FEEL ACCEPTANCE: DEFERRED —
same Visual Vertical Slice policy as every prior milestone this
session; do not record "HUMAN PASS".

SAVE_VERSION: 14 (unchanged). ACTIVE_RUN_VERSION: 1 (unchanged) — the
new `RunState.newly_unlocked_biome_ids` field is additive and
defensively defaulted to `[]` by the existing `_read_string_name_array()`
reader on missing/older data, needing no version bump.

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
was approximately 2360 lines
in the 2026-09-07 audit.

Combat Domain M1 (2026-09-12):
STATUS: MERGED (main @ d306abb).

Turn authority:
CombatTurnController
(scripts/combat/combat_turn_controller.gd).
RefCounted, no _process(), no timers, no polling,
no UI/scene-node access. Pull-based: Combat2D
drives it by calling start()/complete_current_turn()/
stop(); round_started/team_block_started/
actor_turn_started/actor_turn_ended/
combat_sequence_stopped are observability signals only,
not the driving mechanism.

Round/team-block model:
ROUND -> PLAYER block -> ENEMY block -> next ROUND.
No round counter existed before M1 — round boundary was
implicit in combat.gd's while loop. Team blocks are
snapshotted (duplicated) from the SAME array references
combat.gd owns (player_actors / enemy_actors) at each
block start, matching the pre-M1 behavior where a boss
summon mid-round never acts before the following round.

Current runtime composition:
UNCHANGED — player + optional companion vs current
supported enemy count. No 5v5, no formation UI, no
summon/revive architecture changes.

Team defeat semantics:
CHANGED IN M2 — see the Combat Domain M2 block below.
As of M1 alone, defeat was still keyed specifically to
player_actor; M2 moved it to whole-Player-Team.

Cooldown semantics (bug found and fixed in M1):
Before M1, CombatSkillController.on_basic_attack_completed()
was the ONLY call site that decremented skill cooldowns,
and combat.gd only called it from the BASIC_ATTACK branch
of the player's action — never from ACTIVE_SKILL. A player
turn spent using a skill silently froze the cooldown of
every OTHER equipped skill.
FIX: CombatSkillController.advance_cooldowns(exclude) is
now the generic per-turn hook, called on every player turn
regardless of action chosen (BASIC_ATTACK: exclude=null;
ACTIVE_SKILL: exclude=the skill just used, so its own
freshly-set cooldown does not lose a tick the same turn
it activated). on_basic_attack_completed() still exists
unchanged (energy gain + calls advance_cooldowns()
internally) for backward compatibility with
tools/simulation/full_run_simulation.gd, an independent
balance-simulation tool intentionally left out of scope.
Regression test: tools/tests/combat_skill_cooldown_regression_test.gd.

Status/intent/energy/boss timing:
PRESERVED, unchanged call order and boundaries — only WHO
calls _process_actor_turn_start / _statuses.process_turn_end
/ _plan_all_enemy_intents changed (moved from a manual
while-loop + per-enemy for-loop into wrapper functions
driven by the controller), never WHEN relative to each
other. ashen_warden_phase3_curse_test produces
byte-identical output before/after M1 (same failures, same
JSON) — confirmed still PRE-EXISTING/UNRELATED, not an M1
regression.

Combat Events (structured DamageEvent/HealEvent/etc.):
NOT YET — M4 scope. M1 only added plain signals for
sequencing observability, not a domain event stream.

Domain/integration tests added in M1:
tools/tests/combat_turn_controller_test.gd (pure
controller unit tests, no Combat2D needed) and
tools/tests/combat_skill_cooldown_regression_test.gd.
Broader existing suite (enemy intent, HP continuity,
weak/resist, equipment, Map3D defeat/return/boss-result,
Active Run encounter resume, boss set loot, core loop
reward accounting) re-run against the new controller with
zero attributable regressions. Non-headless engineering
smoke (core_loop_render_smoke, real D3D12 renderer)
passed: defeat, boss victory with full reward accounting,
replay, and no duplicate unlock announcement all verified
end-to-end through the new turn controller.

Combat Domain M2 (2026-09-12):
STATUS: MERGED (main @ 835b6f3).

Controller ownership:
CombatActor.controller_type (PLAYER_CONTROLLED / AI_ALLY /
AI_ENEMY / SCRIPTED — SCRIPTED is an approved enum seed,
nothing uses it), assigned once at construction
(from_player/from_companion/from_enemy), separate from
Team (which side) and ActorType (what the actor is
narratively/mechanically). Transient only, never
serialized. combat.gd's main dispatch loop now matches on
controller_type instead of comparing acting_actor's
identity against the player_actor/companion_actor
scalars — this is what lets a KO'd protagonist stop
blocking the round without the dispatch needing to know
"who the protagonist is."

Team model:
Array[CombatActor] player_actors / enemy_actors remain the
team representation (no CombatTeam wrapper object — no
evidence of team-level metadata justified one).
CombatTeamUtils (scripts/combat/combat_team_utils.gd) is
the single definition of living_actors() / has_living_actor()
/ is_defeated() for either team, replacing three
near-duplicate loops that used to live in combat.gd
(two of which subtly differed: is_targetable() vs
is_alive() — behaviorally identical today, since
CombatActor.targetable only ever turns off together with
is_alive(), never back on).

Defeat semantics (approved gameplay change):
OLD: protagonist HP <= 0 -> immediate defeat, regardless
of companion state.
NEW: Player Team defeat only when CombatTeamUtils.
has_living_actor(player_actors) is false. Protagonist KO
with a living ally no longer ends combat — the ally keeps
acting automatically (CombatTurnController already skipped
dead actors before M2; only combat.gd's termination POLICY
changed, not the controller). All 4 real _finish_defeat()
call sites in combat.gd were switched to this one check
(_wait_for_player_action, two sites in _run_enemy_turn,
_resolve_warden_counter/Warden's Rebuke). A downed-but-
team-alive protagonist gets a new _present_player_down()
presentation (mirrors _present_companion_death()) instead
of the old immediate _finish_defeat() call; is_alive()/
is_targetable() already exclude it from being targeted
again with zero new code.

Anti-softlock HP normalization:
If the Player Team wins a combat while the protagonist is
at 0 HP (an ally landed the final blow), _finish_victory()
sets it to exactly 1 HP via the existing authoritative
CombatActor.set_current_hp() setter (which already writes
through to RunState.current_health live) before the run
returns to Map3D. Never full HP, never a percentage, and
never touched at all if the protagonist's HP was already
> 0 at victory, or on an actual defeat (full team wipe —
that code path never calls this). No new Active Run field:
the existing post-combat checkpoint just persists whatever
current_health already is.

Companion HP persistence:
STILL NONE — unchanged, explicitly out of scope for M2.
Companion always starts a combat at full HP
(CombatActor.from_companion), same as before M1/M2.

CombatSkillController / combat energy:
STILL protagonist-singular — approved debt, not touched in
M2. No per-actor skill controllers, no team energy pool.
Documented explicitly so a future second PLAYER_CONTROLLED
hero doesn't get built without first generalizing this.

Formation order:
CombatTurnController still orders by array insertion order,
not formation_slot — unchanged from M1, no evidence
justified changing it in M2.

Dormant TargetTypes:
RESOLVED IN M3 — see the Combat Domain M3 block below. As
of M2 alone, only SELF/SINGLE_ENEMY were implemented; the
other three silently no-op'd.

Tests added in M2:
tools/tests/combat_actor_controller_type_test.gd
(constructor -> controller_type mapping, no scene),
tools/tests/combat_team_utils_test.gd (living/dead/mixed/
empty/null-actor teams, no scene), and
tools/tests/combat_team_defeat_test.gd (real Combat2D:
companion-dies-combat-continues, protagonist-KO-ally-
continues with no deadlock and a disabled action bar,
ally-saved victory normalizing to 1 HP with RunState
agreement, full-team-death defeat with NO normalization,
no-companion defeat, HP-unchanged on a normal victory, and
Warden's Rebuke killing the protagonist with a living ally
not ending combat). All existing M1 tests + a broad
existing regression set re-run with zero attributable
failures; non-headless real-D3D12-renderer validation
passed for both the new team-defeat scenarios and the
existing Map3D return-flow smoke.

Combat Domain M3 (2026-09-12):
STATUS: IMPLEMENTED AND MERGED (main @ 19c6ca0).

No generic ActionIntent class:
deliberately not introduced. The repository's existing
convention (small nested plain-data classes — Decision,
ActionPlan, TickResult, TransitionResult) already covered
everything needed; CombatTargetResolver.Resolution follows
the same pattern rather than adding a new architectural
style.

CombatTargetResolver
(scripts/combat/combat_target_resolver.gd, static,
presentation-independent): the single place all 5
ActiveSkillData.TargetType values resolve to
Array[CombatActor]. Team authority is player_actors/
enemy_actors (or the caller's own ally_team/enemy_team
arrays), never ActorType — COMPANION+PLAYER are one team,
BOSS+MINION are the other, matching M2. Dead actors are
invalid for every TargetType (no revive exists). No
automatic ally selection: SINGLE_ALLY with no
explicit_target returns TARGET_SELECTION_REQUIRED rather
than guessing "the first living ally" — Combat2D has no
ally-selection UI yet, so this is the honest answer, not a
bug. SINGLE_ENEMY preserves current behavior exactly:
Combat2D still decides the currently-selected enemy before
calling in; the resolver only validates it.

Player action flow (before -> after):
Before: _on_attack_pressed/_on_skill_requested picked a
target inline (a match statement, SELF/SINGLE_ENEMY only,
silent return for the other three), then _commit_player_action
carried a single CombatActor all the way to
_run_player_basic_action/_execute_active_skill.
After: both entry points resolve through
_resolve_player_target() (wrapping CombatTargetResolver)
BEFORE any cost/cooldown mutation — target validity is
established first, matching AI's existing DECIDE-then-
RESOLVE shape. _committed_targets (Array[CombatActor]) is
the real multi-target field; _committed_target_actor
remains targets[0] as a compatibility alias so the ~15
existing single-target call sites (telemetry,
_run_player_basic_action, _execute_active_skill) needed
zero changes. _execute_active_skill() itself — the
single-target SELF/SINGLE_ENEMY path, 100% of currently
authored content — was not touched at all; byte-identical
behavior confirmed by ashen_warden_phase3_curse_test
staying byte-for-byte identical to the M1/M2 baseline.

No silent retarget:
_run_player_basic_action's old "if the committed target
died, silently attack whichever enemy refresh_primary_enemy_actor()
finds instead" fallback is removed. This path was already
unreachable in practice (no await exists between target
validation in _on_attack_pressed and this call, so nothing
can invalidate the target in between) — the change is
forward-looking correctness, not a behavior fix for a real
bug, verified by a direct test that deliberately passes a
foreign actor to prove the attack fizzles (zero mutation)
instead of silently retargeting.

Multi-target effect application:
_execute_active_skill_multi_target() (new, additive — does
not replace or alter _execute_active_skill) applies the
existing single-target mechanic (calculate_skill_damage /
CombatActor.heal / apply_status "guard") once per resolved
living target, for DAMAGE/HEAL/DEFENSE skill_types. No new
skill semantics invented for any skill_type x TargetType
combination — this is the same mechanic each type already
had, generalized to N targets. Cost/cooldown are paid
exactly once per cast regardless of target count (they're
committed in _on_skill_requested, before this function ever
runs). No authored skill uses ALL_ENEMIES/ALL_ALLIES/
SINGLE_ALLY — this path is exercised only by synthetic test
fixtures (ActiveSkillData.new() built in test code), never
by real loadouts.

Critical hits:
Confirmed EquipmentEffectResolver.roll_critical()/
apply_critical_damage() were the sole (and already correct)
crit mechanism; no formula changed. Added the crit
regression coverage that was missing (deterministic via
forced equipment_crit_chance, not RNG-dependent).

CombatMath / protagonist-only layers:
Unchanged. CombatMath.calculate_damage() remains the one
authoritative base formula for every damage source. Boons/
Equipment/Synergy remain applied only to the protagonist's
own basic-attack/skill damage (they modify the CASTER's
effective stats, never applied as a bonus to companion/
enemy targets) — M3 did not generalize or duplicate these.

Boss / Warden's Rebuke:
Untouched in M3 — _resolve_warden_counter, BossEncounterController,
BossRuntimeState, summon, and phase transitions were not
modified. Regression-verified via combat_team_defeat_test's
existing Warden's Rebuke case (still green).

Turn/terminal boundaries:
Unchanged. _execute_active_skill_multi_target calls
_finish_victory()/complete_current_turn() at exactly the
same call sites and under the same conditions the existing
single-target path already used — no second victory/defeat
authority, no resolver-owned turn advancement.

Tests added in M3:
tools/tests/combat_target_resolver_test.gd (24 checks, no
scene: SELF, SINGLE_ENEMY/SINGLE_ALLY valid/wrong-team/dead/
missing-selection, ALL_ENEMIES/ALL_ALLIES multiple/dead-
excluded/no-living-targets) and
tools/tests/combat_action_atomicity_test.gd (real Combat2D:
crit unit checks, insufficient-energy and on-cooldown zero-
mutation, successful-skill cost/cooldown/effect-exactly-once,
multi-target damage-each-once-with-dead-excluded, one-cast-
one-cost-one-cooldown for a 3-target nuke, forced-crit basic
attack damage match, and the no-silent-retarget stale-target
case). Full M1/M2 regression suite + non-headless real-
D3D12-renderer validation (including the full Map3D core-loop
smoke) re-run with zero attributable failures;
ashen_warden_phase3_curse_test stayed byte-identical to the
established baseline.

Combat Domain M4 (2026-09-13):
STATUS: IMPLEMENTED AND MERGED (main @ 68a3936).

CombatEventStream
(scripts/combat/combat_event_stream.gd, one instance per
encounter, same lifecycle as CombatTurnController — created
and connected in _run_combat()): the single place Combat2D
reports "what happened" as a presentation-independent record.
signal event_emitted(event: RefCounted) is emitted
synchronously — connected handlers run in the same call stack/
frame as the emitting code, so this is not an async
sequencing mechanism. No history is retained: the stream has
no events array, no getter for past events — a future combat
log would be its own consumer with its own bounded buffer.
next_action_id() returns a per-encounter monotonically
increasing int starting at 1; NO_ACTION_ID=0 is the sentinel
used by effects with no causing action (status ticks, a boss
phase transition detected outside of a player/enemy action).

8 event types (scripts/combat/events/, all RefCounted, no
methods besides _init, no Control/Node2D/Node3D/
CombatCharacterView/scene/animation/audio references —
CombatActor is domain identity, not presentation): ActionEvent
(source_actor, action_kind, action_data_id, targets — a
duplicate()'d snapshot, never the live array), DamageEvent
(authoritative already-applied amount + hp_before/hp_after,
is_critical, affinity_relation, and a caused_death field
computed once in _init from hp_before>0 and hp_after<=0 —
never recalculates the damage formula), HealEvent
(requested_amount vs. actual_amount — actual is always the
post-clamp/post-Decay applied amount, never the theoretical
ask), StatusEvent (one class for both APPLIED and TICK,
distinguished by a Kind enum, since both share the same
shape), ReactionEvent, DeathEvent (source_actor nullable —
null when the domain cannot prove a cause, e.g. an unattributed
tick), BossPhaseEvent, and SummonEvent (summoned_actors also a
duplicate()'d snapshot).

DeathEvent uniqueness:
deliberately NOT based on the death_presented flag (that flag
remains exclusively Combat2D's presentation/animation
idempotency mechanism, unchanged by M4). Detection is the
hp_before>0 && hp_after<=0 transition, computed inside
DamageEvent itself (caused_death) and checked by a shared
_emit_damage() helper that also emits the paired DeathEvent
when true. This naturally handles a same-action second hit on
an already-dead target (e.g. Burning Strike's bonus hit after
a killing main hit): hp_before is already 0 for that second
hit, so caused_death correctly stays false — verified by
combat_event_order_test's
_test_death_event_no_duplicate_on_burning_strike_overkill.

Reaction detection (WET+CHILLED bonus stacks, WET+SHOCK single-
jump chain):
CombatStatusController gained a LastReactionInfo nested class
and a `last_reaction` field — the same "last outcome" query
pattern the repository already used elsewhere (
ActiveSkillController.last_guard_reduction,
BoonController.was_inferno_triggered()). apply_status()/
_chain_shock() populate it at the exact two points they
already detected these reactions; no new detection logic, no
parallel reaction system, no change to reaction rules, stacks,
damage, duration, or RNG. _chain_shock() deliberately
overwrites last_reaction AFTER its own recursive apply_status()
call returns, so the outer caller sees the chain-jump fact
rather than the inner recursive call's own reset.

action_id / causal grouping:
one action_id per resolved player/companion/enemy action,
generated once and threaded through every effect event that
action produces (main hit, equipment statuses, Burning Strike
bonus hit, its own burn application, boss-phase-transition
event) — verified end-to-end for the basic attack + Burning
Strike sequence, and for a synthetic ALL_ENEMIES multi-target
skill (1 ActionEvent + N DamageEvent sharing one action_id, no
target hit twice, stable order matching input order).

Warden's Rebuke gets its OWN new action_id:
_resolve_warden_counter() calls
_event_stream.next_action_id() itself rather than reusing the
triggering basic attack's — it is a causally distinct action
(the boss responding), not a side effect of the player's
attack. Verified by combat_event_order_test's
_test_warden_counter_own_action_id (two ActionEvents, two
different action_ids, correct action_kind on each).

No terminal/lifecycle duplication (explicit user override of
this feature's original audit, which had proposed reusing
death_presented and considered Victory/Defeat events):
round_started/team_block_started/actor_turn_started/
actor_turn_ended/combat_sequence_stopped remain
CombatTurnController's alone — never re-emitted as a
CombatEvent. combat_won/combat_lost and the RunResult/reward
pipeline remain the only terminal authority — there is no
VictoryEvent or DefeatEvent, and CombatEventStream cannot
trigger either path (it holds no reference to
CombatTurnController and never calls
_finish_victory()/_finish_defeat()). No EnergyChangedEvent or
CooldownChangedEvent were added. Rejected/invalid actions
(insufficient energy, on cooldown, invalid target) emit
nothing — M3's commit-before-resolution ordering already
guarantees _execute_active_skill()/_execute_active_skill_multi_target()/
_run_player_basic_action() are only reached after a successful
try_use()/target validation, so there was no separate gate to
add. An AI turn with no valid target (already an early return
in _run_enemy_turn before M4) does not emit an
ActionSkippedEvent — no such event type exists.

Presentation adapter — deliberately minimal:
Combat2D connects exactly one handler, _on_combat_event(),
which reacts only to StatusEvent(kind=TICK) to draw that tick's
floating damage/heal number — the one inline
vfx.show_damage_number() call this replaced had no await
before or after it and no interleaved branches, making it the
one safe call site to move behind a signal listener without
inverting choreography order. The handler itself contains no
await. Every other animation/impact/choreography call
(approach, impact_and_return, play_attack/play_hit/play_idle,
AudioManager.play_event, death presentation) remains exactly
where it already lived in combat.gd — CombatTurnController's
progression and Combat2D's existing awaited choreography were
not restructured behind CombatEventStream.

Tests added in M4:
tools/tests/combat_event_stream_test.gd (43 checks, no scene:
CombatEventStream action_id monotonicity/NO_ACTION_ID/no-
history, field-correctness construction tests for all 8 event
types including ActionEvent/SummonEvent snapshot-not-reference
and DamageEvent caused_death transition/no-duplicate-on-corpse,
and a reaction regression suite exercising
CombatStatusController.apply_status()/_chain_shock() directly
for WET+CHILLED and WET+SHOCK) and
tools/tests/combat_event_order_test.gd (66 checks, real
Combat2D: basic attack action/damage grouping, forced-crit
flag, affinity relation via a real weak-tagged fixture,
Burning Strike's full 4-event sequence sharing one action_id,
overkill no-duplicate-death, a synthetic ALL_ENEMIES multi-
target grouping, status-tick and status-tick-death events,
companion-turn and enemy-turn action_id sharing driven through
a real round via _on_attack_pressed(), Warden's Rebuke's
separate action_id, a real boss's (Sunken Pyre / Ember Marsh)
phase transition and its Ember Spawn summon using real catalog
data rather than synthetic fixtures, and a final sweep
asserting every event captured across the whole file is one of
the 8 authorized types). Full M1/M2/M3 regression suite
(combat_turn_controller_test, combat_skill_cooldown_regression_test,
combat_actor_controller_type_test, combat_team_utils_test,
combat_team_defeat_test, combat_target_resolver_test,
combat_action_atomicity_test, enemy_intent_runtime_test,
combat_hp_continuity_test, weak_resist_verification,
map3d_production_return_flow_test,
active_run_checkpoint_wiring_test,
active_run_encounter_snapshot_test) re-run sequentially with
zero attributable failures. ashen_warden_phase3_curse_test's
two pre-existing basic-attack-observation failures were
confirmed present BYTE-FOR-BYTE IDENTICAL on the pre-M4
baseline (verified by temporarily stashing the M4 diff and
re-running the same seed) — not a regression introduced by
this milestone.

Combat Domain M5 (2026-09-13):
STATUS: IMPLEMENTED, LOCAL ONLY, NOT MERGED
(branch feature/combat-domain-m5).

Capability definition (explicit product/architecture decision):
M5 means the combat RUNTIME/DOMAIN can correctly schedule and
resolve up to 5 actors per team. It does NOT mean production
can field 5 heroes, does NOT add persistent multi-ally roster
state, and does NOT add multiple PLAYER_CONTROLLED heroes.
Production composition is unchanged: 1 protagonist + 0-1
equipped companion. Capacity is proven with synthetic
CompanionData/CombatActor fixtures constructed by tests, never
by authoring new production content.

CombatRules (scripts/combat/combat_rules.gd, new):
the single canonical authority for combat-domain product
limits, deliberately separate from CombatTeamUtils (which
stays scoped to team OPERATIONS — living_actors/
has_living_actor/is_defeated/validate_team — not limits).
MAX_TEAM_SIZE: int = 5 lives here. Content-schema
@export_range annotations (EncounterTemplateData.slots,
BossEncounterData.max_active_enemies) cannot reference this
constant directly — GDScript requires literal compile-time
values in @export_range arguments — so those annotations carry
a literal 5 documented as a manual mirror; every runtime check
(is_eligible(), _is_fair(), summon capacity) reads
CombatRules.MAX_TEAM_SIZE instead of its own literal.
CombatRules.find_available_formation_slots(occupied, count) is
the generic formation-slot allocator that replaced the old
hardcoded available_slots = [0, 2] in boss summon placement —
deterministic ascending free-slot order, never duplicates,
never exceeds 0..MAX_TEAM_SIZE-1, never returns more than
`count` entries.

Enemy capacity raised to 5, one authority: Combat2D.MAX_ENEMY_ACTORS,
EncounterTemplateData.slots' range/is_eligible() check, and
EncounterResolver.MAX_ENEMIES were three independent literal
3's before M5 — now all three derive from
CombatRules.MAX_TEAM_SIZE. BossEncounterData.max_active_enemies'
range widened to (1,5) but its DEFAULT stays 3 — no authored
boss's behavior changes unless a future/test boss explicitly
asks for more. EnemyCombatSlot/EnemyFormation already had the
right per-actor dynamic-container shape (unlike the player
side) — raising the cap was a small, contained change with no
new node types.

Boss summon at team cap: summon_total is now clamped with
maxi(0, ...) against min(boss's own max_active_enemies,
CombatRules.MAX_TEAM_SIZE) minus current Enemy Team size. When
that's 0, _run_boss_summon_action() returns having emitted
NO ActionEvent and NO SummonEvent (M4 rule: events describe
what actually happened — nothing happened here) and without
running the summon choreography; mark_summon_completed() and
ai_state.record_action() still fire so the boss doesn't retry
the same blocked summon forever (no AI-policy redesign, just
preserving the existing no-turn-deadlock guarantee).

Player Team construction generalized: _initialize_actors()
used to hand-build exactly player_actor + an optional single
companion_actor. It now calls _build_ai_allies(_resolve_ally_data_list()),
where _resolve_ally_data_list() returns production's existing
0-or-1-CompanionData behavior unless a new test seam,
_ally_data_override: Array[CompanionData], has been populated
(a fixture can assign up to CombatRules.MAX_TEAM_SIZE - 1
synthetic CompanionData before the combat scene's _ready() runs).
_build_ai_allies() constructs one CombatActor per entry with an
indexed id ("companion_0".."companion_3", replacing the old
literal "companion_0"), formation_slot ally_index+1, and its
own CompanionRuntimeState. companion_actor is kept as a
compatibility alias pointing at the FIRST ally only (index 0) —
it's still the sole actor the legacy single-companion HUD
(companion_panel/companion_view) presents; index 0 is also the
only ally that receives set_visual_view(companion_view). No
companion_actor_2/3/4 aliases were added.

Per-ally runtime state: the old singular _companion_runtime
field is now _companion_runtimes: Dictionary[StringName, CompanionRuntimeState],
keyed by actor_id. CompanionActionResolver was not changed —
it already took runtime_state as an explicit parameter; only
the caller-side lookup changed. Verified end-to-end (not just
by inspection): two synthetic allies with independent
ability_every_actions cadences each end a real round with their
own actions_completed incremented exactly once, never leaking
into each other.

Death-presentation bug found AND fixed (not left as documented
debt): _present_companion_death()/_present_player_down() were
two nearly-identical scalar functions; the real call site
(_run_enemy_turn) chose between them with
`target_actor == companion_actor ? companion : protagonist`,
correct only while Player Team had at most 2 possible members.
With a 3rd+ AI_ALLY, that `else` branch would have marked
death_presented on the STILL-ALIVE PROTAGONIST and animated the
protagonist's own view — silently suppressing the protagonist's
real death presentation later in the same combat, and never
presenting the ally's actual death. Merged into one function,
_present_player_team_actor_down(actor: CombatActor), which
operates only on the actor passed in — no comparison against
any reference actor anywhere. Regression-locked by a direct
test: killing a 3rd ally sets only that ally's death_presented;
the protagonist's own subsequent death still presents normally.

No-view actor safety: a 2nd-5th synthetic AI_ALLY has no
dedicated CombatCharacterView (that HUD work is explicitly M6,
not M5) — direct CombatCharacterView method calls inside
_run_companion_turn (play_attack/play_idle) are now guarded
with is_instance_valid(); CombatChoreographyController's
approach()/begin_static()/finish_static()/impact_and_return()
and CombatVFXController's status_tick()/show_damage_number()
were already null-safe internally. Domain resolution (damage,
statuses, events, HP, turn advancement) proceeds identically
whether or not the acting actor has a view — verified by a real
Combat2D round with 4 viewless synthetic allies completing with
zero crashes, headless and non-headless.

Team composition validation (new, minimal — not a validation
framework): CombatTeamUtils.validate_team(team, expected_team)
returns a ValidationResult (valid: bool, errors: Array[String])
checking team size vs. MAX_TEAM_SIZE, null actors, duplicate
actor_id, duplicate/out-of-range formation_slot, and
actor.team mismatch. Wired as a non-blocking push_error() safety
net in combat.gd right after boss-encounter setup — a legitimate
1-protagonist+companion-vs-N-enemies composition never triggers
it (confirmed by the full regression suite running with zero
new push_error output); it exists for "programmer corruption",
not expected content mistakes, so it observes rather than blocks.

Turn order: UNCHANGED, explicit decision — array insertion
order remains authoritative. CombatTurnController itself was
NOT touched at all in M5 (confirmed by a zero-diff check against
the M4 baseline) and still has no knowledge of MAX_TEAM_SIZE or
formation_slot — it was already fully N-actor-generic since M1.
formation_slot's only role is placement/allocation (boss summon,
enemy formation display), never turn sequencing.

Multiple PLAYER_CONTROLLED heroes: explicitly deferred, not
supported. CombatSkillController/combat energy/the action bar
remain protagonist-singular by design — untouched in M5.

Tests added in M5: combat_rules_test.gd (9 checks, no scene:
MAX_TEAM_SIZE, find_available_formation_slots() determinism/
no-duplicates/no-overflow/under-capacity behavior),
combat_team_composition_validation_test.gd (10 checks, no
scene: validate_team()'s size/null/duplicate-id/duplicate-slot/
out-of-range-slot/wrong-team-enum rejections), and
combat_5v5_capacity_test.gd (46 checks, real Combat2D via the
new _ally_data_override seam plus synthetic enemy actors: exact
5v5 turn order across one full round, a synthetic 5-target
ALL_ENEMIES multi-target cast with one cost/cooldown and M4's
1-ActionEvent-plus-5-DamageEvent grouping, companion-runtime
cadence isolation between two real allies, the death-presentation
routing regression, a real boss (Sunken Pyre/Ember Marsh) hitting
its 5-actor cap and cleanly declining a 6th summon with no
fabricated events, 5-actor team-defeat/victory boundary checks
on both sides, and a full-round no-crash sanity pass). Full
M1-M4 regression suite re-run sequentially with zero
attributable failures; the two pre-existing baseline issues
(ashen_warden_phase3_curse_test's basic-attack-observation gaps,
combined_refuge_runtime_test's headless screenshot capture) were
confirmed unchanged. Non-headless real-D3D12-renderer runs of
both combat_5v5_capacity_test.gd and the existing 1-protagonist-
plus-companion combat_team_defeat_test.gd passed identically to
headless.

Not touched in M5: CombatTurnController, CombatTargetResolver,
CombatEventStream and the 8 M4 event types (no schema change —
Array[CombatActor] fields were already unbounded), RunState,
SAVE_VERSION (14), ACTIVE_RUN_VERSION (1), and
tools/simulation/full_run_simulation.gd. The simulator remains
its own independent, hand-rolled Dictionary-based reimplementation
with a singular player/companion model — it does not use
CombatTurnController/CombatTeamUtils/CombatTargetResolver/
CombatEventStream at all, so M5's N-actor domain work neither
fixes nor worsens that pre-existing divergence. Alignment is
recommended only after M5 and M6 stabilize the production
N-actor path, as its own scoped effort — not attempted here.

This remains the largest architectural risk
for future Combat3D — M1/M2/M3/M4/M5 are extraction,
generalization, action-resolution, event-reporting, and
capacity-scaling work only; M6 (final Combat2D adapter cleanup,
including a real dynamic Player Team HUD for 3-5 actors) is
still ahead of Combat3D.

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