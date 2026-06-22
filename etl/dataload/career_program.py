"""Load occupational-series to career-program crosswalk data."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "xwalk.occupationalseriestocareerprogram"
SOURCE_PATTERNS = ["**/OCC Series to CP Matrix*.csv", "**/*CareerProgram*.csv"]
SERIES_PATTERN = re.compile(r"^(?P<code>\d{3,5})\s*-\s*(?P<title>.+)$")


def _conflict_columns(columns: list[str]) -> list[str]:
    preferred = ["occupational_series_number", "career_program_number"]
    selected = [column for column in preferred if column in columns]
    return selected or columns[:1]


def _split_series(value: object) -> tuple[str | None, str | None]:
    text = str(value).strip()
    match = SERIES_PATTERN.match(text)
    if match:
        return match.group("code"), match.group("title")
    return (text or None, None)


def transform_career_program(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    if "occupational_series_number" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "occupational_series_raw"})
    if "career_program_number" not in working.columns and len(working.columns) >= 2:
        working = working.rename(columns={working.columns[1]: "career_program_number"})
    source_column = "occupational_series_raw" if "occupational_series_raw" in working.columns else working.columns[0]
    split = working[source_column].map(_split_series)
    working["occupational_series_number"] = split.map(lambda value: value[0])
    if "series_title" not in working.columns:
        working["series_title"] = split.map(lambda value: value[1])
    return working.dropna(subset=["occupational_series_number"])


def load_career_program(file_path: Path | str | None = None) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a career-program matrix input beneath AMCOS_DATA_DIR.")
    transformed = transform_career_program(read_csv_flexible(source))
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        conflict_columns=_conflict_columns(list(transformed.columns)),
    )
    logger.info("Loaded %s career-program rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_career_program()
