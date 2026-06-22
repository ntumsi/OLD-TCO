"""Load SingleValues key/value parameters from the legacy SSIS reference-table input."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "dataload.singlevalues"


def transform_single_values(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    rename_map = {
        "key": "id",
        "name": "id",
        "parameter": "id",
        "parametername": "id",
        "value": "param_value",
        "paramvalue": "param_value",
        "parametervalue": "param_value",
    }
    working = working.rename(columns=rename_map)
    if "id" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "id"})
    if "param_value" not in working.columns and len(working.columns) >= 2:
        working = working.rename(columns={working.columns[1]: "param_value"})
    ordered = [column for column in ["id", "param_value"] if column in working.columns]
    return working[ordered].dropna(subset=["id"])


def load_single_values(data_dir: Path | str = DATA_DIR) -> int:
    source = find_first_existing(data_dir, ["**/SingleValues.csv", "**/ReferenceTables/SingleValues.csv"])
    if not source:
        raise FileNotFoundError("Could not locate SingleValues.csv beneath AMCOS_DATA_DIR.")
    transformed = transform_single_values(read_csv_flexible(source))
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        conflict_columns=["id"],
        update_columns=["param_value"],
    )
    logger.info("Loaded %s single-value parameters from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_single_values()
