"""Load GS occupational-series and occupational-group lookup tables."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
SERIES_TABLE = "lookup.gs_occupationalseries"
GROUP_TABLE = "lookup.gs_occupationalgroup"
SOURCE_PATTERNS = ["**/GS_Job_Series.csv", "**/*GS*Occup*.csv"]
SERIES_PATTERN = re.compile(r"^(?P<number>\d{3,5})\s*-\s*(?P<title>.+)$")
GROUP_PATTERN = re.compile(r"^(?P<number>\d{2,4})\s*-\s*(?P<title>.+)$")


def _split_labeled_value(value: object, pattern: re.Pattern[str]) -> tuple[str | None, str | None]:
    text = str(value).strip()
    match = pattern.match(text)
    if match:
        return match.group("number"), match.group("title")
    return (text or None, None)


def transform_gs_occupational_series(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    series_source = None
    for candidate in ["occupationalseries", "occupational_series", "series", working.columns[0]]:
        if candidate in working.columns:
            series_source = candidate
            break
    if series_source is None:
        return pd.DataFrame()
    split = working[series_source].map(lambda value: _split_labeled_value(value, SERIES_PATTERN))
    working["occupational_series_number"] = split.map(lambda value: value[0])
    working["series_title"] = split.map(lambda value: value[1])
    if "work_role_code_required" not in working.columns:
        working["work_role_code_required"] = False
    working["amcos_version_id"] = str(version_id)
    return working[[column for column in ["amcos_version_id", "occupational_series_number", "series_title", "work_role_code_required"] if column in working.columns]].dropna(subset=["occupational_series_number"])


def transform_gs_occupational_groups(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    group_source = None
    for candidate in ["occupationalgroup", "occupational_group", "group", working.columns[0]]:
        if candidate in working.columns:
            group_source = candidate
            break
    if group_source is None:
        return pd.DataFrame()
    split = working[group_source].map(lambda value: _split_labeled_value(value, GROUP_PATTERN))
    working["occupational_group_number"] = split.map(lambda value: value[0])
    working["group_title"] = split.map(lambda value: value[1])
    working["amcos_version_id"] = str(version_id)
    return working[[column for column in ["amcos_version_id", "occupational_group_number", "group_title"] if column in working.columns]].dropna(subset=["occupational_group_number"])


def load_lookup_gs_occupations(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate a GS occupational lookup source file beneath AMCOS_DATA_DIR.")
    source_df = read_csv_flexible(source)
    series_df = transform_gs_occupational_series(source_df, version_id)
    groups_df = transform_gs_occupational_groups(source_df, version_id)
    results = {
        "series": load_dataframe(series_df, SERIES_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,)) if not series_df.empty else 0,
        "groups": load_dataframe(groups_df, GROUP_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,)) if not groups_df.empty else 0,
    }
    logger.info("Loaded GS occupational datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_lookup_gs_occupations()
