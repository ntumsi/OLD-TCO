"""Export AMCOS PostgreSQL tables to CSV, replacing SSIS ExportData and ExportForRelease."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import fetch_dataframe
from common.file_utils import ensure_directory
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)

EXPORT_TABLES = [
    "dataload.costs_1activeday_ne", "dataload.costs_1activeday_no", "dataload.costs_1activeday_nwo",
    "dataload.costs_1activeday_re", "dataload.costs_1activeday_ro", "dataload.costs_1activeday_rwo",
    "dataload.costs_ae", "dataload.costs_ao", "dataload.costs_awo", "dataload.costs_ne", "dataload.costs_no",
    "dataload.costs_nwo", "dataload.costs_re", "dataload.costs_ro", "dataload.costs_rwo", "dataload.costs_gp",
    "dataload.costs_gs", "dataload.costs_gss", "dataload.costs_ses", "dataload.costs_wg", "dataload.costs_wl",
    "dataload.costs_ws", "data.costswithdescriptions", "data.inventory", "data.categorygroup", "data.categorysubgroup",
    "lookup.costelement", "lookup.costsummariesbypayplan", "lookup.costsummary", "lookup.costsummaryelement",
    "lookup.grade", "lookup.metroarea", "lookup.payplan", "payschedule.localityrates", "payschedule.opm_specialrate",
    "bls_oes.occupationalemploymentstatisticsmetro", "bls_oes.occupationalemploymentstatisticsnational",
]


def export_data(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    output_root = ensure_directory(output_dir)
    results: dict[str, int] = {}
    for table_name in EXPORT_TABLES:
        df = fetch_dataframe(f"SELECT * FROM {table_name}")
        target_path = output_root / f"{table_name}.csv"
        ensure_directory(target_path.parent)
        df.to_csv(target_path, index=False)
        results[table_name] = len(df)
    logger.info("Exported datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    export_data()
