"""Load raw DMDC inventory records into PostgreSQL staging tables."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_inventory.dmdc_raw"


def load_inventory(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, ["**/*INFINAL*.txt", "**/*INVFINAL*.txt", "**/*inventory*.txt"])
    if not source:
        raise FileNotFoundError("Could not locate a DMDC inventory flat file beneath AMCOS_DATA_DIR.")
    logger.info("Loading raw inventory from %s", source)
    working = normalize_columns(read_csv_flexible(source, delimiter="|"))
    working["amcos_version_id"] = str(version_id)
    rows = load_dataframe(
        working,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s raw inventory rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_inventory()
