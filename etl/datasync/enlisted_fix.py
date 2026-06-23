"""Fix enlisted 91C data between environments (AMCOS.SSIS.Enlisted-91C-Fix).

This package migrates 202301-cycle enlisted-91C cost rows from one environment
to another, deleting stale rows before re-importing.
"""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import fetch_dataframe, load_dataframe
from common.file_utils import ensure_directory, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)

ENLISTED_FIX_TABLES = [
    "crunch.costs_1activeday_ne",
    "crunch.costs_ae",
    "crunch.costs_ne",
    "crunch.costs_re",
]
AMCOS_VERSION_FILTER = "202301"


def export_enlisted_fix(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    """Export 91C-related cost rows for the 202301 cycle to CSV."""
    output_root = ensure_directory(output_dir)
    results: dict[str, int] = {}
    for table_name in ENLISTED_FIX_TABLES:
        df = fetch_dataframe(
            f"SELECT * FROM {table_name} WHERE amcosversionid = %s",
            (AMCOS_VERSION_FILTER,),
        )
        file_name = f"enlisted91c.{table_name}.csv"
        target_path = output_root / file_name
        ensure_directory(target_path.parent)
        df.to_csv(target_path, index=False)
        results[table_name] = len(df)
    logger.info("Exported enlisted-91C fix datasets: %s", results)
    return results


def import_enlisted_fix(input_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    """Import enlisted-91C fix CSVs, deleting existing 202301 rows first."""
    input_root = Path(input_dir)
    results: dict[str, int] = {}
    for table_name in ENLISTED_FIX_TABLES:
        file_name = f"enlisted91c.{table_name}.csv"
        source = find_first_existing(input_root, [file_name, f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing enlisted-fix file %s", file_name)
            continue
        df = normalize_columns(read_csv_flexible(source))
        results[table_name] = load_dataframe(
            df,
            table_name,
            delete_where_clause="amcosversionid = %s",
            delete_params=(AMCOS_VERSION_FILTER,),
        )
    logger.info("Imported enlisted-91C fix datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    export_enlisted_fix()
