"""Tiny shared helper for tools/simulation/*_report.py scripts.

Simulator Reliability audit: no report script validated the input
runs.jsonl's own "schema" field before this — a schema drift in any field
(not just the TileType/FORK case that motivated this fix) would surface as
an arbitrary KeyError/AttributeError deep inside whichever aggregation
happened to touch the changed/missing field first, instead of a clear
message. This is intentionally the only thing factored out: each report
script's actual field/aggregation logic stays independent (see the
Reliability audit's §14 "minimum churn" call — not a shared framework).
"""
from __future__ import annotations

from pathlib import Path
from typing import Any

SUPPORTED_SCHEMA = 7


def require_supported_schema(rows: list[dict[str, Any]], path: Path, supported: int = SUPPORTED_SCHEMA) -> None:
    """Fails clearly and immediately on a schema this report wasn't built
    for, instead of letting an arbitrary KeyError/AttributeError surface
    later. Call this right after loading rows, before any aggregation."""
    schemas = {int(row["schema"]) for row in rows if "schema" in row}
    unsupported = schemas - {supported}
    if unsupported:
        raise SystemExit(
            f"Unsupported simulator schema in {path}: expected {supported}, received {sorted(unsupported)}. "
            f"This report was written against schema {supported} and may read the wrong fields on a "
            f"different schema — regenerate the input with a matching simulator version, or update this report."
        )
