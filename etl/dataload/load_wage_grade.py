"""Load wage-grade definitions from a legacy Excel workbook (LoadWageGrade.dtsx)."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.wagegraderaw"
SOURCE_PATTERNS = [
    "**/*WFA Load*.xlsx",
    "**/*WFA Load*.xls",
    "**/*WageGrade*.xlsx",
    "**/*WageGrade*.xls",
    "**/WageGrade.csv",
]


def transform_wage_grade(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[column for column in working.columns if column.startswith("unnamed")],
        errors="ignore",
    )
    rename_map = {
        "wagegrade": "wage_grade",
        "wageschedule": "wage_schedule",
        "schedulenumber": "schedule_number",
        "wagearea": "wage_area",
        "wageareaname": "wage_area_name",
    }
    working = working.rename(
        columns={column: rename_map[column] for column in working.columns if column in rename_map}
    )
    for column in [c for c in working.columns if any(t in c for t in ("rate", "amount", "pay", "grade"))]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    return working.dropna(how="all")


def load_wage_grade(data_dir: Path | str = DATA_DIR) -> int:
    data_root = Path(data_dir)
    source = find_first_existing(data_root, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a WFA Load workbook beneath AMCOS_DATA_DIR.")
    if source.suffix.lower() in (".xls", ".xlsx"):
        df = pd.read_excel(source, header=0)
    else:
        from common.file_utils import read_csv_flexible

        df = read_csv_flexible(source)
    transformed = transform_wage_grade(df)
    rows = load_dataframe(transformed, TARGET_TABLE, delete_where_clause="TRUE")
    logger.info("Loaded %s wage-grade rows from %s", rows, source.name)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_wage_grade()
