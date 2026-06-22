"""Load ATRM and ATRRS training data, then build the ATRRS/ATRM merge and reject sets."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import fetch_dataframe, load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
ATRM_TABLE = "load_training.atrm"
ATRRS_TABLE = "greg.atrrs"
MERGE_TABLE = "greg.atrrs_atrm_merge"
NO_MATCH_TABLE = "greg.atrrs_atrm_nomatch"
INVALID_MOS_TABLE = "greg.atrrs_atrm_merge_invalidmos"
INVALID_CODE_PATTERN = re.compile(r"^[A-Z0-9]{2,7}$")


def _drop_unnamed(df: pd.DataFrame) -> pd.DataFrame:
    return df.drop(columns=[column for column in df.columns if column.startswith("unnamed")], errors="ignore")


def _first_existing(columns: list[str], candidates: list[str]) -> str | None:
    for candidate in candidates:
        if candidate in columns:
            return candidate
    return None


def _normalize_join_columns(working: pd.DataFrame) -> pd.DataFrame:
    working = working.rename(
        columns={
            "schoolcode": "school_code",
            "school": "school_code",
            "coursenumber": "course_number",
            "course": "course_number",
            "coursephase": "course_phase",
            "phase": "course_phase",
        }
    )
    for column in ["school_code", "course_number", "course_phase"]:
        if column in working.columns:
            working[column] = working[column].fillna("").astype(str).str.strip().str.upper()
    return working


def transform_atrm(df: pd.DataFrame, version_id: str, source_name: str) -> pd.DataFrame:
    working = _normalize_join_columns(_drop_unnamed(normalize_columns(df)))
    working = working.rename(
        columns={
            "fy23_training_in_fy25_dollars_cost_per_graduate": "cost_per_graduate",
            "costpergraduate": "cost_per_graduate",
        }
    )
    if "cost_per_graduate" in working.columns:
        working["cost_per_graduate"] = pd.to_numeric(working["cost_per_graduate"], errors="coerce")
    working["amcos_version_id"] = str(version_id)
    working["source_file"] = source_name
    return working


def transform_atrrs(df: pd.DataFrame, source_name: str) -> pd.DataFrame:
    working = _normalize_join_columns(_drop_unnamed(normalize_columns(df)))
    working["source_file"] = source_name
    return working


def transform_atrrs_atrm_merge(atrrs_df: pd.DataFrame, atrm_df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    join_columns = [
        column
        for column in ["school_code", "course_number", "course_phase"]
        if column in atrrs_df.columns and column in atrm_df.columns
    ]
    if not join_columns:
        merged = atrrs_df.copy()
        merged["_merge"] = "left_only"
        return merged.iloc[0:0].copy(), merged
    merged = atrrs_df.merge(
        atrm_df,
        how="left",
        on=join_columns,
        suffixes=("_atrrs", "_atrm"),
        indicator=True,
    )
    matched = merged[merged["_merge"] == "both"].copy()
    no_match = merged[merged["_merge"] != "both"].copy()
    return matched.drop(columns=["_merge"]), no_match.drop(columns=["_merge"])


def _fetch_valid_mos_codes() -> set[str]:
    valid_codes: set[str] = set()
    for table_name, candidates in [
        ("lookup.mos", ["mos"]),
        ("lookup.aoc", ["aoc"]),
        ("lookup.womos", ["womos"]),
    ]:
        try:
            df = fetch_dataframe(f"SELECT * FROM {table_name}")
        except Exception as exc:
            logger.warning("Could not fetch validation codes from %s: %s", table_name, exc)
            continue
        normalized = {str(column).lower(): column for column in df.columns}
        for candidate in candidates:
            match = normalized.get(candidate)
            if match:
                valid_codes.update(
                    value.strip().upper()
                    for value in df[match].fillna("").astype(str)
                    if value and value.strip()
                )
    return valid_codes


def split_invalid_mos(df: pd.DataFrame, valid_codes: set[str]) -> tuple[pd.DataFrame, pd.DataFrame]:
    candidates = ["mos", "pmos", "course_mos", "mos_code", "aoc", "womos"]
    code_column = _first_existing(list(df.columns), candidates)
    if not code_column:
        return df, df.iloc[0:0].copy()
    codes = df[code_column].fillna("").astype(str).str.strip().str.upper()
    if valid_codes:
        invalid_mask = codes.ne("") & ~codes.isin(valid_codes)
    else:
        invalid_mask = codes.ne("") & ~codes.str.match(INVALID_CODE_PATTERN)
    invalid = df[invalid_mask].copy()
    valid = df[~invalid_mask].copy()
    return valid, invalid


def load_training(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    atrm_sources = find_all_existing(data_dir, ["**/ATRM*/*.csv"])
    atrrs_source = find_first_existing(data_dir, ["**/ATRRS/CNTROST*.csv"])
    if not atrm_sources:
        raise FileNotFoundError("Could not locate ATRM CSVs beneath AMCOS_DATA_DIR.")
    if not atrrs_source:
        raise FileNotFoundError("Could not locate an ATRRS CNTROST CSV beneath AMCOS_DATA_DIR.")

    atrm_df = pd.concat(
        [transform_atrm(read_csv_flexible(source), version_id, source.name) for source in atrm_sources],
        ignore_index=True,
        sort=False,
    )
    atrrs_df = transform_atrrs(read_csv_flexible(atrrs_source), atrrs_source.name)
    merged_df, no_match_df = transform_atrrs_atrm_merge(atrrs_df, atrm_df)
    valid_codes = _fetch_valid_mos_codes()
    merged_valid_df, invalid_mos_df = split_invalid_mos(merged_df, valid_codes)

    results = {
        "atrm": load_dataframe(
            atrm_df,
            ATRM_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        ),
        "atrrs": load_dataframe(atrrs_df, ATRRS_TABLE, delete_where_clause="TRUE"),
        "merged": load_dataframe(merged_valid_df, MERGE_TABLE, delete_where_clause="TRUE"),
        "no_match": load_dataframe(no_match_df, NO_MATCH_TABLE, delete_where_clause="TRUE"),
        "invalid_mos": load_dataframe(invalid_mos_df, INVALID_MOS_TABLE, delete_where_clause="TRUE"),
    }
    logger.info("Loaded training datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_training()
