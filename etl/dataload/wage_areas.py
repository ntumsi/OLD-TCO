"""Load wage-area definitions from DCPAS reference CSVs."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.wageareanew"


def transform_wage_areas(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working = working.rename(
        columns={
            "name": "title",
            "localitypayareacode": "locality_pay_area",
            "schedulenumber": "schedule_number",
            "scheduletype": "schedule_type",
        }
    )
    if "wage_area" in working.columns:
        working["wage_area_with_leading_zeros"] = working["wage_area"].fillna("").astype(str).str.zfill(5)
    if "fips" in working.columns:
        working["fips_with_leading_zeros"] = working["fips"].fillna("").astype(str).str.zfill(5)
    if "schedule_number" in working.columns:
        working["schedule_number_with_leading_zeros"] = working["schedule_number"].fillna("").astype(str).str.zfill(3)
    return working


def load_wage_areas(data_dir: Path | str = DATA_DIR) -> int:
    source = find_first_existing(data_dir, ["**/Wage_Area_Table_DCPAS.csv", "**/ReferenceTables/Wage_Area*.csv"])
    if not source:
        raise FileNotFoundError("Could not locate a Wage Area reference CSV beneath AMCOS_DATA_DIR.")
    transformed = transform_wage_areas(read_csv_flexible(source))
    rows = load_dataframe(transformed, TARGET_TABLE, delete_where_clause="TRUE")
    logger.info("Loaded %s wage-area rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_wage_areas()
