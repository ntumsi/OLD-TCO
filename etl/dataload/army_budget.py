"""Load Army budget lookup data from cProbe CSV extracts."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "dataload.armybudget"
SOURCE_PATTERNS = ["**/cProbe PB/*.csv", "**/cProbe*/*.csv"]


def transform_army_budget(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    rename_map = {
        "dutystation": "duty_station_code",
        "dutystationcode": "duty_station_code",
        "code": "duty_station_code",
        "localitypayarea": "locality_pay_area",
        "lpa": "locality_pay_area",
        "cbsa": "cbsa_code",
        "csa": "csa_code",
        "city": "city_name",
        "county": "county_name",
        "state": "state_name",
        "country": "country_name",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    for column in [column for column in working.columns if any(token in column for token in ("budget", "amount", "cost", "rate"))]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    working["amcos_version_id"] = str(version_id)
    return working.dropna(subset=[column for column in ["duty_station_code"] if column in working.columns])


def load_army_budget(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    data_root = Path(data_dir)
    sources = find_all_existing(data_root, SOURCE_PATTERNS)
    if not sources:
        source = find_first_existing(data_root, SOURCE_PATTERNS)
        sources = [source] if source else []
    if not sources:
        raise FileNotFoundError("Could not locate Army budget cProbe files beneath AMCOS_DATA_DIR.")
    transformed = pd.concat([transform_army_budget(read_csv_flexible(source), version_id) for source in sources], ignore_index=True)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s Army budget rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_army_budget()
