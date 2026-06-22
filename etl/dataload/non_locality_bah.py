"""Load non-locality BAH reference rates from the SSIS NonLocalityBAHRates inputs."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "dataload.nonlocalitybahrates"


def transform_non_locality_bah(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working = working.rename(
        columns={
            "location": "location_name",
            "nonlocality": "location_name",
            "non_locality": "location_name",
            "zip": "zip_code",
            "zipcode": "zip_code",
            "withdependents": "with_dependents",
            "withoutdependents": "without_dependents",
            "bah": "amount",
            "rate": "amount",
        }
    )
    if "location_name" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "location_name"})
    working["amcos_version_id"] = str(version_id)
    return working.dropna(subset=["location_name"] if "location_name" in working.columns else None)


def load_non_locality_bah(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    source = find_first_existing(data_dir, ["**/*Non*Locality*BAH*.csv", "**/2019_Non_Locality_BAH_Rates.csv"])
    if not source:
        raise FileNotFoundError("Could not locate a Non Locality BAH CSV beneath AMCOS_DATA_DIR.")
    transformed = transform_non_locality_bah(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s non-locality BAH rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_non_locality_bah()
