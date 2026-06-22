"""Export and import migration datasets, replacing the SSIS MigrateExport/MigrateImport packages."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import fetch_dataframe, load_dataframe
from common.file_utils import ensure_directory, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)
MIGRATE_TABLES = {
    "webuser.AMCOSUser.csv": "webuser.amcosuser",
    "webuser.PMProject.csv": "webuser.pmproject",
    "webuser.User_Login_History.csv": "webuser.user_login_history",
    "webuser.PCSProject.csv": "webuser.pcsproject",
    "web.ApplicationErrorLog.csv": "web.applicationerrorlog",
    "webuser.AmcosLiteAudit.csv": "webuser.amcosliteaudit",
}
UNIT_PERSONNEL_FILE = "warehouse.UnitPersonnel.csv"
UNIT_PERSONNEL_TABLE = "warehouse.unitpersonnel"


def transform_migrated_rows(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def migrate_export(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    output_root = ensure_directory(output_dir)
    results: dict[str, int] = {}
    for file_name, table_name in MIGRATE_TABLES.items():
        df = fetch_dataframe(f"SELECT * FROM {table_name}")
        target_path = output_root / file_name
        df.to_csv(target_path, index=False)
        results[file_name] = len(df)
    logger.info("Exported migration datasets: %s", results)
    return results


def migrate_import(input_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    input_root = Path(input_dir)
    results: dict[str, int] = {}
    for file_name, table_name in MIGRATE_TABLES.items():
        source = find_first_existing(input_root, [file_name, f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing migration import %s", file_name)
            continue
        transformed = transform_migrated_rows(read_csv_flexible(source))
        results[file_name] = load_dataframe(transformed, table_name, delete_where_clause="TRUE")
    logger.info("Imported migration datasets: %s", results)
    return results


def migrate_unit_personnel(output_dir: Path | str = OUTPUT_DIR) -> dict[str, int | str]:
    output_root = ensure_directory(output_dir)
    source = find_first_existing(output_root, [UNIT_PERSONNEL_FILE, f"**/{UNIT_PERSONNEL_FILE}"])
    if source:
        transformed = transform_migrated_rows(read_csv_flexible(source))
        rows = load_dataframe(transformed, UNIT_PERSONNEL_TABLE, delete_where_clause="TRUE")
        result = {"mode": "import", "rows": rows}
    else:
        df = fetch_dataframe(f"SELECT * FROM {UNIT_PERSONNEL_TABLE}")
        target_path = output_root / UNIT_PERSONNEL_FILE
        df.to_csv(target_path, index=False)
        result = {"mode": "export", "rows": len(df)}
    logger.info("Migrated warehouse.UnitPersonnel: %s", result)
    return result


if __name__ == "__main__":
    configure_logging()
    migrate_export()
