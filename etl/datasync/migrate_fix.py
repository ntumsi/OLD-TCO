"""Migrate 17C/17Z fix rows between environments (AMCOS.SSIS.Migrate17C-Fix).

Copies 202301-cycle 17C and 17Z MOS rows from the DMDC_processed staging table
in one environment to another, deleting stale rows before inserting.
"""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import fetch_dataframe, load_dataframe
from common.file_utils import ensure_directory, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)

MIGRATE_FIX_TABLE = "load_inventory.dmdc_processed"
AMCOS_VERSION_FILTER = "202301"
MOS_FILTER = ("17C", "17Z")
FIX_FILE = "migrate17c.dmdc_processed.csv"


def export_17c_fix(output_dir: Path | str = OUTPUT_DIR) -> int:
    """Export 17C/17Z rows from dmdc_processed for the 202301 cycle."""
    output_root = ensure_directory(output_dir)
    placeholders = ", ".join(["%s"] * len(MOS_FILTER))
    df = fetch_dataframe(
        f"SELECT * FROM {MIGRATE_FIX_TABLE} WHERE amcosversionid = %s AND mos IN ({placeholders})",
        (AMCOS_VERSION_FILTER, *MOS_FILTER),
    )
    target_path = output_root / FIX_FILE
    df.to_csv(target_path, index=False)
    logger.info("Exported %s 17C/17Z rows to %s", len(df), target_path.name)
    return len(df)


def import_17c_fix(input_dir: Path | str = OUTPUT_DIR) -> int:
    """Import 17C/17Z rows into dmdc_processed, deleting existing 202301 17C/17Z rows first."""
    input_root = Path(input_dir)
    source = find_first_existing(input_root, [FIX_FILE, f"**/{FIX_FILE}"])
    if not source:
        raise FileNotFoundError(f"Could not locate {FIX_FILE} beneath {input_dir}.")
    df = normalize_columns(read_csv_flexible(source))
    placeholders = ", ".join(["%s"] * len(MOS_FILTER))
    rows = load_dataframe(
        df,
        MIGRATE_FIX_TABLE,
        delete_where_clause=f"amcosversionid = %s AND mos IN ({placeholders})",
        delete_params=(AMCOS_VERSION_FILTER, *MOS_FILTER),
    )
    logger.info("Imported %s 17C/17Z rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    export_17c_fix()
