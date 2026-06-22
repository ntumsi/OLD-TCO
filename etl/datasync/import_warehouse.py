"""Import exported warehouse CSVs back into PostgreSQL, replacing SSIS ImportWarehouse."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)
EXPORT_FILES = {
    "warehouse.Category.csv": "warehouse.category",
    "warehouse.Location.csv": "warehouse.location",
    "warehouse.LocationByCategory.csv": "warehouse.locationbycategory",
    "warehouse.PPXwalk.csv": "warehouse.ppxwalk",
    "warehouse.UnitPersonnel.csv": "warehouse.unitpersonnel",
    "warehouse.JointInflationCalculator.csv": "warehouse.jointinflationcalculator",
}


def transform_exported_warehouse(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def import_warehouse(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    output_root = Path(output_dir)
    results: dict[str, int] = {}
    for file_name, table_name in EXPORT_FILES.items():
        source = find_first_existing(output_root, [file_name, f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing warehouse export %s", file_name)
            continue
        transformed = transform_exported_warehouse(read_csv_flexible(source))
        results[file_name] = load_dataframe(transformed, table_name, delete_where_clause="TRUE")
    logger.info("Imported warehouse datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    import_warehouse()
