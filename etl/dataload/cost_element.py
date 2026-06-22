"""Load cost-element reference data from CSV and workbook sources."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible, read_excel_sheet
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "lookup.costelement"
CSV_PATTERNS = ["**/CostElement.csv", "**/ReferenceTables/CostElement.csv"]
XLS_PATTERNS = ["**/*CostElement*.xls", "**/*CostElement*.xlsx", "**/*ReferenceTables*.xls", "**/*ReferenceTables*.xlsx"]


def _conflict_columns(columns: list[str]) -> list[str]:
    preferred = ["payplan", "appn", "costelementcategory", "costelementname"]
    selected = [column for column in preferred if column in columns]
    return selected or columns[:1]


def transform_cost_element(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    rename_map = {
        "pay_plan": "payplan",
        "appropriation_group": "appropriationgroup",
        "cost_element_category": "costelementcategory",
        "cost_element_name": "costelementname",
        "show_order": "showorder",
        "army_ces_title": "armycestitle",
        "osd_capec_es_title": "osdcapecestitle",
        "apply_inflation": "applyinflation",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    for column in ["amort", "model", "showorder"]:
        if column in working.columns:
            working[column] = pd.to_numeric(working[column], errors="coerce").astype("Int64")
    return working.dropna(subset=[column for column in ["payplan", "appn", "costelementname"] if column in working.columns])


def _read_combined_sheet(workbook: Path) -> pd.DataFrame | None:
    for sheet_name in ("CombinedSheet$", "CombinedSheet"):
        try:
            return transform_cost_element(read_excel_sheet(workbook, sheet_name=sheet_name))
        except Exception:
            continue
    return None


def load_cost_element(data_dir: Path | str = DATA_DIR) -> int:
    data_root = Path(data_dir)
    frames: list[pd.DataFrame] = []
    for source in find_all_existing(data_root, CSV_PATTERNS):
        frames.append(transform_cost_element(read_csv_flexible(source)))
    workbook = find_first_existing(data_root, XLS_PATTERNS)
    if workbook:
        combined_sheet = _read_combined_sheet(workbook)
        if combined_sheet is not None:
            frames.append(combined_sheet)
    if not frames:
        raise FileNotFoundError("Could not locate CostElement CSV or workbook inputs beneath AMCOS_DATA_DIR.")
    transformed = pd.concat(frames, ignore_index=True).drop_duplicates()
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        conflict_columns=_conflict_columns(list(transformed.columns)),
    )
    logger.info("Loaded %s cost-element rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_cost_element()
