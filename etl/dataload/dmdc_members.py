"""Load DMDC members-and-dependents extracts."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "dmdc.membersanddependents"
SOURCE_PATTERNS = ["**/DRS_42625_FY*Dependents*.csv", "**/*Members*Dependents*.csv"]


def _conflict_columns(columns: list[str]) -> list[str]:
    preferred = ["fiscal_year", "component", "pay_grade", "dependents"]
    selected = [column for column in preferred if column in columns]
    return selected or columns[:1]


def transform_dmdc_members(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    for column in [column for column in working.columns if any(token in column for token in ("count", "depend", "member", "total"))]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore").dropna(how="all")


def load_dmdc_members(file_path: Path | str | None = None) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a DMDC members/dependents input file beneath AMCOS_DATA_DIR.")
    transformed = transform_dmdc_members(read_csv_flexible(source))
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        conflict_columns=_conflict_columns(list(transformed.columns)),
    )
    logger.info("Loaded %s DMDC members/dependents rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_dmdc_members()
