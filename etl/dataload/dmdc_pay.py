"""Load DMDC pay files, splitting valid and rejected records."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
PAY_TABLE = "dmdc.pay"
REJECTED_TABLE = "dmdc.payrejected"
SOURCE_PATTERNS = ["**/DMDC/ActiveDutyPay*.csv", "**/DMDC/ReserveComponentPay*.csv"]


def _conflict_columns(columns: list[str], preferred: list[str]) -> list[str]:
    selected = [column for column in preferred if column in columns]
    return selected or columns[:1]


def transform_dmdc_pay(df: pd.DataFrame, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["source_file"] = source_name
    working["component"] = "RESERVE" if "reserve" in source_name.lower() else "ACTIVE"
    working["row_number"] = range(1, len(working) + 1)
    numeric_columns = [
        column for column in working.columns
        if any(token in column for token in ("amount", "rate", "pay", "salary")) and column not in {"component", "pay_grade", "pay_plan"}
    ]
    for column in numeric_columns:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    return working


def _split_valid_rejected(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    required_columns = [column for column in ["component", "pay_grade"] if column in df.columns]
    numeric_columns = [
        column for column in df.columns
        if any(token in column for token in ("amount", "rate", "pay", "salary")) and column not in {"component", "pay_grade", "pay_plan"}
    ]
    valid_mask = pd.Series(True, index=df.index)
    if required_columns:
        valid_mask &= df[required_columns].notna().all(axis=1)
    if numeric_columns:
        valid_mask &= df[numeric_columns].notna().any(axis=1)
    rejected = df[~valid_mask].copy()
    if not rejected.empty:
        reasons: list[str] = []
        for _, row in rejected.iterrows():
            missing = [column for column in required_columns if pd.isna(row[column]) or str(row[column]).strip() == ""]
            has_numeric = bool(numeric_columns) and pd.notna(row[numeric_columns]).any()
            if missing:
                reasons.append("missing " + ", ".join(missing))
            elif numeric_columns and not has_numeric:
                reasons.append("no numeric pay value")
            else:
                reasons.append("validation failed")
        rejected["rejection_reason"] = reasons
    return df[valid_mask].copy(), rejected


def load_dmdc_pay(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    sources = find_all_existing(data_dir, SOURCE_PATTERNS)
    if not sources:
        raise FileNotFoundError("Could not locate DMDC pay source files beneath AMCOS_DATA_DIR.")
    transformed = pd.concat([transform_dmdc_pay(read_csv_flexible(source), source.name) for source in sources], ignore_index=True)
    valid_rows, rejected_rows = _split_valid_rejected(transformed)
    results = {
        "pay": load_dataframe(valid_rows, PAY_TABLE, conflict_columns=_conflict_columns(list(valid_rows.columns), ["component", "pay_grade", "years_of_service", "source_file", "row_number"])) if not valid_rows.empty else 0,
        "rejected": load_dataframe(rejected_rows, REJECTED_TABLE, conflict_columns=_conflict_columns(list(rejected_rows.columns), ["source_file", "row_number"])) if not rejected_rows.empty else 0,
    }
    logger.info("Loaded DMDC pay datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_dmdc_pay()
