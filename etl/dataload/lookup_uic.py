"""Load FMSWeb UIC reference data from flat file (AMCOS.SSIS.DataLoad.LookupUIC)."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.uic"
SOURCE_PATTERNS = [
    "**/FMSWeb/*uic.txt",
    "**/FMSWeb/uic*.txt",
    "**/FMSWeb/*uic*.csv",
    "**/uic.txt",
]


def transform_lookup_uic(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[column for column in working.columns if column.startswith("unnamed") or column.startswith("column_")],
        errors="ignore",
    )
    rename_map = {
        "uicod": "uic_code",
        "edateuic": "effective_date",
        "lname": "long_name",
        "locnm": "location_name",
        "macom": "macom",
        "sbcom": "sub_command",
        "tpaco": "type_pac_org",
        "ppaco": "parent_pac_org",
        "uicur": "uic_parent",
        "geloc": "geo_location",
        "udate": "update_date",
        "tcode": "type_code",
        "arloc": "ar_location",
        "zipcd": "zip_code",
        "tpsn": "table_sequence_number",
        "status": "status",
    }
    working = working.rename(
        columns={column: rename_map[column] for column in working.columns if column in rename_map}
    )
    working["amcos_version_id"] = str(version_id)
    return working.dropna(
        subset=[column for column in ["uic_code"] if column in working.columns]
    )


def load_lookup_uic(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    source = find_first_existing(data_dir, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a UIC reference file beneath AMCOS_DATA_DIR.")
    transformed = transform_lookup_uic(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s UIC rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_lookup_uic()
