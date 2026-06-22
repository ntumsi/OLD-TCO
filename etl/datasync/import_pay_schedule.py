"""Import exported pay-schedule CSVs back into PostgreSQL, replacing SSIS ImportPaySchedule."""

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
    "load_payschedule.PaySchedule_D_NSeries.csv": "load_payschedule.payschedule_d_nseries",
    "load_payschedule.PaySchedule_G_Series.csv": "load_payschedule.payschedule_g_series",
    "load_payschedule.PaySchedule_G_Series_raw.csv": "load_payschedule.payschedule_g_series_raw",
    "load_payschedule.PaySchedule_Military.csv": "load_payschedule.payschedule_military",
    "load_payschedule.PaySchedule_SES.csv": "load_payschedule.payschedule_ses",
}


def transform_exported_pay_schedule(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def import_pay_schedule(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    output_root = Path(output_dir)
    results: dict[str, int] = {}
    for file_name, table_name in EXPORT_FILES.items():
        source = find_first_existing(output_root, [file_name, f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing pay-schedule export %s", file_name)
            continue
        transformed = transform_exported_pay_schedule(read_csv_flexible(source))
        results[file_name] = load_dataframe(transformed, table_name, delete_where_clause="TRUE")
    logger.info("Imported pay-schedule datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    import_pay_schedule()
