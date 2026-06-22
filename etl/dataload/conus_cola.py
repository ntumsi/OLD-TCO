"""Load CONUS COLA ZIP mappings and rate tables from legacy SSIS files."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
LOCATION_TABLE = "dataload.conuscolalocations"
RATE_TABLE = "dataload.conuscola"
ZIP_PATTERNS = ["**/cczips*.txt", "**/conus*cola*/*.csv"]
WITH_DEPENDENTS_PATTERNS = ["**/ccwd*.txt", "**/conus*cola*/*with*depend*.csv"]
WITHOUT_DEPENDENTS_PATTERNS = ["**/ccwod*.txt", "**/conus*cola*/*without*depend*.csv"]


def transform_conus_cola_locations(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    rename_map = {
        "zip": "zip_code",
        "zipcode": "zip_code",
        "colaarea": "cola_area",
        "location": "cola_area",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    if "zip_code" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "zip_code"})
    working["amcos_version_id"] = str(version_id)
    return working.dropna(subset=["zip_code"])


def transform_conus_cola_rates(df: pd.DataFrame, version_id: str, with_dependents: bool) -> pd.DataFrame:
    working = normalize_columns(df)
    rate_candidates = [column for column in working.columns if any(token in column for token in ("rate", "amount", "cola"))]
    for column in rate_candidates:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    if "cola_area" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "cola_area"})
    working["with_dependents"] = with_dependents
    working["amcos_version_id"] = str(version_id)
    return working.dropna(subset=["cola_area"])


def load_conus_cola(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    zip_source = find_first_existing(data_root, ZIP_PATTERNS)
    with_dep_sources = find_all_existing(data_root, WITH_DEPENDENTS_PATTERNS)
    without_dep_sources = find_all_existing(data_root, WITHOUT_DEPENDENTS_PATTERNS)
    if not zip_source and not with_dep_sources and not without_dep_sources:
        raise FileNotFoundError("Could not locate CONUS COLA inputs beneath AMCOS_DATA_DIR.")

    results = {"locations": 0, "rates": 0}
    if zip_source:
        transformed = transform_conus_cola_locations(read_csv_flexible(zip_source), version_id)
        results["locations"] = load_dataframe(
            transformed,
            LOCATION_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    rate_frames: list[pd.DataFrame] = []
    rate_frames.extend(transform_conus_cola_rates(read_csv_flexible(source), version_id, True) for source in with_dep_sources)
    rate_frames.extend(transform_conus_cola_rates(read_csv_flexible(source), version_id, False) for source in without_dep_sources)
    if rate_frames:
        results["rates"] = load_dataframe(
            pd.concat(rate_frames, ignore_index=True),
            RATE_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    logger.info("Loaded CONUS COLA datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_conus_cola()
