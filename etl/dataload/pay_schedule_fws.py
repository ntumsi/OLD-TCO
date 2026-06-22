"""Load FWS wage schedules from AF and NAF directory inputs."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_payschedule.payschedule_fws"


def load_pay_schedule_fws(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    rows_loaded = 0
    for source in find_all_existing(data_dir, ["**/Wage AF/**/*.csv", "**/Wage NAF/**/*.csv"]):
        working = normalize_columns(read_csv_flexible(source))
        working["amcos_version_id"] = str(version_id)
        working["wage_category"] = "AF" if "wage af" in str(source).lower() else "NAF"
        working["source_file"] = source.name
        rows_loaded += load_dataframe(
            working,
            TARGET_TABLE,
            delete_where_clause="amcosversionid = %s AND sourcefile = %s",
            delete_params=(version_id, source.name),
        )
    logger.info("Loaded %s FWS rows", rows_loaded)
    return rows_loaded


if __name__ == "__main__":
    configure_logging()
    load_pay_schedule_fws()
