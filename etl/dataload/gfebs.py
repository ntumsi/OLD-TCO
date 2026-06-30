"""Load GFEBS lookup extracts plus cleaned/rejected staging rows."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, BATCH_SIZE, DATA_DIR

logger = logging.getLogger(__name__)
FUNCTIONAL_AREA_TABLE = "lookup.gfebs_functionalarea"
ACTIVITY_TYPE_TABLE = "lookup.gfebs_activitytype"
COST_CENTER_TABLE = "lookup.gfebs_costcenter"
FUNDS_CENTER_TABLE = "lookup.gfebs_fundscenter"
CLEANED_TABLE = "load_gfebs.cleaned"
REJECTED_TABLE = "load_gfebs.rejected"
SOURCE_PATTERNS = ["**/GFEBS/AD.csv", "**/GFEBS/*.csv"]


def _transform_lookup(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["amcos_version_id"] = str(version_id)
    return working.dropna(how="all")


def _transform_staging(df: pd.DataFrame, version_id: str, source_name: str) -> pd.DataFrame:
    working = _transform_lookup(df, version_id)
    working["source_file"] = source_name
    working["component"] = Path(source_name).stem.upper()
    working["row_number"] = range(1, len(working) + 1)
    for column in [column for column in working.columns if any(token in column for token in ("amount", "cost", "hours", "quantity"))]:
        working[column] = pd.to_numeric(working[column], errors="coerce")
    return working


def _split_cleaned_rejected(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    required_columns = [column for column in ["component"] if column in df.columns]
    numeric_columns = [column for column in df.columns if any(token in column for token in ("amount", "cost", "hours", "quantity"))]
    valid_mask = pd.Series(True, index=df.index)
    if required_columns:
        valid_mask &= df[required_columns].notna().all(axis=1)
    if numeric_columns:
        valid_mask &= df[numeric_columns].notna().any(axis=1)
    rejected = df[~valid_mask].copy()
    if not rejected.empty:
        rejected["rejection_reason"] = "missing component or numeric measure"
    return df[valid_mask].copy(), rejected


def load_gfebs(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    sources = find_all_existing(data_dir, SOURCE_PATTERNS)
    if not sources:
        raise FileNotFoundError("Could not locate GFEBS source files beneath AMCOS_DATA_DIR.")

    lookup_frames = {"functional_area": [], "activity_type": [], "cost_center": [], "funds_center": []}
    staging_frames: list[pd.DataFrame] = []
    for source in sources:
        lower_name = source.name.lower()
        if "functional" in lower_name:
            lookup_frames["functional_area"].append(_transform_lookup(read_csv_flexible(source), version_id))
        elif "activity" in lower_name:
            lookup_frames["activity_type"].append(_transform_lookup(read_csv_flexible(source), version_id))
        elif "fundscenter" in lower_name or "funds_center" in lower_name:
            lookup_frames["funds_center"].append(_transform_lookup(read_csv_flexible(source), version_id))
        elif "costcenter" in lower_name or "cost_center" in lower_name:
            lookup_frames["cost_center"].append(_transform_lookup(read_csv_flexible(source), version_id))
        else:
            staging_frames.append(_transform_staging(read_csv_flexible(source), version_id, source.name))

    results = {"functional_area": 0, "activity_type": 0, "cost_center": 0, "funds_center": 0, "cleaned": 0, "rejected": 0}
    if lookup_frames["functional_area"]:
        results["functional_area"] = load_dataframe(
            pd.concat(lookup_frames["functional_area"], ignore_index=True),
            FUNCTIONAL_AREA_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if lookup_frames["activity_type"]:
        results["activity_type"] = load_dataframe(
            pd.concat(lookup_frames["activity_type"], ignore_index=True),
            ACTIVITY_TYPE_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if lookup_frames["cost_center"]:
        results["cost_center"] = load_dataframe(
            pd.concat(lookup_frames["cost_center"], ignore_index=True),
            COST_CENTER_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if lookup_frames["funds_center"]:
        results["funds_center"] = load_dataframe(
            pd.concat(lookup_frames["funds_center"], ignore_index=True),
            FUNDS_CENTER_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if staging_frames:
        staging = pd.concat(staging_frames, ignore_index=True)
        cleaned, rejected = _split_cleaned_rejected(staging)
        if not cleaned.empty:
            results["cleaned"] = load_dataframe(
                cleaned,
                CLEANED_TABLE,
                delete_where_clause="amcosversionid = %s",
                delete_params=(version_id,),
                chunk_size=BATCH_SIZE,
            )
        if not rejected.empty:
            results["rejected"] = load_dataframe(
                rejected,
                REJECTED_TABLE,
                delete_where_clause="amcosversionid = %s",
                delete_params=(version_id,),
                chunk_size=BATCH_SIZE,
            )
    logger.info("Loaded GFEBS datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_gfebs()
