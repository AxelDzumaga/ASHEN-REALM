"""Static onboarding audit for Ashen Realm. Never invokes Godot."""

from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "scripts/tutorial/tutorial_catalog.gd"
MANAGER = ROOT / "scripts/tutorial/tutorial_manager.gd"
GAME = ROOT / "scripts/core/game.gd"
BOARD = ROOT / "scripts/board/board.gd"

LEGACY_IDS = {
    "roll_die",
    "skill_ready",
    "skill_cooldown",
    "upgrade_selection",
    "reroll",
    "synergy_hint",
    "equipment_found",
    "archive_new",
    "first_defeat",
    "first_victory",
}

FIRST_RUN_CONCEPTUAL = [
    "lobby_intro",
    "biome_rules",
    "board_intro",
    "tile_combat",
    "combat_auto",
    "energy_gain",
    "combat_active_skill",
    "run_xp",
    "run_level_up",
    "passive_boon",
    "skill_augment",
    "synergy_activated",
    "tile_boss",
    "boss_phase",
    "boss_reward",
    "run_results",
    "ash_currency",
]

OPTIONAL_CONTEXTUAL = [
    "target_selection",
    "status_effects",
    "companion_selection",
    "companion_combat",
    "enemy_ai",
    "boss_summon",
    "tile_elite",
    "tile_event",
    "tile_treasure",
    "tile_heal",
]


def gd_files() -> list[Path]:
    return sorted(ROOT.glob("scripts/**/*.gd"))


def main() -> int:
    catalog_text = CATALOG.read_text(encoding="utf-8")
    manager_text = MANAGER.read_text(encoding="utf-8")
    game_text = GAME.read_text(encoding="utf-8")
    board_text = BOARD.read_text(encoding="utf-8")
    overlay_text = (ROOT / "scripts/tutorial/tutorial_overlay.gd").read_text(encoding="utf-8")
    constants = dict(
        re.findall(r'^const\s+([A-Z][A-Z0-9_]*)\s*:=\s*&"([a-z0-9_]+)"', catalog_text, re.M)
    )
    entry_names = re.findall(r"_add\(entries,\s*([A-Z][A-Z0-9_]*)\s*,", catalog_text)
    entry_ids = [constants[name] for name in entry_names if name in constants]
    entry_counts = Counter(entry_ids)

    references: Counter[str] = Counter()
    reference_files: dict[str, list[str]] = {}
    unknown_constant_references: list[dict[str, str]] = []
    for path in gd_files():
        text = path.read_text(encoding="utf-8")
        for name in re.findall(r"TutorialCatalog\.([A-Z][A-Z0-9_]*)", text):
            if name in {"ALL_IDS", "MIGRATED_V5_COMPLETED"}:
                continue
            if name not in constants:
                unknown_constant_references.append({"file": str(path.relative_to(ROOT)), "name": name})
                continue
            tutorial_id = constants[name]
            references[tutorial_id] += 1
            reference_files.setdefault(tutorial_id, []).append(str(path.relative_to(ROOT)))

    duplicate_ids = sorted(key for key, count in entry_counts.items() if count > 1)
    missing_entries = sorted(set(constants.values()) - set(entry_ids))
    impossible_active = sorted(
        tutorial_id
        for tutorial_id in entry_ids
        if tutorial_id not in LEGACY_IDS and references[tutorial_id] == 0
    )

    request_calls: list[dict[str, str]] = []
    for path in gd_files():
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r"TutorialManager\.(request(?:_and_wait)?)\((.*?)\)", text, re.S):
            arguments = " ".join(match.group(2).split())
            request_calls.append({
                "file": str(path.relative_to(ROOT)),
                "method": match.group(1),
                "arguments": arguments,
            })
    unscoped_requests = [
        call for call in request_calls
        if "TutorialManager.CONTEXT_" not in call["arguments"]
        or not re.search(r"(?:self|current_screen)\s*,?\s*$", call["arguments"])
    ]

    # Manager contract: priority queue, persistence and scene/owner validation.
    manager_contract = {
        "priority_queue": "_enqueue_by_priority" in manager_text,
        "persisted_dedupe": "completed_tutorials.has" in manager_text,
        "touch_safe_completion": "complete_without_presenting" in manager_text,
        "legacy_results_alias": "TutorialCatalog.RUN_RESULTS" in manager_text,
        "context_validation": "_active_context" in manager_text and "_discard_stale_requests" in manager_text,
        "owner_validation": (
            "WeakRef" in manager_text
            and "is_inside_tree" in manager_text
            and "owner == active_owner" in manager_text
        ),
        "stale_not_completed": "tutorial_cancelled.emit" in manager_text,
        "central_finish_route": (
            "func _finish_active_tutorial" in manager_text
            and manager_text.count("\t_clear_current()") == 1
            and "tutorial_closed.emit" in manager_text
        ),
        "dismiss_hides_synchronously": (
            "TutorialManager.tutorial_closed.connect(_close_tutorial)" in overlay_text
            and "func _close_tutorial" in overlay_text
            and "\tvisible = false" in overlay_text
            and "await get_tree().process_frame" not in overlay_text
        ),
        "visible_button_closes_locally_first": (
            overlay_text.index("_hide_visual_immediately(&\"understood\")")
            < overlay_text.index("TutorialManager.complete_current()")
            and overlay_text.index("_hide_visual_immediately(&\"skip_confirmed\")")
            < overlay_text.index("TutorialManager.skip_all()")
        ),
        "single_show_writer": overlay_text.count("\tvisible = true") == 1,
        "post_close_visibility_checks": (
            "_verify_hidden_after_frame" in overlay_text
            and '"frame": frame' in overlay_text
        ),
        "separate_input_guard": (
            "input_guard_requested.emit(2)" in overlay_text
            and "TutorialInputGuard" in game_text
            and "_wait_tutorial_input_guard" in game_text
        ),
        "next_waits_for_guard": (
            "_presentation_blocked" in manager_text
            and "_release_presentation_guard" in manager_text
        ),
        "screen_context_before_add": game_text.index("TutorialManager.set_context") < game_text.index("add_child(current_screen)"),
        "board_intro_safe_point": (
            board_text.index("roll_button.disabled = true")
            < board_text.index("TutorialCatalog.BOARD_INTRO")
            < board_text.index("func _on_roll_button_pressed")
        ),
    }

    class ContextQueue:
        def __init__(self) -> None:
            self.context = "main_menu"
            self.active: tuple[str, str] | None = None
            self.queue: list[tuple[str, str]] = []
            self.completed: set[str] = set()
            self.presented: list[tuple[str, str]] = []
            self.discarded: list[str] = []
            self.overlay_visible = False

        def set_context(self, context: str) -> None:
            self.context = context
            if self.active is not None and self.active[1] != context:
                self.discarded.append(self.active[0])
                self.active = None
                self.overlay_visible = False
            retained = []
            for request in self.queue:
                if request[1] == context:
                    retained.append(request)
                else:
                    self.discarded.append(request[0])
            self.queue = retained

        def request(self, tutorial_id: str, context: str) -> bool:
            if context != self.context or tutorial_id in self.completed:
                return False
            request = (tutorial_id, context)
            if self.active is not None:
                self.queue.append(request)
                return True
            self.active = request
            self.presented.append(request)
            self.overlay_visible = True
            return True

        def complete(self, present_next: bool = True) -> None:
            if self.active is not None:
                self.completed.add(self.active[0])
                self.active = None
                self.overlay_visible = False
            if present_next:
                self.release_guard()

        def release_guard(self) -> None:
            if self.active is None and self.queue:
                self.active = self.queue.pop(0)
                self.presented.append(self.active)
                self.overlay_visible = True

        def skip_all(self) -> None:
            self.active = None
            self.queue.clear()
            self.overlay_visible = False
            self.completed.update(entry_ids)

    normal = ContextQueue()
    for context, tutorial_id in [
        ("lobby", "lobby_intro"),
        ("region", "biome_rules"),
        ("board", "board_intro"),
        ("board", "tile_combat"),
        ("combat", "combat_auto"),
    ]:
        normal.set_context(context)
        normal.request(tutorial_id, context)
        normal.complete()

    rapid = ContextQueue()
    rapid.set_context("lobby")
    rapid.request("lobby_intro", "lobby")
    rapid.set_context("region")
    rapid.request("biome_rules", "region")
    rapid.set_context("board")
    rapid.request("board_intro", "board")

    skipped = ContextQueue()
    skipped.set_context("lobby")
    skipped.request("lobby_intro", "lobby")
    skipped.skip_all()
    skipped.set_context("board")
    skip_followups = [tutorial_id for tutorial_id in FIRST_RUN_CONCEPTUAL if skipped.request(tutorial_id, "board")]

    expected_contexts = {
        "lobby_intro": "lobby",
        "biome_rules": "region",
        "board_intro": "board",
        "tile_combat": "board",
        "combat_auto": "combat",
    }
    invalid_presentations = [
        {
            "tutorial_id": tutorial_id,
            "shown_in": shown_context,
            "expected": expected_contexts[tutorial_id],
        }
        for tutorial_id, shown_context in normal.presented + rapid.presented
        if shown_context != expected_contexts[tutorial_id]
    ]

    understood = ContextQueue()
    understood.set_context("lobby")
    understood.request("lobby_intro", "lobby")
    understood.complete()
    understood_state = {
        "active": understood.active,
        "overlay_visible": understood.overlay_visible,
        "completed": "lobby_intro" in understood.completed,
    }

    stale = ContextQueue()
    stale.set_context("lobby")
    stale.request("lobby_intro", "lobby")
    stale.set_context("region")
    stale_state = {
        "active": stale.active,
        "overlay_visible": stale.overlay_visible,
        "completed": "lobby_intro" in stale.completed,
    }

    two_queued = ContextQueue()
    two_queued.set_context("board")
    two_queued.request("board_intro", "board")
    two_queued.request("tile_combat", "board")
    two_queued.complete(present_next=False)
    two_queue_immediate_close = {
        "active": two_queued.active,
        "overlay_visible": two_queued.overlay_visible,
        "queue": [item[0] for item in two_queued.queue],
    }
    two_queued.release_guard()
    two_queue_after_guard = {
        "active": two_queued.active[0] if two_queued.active else None,
        "overlay_visible": two_queued.overlay_visible,
    }

    # Simulate persistence: each conceptual event is requested twice; only first request presents.
    completed: set[str] = set()
    first_presented: list[str] = []
    duplicates_suppressed = 0
    for tutorial_id in FIRST_RUN_CONCEPTUAL + OPTIONAL_CONTEXTUAL:
        for _attempt in range(2):
            if tutorial_id in completed:
                duplicates_suppressed += 1
                continue
            completed.add(tutorial_id)
            first_presented.append(tutorial_id)
    second_run_presented = [tutorial_id for tutorial_id in FIRST_RUN_CONCEPTUAL if tutorial_id not in completed]

    active_entries = [tutorial_id for tutorial_id in entry_ids if tutorial_id not in LEGACY_IDS]
    report = {
        "tutorial_ids_total": len(entry_ids),
        "active_ids": len(active_entries),
        "legacy_compatible_ids": sorted(LEGACY_IDS),
        "duplicate_ids": duplicate_ids,
        "constants_without_entry": missing_entries,
        "unknown_constant_references": unknown_constant_references,
        "impossible_active_tutorials": impossible_active,
        "manager_contract": manager_contract,
        "request_calls": len(request_calls),
        "unscoped_requests": unscoped_requests,
        "context_simulation": {
            "normal_first_run": normal.presented,
            "rapid_input_presented": rapid.presented,
            "rapid_input_discarded_stale": rapid.discarded,
            "rapid_lobby_marked_completed": "lobby_intro" in rapid.completed,
            "skip_followup_requests": skip_followups,
            "invalid_context_presentations": invalid_presentations,
            "board_roll_locked_until_intro_finishes": manager_contract["board_intro_safe_point"],
        },
        "dismiss_simulation": {
            "understood": understood_state,
            "skip": {
                "active": skipped.active,
                "overlay_visible": skipped.overlay_visible,
                "queue": skipped.queue,
            },
            "stale": stale_state,
            "two_queue_immediate_close": two_queue_immediate_close,
            "two_queue_after_guard": two_queue_after_guard,
        },
        "first_run_conceptual_order": FIRST_RUN_CONCEPTUAL,
        "contextual_optional": OPTIONAL_CONTEXTUAL,
        "first_run_presented_unique": len(first_presented),
        "duplicate_requests_suppressed": duplicates_suppressed,
        "second_run_basic_repeats": second_run_presented,
        "returning_v8_result_alias": "run_results" if manager_contract["legacy_results_alias"] else "missing",
        "potential_events": {
            "first_5_minutes_conceptual_max": 4,
            "first_combat_core": 3,
            "first_run_core": len(FIRST_RUN_CONCEPTUAL),
            "later_contextual": len(OPTIONAL_CONTEXTUAL),
        },
        "trigger_files": {key: sorted(set(value)) for key, value in sorted(reference_files.items())},
    }
    failures = []
    if duplicate_ids:
        failures.append("duplicate tutorial IDs")
    if missing_entries:
        failures.append("constants without catalog entries")
    if unknown_constant_references:
        failures.append("unknown TutorialCatalog constants")
    if impossible_active:
        failures.append("active tutorials without trigger")
    if not all(manager_contract.values()):
        failures.append("incomplete manager contract")
    if unscoped_requests:
        failures.append("tutorial requests without context/owner")
    if invalid_presentations:
        failures.append("tutorial presented outside its context")
    if rapid.discarded != ["lobby_intro", "biome_rules"]:
        failures.append("rapid transitions do not discard stale tutorials")
    if "lobby_intro" in rapid.completed:
        failures.append("discarded tutorial was marked completed")
    if skip_followups:
        failures.append("skip leaves follow-up requests")
    if second_run_presented:
        failures.append("basic tutorials repeat in second-run simulation")
    if understood_state != {"active": None, "overlay_visible": False, "completed": True}:
        failures.append("ENTENDIDO leaves partial tutorial state")
    if skipped.active is not None or skipped.overlay_visible or skipped.queue:
        failures.append("OMITIR leaves active tutorial UI or queue")
    if stale_state != {"active": None, "overlay_visible": False, "completed": False}:
        failures.append("stale dismiss leaves partial state or completion")
    if two_queue_immediate_close != {"active": None, "overlay_visible": False, "queue": ["tile_combat"]}:
        failures.append("queued tutorial reopens before input guard")
    if two_queue_after_guard != {"active": "tile_combat", "overlay_visible": True}:
        failures.append("next queued tutorial is not presented after input guard")
    report["failures"] = failures
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
