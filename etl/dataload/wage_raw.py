"""Load raw DCPAS wage-schedule data, replacing the SSIS Load.WageRaw package."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_payschedule.wageschedule_raw"
SOURCE_PATTERNS = [
    "**/DCPAS/Wagedata.csv",
    "**/DCPAS/*Wagedata*.csv",
    "**/DCPAS/wagedata*.csv",
    "**/Wagedata.csv",
]


def transform_wage_raw(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[column for column in working.columns if column.startswith("unnamed") or column.startswith("throwaway")],
        errors="ignore",
    )
    rename_map = {
        "schedulenumber": "schedule_number",
        "typeschedule": "type_schedule",
        "effdate": "effective_date",
        "filename": "source_file",
    }
    working = working.rename(
        columns={column: rename_map[column] for column in working.columns if column in rename_map}
    )
    rate_columns = [c for c in working.columns if c.startswith("rate")]
    for column in rate_columns:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    working["amcos_version_id"] = str(version_id)
    return working.dropna(
        subset=[column for column in ["wagearea", "grade"] if column in working.columns]
    )


def load_wage_raw(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    data_root = Path(data_dir)
    sources = find_all_existing(data_root, SOURCE_PATTERNS)
    if not sources:
        source = find_first_existing(data_root, SOURCE_PATTERNS)
        sources = [source] if source else []
    if not sources:
        raise FileNotFoundError("Could not locate a Wagedata CSV beneath AMCOS_DATA_DIR.")
    transformed = pd.concat(
        [transform_wage_raw(read_csv_flexible(source), version_id) for source in sources],
        ignore_index=True,
    )
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s raw wage-schedule rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_wage_raw()
