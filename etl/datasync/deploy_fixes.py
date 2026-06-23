"""Copy selected crunch/warehouse/OES tables between environments (AMCOS.SSIS.DeployFixes)."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import fetch_dataframe, load_dataframe
from common.file_utils import ensure_directory, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)

DEPLOY_TABLES = [
    "warehouse.category",
    "crunch.costs_ae",
    "crunch.costs_ne",
    "crunch.costs_re",
    "load_inventory.dmdc_processed",
    "warehouse.locationbycategory",
    "bls_oes.occupationalemploymentstatisticsmetro",
    "bls_oes.occupationalemploymentstatisticsnational",
    "warehouse.ppxwalk",
]


def export_deploy_data(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    """Export fix tables to CSV for cross-environment deployment."""
    output_root = ensure_directory(output_dir)
    results: dict[str, int] = {}
    for table_name in DEPLOY_TABLES:
        df = fetch_dataframe(f"SELECT * FROM {table_name}")
        target_path = output_root / f"{table_name}.csv"
        ensure_directory(target_path.parent)
        df.to_csv(target_path, index=False)
        results[table_name] = len(df)
    logger.info("Exported deploy-fix datasets: %s", results)
    return results


def import_deploy_data(input_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    """Import fix CSVs exported by export_deploy_data into the target environment."""
    input_root = Path(input_dir)
    results: dict[str, int] = {}
    for table_name in DEPLOY_TABLES:
        file_name = f"{table_name}.csv"
        source = find_first_existing(input_root, [file_name, f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing deploy-fix file %s", file_name)
            continue
        df = normalize_columns(read_csv_flexible(source))
        results[table_name] = load_dataframe(df, table_name, delete_where_clause="TRUE")
    logger.info("Imported deploy-fix datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    export_deploy_data()
