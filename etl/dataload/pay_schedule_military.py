"""Load military basic and drill pay from the SSIS PaySchedule.Military package."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_payschedule.payschedule_military"


def load_pay_schedule_military(file_path: Path | str | None = None, version_id: str = AMCOS_VERSION_ID) -> int:
    source = Path(file_path) if file_path else find_first_existing(DATA_DIR, ["**/*BasicPay*DrillPay*.csv"])
    if not source:
        raise FileNotFoundError("Could not locate the military pay input file beneath AMCOS_DATA_DIR.")
    working = normalize_columns(read_csv_flexible(source))
    working["amcos_version_id"] = str(version_id)
    rows = load_dataframe(
        working,
        TARGET_TABLE,
        conflict_columns=["amcos_version_id", "pay_plan", "grade_type", "grade_level", "yos", "rate_type", "date_effective"],
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s military pay rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_pay_schedule_military()
