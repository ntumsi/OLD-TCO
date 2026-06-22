"""Load Army pay-type lookup crosswalk data from CSV inputs."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.armypaytype"
SOURCE_PATTERNS = ["**/*ArmyPayType*.csv", "**/*DMDC*Xwalk*.csv", "**/*xwalk*.csv"]


def _conflict_columns(columns: list[str]) -> list[str]:
    preferred = ["army_pay_type", "dmdc_pay_type", "pay_plan", "component", "code"]
    selected = [column for column in preferred if column in columns]
    return selected or columns[:1]


def transform_army_pay_type(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    rename_map = {
        "armypaytype": "army_pay_type",
        "paytype": "army_pay_type",
        "dmdcpaytype": "dmdc_pay_type",
        "payplan": "pay_plan",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    return working.dropna(how="all")


def load_army_pay_type(file_path: Path | str | None = None) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, SOURCE_PATTERNS)
    if not source:
        raise FileNotFoundError("Could not locate an Army pay-type input file beneath AMCOS_DATA_DIR.")
    transformed = transform_army_pay_type(read_csv_flexible(source))
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        conflict_columns=_conflict_columns(list(transformed.columns)),
    )
    logger.info("Loaded %s Army pay-type rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_army_pay_type()
