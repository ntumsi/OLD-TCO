"""Load duty-station location data from the SSIS Locations package."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.dutystation"


def transform_duty_stations(df, version_id: str):
    working = normalize_columns(df)
    working = working.rename(
        columns={
            "code": "duty_station_code",
            "lpa": "locality_pay_area",
            "cbsa": "cbsa_code",
            "csa": "csa_code",
            "city": "city_name",
            "county": "county_name",
            "state": "state_name",
            "country": "country_name",
        }
    )
    working["amcos_version_id_start"] = str(version_id)
    working["amcos_version_id_end"] = str(version_id)
    ordered = [
        "amcos_version_id_start",
        "amcos_version_id_end",
        "duty_station_code",
        "locality_pay_area",
        "cbsa_code",
        "csa_code",
        "city_name",
        "county_name",
        "state_name",
        "country_name",
    ]
    return working[ordered].dropna(subset=["duty_station_code"])


def load_locations(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, ["**/dutystations.csv"])
    if not source:
        raise FileNotFoundError("Could not locate dutystations.csv beneath AMCOS_DATA_DIR.")
    transformed = transform_duty_stations(read_csv_flexible(source, delimiter="\t"), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        conflict_columns=["amcos_version_id_start", "duty_station_code"],
        delete_where_clause="amcosversionidend = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s duty stations", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_locations()
