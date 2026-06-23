"""Load FMSWeb SACS header and personnel-detail records (AMCOS.SSIS.DataLoad.SACSHeader)."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
HEADER_TABLE = "fmsweb.sacsheader"
PERDET_TABLE = "fmsweb.sacsperdet"
HEADER_PATTERNS = [
    "**/FMSWeb/sacs/cla_header_roll*/*.txt",
    "**/FMSWeb/sacs/cla_header_roll*.txt",
    "**/FMSWeb/*cla_header*.txt",
    "**/sacs/*header*.txt",
]
PERDET_PATTERNS = [
    "**/FMSWeb/sacs/cla_perdet_roll*/*.txt",
    "**/FMSWeb/sacs/cla_perdet_roll*.txt",
    "**/FMSWeb/*cla_perdet*.txt",
    "**/sacs/*perdet*.txt",
]


def transform_sacs_header(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[column for column in working.columns if column.startswith("unnamed")],
        errors="ignore",
    )
    working["amcos_version_id"] = str(version_id)
    return working.dropna(
        subset=[column for column in ["runid", "uic"] if column in working.columns]
    )


def transform_sacs_perdet(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(
        columns=[column for column in working.columns if column.startswith("unnamed")],
        errors="ignore",
    )
    working["amcos_version_id"] = str(version_id)
    return working.dropna(
        subset=[column for column in ["runid", "uic"] if column in working.columns]
    )


def load_sacs_header(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    results: dict[str, int] = {}

    header_source = find_first_existing(data_root, HEADER_PATTERNS)
    if header_source:
        transformed = transform_sacs_header(read_csv_flexible(header_source), version_id)
        results["header"] = load_dataframe(
            transformed,
            HEADER_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
        logger.info("Loaded %s SACS header rows from %s", results["header"], header_source.name)
    else:
        logger.warning("No SACS header file found; skipping header load.")

    perdet_source = find_first_existing(data_root, PERDET_PATTERNS)
    if perdet_source:
        transformed = transform_sacs_perdet(read_csv_flexible(perdet_source), version_id)
        results["perdet"] = load_dataframe(
            transformed,
            PERDET_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
        logger.info("Loaded %s SACS perdet rows from %s", results["perdet"], perdet_source.name)
    else:
        logger.warning("No SACS perdet file found; skipping perdet load.")

    return results


if __name__ == "__main__":
    configure_logging()
    load_sacs_header()
