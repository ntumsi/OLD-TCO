"""Load legacy duty-station reference data from CSV (AMCOS.SSIS.DataLoad.DutyStation)."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "dataload.dutystation"
SOURCE_PATTERNS = [
    "**/OPM/dutystations.csv",
    "**/dutystations.csv",
    "**/DutyStation*.csv",
]


def transform_duty_station(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[column for column in working.columns if column.startswith("unnamed")],
        errors="ignore",
    )
    rename_map = {
        "code": "duty_station_code",
        "lpa": "locality_pay_area",
        "cbsa": "cbsa_code",
        "csa": "csa_code",
        "city": "city_name",
        "county": "county_name",
        "state": "state_name",
        "country": "country_name",
        "rate1": "rate_1",
        "rate2": "rate_2",
    }
    working = working.rename(
        columns={column: rename_map[column] for column in working.columns if column in rename_map}
    )
    working["amcos_version_id"] = str(version_id)
    return working.dropna(
        subset=[column for column in ["duty_station_code"] if column in working.columns]
    )


def load_duty_station(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    source = find_first_existing(data_dir, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a duty-station CSV beneath AMCOS_DATA_DIR.")
    transformed = transform_duty_station(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s duty-station rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_duty_station()
