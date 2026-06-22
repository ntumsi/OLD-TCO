"""Import exported lookup CSVs back into PostgreSQL, replacing SSIS ImportLookup."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)

LOOKUP_FILES = {
    "lookup.WeaponSystem.csv": "lookup.weaponsystem",
    "lookup.AOC.csv": "lookup.aoc",
    "lookup.CostElement.csv": "lookup.costelement",
    "lookup.CostSummary.csv": "lookup.costsummary",
    "lookup.CostSummaryElement.csv": "lookup.costsummaryelement",
    "lookup.GS_OccupationalSeries.csv": "lookup.gs_occupationalseries",
    "lookup.MetroArea.csv": "lookup.metroarea",
    "lookup.MOS.csv": "lookup.mos",
    "lookup.PayPlan.csv": "lookup.payplan",
    "lookup.PayPlanTags.csv": "lookup.payplantags",
    "lookup.WOMOS.csv": "lookup.womos",
}


def import_lookup(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    results: dict[str, int] = {}
    for file_name, table_name in LOOKUP_FILES.items():
        source = find_first_existing(data_dir, [f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing lookup export %s", file_name)
            continue
        df = normalize_columns(read_csv_flexible(source))
        results[file_name] = load_dataframe(df, table_name, delete_where_clause="TRUE")
    logger.info("Imported lookup datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    import_lookup()
