"""Load FIPS-to-ZIP crosswalk data."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.fips_zip"
SOURCE_PATTERNS = ["**/Zipwise Geo US*.csv", "**/*FIPS*ZIP*.csv", "**/*fips*zip*.csv"]


def transform_fips_zip(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    rename_map = {
        "fips": "fips_code",
        "fipscode": "fips_code",
        "zip": "zip_code",
        "zipcode": "zip_code",
        "statenamecapitalized": "state_name_capitalized",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    for column in [column for column in ["latitude", "longitude"] if column in working.columns]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    working["amcos_version_id"] = str(version_id)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore").dropna(subset=[column for column in ["fips_code", "zip_code"] if column in working.columns])


def load_fips_zip(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a FIPS-to-ZIP input file beneath AMCOS_DATA_DIR.")
    transformed = transform_fips_zip(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s FIPS-ZIP rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_fips_zip()
