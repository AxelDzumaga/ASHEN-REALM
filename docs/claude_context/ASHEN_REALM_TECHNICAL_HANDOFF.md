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