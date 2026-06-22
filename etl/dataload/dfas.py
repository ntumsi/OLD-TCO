"""Load DFAS military basic-pay and drill-pay schedules."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "payschedule.payschedule_military"
SOURCE_PATTERNS = ["**/DFAS/*basic_pay*.csv", "**/DFAS/*drill_pay*.csv"]


def transform_dfas_pay(df: pd.DataFrame, version_id: str, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["rate_type"] = "DRILL" if "drill" in source_name.lower() else "BASIC"
    working["amcos_version_id"] = str(version_id)
    for column in [column for column in working.columns if any(token in column for token in ("amount", "rate", "pay", "salary")) and column not in {"rate_type", "pay_plan"}]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    return working.dropna(how="all")


def load_dfas(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    sources = find_all_existing(data_dir, SOURCE_PATTERNS)
    if not sources:
        raise FileNotFoundError("Could not locate DFAS military pay source files beneath AMCOS_DATA_DIR.")
    transformed = pd.concat(
        [transform_dfas_pay(read_csv_flexible(source), version_id, source.name) for source in sources],
        ignore_index=True,
    )
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s DFAS military-pay rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_dfas()
