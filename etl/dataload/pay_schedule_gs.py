"""Load GS-style pay schedules from DCPAS and raw OPM schedule files."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_payschedule.payschedule_gs"


def load_pay_schedule_gs(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    rows_loaded = 0
    for source in find_all_existing(data_dir, ["**/*NFData*.csv", "**/*PaySchedule_G_Series_raw-*.csv"]):
        working = normalize_columns(read_csv_flexible(source))
        working["amcos_version_id"] = str(version_id)
        if "pay_plan" not in working.columns:
            if "-gs" in source.stem.lower():
                working["pay_plan"] = "GS"
            elif "-gl" in source.stem.lower():
                working["pay_plan"] = "GL"
        pay_plan = working["pay_plan"].iloc[0] if "pay_plan" in working.columns and not working.empty else None
        rows_loaded += load_dataframe(
            working,
            TARGET_TABLE,
            conflict_columns=["amcos_version_id", "pay_plan", "grade", "step"],
            delete_where_clause="amcosversionid = %s" + (" AND payplan = %s" if pay_plan else ""),
            delete_params=(version_id, pay_plan) if pay_plan else (version_id,),
        )
    logger.info("Loaded %s GS-style schedule rows", rows_loaded)
    return rows_loaded


if __name__ == "__main__":
    configure_logging()
    load_pay_schedule_gs()
