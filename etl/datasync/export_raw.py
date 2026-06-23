"""Export raw crunch and warehouse tables to CSV, replacing AMCOS.SSIS.ExportRawFromDev."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import fetch_dataframe
from common.file_utils import ensure_directory
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)

CIVILIAN_PCS_TABLES = {
    "dataload.DoSPerDiem.csv": "dataload.dosperdiem",
    "crunch.GSAPerDiem.csv": "crunch.gsaperdiem",
}
INVENTORY_TABLES = {
    "crunch.InventoryProcessed.csv": "crunch.inventoryprocessed",
    "crunch.Inventory_GFEBS.csv": "crunch.inventory_gfebs",
    "crunch.WASS_Processed.csv": "crunch.wass_processed",
}
MILITARY_COST_TABLES = {
    "crunch.Costs_AE.csv": "crunch.costs_ae",
    "crunch.Costs_AO.csv": "crunch.costs_ao",
    "crunch.Costs_AWO.csv": "crunch.costs_awo",
    "crunch.Costs_NE.csv": "crunch.costs_ne",
    "crunch.Costs_NO.csv": "crunch.costs_no",
    "crunch.Costs_NWO.csv": "crunch.costs_nwo",
    "crunch.Costs_RE.csv": "crunch.costs_re",
    "crunch.Costs_RO.csv": "crunch.costs_ro",
    "crunch.Costs_RWO.csv": "crunch.costs_rwo",
}
WAREHOUSE_TABLES = {
    "warehouse.Category.csv": "warehouse.category",
    "warehouse.JointInflationCalculator.csv": "warehouse.jointinflationcalculator",
    "warehouse.Location.csv": "warehouse.location",
    "warehouse.LocationByCategory.csv": "warehouse.locationbycategory",
    "warehouse.PPXwalk.csv": "warehouse.ppxwalk",
    "warehouse.UnitPersonnel.csv": "warehouse.unitpersonnel",
}
CIVILIAN_COST_TABLES = {
    "crunch.Costs_CY.csv": "crunch.costs_cy",
    "crunch.Costs_G.csv": "crunch.costs_g",
    "crunch.Costs_GFEBS.csv": "crunch.costs_gfebs",
    "crunch.Costs_G_Overseas.csv": "crunch.costs_g_overseas",
    "crunch.Costs_NF.csv": "crunch.costs_nf",
    "crunch.Costs_SES.csv": "crunch.costs_ses",
    "crunch.Costs_Wage.csv": "crunch.costs_wage",
}


def _export_tables(output_root: Path, file_table_map: dict[str, str]) -> dict[str, int]:
    results: dict[str, int] = {}
    for file_name, table_name in file_table_map.items():
        df = fetch_dataframe(f"SELECT * FROM {table_name}")
        target_path = output_root / file_name
        ensure_directory(target_path.parent)
        df.to_csv(target_path, index=False)
        results[file_name] = len(df)
    return results


def export_raw(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    """Export all raw crunch/warehouse tables to CSV for environment synchronisation."""
    output_root = ensure_directory(output_dir)
    results: dict[str, int] = {}
    for table_group in (
        CIVILIAN_PCS_TABLES,
        INVENTORY_TABLES,
        MILITARY_COST_TABLES,
        WAREHOUSE_TABLES,
        CIVILIAN_COST_TABLES,
    ):
        results.update(_export_tables(output_root, table_group))
    logger.info("Exported raw datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    export_raw()
