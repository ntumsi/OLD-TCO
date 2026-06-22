"""Import exported crunch cost files, replacing the SSIS ImportCosts packages."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)


def import_costs(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    results: dict[str, int] = {}
    for source in find_all_existing(data_dir, ["**/crunch.Costs_*.csv"]):
        table_name = "crunch." + source.stem.replace("crunch.", "").lower()
        df = normalize_columns(read_csv_flexible(source))
        results[source.name] = load_dataframe(df, table_name, delete_where_clause="TRUE")
    logger.info("Imported cost datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    import_costs()
