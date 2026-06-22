"""Load military installation and military-base reference files from legacy SSIS inputs."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
MILITARY_INSTALLATIONS_TABLE = "lookup.militaryinstallations"
MILITARY_BASE_TABLE = "dbo.militarybase"


def transform_military_installations(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working = working.rename(
        columns={
            "primaryzipcode": "primary_zip_code",
            "zipcode": "primary_zip_code",
            "zip": "primary_zip_code",
            "jointbase": "joint_base",
            "operstat": "oper_stat",
            "sitename": "site_name",
            "stateterritory": "state_territory",
            "activearmy": "active_army",
        }
    )
    expected = [
        "installation",
        "component",
        "country",
        "primary_zip_code",
        "joint_base",
        "oper_stat",
        "site_name",
        "state_territory",
        "active_army",
    ]
    existing = [column for column in expected if column in working.columns]
    return working[existing].dropna(subset=["installation"] if "installation" in working.columns else None)


def transform_military_base(df: pd.DataFrame, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working = working.rename(
        columns={
            "zipcode": "zip_code",
            "zip": "zip_code",
            "mha": "military_housing_area",
            "basename": "base_name",
            "installationname": "installation_name",
            "sitename": "site_name",
        }
    )
    working["source_file"] = source_name
    return working


def load_military_installations(data_dir: Path | str = DATA_DIR) -> int:
    source = find_first_existing(data_dir, ["**/*MIL COLA*BAH*.csv", "**/*MilitaryInstallations*.csv"])
    if not source:
        raise FileNotFoundError("Could not locate a MilitaryInstallations CSV beneath AMCOS_DATA_DIR.")
    transformed = transform_military_installations(read_csv_flexible(source))
    rows = load_dataframe(transformed, MILITARY_INSTALLATIONS_TABLE, delete_where_clause="TRUE")
    logger.info("Loaded %s military installations from %s", rows, source.name)
    return rows


def load_military_base(data_dir: Path | str = DATA_DIR) -> int:
    sources = find_all_existing(data_dir, ["**/webexls*.csv", "**/BaseOriginal*.csv"])
    if not sources:
        raise FileNotFoundError("Could not locate MilitaryBase CSVs beneath AMCOS_DATA_DIR.")
    transformed = pd.concat(
        [transform_military_base(read_csv_flexible(source), source.name) for source in sources],
        ignore_index=True,
        sort=False,
    )
    rows = load_dataframe(transformed, MILITARY_BASE_TABLE, delete_where_clause="TRUE")
    logger.info("Loaded %s military base rows from %s files", rows, len(sources))
    return rows


if __name__ == "__main__":
    configure_logging()
    load_military_installations()
    load_military_base()
