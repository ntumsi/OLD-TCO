"""Load locality-rate reference data from CSV, replacing SSIS LookupLocalityRates."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.localityrates"
SOURCE_PATTERNS = [
    "**/LookupTables/LocalityRates.csv",
    "**/ReferenceTables/LocalityRates.csv",
    "**/LocalityRates.csv",
]


def transform_locality_rates(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[column for column in working.columns if column.startswith("unnamed") or column.startswith("column_")],
        errors="ignore",
    )
    rename_map = {
        "opmid": "opm_id",
        "statename": "state_name",
        "areacode": "area_code",
        "localityid": "locality_id",
        "amount2017": "amount",
        "description2017": "description_2017",
        "namt": "namt",
    }
    working = working.rename(
        columns={column: rename_map[column] for column in working.columns if column in rename_map}
    )
    for column in [c for c in working.columns if "amount" in c]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    working["amcos_version_id"] = str(version_id)
    return working.dropna(
        subset=[column for column in ["opm_id", "locality_id"] if column in working.columns]
    )


def load_locality_rates(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    source = find_first_existing(data_dir, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a LocalityRates CSV beneath AMCOS_DATA_DIR.")
    transformed = transform_locality_rates(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s locality-rate rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_locality_rates()
