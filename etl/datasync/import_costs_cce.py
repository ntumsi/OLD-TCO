"""Import BLS OES contractor-cost data, replacing AMCOS.SSIS.ImportCostsCCE."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
METRO_TABLE = "bls_oes.occupationalemploymentstatisticsmetro"
NATIONAL_TABLE = "bls_oes.occupationalemploymentstatisticsnational"
METRO_FILES = ["**/BLS_OES.OccupationalEmploymentStatisticsMetro.csv", "**/OccupationalEmploymentStatisticsMetro.csv"]
NATIONAL_FILES = [
    "**/BLS_OES.OccupationalEmploymentStatisticsNational.csv",
    "**/OccupationalEmploymentStatisticsNational.csv",
]


def import_costs_cce(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    """Import BLS OES metro and national OES exports into the bls_oes schema."""
    data_root = Path(data_dir)
    results: dict[str, int] = {}

    metro_source = find_first_existing(data_root, METRO_FILES)
    if metro_source:
        df = normalize_columns(read_csv_flexible(metro_source))
        results["metro"] = load_dataframe(df, METRO_TABLE, delete_where_clause="TRUE")
        logger.info("Imported %s metro OES rows", results["metro"])
    else:
        logger.warning("OccupationalEmploymentStatisticsMetro.csv not found; skipping.")

    national_source = find_first_existing(data_root, NATIONAL_FILES)
    if national_source:
        df = normalize_columns(read_csv_flexible(national_source))
        results["national"] = load_dataframe(df, NATIONAL_TABLE, delete_where_clause="TRUE")
        logger.info("Imported %s national OES rows", results["national"])
    else:
        logger.warning("OccupationalEmploymentStatisticsNational.csv not found; skipping.")

    logger.info("Imported CCE contractor-cost datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    import_costs_cce()
