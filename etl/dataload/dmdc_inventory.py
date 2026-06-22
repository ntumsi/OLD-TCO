"""Partition raw DMDC inventory into civilian and military target tables.

Covers:
  - AMCOS.SSIS.DataLoad.DMDC.InventoryCivilian.dtsx
  - AMCOS.SSIS.DataLoad.DMDC.InventoryMilitary.dtsx
  - AMCOS.SSIS.DataLoad.DMDC.InventoryMilitaryOfficer.dtsx
  - AMCOS.SSIS.DataLoad.DMDC.Inventory.dtsx (combined load)
"""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import fetch_dataframe, load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR
from dataload.inventory import load_inventory

logger = logging.getLogger(__name__)

# Summary tables (legacy)
CIVILIAN_TABLE = "data.inventorycivilian"
MILITARY_TABLE = "data.inventorymilitary"

# Fine-grained staging tables from InventoryCivilian.dtsx
CIV_GS_TABLE = "load_inventory.inventory_civiliargs"
CIV_ACQUISITION_TABLE = "load_inventory.inventory_civilianacquisition"
CIV_DEMO_TABLE = "load_inventory.inventory_civiliandemonstration"
CIV_SES_TABLE = "load_inventory.inventory_civilianses"
CIV_REJECTED_TABLE = "load_inventory.rejected"

# Fine-grained staging tables from InventoryMilitary.dtsx
MIL_ENLISTED_TABLE = "load_inventory.inventory_military_enlisted"
MIL_OFFICER_TABLE = "load_inventory.inventory_military_officer"
MIL_WARRANT_TABLE = "load_inventory.inventory_military_warrant"


def _get_col(df: pd.DataFrame, *names: str) -> str | None:
    """Return the first column name (case-insensitive) that exists in df."""
    lookup = {col.lower(): col for col in df.columns}
    for name in names:
        found = lookup.get(name.lower())
        if found:
            return found
    return None


def load_dmdc_inventory(version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    """Ingest raw inventory and split into summary civilian/military tables."""
    load_inventory(version_id=version_id)
    df = fetch_dataframe("SELECT * FROM load_inventory.dmdc_raw WHERE amcosversionid = %s", (version_id,))
    if df.empty:
        return {"civilian": 0, "military": 0}

    payplan_col = _get_col(df, "payplan")
    civtype_col = _get_col(df, "civtype")
    grade_type_col = _get_col(df, "gradetype")

    if payplan_col:
        mil_mask = df[payplan_col].fillna("").astype(str).str.upper() == "MIL"
    elif civtype_col:
        mil_mask = df[civtype_col].fillna("").astype(str).str.upper() == "MIL"
    elif grade_type_col:
        mil_mask = df[grade_type_col].fillna("").astype(str).str.upper().str.startswith(("E", "O", "W"))
    else:
        mil_mask = pd.Series(False, index=df.index)

    civilian = df[~mil_mask]
    military = df[mil_mask]

    results = {
        "civilian": load_dataframe(civilian, CIVILIAN_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,)),
        "military": load_dataframe(military, MILITARY_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,)),
    }
    logger.info("Loaded DMDC inventory partitions: %s", results)
    return results


def load_civilian_inventory(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    """Partition a dedicated civilian inventory CSV into fine-grained staging tables.

    Replaces AMCOS.SSIS.DataLoad.DMDC.InventoryCivilian.dtsx.
    """
    data_root = Path(data_dir)
    source = find_first_existing(
        data_root,
        [
            "**/DMDC/INVENTORY.CIV*.csv",
            "**/DMDC/*civilian*.csv",
            "**/DMDC/*Civilian*.csv",
        ],
    )
    if not source:
        logger.warning("No civilian-specific inventory file found; skipping.")
        return {}

    logger.info("Loading civilian inventory from %s", source)
    df = normalize_columns(read_csv_flexible(source))
    df["amcos_version_id"] = str(version_id)

    payplan_col = _get_col(df, "payplan", "pay_plan")
    category_col = _get_col(df, "categorygroup", "category_group")

    results: dict[str, int] = {}

    def _filter_and_load(mask: pd.Series, table: str) -> int:
        subset = df[mask]
        if subset.empty:
            return 0
        return load_dataframe(
            subset, table,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    if payplan_col:
        gs_mask = df[payplan_col].fillna("").astype(str).str.upper().isin({"GS", "GL"})
        ses_mask = df[payplan_col].fillna("").astype(str).str.upper() == "ES"
        acq_mask = df[payplan_col].fillna("").astype(str).str.upper() == "NH"
        demo_mask = df[payplan_col].fillna("").astype(str).str.upper().isin({"DJ", "DE"})
        other_mask = ~(gs_mask | ses_mask | acq_mask | demo_mask)
    elif category_col:
        gs_mask = df[category_col].fillna("").astype(str).str.upper().str.contains("GS|GL")
        ses_mask = df[category_col].fillna("").astype(str).str.upper().str.contains("SES|ES")
        acq_mask = df[category_col].fillna("").astype(str).str.upper().str.contains("ACQUI|NH")
        demo_mask = df[category_col].fillna("").astype(str).str.upper().str.contains("DEMO")
        other_mask = ~(gs_mask | ses_mask | acq_mask | demo_mask)
    else:
        gs_mask = pd.Series(True, index=df.index)
        ses_mask = acq_mask = demo_mask = other_mask = pd.Series(False, index=df.index)

    results["civ_gs"] = _filter_and_load(gs_mask, CIV_GS_TABLE)
    results["civ_ses"] = _filter_and_load(ses_mask, CIV_SES_TABLE)
    results["civ_acquisition"] = _filter_and_load(acq_mask, CIV_ACQUISITION_TABLE)
    results["civ_demonstration"] = _filter_and_load(demo_mask, CIV_DEMO_TABLE)
    if other_mask.any():
        results["rejected"] = _filter_and_load(other_mask, CIV_REJECTED_TABLE)

    logger.info("Loaded civilian inventory partitions: %s", results)
    return results


def load_military_inventory(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    """Partition a military inventory CSV into enlisted/officer/warrant staging tables.

    Replaces AMCOS.SSIS.DataLoad.DMDC.InventoryMilitary.dtsx and
    AMCOS.SSIS.DataLoad.DMDC.InventoryMilitaryOfficer.dtsx.
    """
    data_root = Path(data_dir)
    # Accept multiple source files for military, enlisted, officer, warrant
    enlisted_source = find_first_existing(
        data_root,
        ["**/DMDC/INVENTORY.AD.Enl*", "**/DMDC/*enlisted*.csv", "**/DMDC/*Enl*.txt"],
    )
    officer_source = find_first_existing(
        data_root,
        ["**/DMDC/INVENTORY.AD.Off*", "**/DMDC/*officer*.csv", "**/DMDC/*Off*.txt"],
    )
    warrant_source = find_first_existing(
        data_root,
        ["**/DMDC/INVENTORY.AD.Wrnt*", "**/DMDC/*warrant*.csv", "**/DMDC/*Wrnt*.txt"],
    )

    results: dict[str, int] = {}

    def _load_one(source: Path | None, table: str, label: str) -> int:
        if not source:
            logger.warning("No %s inventory source found; skipping.", label)
            return 0
        df = normalize_columns(read_csv_flexible(source))
        df["amcos_version_id"] = str(version_id)
        return load_dataframe(
            df, table,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    results["enlisted"] = _load_one(enlisted_source, MIL_ENLISTED_TABLE, "enlisted")
    results["officer"] = _load_one(officer_source, MIL_OFFICER_TABLE, "officer")
    results["warrant"] = _load_one(warrant_source, MIL_WARRANT_TABLE, "warrant")

    if not any(results.values()):
        # Fallback: read from dmdc_raw and partition by grade prefix
        df = fetch_dataframe(
            "SELECT * FROM load_inventory.dmdc_raw WHERE amcosversionid = %s", (version_id,)
        )
        if not df.empty:
            grade_col = _get_col(df, "grade", "paygrade")
            if grade_col:
                e_mask = df[grade_col].fillna("").astype(str).str.upper().str.startswith("E")
                o_mask = df[grade_col].fillna("").astype(str).str.upper().str.startswith("O")
                w_mask = df[grade_col].fillna("").astype(str).str.upper().str.startswith("W")
                results["enlisted"] = load_dataframe(df[e_mask], MIL_ENLISTED_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,))
                results["officer"] = load_dataframe(df[o_mask], MIL_OFFICER_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,))
                results["warrant"] = load_dataframe(df[w_mask], MIL_WARRANT_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,))

    logger.info("Loaded military inventory partitions: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_dmdc_inventory()
