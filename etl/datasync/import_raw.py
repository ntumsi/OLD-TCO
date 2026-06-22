"""Import exported raw-area CSVs back into PostgreSQL, replacing the SSIS ImportRaw packages."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)
CRUNCH_CIVILIAN_FILES = {
    "crunch.Costs_G.csv": "crunch.costs_g",
    "crunch.Costs_SES.csv": "crunch.costs_ses",
    "crunch.Costs_Wage.csv": "crunch.costs_wage",
    "crunch.Costs_G_Overseas.csv": "crunch.costs_g_overseas",
    "crunch.Costs_NF.csv": "crunch.costs_nf",
}
CRUNCH_MILITARY_FILES = {
    "crunch.Costs_AE.csv": "crunch.costs_ae",
    "crunch.Costs_AO.csv": "crunch.costs_ao",
    "crunch.Costs_AWO.csv": "crunch.costs_awo",
    "crunch.Costs_NE.csv": "crunch.costs_ne",
    "crunch.Costs_NWO.csv": "crunch.costs_nwo",
    "crunch.Costs_RE.csv": "crunch.costs_re",
    "crunch.Costs_RO.csv": "crunch.costs_ro",
    "crunch.Costs_RWO.csv": "crunch.costs_rwo",
}
INVENTORY_FILES = {
    "crunch.InventoryProcessed.csv": "crunch.inventoryprocessed",
    "crunch.WASS_Processed.csv": "crunch.wass_processed",
    "crunch.Inventory_GFEBS.csv": "crunch.inventory_gfebs",
}
WAREHOUSE_FILES = {
    "warehouse.Location.csv": "warehouse.location",
    "warehouse.Category.csv": "warehouse.category",
    "warehouse.LocationByCategory.csv": "warehouse.locationbycategory",
    "warehouse.PPXwalk.csv": "warehouse.ppxwalk",
    "warehouse.JointInflationCalculator.csv": "warehouse.jointinflationcalculator",
    "warehouse.UnitPersonnel.csv": "warehouse.unitpersonnel",
}
CIVILIAN_PCS_FILES = {
    "crunch.GSAPerDiem.csv": "crunch.gsaperdiem",
    "dataload.DoSPerDiem.csv": "dataload.dosperdiem",
}


def transform_exported_raw(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def _import_tables(output_dir: Path | str, file_map: dict[str, str]) -> dict[str, int]:
    output_root = Path(output_dir)
    results: dict[str, int] = {}
    for file_name, table_name in file_map.items():
        source = find_first_existing(output_root, [file_name, f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing raw export %s", file_name)
            continue
        transformed = transform_exported_raw(read_csv_flexible(source))
        results[file_name] = load_dataframe(transformed, table_name, delete_where_clause="TRUE")
    return results


def import_crunch_civilian(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    results = _import_tables(output_dir, CRUNCH_CIVILIAN_FILES)
    logger.info("Imported raw crunch civilian datasets: %s", results)
    return results


def import_crunch_military(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    results = _import_tables(output_dir, CRUNCH_MILITARY_FILES)
    logger.info("Imported raw crunch military datasets: %s", results)
    return results


def import_inventory_raw(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    results = _import_tables(output_dir, INVENTORY_FILES)
    logger.info("Imported raw inventory datasets: %s", results)
    return results


def import_warehouse_raw(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    results = _import_tables(output_dir, WAREHOUSE_FILES)
    logger.info("Imported raw warehouse datasets: %s", results)
    return results


def import_civilian_pcs(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    results = _import_tables(output_dir, CIVILIAN_PCS_FILES)
    logger.info("Imported raw civilian PCS datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    import_crunch_civilian()
    import_crunch_military()
    import_inventory_raw()
    import_warehouse_raw()
    import_civilian_pcs()
