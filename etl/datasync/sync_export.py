"""Export lookup and webuser tables for environment sync (AMCOS.SSIS.Sync.Export)."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import fetch_dataframe
from common.file_utils import ensure_directory
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)

LOOKUP_SYNC_TABLES = [
    "lookup.aoc",
    "lookup.cmf_branch_fa",
    "lookup.costelement",
    "lookup.costsummary",
    "lookup.costsummaryelement",
    "lookup.grade",
    "lookup.gs_occupationalgroup",
    "lookup.gs_occupationalseries",
    "lookup.localityrates",
    "lookup.mos",
    "lookup.payplan",
    "lookup.wageareanew",
    "lookup.womos",
]
WEBUSER_SYNC_TABLES = [
    "webuser.amcosuser",
    "webuser.pmproject",
    "webuser.pcsproject",
    "webuser.user_login_history",
    "webuser.amcosliteaudit",
]


def sync_export(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    """Export lookup and webuser tables to CSV for cross-environment synchronisation."""
    output_root = ensure_directory(output_dir)
    results: dict[str, int] = {}
    for table_name in LOOKUP_SYNC_TABLES + WEBUSER_SYNC_TABLES:
        df = fetch_dataframe(f"SELECT * FROM {table_name}")
        target_path = output_root / f"{table_name}.csv"
        ensure_directory(target_path.parent)
        df.to_csv(target_path, index=False)
        results[table_name] = len(df)
    logger.info("Sync-exported datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    sync_export()
