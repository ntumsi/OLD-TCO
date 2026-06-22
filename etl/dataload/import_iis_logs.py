"""Load IIS log extracts into logs.iislogs, replacing AMCOS.SSIS.Import_IISLogs.dtsx."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "logs.iislogs"
SOURCE_PATTERNS = [
    "**/*iis*log*.csv",
    "**/*iis*log*.txt",
    "**/*iis*log*.log",
    "**/*iislogs*",
]


def _read_w3c_log(path: Path) -> pd.DataFrame:
    lines = path.read_text(encoding="utf-8-sig", errors="ignore").splitlines()
    fields: list[str] | None = None
    data_lines: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#Fields:"):
            fields = [part.strip() for part in stripped.replace("#Fields:", "", 1).split()]
            continue
        if stripped.startswith("#"):
            continue
        data_lines.append(stripped)

    if not data_lines:
        return pd.DataFrame()

    rows = [re.split(r"\s+", line) for line in data_lines]
    if fields and all(len(row) == len(fields) for row in rows):
        return pd.DataFrame(rows, columns=fields)
    return pd.DataFrame(rows)


def _read_iis_source(path: Path) -> pd.DataFrame:
    suffix = path.suffix.lower()
    if suffix in {".log", ".txt"}:
        parsed = _read_w3c_log(path)
        if not parsed.empty:
            return parsed
    return read_csv_flexible(path)


def load_iis_logs(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    sources = [path for path in find_all_existing(data_dir, SOURCE_PATTERNS) if path.is_file()]
    if not sources:
        raise FileNotFoundError("Could not locate IIS log source files beneath AMCOS_DATA_DIR.")

    results: dict[str, int] = {}
    clear_target = True
    for source in sources:
        transformed = normalize_columns(_read_iis_source(source))
        transformed = transformed.drop(columns=[column for column in transformed.columns if column.startswith("unnamed")], errors="ignore")
        transformed = transformed.dropna(how="all")
        if transformed.empty:
            results[source.name] = 0
            continue
        transformed["logfilename"] = source.name
        results[source.name] = load_dataframe(
            transformed,
            TARGET_TABLE,
            delete_where_clause="TRUE" if clear_target else None,
        )
        clear_target = False

    logger.info("Loaded IIS log datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_iis_logs()
