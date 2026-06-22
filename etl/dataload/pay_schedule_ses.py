"""Load SES pay schedules from GFEBS/WASS CSVs, including wide-to-long normalization."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
LOAD_TABLE = "load_payschedule.payschedule_ses"
TARGET_TABLE = "dataload.payschedule_ses"
STEP_PATTERN = re.compile(r"(?:step|level)?\s*(\d+)$", re.IGNORECASE)
GRADE_PATTERN = re.compile(r"([A-Z]+)?\s*-?\s*(\d+)")


def _derive_effective_date(working: pd.DataFrame, source: Path) -> pd.Series:
    for column in ["effective_date", "date_effective", "date", "pay_effective_date"]:
        if column in working.columns:
            return pd.to_datetime(working[column], errors="coerce")
    parsed = pd.to_datetime(source.stem, errors="coerce")
    if pd.isna(parsed):
        parsed = pd.Timestamp.today().normalize()
    return pd.Series([parsed] * len(working), index=working.index)


def _step_from_column(value: str) -> str:
    match = STEP_PATTERN.search(str(value))
    return match.group(1) if match else str(value).strip()


def _grade_parts(grade: str) -> tuple[str, int | None]:
    text = str(grade).strip().upper() or "SES"
    match = GRADE_PATTERN.search(text)
    if match:
        return (match.group(1) or "SES"), int(match.group(2))
    return text, None


def transform_pay_schedule_ses(df: pd.DataFrame, source: Path, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working = working.rename(columns={"step_yos": "step", "rate": "annual_rate", "dateeffective": "date_effective"})

    if {"step", "annual_rate"}.issubset(working.columns):
        long_df = working.copy()
    else:
        id_columns = [
            column
            for column in ["pay_plan", "grade", "grade_type", "grade_level", "rate_type", "occupational_series_number"]
            if column in working.columns
        ]
        date_series = _derive_effective_date(working, source)
        wide = working.assign(effective_date=date_series)
        if "grade" not in wide.columns:
            if {"grade_type", "grade_level"}.issubset(wide.columns):
                wide["grade"] = wide["grade_type"].fillna("") + wide["grade_level"].fillna("").astype(str)
            else:
                wide["grade"] = "SES"
        id_columns = ["effective_date", "grade", *id_columns]
        id_columns = list(dict.fromkeys([column for column in id_columns if column in wide.columns]))
        value_columns = [
            column
            for column in wide.columns
            if column not in id_columns and STEP_PATTERN.search(column) and pd.to_numeric(wide[column], errors="coerce").notna().any()
        ]
        if not value_columns:
            value_columns = [
                column
                for column in wide.columns
                if column not in id_columns and pd.to_numeric(wide[column], errors="coerce").notna().any()
            ]
        long_df = wide.melt(id_vars=id_columns, value_vars=value_columns, var_name="step", value_name="annual_rate")
        long_df["step"] = long_df["step"].map(_step_from_column)

    if "effective_date" not in long_df.columns:
        long_df["effective_date"] = _derive_effective_date(long_df, source)
    long_df["effective_date"] = pd.to_datetime(long_df["effective_date"], errors="coerce")
    if "grade" not in long_df.columns:
        long_df["grade"] = "SES"
    long_df["grade"] = long_df["grade"].fillna("SES").astype(str).str.strip().str.upper()
    long_df["annual_rate"] = pd.to_numeric(long_df["annual_rate"], errors="coerce")
    long_df = long_df.dropna(subset=["annual_rate"])
    if "pay_plan" in long_df.columns:
        long_df["pay_plan"] = long_df["pay_plan"].fillna("SES")
    else:
        long_df["pay_plan"] = "SES"
    long_df["grade_type"] = long_df["grade"].map(lambda value: _grade_parts(value)[0])
    long_df["grade_level"] = long_df["grade"].map(lambda value: _grade_parts(value)[1])
    if "rate_type" in long_df.columns:
        long_df["rate_type"] = long_df["rate_type"].fillna("Annual")
    else:
        long_df["rate_type"] = "Annual"
    long_df["date_effective"] = long_df["effective_date"]
    long_df["rate"] = long_df["annual_rate"]
    long_df["amcos_version_id"] = str(version_id)
    long_df["source_file"] = source.name
    ordered = [
        "amcos_version_id",
        "pay_plan",
        "grade",
        "grade_type",
        "grade_level",
        "step",
        "date_effective",
        "effective_date",
        "occupational_series_number",
        "rate_type",
        "rate",
        "annual_rate",
        "source_file",
    ]
    for column in ordered:
        if column not in long_df.columns:
            long_df[column] = None
    return long_df[ordered]


def load_pay_schedule_ses(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    sources = find_all_existing(data_dir, ["**/PaySchedules/SES/SES*.csv", "**/*SES*WASS*.csv"])
    if not sources:
        raise FileNotFoundError("Could not locate SES pay schedule CSVs beneath AMCOS_DATA_DIR.")
    transformed = pd.concat(
        [transform_pay_schedule_ses(read_csv_flexible(source), source, version_id) for source in sources],
        ignore_index=True,
        sort=False,
    )
    results = {
        "load_payschedule": load_dataframe(
            transformed,
            LOAD_TABLE,
            conflict_columns=["amcos_version_id", "pay_plan", "grade_type", "grade_level", "step", "date_effective"],
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        ),
        "dataload": load_dataframe(
            transformed,
            TARGET_TABLE,
            conflict_columns=["amcos_version_id", "pay_plan", "grade_type", "grade_level", "step", "date_effective"],
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        ),
    }
    logger.info("Loaded SES pay schedule rows: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_pay_schedule_ses()
