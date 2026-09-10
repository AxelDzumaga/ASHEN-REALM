# ASHEN REALM — LOGIC COMPLETION AUDIT
Date: 2026-09-07
Scope: read-only audit per docs/claude_context/ protocol. No code changed.

---

## 1. EXECUTIVE SUMMARY

**Current approximate logic completion: ~76%**

Basis: of the ~30 domains inventoried in Phase 1, roughly 21 meet the LOGIC COMPLETE bar (domain model + runtime flow + integration + invalid-state handling + persistence + tests, remaining work is content/balance/presentation only), 6 are PARTIAL (a working core with one concrete, nameable gap), and 3 carry unresolved architecture/design gates that block the next tier of scope (party combat, active-run persistence, region-completion semantics). Two P0 bugs exist, both small and fully diagnosed.

The project is meaningfully further along than the 2026-09-04 Technical Handoff snapshot implies. Systems the handoff flags as risk (skills, status, affinities-as-mechanic, enemy AI, boss reusability, economy transaction safety, save integrity, telemetry hygiene, events, regions-as-data, tutorial) are independently confirmed COMPLETE by this audit. The real remaining work concentrates in three places:

1. **Combat's presentation/domain coupling and single-actor assumptions** — `combat.gd` is 2,360 lines (up from the 2,148 cited in the handoff — the risk was understated, not overstated), and the player side of combat is still hard-singular (`player_actor` + one `companion_actor`) while the enemy side is already array-based. This is the real 5v5 blocker, more than raw line count.
2. **Four design decisions genuinely require your approval before more architecture work** (Section 34) — turn order for party combat, region-completion semantics, active-run persistence scope, and whether the Map3D "prototype/sandbox" victory path is player-facing or dev-only scaffolding.
3. **Two P0 bugs**, both cheap, no-design-decision fixes (Section 29).

This branch (`feature/map3d-true-routing`) has **not** been human-playtested — both post-baseline playtest report templates are blank stubs. Per protocol it stays **HUMAN PLAYTEST PENDING**; this audit does not merge, close, or advance that status.

---

## 2. CURRENT GIT STATE

- Branch: `feature/map3d-true-routing`. Working tree clean.
- 6 commits ahead of `origin/main`/`main` (both at `0bc1e3a`): `ea6b413` (deterministic route branch domain) → `2cce67d` (mandatory fork interception) → `174f69c` (render true branches in board presentations) → `8e11125` (deterministic branch routing tests) → `1629304` (fix: keep AshenBackdrop behind screen content — the black-screen-after-boss-victory fix) → `f635753` (UID sidecar for boss result visibility test).
- Diff vs `main`: 30 files, +1317/-339 — `scripts/board/*`, `scripts/board3d/*`, `scripts/core/{game.gd,run_state.gd}`, plus 6 new/expanded files under `tools/tests/`.
- Two post-baseline playtest report files exist and are **both unfilled blank templates**: `build/map3d_true_routing_v14_2026-09-06/HUMAN_PLAYTEST.md` (routing feel) and `build/map3d_true_routing_bossfix_v14_2026-09-06/HUMAN_PLAYTEST.md` (black-screen retest). No DATE/TESTER/answers recorded.
- **Conclusion: MAP3D-HUMAN-004 (route differentiation) and the black-screen fix are HUMAN PLAYTEST PENDING, not passed.** Do not merge. This audit proceeded read-only, as instructed.

---

## 3. CORE LOOP STATUS

| Transition | Status | Evidence |
|---|---|---|
| Boot → Lobby | PASS | `game.gd:333-365` |
| Lobby → start run → Board | PASS | `game.gd:672-675`, `run_manager.gd:6-47 start_new_run()` |
| Roll → move → land → resolve | PASS | `board_turn_controller.gd:59-146` |
| Route fork → A/B choice → divergent content | PASS (new this branch) | `route_branch_data.gd`, `board_generator.gd` (+147 lines), `board_turn_controller.gd:93-101` — real pre-generated branch archetypes (combat/recovery/treasure/balanced), replacing the old probabilistic `route_choice_resolver.gd` (its own maintainer comment at `:9-14` confirms it's retired from production) |
| Combat/Event/Treasure → back to Board | PASS | `game.gd:678-745`, signal-wired via `_connect_board_screen` |
| Boss victory → Boss Reward (applied exactly once) | PASS | `game.gd:681-685`, `boss_reward_screen.gd:62-78` guarded by `boss_reward_applied` |
| Boss Reward → Run Result → deposit → Lobby | PASS | `run_result.gd:51` — `if not RunManager.current_run.rewards_deposited and not SaveManager.deposit_run(...)`; idempotent |
| Defeat → terminate → Run Result (defeat) → Lobby | PASS | `game.gd:716-723` guarded by `_run_terminal_transition_started`; confirmed by `map3d_defeat_flow_test.gd`, `map3d_defeat_inside_branch_test.gd` |
| **Map3D prototype/sandbox victory → reward** | **PLACEHOLDER, not broken** | `game.gd:747-784` — literally titled "PROTOTIPO COMPLETADO" / "No se depositaron recompensas ni se modificó el perfil". Entered only via the dedicated `_launch_map3d_prototype()` playtest-build path (`game.gd:452-458`), never the mainline flow. |

**Final-reward pipeline: a real, safe system already exists in the mainline flow** — idempotent, double-claim-proof, defeat-proof. This predates the current branch and is stronger than the docs credit it for.

**MAP3D-HUMAN-005 root cause identified**: it is not that "reward logic is missing" — it's that the **Map3D sandbox/prototype victory path never calls the real deposit pipeline** (`SaveManager.deposit_run`) at all, by design, because it's a technical routing sandbox. The 2026-09-06 human playtest evidently exercised this sandbox path, not the mainline Board2D reward flow. This is a **P1 integration gap** (wire prototype mode into the real pipeline, or explicitly exclude prototype mode from future human playtests) — not a P0 architecture gap, and not evidence the reward *system* itself needs to be built. See Design Decision #4 (Section 34).

---

## 4. COMBAT DOMAIN

`scripts/combat/` = 29 files, ~6,297 lines total. `combat.gd` itself: **2,360 lines**, `extends Control`. No `CombatV2` duplicate exists — single implementation, consistent with the no-rewrite rule.

Real decomposition already exists outside `combat.gd`: `combat_actor.gd` (213L), `affinity_resolver.gd` (68L), `combat_status_controller.gd` (208L), `boss_encounter_controller.gd` (124L), `enemy_ai_runtime_state.gd`, `enemy_intent_planner.gd`, `enemy_action_resolver.gd`, `companion_action_resolver.gd`, `combat_math.gd`, plus presentation-only `combat_choreography_controller.gd`/`combat_vfx_controller.gd` (491L). This is more presentation-independent logic than the 2026-09-04 handoff implied.

**Confirmed ARCHITECTURAL DEBT**: turn orchestration is still fused with UI/audio/VFX inside `combat.gd` — `_run_combat` (L879), `_run_player_basic_action` (L1125), `_run_enemy_round` (L1224), `_check_boss_phase_transition` (L1534), `_update_skill_ui` (L2083); damage math, status application, and UI text updates are interleaved in the same blocks (e.g. L1290-1353). A Combat3D-reusable core requires pulling apart nearly every method here, not just relocating files. **Verdict: PARTIAL / the single largest architectural risk in the project**, matching the handoff's own flag — just larger than reported.

---

## 5. PARTY / MULTI-ACTOR READINESS

- **Actor model: COMPLETE as a data object.** `CombatActor` (`combat_actor.gd`): unique id, `team` enum (PLAYER/ENEMY), `actor_type` enum (PLAYER/COMPANION/NORMAL_ENEMY/ELITE/BOSS/MINION), hp/derived stats, `status_effects: Array[StatusEffectInstance]`, `formation_slot`.
- **Enemy side is already array-based**: `enemy_actors: Array[CombatActor]`, `MAX_ENEMY_ACTORS = 3`, boss summons append into this array (`combat.gd:1483-1533`). Real precedent for N-actor combat exists today, just capped at 3 and enemy-only.
- **Player side is hard-singular**: named fields `player_actor` / `companion_actor` referenced 100+ times across `combat.gd`; `get_alive_player_actors()` (`:397`) just wraps the two singular fields into an array after the fact rather than iterating a real roster.
- **Win/loss condition is single-player-life, not party-wipe**: loop condition is `player_actor.is_alive() and has_alive_enemies()`. Extending to a real party means redefining defeat semantics, not just adding array slots.
- **Targeting modes implemented**: single-enemy select + cycle (`_set_selected_enemy_actor` L698, `_cycle_selected_enemy` L764). **AoE targeting is declared but dead**: `ActiveSkillData.TargetType` has SELF/SINGLE_ENEMY/ALL_ENEMIES/SINGLE_ALLY/ALL_ALLIES, but `combat.gd:1943-1951` only implements SELF and SINGLE_ENEMY — the other branches silently return. No shipped skill currently sets those values, so it's dormant scaffolding, not a live bug.
- **Verdict: PARTIAL.** Enemy side is architecturally 5v5-ready; player side needs the same array treatment. This is real, scoped work (Milestone L3), not a rewrite.

---

## 6. SKILLS

**COMPLETE.** `ActiveSkillData`/`SkillAugmentData` (`scripts/data/`) are pure `Resource`s: target type, cooldown, cost, damage/heal formula, tags, tooltip text. Runtime consumption (`active_skill_controller.gd`, `skill_augment_resolver.gd`) reads them generically; execution dispatch sits in `combat.gd:1988` but cost/cooldown/targeting logic itself lives on the data. A small number of named passive checks remain (`ember_hunter` in `companion_action_resolver.gd:42-45`) — acceptable named exceptions for signature effects, not a systemic per-skill-code pattern. A new normal skill ships via data alone; boss-signature mechanics intentionally stay in `BossEncounterController`, consistent with the design rules.

---

## 7. STATUS SYSTEM

**COMPLETE.** Single authoritative chain: `StatusEffectData → StatusEffectInstance → CombatStatusController`. Full lifecycle — `apply_status` (L28), `remove_status` (L93), `clear_expired_statuses` (L97), `clear_all` (L103), `process_turn_start`/`process_turn_end` (L108/L140), effective-stat queries (L161-185). No duplicate status implementations found anywhere else in the codebase. **One honestly-flagged gap**: `can_apply_status()` (`:88-90`) unconditionally returns `true` — status immunity/resistance is not enforced at apply time; it's marked in-code as pending ("ETAPA 40"), not silently broken.

---

## 8. AFFINITIES / REACTIONS

**Mechanic: COMPLETE. Content: GAP for 2 of 7 types — correctly separable, matching handoff.** `AffinityResolver` supports all 7 declared types (physical, ember, tide, ash, miasma, frost, storm) with generic weak/resist math (75%/125% multipliers, `resolve_damage_preview` L27-42). Real authored reactions exist: WET→CHILLED, WET→SHOCK chain, DECAY reduces healing, CURSE amplifies damage — genuinely wired, not stubs. Frost/Storm remain unassigned to any enemy/item/biome content — **CONTENT GAP, not LOGIC GAP**, exactly as the handoff states.

**One real defect**: `AffinityResolver.preview_status_interaction()` — the one documented WET-reduces-BURN-duration rule — has **zero call sites**. It's dead code; the single non-WET-chain interaction rule described in comments doesn't actually run at runtime. Minor (P2), but means "reactions are wired" isn't 100% true today.

---

## 9. ENEMY AI

**COMPLETE.** Fully data-driven (`EnemyAIData`/`EnemyActionData`), weighted action selection with cooldown/target-policy filtering. RNG is deterministically seeded per action from `board_seed ^ actor_id.hash() ^ board_position ^ ...` (`combat.gd:495-502`) — reproducible given a fixed run seed, and covered by `enemy_intent_runtime_test.gd` for RNG-state invariants.

**Flaky-test finding, reconciled across two independent investigations**: `ashen_warden_phase3_curse_test.gd` is **not flaky today** — it runs on a single fixed seed (754331). In-file comments document real tuning history: originally tested across 4 seeds with inconsistent stack counts (the historical flakiness), fixed by two approved tuning changes (`status_duration` 2→4, `weight` 35→60) plus a deliberately loosened acceptance criterion (require ≥2 stacks reached, not "always hits cap 3"). One auditor separately flagged that `_wait_for_player_turn`-style frame-count polling (used here and in `enemy_intent_runtime_test.gd`) is a fragile proxy for "turn resolved" under variable frame timing, and could be a *secondary* source of flakiness distinct from the seed history. **Net: currently passing and deterministic; the seed-tuning fix is real and documented; the frame-polling pattern is a P2 test-architecture smell worth hardening (await an explicit signal) but not confirmed as an active failure.** Recommend confirming by actually executing the suite before treating this as fully closed — no fast headless test runner is documented in the repo (see Section 26).

---

## 10. BOSSES

**Reusable framework, confirmed by direct evidence — not aspirational.** `BossEncounterData/BossPhaseData/BossRuntimeState/BossEncounterController` generically model phase transitions by HP% (`check_phase_transition` L53-71), per-phase AI overrides (L38-40), attack/defense modifiers (L43-50), forced summon actions (L74-77), and counter-mechanic arming (L97-110) — none of it references "Ashen Warden" by name. **A second boss, `sunken_pyre.tres`, already exists and runs through the same controller with zero `combat.gd` changes** — this is real proof of reusability, not a claim.

**One confirmed exception (ARCHITECTURAL DEBT)**: `_resolve_warden_counter` (`combat.gd:1563-1618`) hardcodes Warden-branded logic for its counter-attack mechanic, and `enemy_intent_planner.gd:52` special-cases the `warden_rebuke` action id by name. Must be generalized before a second boss with a similar counter mechanic can ship cleanly.

---

## 11. EQUIPMENT

**PARTIAL — solid core, one concrete gap.** 5 real slots confirmed exactly: `WEAPON, CHEST, HEAD, CAPE, RELIC` (ARMOR→CHEST rename preserved, v14 migration). Equip validates ownership + level requirements; stat recalculation is centralized (`run_state.gd:252-328`); compare logic exists (`item_card_view.gd:212-254`); duplicate-slot handling and set-item lock interaction confirmed correct (see Section 13). **Gap**: there is no explicit "unequip" action — a slot can only be overwritten by equipping something else, never cleared back to empty once filled.

---

## 12. INVENTORY

**PARTIAL by design, not by defect.** Storage is `owned_equipment: Dictionary[String,int]` — stackable-by-id counts, not per-instance unique item objects (no individual item UUIDs). Favorite/lock/sort/filter/seen-tracking are all implemented; no capacity cap exists (unbounded growth, not currently a problem). Corruption protection is strong — malformed entries are dropped individually on load rather than failing the whole profile (`_sanitize_equipment`, `save_manager.gd:875-918`). Per-instance uniqueness (e.g. to support two differently-refined copies of the same item existing independently) is **not currently needed by any feature** — defer, don't build ahead of a use case.

---

## 13. REFINEMENT / SET BONUSES

**Refinement: COMPLETE.** Max +20 confirmed, with milestone-based bonuses and interpolated cost curves. Transactions snapshot-then-mutate-then-save-then-rollback-on-failure. The NO ITEM DESTRUCTION invariant holds and is explicitly tested up to max level (`refinement_never_destroys`). **P1 (confirmed independently by two auditors)**: `salvage_equipment_duplicates` (`save_manager.gd:535-550`) is the one economy-adjacent mutator that skips the snapshot/rollback pattern every other transaction uses — if `save_profile()` fails mid-call, the in-memory profile keeps the mutation while the function returns as if nothing happened. Not data destruction, but a real state/return-value mismatch.

**Sets: PARTIAL / pilot-only.** `EquipmentSetResolver` is a generic dispatch table, but only `ashen_warden_set` is registered, and the framework supports a single flat "2+ pieces" threshold — **not** tiered 2pc/4pc/6pc bonuses. A second *simple* (flat-threshold) set can be authored via data alone today; a *tiered* set needs a small framework extension first.

---

## 14. LOOT

**COMPLETE convergence.** All sources — combat, elite, boss, chest, treasure, event, shop — funnel through `_grant_equipment_to_profile` / `_grant_or_salvage_equipment`. Treasure and Event deliberately never grant equipment (only boons/currency/heal) — confirmed as intentional design, not an inconsistency.

---

## 15. ECONOMY

**COMPLETE.** Three currencies confirmed on `ProfileData`: `total_ash`, `guardian_sigils`, `forge_shards`. `EconomyConfig.Currency` enum covers ASH and GUARDIAN_SIGIL for shop purchases; Forge Shards is earn-only (chests, `FORGE_SHARD` reward type) and spend-only via refinement — consistent, not broken, though hard-branching on exactly 2 spendable currencies is minor rigidity if a third spendable currency is ever added (not urgent). All spends are pre-validated before deduction; snapshot/rollback confirmed for chest-opening and refinement. No path to negative balance found. Pity system (`ChestResolver.resolve`) is fully seeded and deterministic/testable.

**P1 (independently confirmed by two auditors, distinct from the refinement/salvage issue above)**: `try_purchase_upgrade` / `try_purchase_meta_unlock` (`save_manager.gd:147-183`) deduct Ash **before** calling `save_profile()`, with no rollback on save failure — a real, if narrow, silent-currency-loss risk.

---

## 16. SHOP / FORGE

**Shop: COMPLETE.** `ShopCatalog` is deterministic (rotation by `total_runs / SHOP_ROTATION_RUNS`, not RNG), gated by level/boss-kill requirements, priced by rarity+tier. Stock + owned-checks block duplicate purchases; persistence verified.

**Doc correction**: the handoff's "Biome Material offer may be incomplete" is stale. Actual current state: **0% shop-connected** — `ShopOfferData.RewardType` has no biome-material entry at all; biome materials are earned only via run events and spent only in refinement. This is a genuine **CONTENT GAP** (a shop-buyable biome-material offer doesn't exist), not a partial/broken implementation.

**Forge/Salvage: COMPLETE**, no destructive edge cases. Salvage respects locks (both manual player-locks and automatic set-item-while-equipped locks); favorites intentionally do **not** block salvage (by design, per in-code comment). Refinement investment on an item survives salvage of duplicates (inventory is count-based per equipment_id, refinement is keyed the same way) — explicitly tested (`stage78_economy_runtime_test.gd:104`). Pricing is consistently labeled INITIAL TUNING, not asserted final.

---

## 17. MAP / ROUTING

**COMPLETE for the true-routing feature, pending human confirmation.** Route A/B now diverge into distinct pre-generated 4-tile sequences with real archetype weighting (combat/recovery/treasure/balanced) via `route_branch_data.gd` + `board_generator.gd`, replacing the deprecated dynamic base+1/gate formula in `route_choice_resolver.gd` (confirmed retired from production by its own maintainer comment, and by `git log` showing it untouched since baseline while the new files were added in `ea6b413`). Covered by new tests (`board2d_true_routing_test.gd`, `board_generator_fork_test.gd`, `board_presentations_contract_test.gd`). **This appears to genuinely fix MAP3D-HUMAN-004 at the logic level — but per Section 2, this must not be marked closed until a human actually plays it; both playtest templates are still blank.**

---

## 18. REGIONS

**Data architecture: COMPLETE.** `BiomeData` (a `Resource`) covers board length, tile-weight ranges per encounter type, enemy/elite/boss pools, event pool, affinity tag, gameplay modifiers, full presentation hooks, and progression metadata (`progression_order`, `difficulty_tier`, `required_milestone_id`, `recommended_level`, `danger_rating`) — all in one place. `BiomeCatalog` is a flat 2-entry array (`ASHEN_WASTES`, `EMBER_MARSH`) with zero per-biome branching in its helper methods. Confirmed by test evidence that the two current regions differ purely by data.

**ARCHITECTURAL DEBT**: `region_selection.gd` hardcodes exactly two named UI buttons instead of iterating `BiomeCatalog`, and `docs/biome_authoring.md` requires manually adding a named const to the catalog to register a new region. **A third region is not yet purely data-authorable** — the selection screen needs a small catalog-driven refactor first, even though the underlying `BiomeData`/`BiomeCatalog` model already supports it.

---

## 19. EVENTS

**PARTIAL — strong core, two named gaps.** `EventResolver.select_for_run()` filters a biome's event pool by required/excluded flags, respects repeatable vs. seen state, and picks deterministically via a seeded RNG (`board_seed ^ position ^ events_resolved`) — fully reproducible. `EventApplier.apply_detailed()` applies per-option stat/health/ash deltas, sets flags, grants boons/augments or a seeded biome-material drop, with a double-resolution guard. **RUN FLAGS vs PROFILE FLAGS split is real and correct**: run-scoped flags live on `RunState` (cleared each run), permanent unlocks/milestones live on `ProfileData` — two clearly separate stores, matching the design rule exactly.

**Gap**: no data field exists for an event to trigger combat, grant/remove a companion, or chain explicitly to a follow-up event beyond the flag-gating mechanism — those need new code, not new data, when a specific event calls for them. Not urgent; no content currently needs it.

---

## 20. PROGRESSION

Three distinct systems confirmed, correctly separated with no code-level overlap:
- **Run-XP/permanent level** (`PlayerProgressionConfig`, 1-50 quadratic curve) — explicitly commented as independent of any in-run temporary stat deltas.
- **Milestone/"Ashen Rank"** (`MilestoneCatalog` + `MilestoneResolver`) — generic condition-evaluated (TOTAL_RUNS, BOSS_DEFEATED, EPIC_EQUIPMENT_OWNED, SYNERGY_DISCOVERED, etc.), also gates region unlocks (see Section 21).
- **Meta-unlock catalog** (`MetaUnlockCatalog`) — milestone-gated permanent "focus" unlocks costing Ash, a separate build-shaping sink from both of the above.

No competing/redundant systems found — these are three intentionally-layered short/medium/long-term tracks, matching the Master doc's own taxonomy. Worth a short doc pass tying their intended relationship together explicitly (nice-to-have, not a bug).

**Region-completion semantics — see Design Decision below, this is the one real nuance in an otherwise mature domain.** The unlock *mechanism* is complete and data-driven (`BiomeCatalog.is_unlocked()` gated on `required_milestone_id`), and boss-defeat milestones exist in the catalog. But **what currently gates Ember Marsh is "complete any one run" (`first_expedition`), not "defeat the Ashen Wastes boss."** The mechanism works exactly as coded; what's undecided is the *design intent* — should regions gate on defeating the previous region's boss, or is milestone-based gating (of any kind) the intended long-term model? This is not a broken system, and not a missing one — it's an unresolved design question about what "completing a region" should mean before a third region's gate is authored. Flagged in Section 34, not resolved here.

---

## 21. SAVE

**COMPLETE.** `SAVE_VERSION = 14` confirmed (`save_manager.gd:15`). Migration chain (`_migrate_profile()`, `:737-767`) is version-gated and strictly additive — `<11` resets level/XP (documented as unrecoverable from history), `<12` initializes chest/refinement/shop fields, `<13` initializes biome materials, `<14` is a documented no-op rename (ARMOR→CHEST) needing no data transform. Every load re-sanitizes discovery/tutorial/milestone/equipment/skills/companion/meta-unlock state regardless of version, then re-saves if the loaded version is older.

**Field matrix (grouped):**

| Group | Fields | Save? | Migration | Validated on load |
|---|---|---|---|---|
| Profile core | level/XP, run/victory/defeat/boss counters | ✓ | pre-v11 reset (documented) | implicit |
| Currencies | total_ash, guardian_sigils (v12+), forge_shards (v12+) | ✓ | ✓ | non-negative-arithmetic guarded |
| Equipment/Inventory | owned_equipment, refinement levels, equipped slots, locked/favorite/seen ids | ✓ | ARMOR→CHEST (v14) | `_sanitize_equipment`/`_sanitize_equipped_slots` drop unknown/unowned entries |
| Chests/loot | unopened_chests, chest_pity, opened counts, shop purchase counts (v12+) | ✓ | ✓ | partial (drops unknown-id chests) |
| Progression/unlocks | milestones, meta-unlocks, companion/skill unlocks | ✓ | ✓ | ✓ |
| Tutorial | completed_tutorials | ✓ | v5+ migration path | ✓ (`TutorialManager.sanitize_profile`) |
| Settings | (theme/audio/etc.) | **separate file** (`user://settings.cfg`, own `ConfigFile`) | N/A — outside SAVE_VERSION entirely | N/A |

**Atomic write / corruption recovery — verified real, not just claimed.** `_write_profile_safely()`: write TEMP → re-read+validate TEMP → rotate existing MAIN into BACKUP → rename TEMP→MAIN. `load_profile()` cascades: MAIN valid → use it; MAIN invalid → try TEMP; TEMP absent/invalid → try BACKUP; everything invalid → fresh defaults **with the corrupt MAIN preserved to a timestamped `.corrupt.<ts>.json` sidecar**, never silently overwritten. Future-version saves are loaded read-only and block all writes. **No silent-data-loss path found.**

`SaveManager.use_isolated_test_profile()` confirmed implemented and debug-build-gated. Of 37 files in `tools/tests/`, 24 use it directly, 3 pre-date it but isolate via a distinct manual save path, 10 touch no persistence at all — **with one exception, see Section 29 P0 #1.**

---

## 22. ACTIVE RUN PERSISTENCE

**MISSING entirely — this is a DESIGN GATE per protocol, not silently implemented, and not silently ignored either.** `RunManager.current_run` is a plain in-memory `RunState` (`RefCounted`), never serialized; the only save-side interaction is `deposit_run()` at terminal victory/defeat. **Closing the app mid-run (including an OS-level background-kill on Android, which is routine) loses all run progress with no recovery path** — board position, route branch, HP, loot rolled, run-level upgrades, all of it.

**Classification for your approval: leaning MUST HAVE FOR 1.0, but flagged as a decision, not a default.** Argument for MUST HAVE: mobile players get backgrounded/killed by the OS routinely, and losing 15-30 tiles of progress to a phone call is a real retention/trust risk specific to mobile that a desktop-only game wouldn't have. Argument for OPTIONAL/deferrable: a run is bounded and short by design, `RunState` has ~60 transient fields (route branches, synergies, telemetry counters) that would all need serialization plus a new `SAVE_VERSION` migration plus a resume-vs-abandon UI/logic layer — this is a real standalone feature, not a quick fix, and no current test or doc treats its absence as a bug. **Not implemented here; scoped as its own milestone (L8) pending your decision (Section 34).**

---

## 23. TUTORIAL

**COMPLETE, logically.** Context-gated request queue (`_enqueue_by_priority`), owner-node-liveness checks so tutorial requests survive scene teardown, `DebugConfig.is_visual_slice_enabled()` short-circuits completion for capture/test tooling. Fresh-profile behavior confirmed clean; `reset_all()`/`skip_all()` both save immediately. The one real problem in this area is a **test-process** issue, not a tutorial-logic issue — see Section 29 P0 #1.

---

## 24. TERMINAL STATES

**COMPLETE.** `_run_terminal_transition_started` prevents double-firing of win/loss handlers, reset correctly at every screen-boundary entry point. The black-screen-after-Boss-Victory bug (root cause: `AshenBackdrop` z-order) is fixed in `game.gd:606-622` on this branch and regression-tested (`map3d_boss_result_visibility_test.gd`) — but per Section 2, still awaiting human confirmation before being called closed. No stale-scene or double-reward risk found in any audited terminal path.

---

## 25. SIMULATION

**STALE — confirmed by source comment, not inference.** `tools/simulation/full_run_simulation.gd:180-266` still drives routing through the deprecated `RouteChoiceResolver`. This is self-documented: commit `ea6b413`'s message explicitly states the old dynamic base+1/gate mechanism is "kept only because tools/simulation/full_run_simulation.gd still depends on it." `git log` confirms `full_run_simulation.gd` has not been touched since the baseline commit while the true-routing files were added afterward. **Economy/loot/reward metrics produced by this simulator no longer reflect true-routing's content mix (no FORK tiles, no branch-archetype weighting) and should not be trusted for balance decisions until it's realigned** — required before/at merge of this branch, per Phase 36's explicit instruction.

---

## 26. TEST COVERAGE

37 files in `tools/tests/` + 5 in `tools/simulation/`, spanning UNIT/DOMAIN/INTEGRATION/RUNTIME/REGRESSION/SIMULATION types — broadly strong, no dedicated CI-style runner script or README-documented headless command was found (a real but minor process gap: test execution appears to be manual, per-file, via the Godot editor or a hand-run `godot --headless --script <path>` invocation).

**Coverage gaps identified (probable, based on file inventory — not exhaustively confirmed against every file's internals):** no dedicated regression test found for SKILLS as a standalone domain (only touched incidentally inside combat/AI tests), REFINEMENT beyond what's bundled into `equipment2_phase1_test.gd`, SET BONUSES (no dedicated `ashen_warden_set` test), EVENTS (no event-chain-specific test), or the REGIONS/biome-authoring framework as a generic mechanism (only Ashen Wastes presentation is tested). Error/invalid-state handling itself (invalid item ID, corrupted save, unknown slot) is consistently fail-closed with fallback/sanitization rather than crash, confirmed across both the equipment and save audits.

---

## 27. ARCHITECTURAL DEBT (full list, most to least severe)

1. `combat.gd` orchestration/presentation fusion — the primary blocker to a clean Combat3D extraction (Section 4).
2. Player-side combat actors hard-singular; win/loss keyed to one actor — blocks 3v3/5v5 (Section 5).
3. `full_run_simulation.gd` stale relative to true-routing (Section 25).
4. `region_selection.gd` hardcodes exactly two regions instead of reading `BiomeCatalog` (Section 18).
5. Boss counter-attack mechanic hardcoded to Warden branding in `combat.gd`/`enemy_intent_planner.gd` (Section 10).
6. `salvage_equipment_duplicates` and `try_purchase_upgrade`/`try_purchase_meta_unlock` both skip the snapshot/rollback pattern used elsewhere (Sections 13, 15) — two separate instances of the same pattern gap.
7. `equipped_companion_id` caps active allies at exactly one, ahead of any confirmed multi-ally content need (Section 20/Master Phase 26).
8. Dead code: `AffinityResolver.preview_status_interaction()` never called (Section 8).
9. Frame-count polling (`_wait_for_player_turn`-style) as a turn-completion proxy in at least two tests — fragile under variable frame timing (Section 9).

---

## 28. LOGIC COMPLETION MATRIX

| System | Status | Blocker? | Arch. Work | Logic Work | Content Work | Balance Work | Presentation Work | Test Status | Priority |
|---|---|---|---|---|---|---|---|---|---|
| Core loop (mainline) | COMPLETE | No | — | — | — | — | — | Strong | — |
| Map3D routing | COMPLETE (pending playtest) | Procedural | — | — | — | — | Human playtest | New tests added | P0 (process) |
| Combat orchestration | PARTIAL | Yes (5v5, Combat3D) | Extraction | — | — | — | — | Good | P1 |
| Party/multi-actor | PARTIAL | Yes (5v5) | Player-side arrays | Win/loss redefinition | — | — | — | Partial | P1 |
| Turn order | UNDECIDED | Yes (party combat) | — | Design decision | — | — | — | N/A | Design gate |
| Skills | COMPLETE | No | — | — | — | — | — | Incidental only | P2 (dedicated tests) |
| Status | COMPLETE | No | — | Immunity stub | — | — | — | Good | P2 |
| Affinities (mechanic) | COMPLETE | No | — | Dead code cleanup | Frost/Storm | — | — | Good | P2 |
| Enemy AI | COMPLETE | No | — | — | — | — | — | Good | — |
| Bosses | COMPLETE | No | Warden-specific counter | — | 2nd+ boss content | — | — | 1 flaky-diagnosed test | P2 |
| Equipment | PARTIAL | No | — | Unequip action | — | — | — | Good | P2 |
| Inventory | COMPLETE (for current needs) | No | — | — | — | — | — | Good | — |
| Refinement | COMPLETE | No | — | Salvage rollback | — | — | — | Good | P1 (small) |
| Sets | PARTIAL | No | Tiered framework | — | 2nd set | — | — | None dedicated | P2 |
| Loot | COMPLETE | No | — | — | — | — | — | Good | — |
| Economy | COMPLETE | No | — | Purchase rollback | — | Pricing = initial tuning | — | Good | P1 (small) |
| Shop | COMPLETE | No | — | — | Biome material offer | — | — | Good | P2/content |
| Forge/Salvage | COMPLETE | No | — | — | — | — | — | Good | — |
| Regions (data model) | COMPLETE | No | — | — | 3rd region content | — | — | Good | P3 |
| Region selection UI | PARTIAL | Yes (3rd region) | Catalog-driven | — | — | — | — | — | P1 |
| Region completion semantics | UNDECIDED | Yes (progression gating) | — | Design decision | — | — | — | — | Design gate |
| Events | PARTIAL | No | — | Combat/ally/chain fields | — | — | — | Good | P2 |
| Allies/companions | COMPLETE framework | No | Single-active cap | — | 2nd companion | — | — | Good | P3/content |
| Player progression | COMPLETE | No | — | — | — | — | — | Good | — |
| Save | COMPLETE | No | — | — | — | — | — | Excellent | — |
| Active run persistence | MISSING | Design gate | New serialization + v15 migration | — | — | — | — | None | Design gate |
| Tutorial | COMPLETE | No | — | — | — | — | — | Good, 1 test bug | P0 (test bug) |
| Terminal states | COMPLETE | No | — | — | — | — | — | Good | — |
| Telemetry | COMPLETE | No | — | — | — | — | — | Good | — |
| Simulation accuracy | STALE | Blocks balance work | Realign to true-routing | — | — | — | — | N/A | P1 |
| Test process | GAP | No | Document/build a runner | — | — | — | — | — | P2 |

---

## 29. P0 BLOCKERS

1. **`tools/tests/tutorial_overlay_runtime_test.gd` corrupts the real player save profile.** It never calls `SaveManager.use_isolated_test_profile()`; its `_prepare()` helper calls `TutorialManager.reset_all()`, which writes directly to `user://profile.json`. Running this test wipes/rewrites the real player's tutorial state. This is the only file in the suite with this gap. Trivial, safe, zero-design-decision fix: add the isolation call to match every other persisting test.
2. **Branch process gate**: `feature/map3d-true-routing` must not be merged or marked closed — MAP3D-HUMAN-004 and the black-screen fix are unverified by an actual human (both playtest templates are blank). Not a code bug; a process/status-integrity item.

*(No data-corruption, reward-duplication, or reward-loss bugs were found anywhere in this audit — the P0 list is short and clean.)*

---

## 30. P1 REQUIRED WORK

- Extract combat's turn/damage/status orchestration from its UI/audio/VFX calls (prerequisite for both 5v5 and Combat3D; large — own milestone, per roadmap Tier 3).
- Resolve the region-completion-semantics design question (Section 20/34) before authoring a 3rd region's unlock gate.
- Resolve the turn-order design question (Section 5/34) before any 3v3/5v5 combat work starts.
- Make `region_selection.gd` catalog-driven before authoring region 3.
- Realign `full_run_simulation.gd` to true-routing before trusting any economy/balance simulation output.
- Wire the Map3D prototype/sandbox path to the real reward pipeline, or explicitly exclude it from future human playtests (Section 3/34).
- Add rollback-on-save-failure to `salvage_equipment_duplicates` and `try_purchase_upgrade`/`try_purchase_meta_unlock` (two small, independent fixes).
- Correct two stale doc claims: "Biome Material offer partially connected" (it's 0% connected — content gap, not partial bug) and `combat.gd` line count (2,148 → 2,360) in the Technical Handoff.

---

## 31. P2 / P3 DEFERRED WORK

- Tiered (2pc/4pc/6pc) set-bonus framework — only needed once a second *tiered* set is planned; a flat-threshold second set needs no framework change.
- Status immunity/resistance enforcement (`can_apply_status()` stub) — once content needs it.
- Generalize the boss counter-attack mechanic before authoring a second boss that uses one.
- Wire dormant AoE targeting branches (ALL_ENEMIES/SINGLE_ALLY/ALL_ALLIES) once party combat or an AoE skill needs them.
- Remove or wire `AffinityResolver.preview_status_interaction()` dead code.
- Harden the frame-polling test-synchronization pattern in `ashen_warden_phase3_curse_test.gd` / `enemy_intent_runtime_test.gd` (await an explicit "turn resolved" signal instead).
- Document or build a single headless test-runner command for the suite.
- Per-instance unique inventory items — only if a future feature needs to distinguish individually-refined copies of the same base item.
- Multi-active-ally support beyond one `equipped_companion_id` — defer until content actually calls for more than one simultaneous ally.
- A shop-purchasable biome-material offer — content decision, not a logic fix.
- 3rd region, 2nd companion, additional bosses/sets — explicit CONTENT work, correctly out of scope for this logic-completion pass.

---

## 32. RECOMMENDED IMPLEMENTATION ORDER

1. **L0** — zero-design-risk fixes: tutorial test isolation bug; doc corrections. Can proceed immediately with your go-ahead.
2. **Branch closure** — get MAP3D-HUMAN-004 / black-screen-fix human playtest actually run and the two report templates filled, before this branch is considered mergeable.
3. **Design decisions** (Section 34) — resolved by you before any combat-architecture or region-progression work proceeds.
4. **L1** — Map3D prototype-vs-production reward wiring, once Design Decision #4 is answered.
5. **L2** — combat domain extraction (own branch, regression-tested against existing Combat2D behavior, no behavior change).
6. **L3** — party-ready combat (player-side actor arrays, party win/loss, AoE targeting), gated on the turn-order decision.
7. **L4** — skills/status/AI normalization touch-ups (immunity enforcement, dead-code cleanup, boss-counter generalization) — small, can interleave with L2/L3.
8. **L5-L7** — equipment/set/region cleanup (catalog-driven region selection, region-progression rules once decided, unequip action, salvage/purchase rollback fixes).
9. **L8** — active-run persistence, only once approved, scoped as its own SAVE_VERSION-bumping milestone.
10. **L9** — simulation realignment with true-routing.
11. **L10** — full regression pass + human logic playtest.

---

## 33. MILESTONES

- **L0 — Hygiene**: fix `tutorial_overlay_runtime_test.gd` isolation; correct the two stale doc claims. No SAVE_VERSION change, no gameplay change.
- **L1 — Core loop closure**: resolve the Map3D prototype/production reward-path question; carry the true-routing branch through actual human playtest; update the Technical Handoff.
- **L2 — Combat domain extraction**: separate orchestration from presentation in `combat.gd`, existing Combat2D behavior preserved and regression-tested.
- **L3 — Party-ready combat**: player-side actor arrays, party win/loss condition, AoE targeting wiring — gated on the turn-order decision.
- **L4 — Skills/status/AI normalization**: status immunity enforcement, generalize boss counter, remove/wire dead affinity code, harden flaky-adjacent test synchronization.
- **L5 — Equipment/inventory/set integrity**: add unequip; decide on and possibly build the tiered-set framework; fix the two transaction-rollback gaps.
- **L6 — Loot/economy/shop/forge**: mostly already complete — doc corrections and (optionally) a biome-material shop offer.
- **L7 — Regions/events/progression**: catalog-driven region selection; region-completion rules once decided; event field extensions if/when a specific event needs them.
- **L8 — Active run persistence**: post-approval only, own SAVE_VERSION migration, own design pass before coding.
- **L9 — Simulation alignment**: update `full_run_simulation.gd` to current routing.
- **L10 — Full logic regression + human logic playtest.**

---

## 34. DESIGN DECISIONS REQUIRING USER APPROVAL

1. **Turn order for party combat (3v3/5v5).** Current model is fixed team-turn (player → companion → full enemy array), no speed/initiative anywhere in the data model. Options: (a) extend the existing "loop all alive actors on one side" pattern to N player actors — smallest change, has direct precedent in the current enemy-array code; (b) alternating single-actor turns interleaved across teams; (c) a real speed/initiative stat + turn queue — biggest change, no current precedent anywhere in the codebase. Blocks Milestone L3.
2. **Region-completion semantics.** The unlock *mechanism* is complete and data-driven (milestone-gated), but Ember Marsh currently unlocks on "complete any one run," not "defeat the Ashen Wastes boss" — even though boss-defeat milestones already exist in the catalog and aren't wired to any region gate. Is milestone-based gating (of any kind) the intended long-term model, or should regions specifically gate on defeating the previous region's boss? Blocks authoring a real, meaningful gate for a third region.
3. **Active run persistence: MUST HAVE FOR 1.0, or OPTIONAL/deferred?** This audit leans toward MUST HAVE given mobile backgrounding risk, but this is explicitly a design gate per your own protocol, not something to decide unilaterally in an audit. Implementing it means a new `SAVE_VERSION` migration and a real resume/abandon UX — its own milestone (L8), not a quick patch.
4. **Is the Map3D prototype/sandbox mode meant to be player-facing, or is it dev/testing scaffolding that should be excluded from future human playtests entirely?** This determines whether MAP3D-HUMAN-005 gets fixed by wiring the sandbox into the real reward pipeline, or by simply keeping it out of what testers see going forward. Affects how the fix (if any) should even be scoped.

---

## 35. FIRST IMPLEMENTATION MILESTONE

**Milestone L0 — Hygiene** is the only work that requires zero design decisions and carries essentially zero risk:

- Add `SaveManager.use_isolated_test_profile()` to `tools/tests/tutorial_overlay_runtime_test.gd`'s setup, matching every other persisting test in the suite (P0 fix).
- Correct two stale lines in `ASHEN_REALM_TECHNICAL_HANDOFF.md`: the "Biome Material offer may be incomplete" note (it's a full content gap, 0% shop-connected, not a partial bug) and the `combat.gd` line count (2,148 → 2,360).

No `SAVE_VERSION` change. No gameplay change. No new files beyond the one test fix and the doc edits.

I'm stopping here per the audit-only instruction. I have **not** implemented anything, including L0 — I want your go-ahead before touching the test file or the handoff doc, and your direction on the four design decisions above before I prepare a technical plan for L1 or L2.
