"""Load FMSWeb UIC location data from flat file (AMCOS.SSIS.DataLoad.UICLocation)."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.uiclocation"
SOURCE_PATTERNS = [
    "**/FMSWeb/*uic locations*.txt",
    "**/FMSWeb/*uic_locations*.txt",
    "**/FMSWeb/*uicloc*.txt",
    "**/FMSWeb/*uicloc*.csv",
    "**/uic locations.txt",
    "**/uic_locations.txt",
]


def transform_uic_location(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[
            column
            for column in working.columns
            if column.startswith("unnamed") or column.startswith("column_")
        ],
        errors="ignore",
    )
    rename_map = {
        "srcasgmt": "src_asgmt",
        "uic": "uic_code",
        "source": "source_system",
        "locnm": "location_name",
        "city": "city_name",
        "state": "state_code",
        "zip": "zip_code",
        "country": "country_code",
        "drrsname": "drrs_name",
        "drrszipcdcity": "drrs_zip_city",
        "drrszipcdstate": "drrs_zip_state",
        "drrszipcd": "drrs_zip_code",
        "drrszipcdcountry": "drrs_zip_country",
        "arloc": "ar_location",
        "staco": "sta_co",
        "staconame": "sta_co_name",
        "stacocity": "sta_co_city",
        "stacostate": "sta_co_state",
        "stacozip": "sta_co_zip",
        "stacocountry": "sta_co_country",
        "geloc": "geo_location",
        "efy": "effective_fiscal_year",
        "tfy": "termination_fiscal_year",
        "samasstacocity": "samas_sta_co_city",
    }
    working = working.rename(
        columns={column: rename_map[column] for column in working.columns if column in rename_map}
    )
    working["amcos_version_id"] = str(version_id)
    return working.dropna(
        subset=[column for column in ["uic_code"] if column in working.columns]
    )


def load_uic_location(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    source = find_first_existing(data_dir, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a UIC locations file beneath AMCOS_DATA_DIR.")
    transformed = transform_uic_location(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s UIC location rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_uic_location()
