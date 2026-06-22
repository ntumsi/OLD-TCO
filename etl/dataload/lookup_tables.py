"""Load workbook and CSV based AMCOS lookup tables from legacy SSIS packages."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible, read_excel_sheet
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)

SHEET_TARGETS = {
    "CMF": "lookup.cmf_branch_fa",
    "AOC": "lookup.aoc",
    "MOS": "lookup.mos",
    "WOMOS": "lookup.womos",
}


def _load_sheet(workbook: Path, sheet_name: str, target: str, version_id: str) -> int:
    df = normalize_columns(read_excel_sheet(workbook, sheet_name=sheet_name))
    df["amcos_version_id"] = str(version_id)
    return load_dataframe(df, target, delete_where_clause="amcosversionid = %s", delete_params=(version_id,))


def load_lookup_tables(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    results: dict[str, int] = {}

    workbook = find_first_existing(data_root, ["**/AMCOS_Lookup*.xls", "**/AMCOS_Lookup*.xlsx"])
    if workbook:
        for sheet_name, target in SHEET_TARGETS.items():
            try:
                results[sheet_name] = _load_sheet(workbook, sheet_name, target, version_id)
            except Exception as exc:
                logger.warning("Skipping workbook sheet %s: %s", sheet_name, exc)

    gs_series = find_first_existing(data_root, ["**/GS_Job_Series.csv"])
    if gs_series:
        df = normalize_columns(read_csv_flexible(gs_series))
        df["amcos_version_id"] = str(version_id)
        results["GS_OccupationalSeries"] = load_dataframe(
            df,
            "lookup.gs_occupationalseries",
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
        results["GS_OccupationalGroup"] = load_dataframe(
            df,
            "lookup.gs_occupationalgroup",
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    logger.info("Loaded lookup-table datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_lookup_tables()
