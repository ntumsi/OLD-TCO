"""Load table-value CSVs from the legacy Table Values folder into dataload tables."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
TABLE_OVERRIDES = {
    "continuationrates": "dataload.ro_continuationrates",
    "pcs": "dataload.ao_pcs",
}


def transform_table_values(df, version_id: str, source_name: str):
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["amcos_version_id"] = str(version_id)
    working["source_file"] = source_name
    return working


def target_table_for_source(source: Path) -> str:
    stem = source.stem.strip()
    normalized = stem.replace(" ", "").replace("-", "").replace("_", "").lower()
    for key, table_name in TABLE_OVERRIDES.items():
        if key in normalized:
            return table_name
    return f"dataload.{stem.lower()}"


def load_table_values(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    sources = find_all_existing(data_dir, ["**/Table Values/*.csv"])
    if not sources:
        raise FileNotFoundError("Could not locate any Table Values CSVs beneath AMCOS_DATA_DIR.")
    results: dict[str, int] = {}
    for source in sources:
        table_name = target_table_for_source(source)
        transformed = transform_table_values(read_csv_flexible(source), version_id, source.name)
        results[source.name] = load_dataframe(transformed, table_name, delete_where_clause="TRUE")
    logger.info("Loaded table-value datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_table_values()
