"""Load raw DMDC inventory records into PostgreSQL staging tables.

Covers:
  - AMCOS.SSIS.DataLoad.DMDC.Inventory.dtsx  (pipe-delimited flat files)
  - AMCOS.SSIS.DataLoad.DMDC.Inventory2024.dtsx (CSV, load_inventory.DMDC_Raw)
  - AMCOS.SSIS.DataLoad.NewInventory.dtsx (CSV, load_inventory.DMDC_Raw)
  - AMCOS.SSIS.DataLoad.Inventory.dtsx (older flat-file variant)
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_inventory.dmdc_raw"

# Search order: most-recent patterns first so the 2024/new-format CSVs are
# found before the older fixed-name patterns.
_FILE_PATTERNS = [
    "**/DMDC/NEW_INVENTORY_*.csv",
    "**/DMDC/DMDC_inventory_*.csv",
    "**/DMDC/Inventory_*.csv",
    "**/*INFINAL*.txt",
    "**/*INVFINAL*.txt",
    "**/load_inventory.dmdc_raw/*.txt",
    "**/*inventory*.txt",
]


def load_inventory(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> int:
    """Load a single DMDC inventory source file into load_inventory.dmdc_raw."""
    if file_path:
        source = Path(file_path)
    else:
        source = find_first_existing(DATA_DIR, _FILE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a DMDC inventory file beneath AMCOS_DATA_DIR.")
    logger.info("Loading raw inventory from %s", source)
    raw = read_csv_flexible(source, delimiter="|")
    working = normalize_columns(raw)
    working["amcos_version_id"] = str(version_id)
    rows = load_dataframe(
        working,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s raw inventory rows", rows)
    return rows


def load_inventory_2024(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    """Load the 2024-format DMDC inventory CSV (Inventory2024 / NewInventory packages)."""
    data_root = Path(data_dir)
    source = find_first_existing(
        data_root,
        [
            "**/DMDC/NEW_INVENTORY_*.csv",
            "**/DMDC/DMDC_inventory_*.csv",
            "**/DMDC/Inventory_*.csv",
        ],
    )
    if not source:
        logger.warning("No 2024-format DMDC inventory CSV found; skipping.")
        return 0
    logger.info("Loading 2024 DMDC inventory from %s", source)
    raw: pd.DataFrame = read_csv_flexible(source)
    working = normalize_columns(raw)
    working["amcos_version_id"] = str(version_id)
    rows = load_dataframe(
        working,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s 2024-format inventory rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_inventory()
