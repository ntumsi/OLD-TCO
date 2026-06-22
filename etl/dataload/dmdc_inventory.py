"""Partition raw DMDC inventory into civilian and military target tables."""

from __future__ import annotations

import logging

from common.db import fetch_dataframe, load_dataframe
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID
from dataload.inventory import load_inventory

logger = logging.getLogger(__name__)
CIVILIAN_TABLE = "data.inventorycivilian"
MILITARY_TABLE = "data.inventorymilitary"


def load_dmdc_inventory(version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    """Recreate the SSIS inventory split after raw inventory ingestion."""
    load_inventory(version_id=version_id)
    df = fetch_dataframe("SELECT * FROM load_inventory.dmdc_raw WHERE amcosversionid = %s", (version_id,))
    if df.empty:
        return {"civilian": 0, "military": 0}

    normalized = {column.lower(): column for column in df.columns}
    payplan_col = normalized.get("payplan")
    civtype_col = normalized.get("civtype")
    grade_type_col = normalized.get("gradetype")

    civilian = df.copy()
    military = df.copy()
    if payplan_col:
        civilian = civilian[civilian[payplan_col].fillna("").astype(str).str.upper() != "MIL"]
        military = military[military[payplan_col].fillna("").astype(str).str.upper() == "MIL"]
    elif civtype_col:
        civilian = civilian[civilian[civtype_col].fillna("").astype(str).str.upper() != "MIL"]
        military = military[military[civtype_col].fillna("").astype(str).str.upper() == "MIL"]
    elif grade_type_col:
        mask = df[grade_type_col].fillna("").astype(str).str.upper().str.startswith(("E", "O", "W"))
        civilian = df[~mask]
        military = df[mask]

    results = {
        "civilian": load_dataframe(civilian, CIVILIAN_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,)),
        "military": load_dataframe(military, MILITARY_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,)),
    }
    logger.info("Loaded DMDC inventory partitions: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_dmdc_inventory()
