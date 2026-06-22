"""Load DMDC military acquisition source-of-commission files."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "dmdc.militaryacqsourceofcommission"
SOURCE_PATTERNS = ["**/DMDC/ActiveDuty_Reserve_Gains*.csv"]


def transform_source_of_commission(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    rename_map = {
        "pay_grade": "paygrade",
        "transaction_type_code": "transactiontypecode",
        "source_of_commission": "sourceofcommission",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    for column in [column for column in working.columns if column.startswith("total")]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    working["amcos_version_id"] = str(version_id)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore").dropna(how="all")


def load_dmdc_source_of_commission(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a DMDC source-of-commission file beneath AMCOS_DATA_DIR.")
    transformed = transform_source_of_commission(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s source-of-commission rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_dmdc_source_of_commission()
