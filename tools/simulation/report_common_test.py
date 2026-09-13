#!/usr/bin/env python3
"""Simulator Reliability — small deterministic contract test for
report_common.py and full_run_report.py's tile_name(), matching this
directory's existing plain-script convention (no pytest anywhere in this
repo; not introducing one for two small checks). Run directly:

    python3 tools/simulation/report_common_test.py

Exits 0 on success, 1 on any failed check, printing a JSON summary.
"""
from __future__ import annotations

import io
import json
import sys
from contextlib import redirect_stderr
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from report_common import SUPPORTED_SCHEMA, require_supported_schema  # noqa: E402
import full_run_report  # noqa: E402


def main() -> int:
    failures: list[str] = []

    def check(label: str, condition: bool) -> None:
        print(f"[REPORT_COMMON_TEST] {label}={condition}")
        if not condition:
            failures.append(label)

    # tile_name(): known values.
    check("tile_name_empty", full_run_report.tile_name(0) == "EMPTY")
    check("tile_name_fork", full_run_report.tile_name(7) == "FORK")

    # tile_name(): unknown value must never alias into an existing
    # category, must warn exactly once, and must not crash.
    stderr_capture = io.StringIO()
    with redirect_stderr(stderr_capture):
        first = full_run_report.tile_name(999)
        second = full_run_report.tile_name(999)
    check("unknown_tile_name_is_explicit", first == "UNKNOWN_999")
    check("unknown_tile_name_not_aliased_to_empty", first != "EMPTY")
    check("unknown_tile_name_stable_across_calls", first == second)
    check("unknown_tile_name_warns_exactly_once", stderr_capture.getvalue().count("UNKNOWN_999") == 1)

    # require_supported_schema(): accepts the current schema.
    ok_rows = [{"schema": SUPPORTED_SCHEMA}, {"schema": SUPPORTED_SCHEMA}]
    try:
        require_supported_schema(ok_rows, Path("fixture.jsonl"))
        check("supported_schema_accepted", True)
    except SystemExit:
        check("supported_schema_accepted", False)

    # require_supported_schema(): rejects a mismatch with a clear message,
    # not a raw traceback from whatever touches the missing/changed field.
    bad_rows = [{"schema": SUPPORTED_SCHEMA}, {"schema": 99}]
    try:
        require_supported_schema(bad_rows, Path("fixture.jsonl"))
        check("mismatched_schema_rejected", False)
    except SystemExit as exc:
        message = str(exc)
        check("mismatched_schema_rejected", True)
        check("mismatched_schema_message_names_expected", str(SUPPORTED_SCHEMA) in message)
        check("mismatched_schema_message_names_received", "99" in message)

    report = {"failures": failures}
    print(json.dumps(report))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
