"""Export AMCOS lookup tables to CSV, replacing the SSIS Export.LookupTables package.

Covers:
  - AMCOS.SSIS.Export.LookupTables.dtsx
"""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import fetch_dataframe
from common.file_utils import ensure_directory
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)

LOOKUP_TABLES = [
    "lookup.aoc",
    "lookup.cmf_branch_fa",
    "lookup.grade",
    "lookup.gs_occupationalgroup",
    "lookup.gs_occupationalseries",
    "lookup.inflationrates",
    "lookup.jicinflationrates",
    "lookup.localityrates",
    "lookup.mos",
    "lookup.payplan",
    "lookup.soc_detailedoccupation",
    "lookup.soc_majorgroup",
    "lookup.wageareanew",
    "lookup.womos",
]


def export_lookup_tables(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    """Export all AMCOS lookup reference tables to CSV files."""
    output_root = ensure_directory(output_dir)
    results: dict[str, int] = {}
    for table_name in LOOKUP_TABLES:
        df = fetch_dataframe(f"SELECT * FROM {table_name}")
        target_path = output_root / f"{table_name}.csv"
        ensure_directory(target_path.parent)
        df.to_csv(target_path, index=False)
        results[table_name] = len(df)
    logger.info("Exported lookup tables: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    export_lookup_tables()
