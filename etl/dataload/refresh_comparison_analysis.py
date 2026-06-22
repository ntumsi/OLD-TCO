"""Load comparison analysis extracts, replacing AMCOS.SSIS.RefreshComparisonAnalysis.dtsx."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import clean_loaded_frame, find_first_existing, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)

SOURCE_TABLE_MAP = {
    "costs_test": (
        ["**/*ExternalTest*Costs*.csv", "**/*External*Costs*.csv"],
        "data.costs_test",
    ),
    "costs_gp_test": (
        ["**/*ExternalTest*Costs*GP*.csv", "**/*External*Costs*GP*.csv"],
        "data.costs_gp_test",
    ),
    "inventory_test": (
        ["**/*ExternalTest*Inventory*.csv", "**/*External*Inventory*.csv"],
        "data.tbldata_inventory_test",
    ),
    "costs_prod": (
        ["**/*Production*Costs*.csv", "**/*InternalTest*Costs*.csv"],
        "data.costs_prod",
    ),
    "costs_gp_prod": (
        ["**/*Production*Costs*GP*.csv", "**/*InternalTest*Costs*GP*.csv"],
        "data.costs_gp_prod",
    ),
    "inventory_prod": (
        ["**/*Production*Inventory*.csv", "**/*InternalTest*Inventory*.csv"],
        "data.inventory_prod",
    ),
}


def load_refresh_comparison_analysis(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    results: dict[str, int] = {}
    found_any = False
    for source_name, (patterns, target_table) in SOURCE_TABLE_MAP.items():
        source = find_first_existing(data_dir, patterns)
        if not source:
            results[source_name] = 0
            continue
        found_any = True
        transformed = clean_loaded_frame(read_csv_flexible(source))
        if transformed.empty:
            results[source_name] = 0
            continue
        results[source_name] = load_dataframe(
            transformed,
            target_table,
            delete_where_clause="TRUE",
        )

    if not found_any:
        raise FileNotFoundError("Could not locate comparison analysis source files beneath AMCOS_DATA_DIR.")

    logger.info("Loaded comparison analysis datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_refresh_comparison_analysis()
