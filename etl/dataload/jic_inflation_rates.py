"""Load JIC inflation rates from the SSIS JICInflationRates package."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "data.asafmcjointinflationrates"


def transform_inflation_rates(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    """Apply the same broad cleanup as the SSIS derived-column flow."""
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working = working.rename(columns={"appn": "appropriation", "type": "rate_type", "baseyear": "base_year", "targetyear": "target_year"})
    working["base_year"] = pd.to_numeric(working["base_year"], errors="coerce").astype("Int64")
    working["target_year"] = pd.to_numeric(working["target_year"], errors="coerce").astype("Int64")
    working["amount"] = pd.to_numeric(working["amount"], errors="coerce")
    working["amcos_version_id"] = str(version_id)
    columns = ["amcos_version_id", "base_year", "target_year", "appropriation", "rate_type", "amount"]
    return working[columns].dropna(subset=["base_year", "target_year", "amount"])


def load_jic_inflation_rates(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, ["**/*JIC*data*.csv", "**/*JIC*.csv"])
    if not source:
        raise FileNotFoundError("Could not locate a JIC inflation input file beneath AMCOS_DATA_DIR.")
    logger.info("Loading JIC inflation rates from %s", source)
    transformed = transform_inflation_rates(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        conflict_columns=["amcos_version_id", "base_year", "target_year", "appropriation", "rate_type"],
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s JIC inflation rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_jic_inflation_rates()
