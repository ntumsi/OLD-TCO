"""Export and import migration datasets, replacing the SSIS MigrateExport/MigrateImport packages."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd
from psycopg2 import sql

from common.db import fetch_dataframe, get_connection, load_dataframe, qualified_identifier
from common.file_utils import ensure_directory, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import OUTPUT_DIR

logger = logging.getLogger(__name__)
# Ordered parent-first so inserts satisfy foreign keys:
# AMCOSUser <- PMProject <- PMCategory <- PMCategorySkill <- PMCategorySkillInventory,
# PMCategory <- PMReport, and AMCOSUser <- PCSProject / User_Login_History / AmcosLiteAudit.
# (aspnet_WebEvent_Events from the legacy SSIS package is not part of the migrated schema.)
MIGRATE_TABLES = {
    "webuser.AMCOSUser.csv": "webuser.amcosuser",
    "webuser.PMProject.csv": "webuser.pmproject",
    "webuser.PMCategory.csv": "webuser.pmcategory",
    "webuser.PMCategorySkill.csv": "webuser.pmcategoryskill",
    "webuser.PMCategorySkillInventory.csv": "webuser.pmcategoryskillinventory",
    "webuser.PMReport.csv": "webuser.pmreport",
    "webuser.PCSProject.csv": "webuser.pcsproject",
    "webuser.User_Login_History.csv": "webuser.user_login_history",
    "webuser.AmcosLiteAudit.csv": "webuser.amcosliteaudit",
    "web.ApplicationErrorLog.csv": "web.applicationerrorlog",
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


def _clear_tables(tables: list[str]) -> None:
    """Delete all rows from the given tables in reverse (children-first) order."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            for table_name in reversed(tables):
                cur.execute(
                    sql.SQL("DELETE FROM {}").format(qualified_identifier(table_name))
                )


def migrate_import(input_dir: Path | str = OUTPUT_DIR) -> dict[str, int]:
    input_root = Path(input_dir)
    results: dict[str, int] = {}

    # Clear the target tables children-first so foreign keys do not block the reload, then insert
    # parent-first (MIGRATE_TABLES order). This keeps the import re-runnable on a populated database.
    _clear_tables(list(MIGRATE_TABLES.values()))

    for file_name, table_name in MIGRATE_TABLES.items():
        source = find_first_existing(input_root, [file_name, f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing migration import %s", file_name)
            continue
        transformed = transform_migrated_rows(read_csv_flexible(source))
        results[file_name] = load_dataframe(transformed, table_name)
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
