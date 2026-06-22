"""Load WASS raw inventory extracts from one or more WASS CSV files."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_inventory.wass_raw"
YEAR_PATTERN = re.compile(r"(20\d{2})")


def transform_wass_rows(df: pd.DataFrame, source: Path, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    stem_lower = source.stem.lower()
    working["amcos_version_id"] = str(version_id)
    working["source_file"] = source.name
    working["gender"] = "Female" if "female" in stem_lower else "Male" if "male" in stem_lower else None
    match = YEAR_PATTERN.search(source.stem)
    working["source_year"] = match.group(1) if match else None
    return working


def load_wass(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    sources = find_all_existing(data_dir, ["**/WASS/**/*.csv", "**/WASS/WASS Pull*.csv"])
    if not sources:
        raise FileNotFoundError("Could not locate WASS CSV files beneath AMCOS_DATA_DIR.")
    transformed = pd.concat(
        [transform_wass_rows(read_csv_flexible(source), source, version_id) for source in sources],
        ignore_index=True,
        sort=False,
    )
    rows = load_dataframe(transformed, TARGET_TABLE, delete_where_clause="TRUE")
    logger.info("Loaded %s WASS raw rows from %s files", rows, len(sources))
    return rows


if __name__ == "__main__":
    configure_logging()
    load_wass()
