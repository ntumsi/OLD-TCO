"""Load BLS ECEC area, estimate, and series reference files."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
AREA_TABLE = "bls_ect.area"
ESTIMATE_TABLE = "bls_ect.estimate"
SERIES_TABLE = "bls_ect.series"
AREA_PATTERNS = ["**/cm.area.txt", "**/ECEC/**/cm.area.txt"]
ESTIMATE_PATTERNS = ["**/cm.estimate.txt", "**/ECEC/**/cm.estimate.txt"]
SERIES_PATTERNS = ["**/cm.series.txt", "**/ECEC/**/cm.series.txt"]


def _conflict_columns(columns: list[str], preferred: list[str]) -> list[str]:
    selected = [column for column in preferred if column in columns]
    return selected or columns[:1]


def transform_area(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def transform_estimate(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    for column in [column for column in working.columns if column.endswith(("year", "quarter", "value", "estimate"))]:
        working[column] = pd.to_numeric(working[column], errors="ignore")
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def transform_series(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def load_bls_ecec(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    data_root = Path(data_dir)
    sources = {
        "area": find_first_existing(data_root, AREA_PATTERNS),
        "estimate": find_first_existing(data_root, ESTIMATE_PATTERNS),
        "series": find_first_existing(data_root, SERIES_PATTERNS),
    }
    if not any(sources.values()):
        raise FileNotFoundError("Could not locate any BLS ECEC source files beneath AMCOS_DATA_DIR.")

    results = {"area": 0, "estimate": 0, "series": 0}
    if sources["area"]:
        transformed = transform_area(read_csv_flexible(sources["area"]))
        results["area"] = load_dataframe(
            transformed,
            AREA_TABLE,
            conflict_columns=_conflict_columns(list(transformed.columns), ["area_code"]),
        )
    if sources["estimate"]:
        transformed = transform_estimate(read_csv_flexible(sources["estimate"]))
        results["estimate"] = load_dataframe(
            transformed,
            ESTIMATE_TABLE,
            conflict_columns=_conflict_columns(list(transformed.columns), ["series_id", "year", "period"]),
        )
    if sources["series"]:
        transformed = transform_series(read_csv_flexible(sources["series"]))
        results["series"] = load_dataframe(
            transformed,
            SERIES_TABLE,
            conflict_columns=_conflict_columns(list(transformed.columns), ["series_id"]),
        )

    logger.info("Loaded BLS ECEC datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_bls_ecec()
