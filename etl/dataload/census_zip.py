"""Load Census ZIP boundaries and military-installation geography files."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
CENSUS_TABLE = "dbo.censuszip"
INSTALLATION_TABLE = "dbo.militaryinstallationgeo"
CENSUS_PATTERNS = ["**/Census*.csv"]
INSTALLATION_PATTERNS = ["**/MIRTABoundary*.csv", "**/MIRTAPoints*.csv"]


def _conflict_columns(columns: list[str], preferred: list[str]) -> list[str]:
    selected = [column for column in preferred if column in columns]
    return selected or columns[:1]


def transform_census_zip(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    for column in [column for column in ["aland10", "awater10", "intptlat10", "intptlon10"] if column in working.columns]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def transform_installation_geo(df: pd.DataFrame, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working["geometry_source"] = "boundary" if "boundary" in source_name.lower() else "point"
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def load_census_zip(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    data_root = Path(data_dir)
    census_source = find_first_existing(data_root, CENSUS_PATTERNS)
    installation_sources = find_all_existing(data_root, INSTALLATION_PATTERNS)
    if not census_source and not installation_sources:
        raise FileNotFoundError("Could not locate Census ZIP geography inputs beneath AMCOS_DATA_DIR.")

    results = {"census_zip": 0, "military_installation_geo": 0}
    if census_source:
        transformed = transform_census_zip(read_csv_flexible(census_source))
        results["census_zip"] = load_dataframe(
            transformed,
            CENSUS_TABLE,
            conflict_columns=_conflict_columns(list(transformed.columns), ["zcta5ce10", "geoid10"]),
        )
    if installation_sources:
        transformed = pd.concat(
            [transform_installation_geo(read_csv_flexible(source), source.name) for source in installation_sources],
            ignore_index=True,
        )
        results["military_installation_geo"] = load_dataframe(
            transformed,
            INSTALLATION_TABLE,
            conflict_columns=_conflict_columns(list(transformed.columns), ["site_no", "installation_name", "geometry_source"]),
        )

    logger.info("Loaded Census ZIP datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_census_zip()
