"""Load DCPDS/WASS inventory staging files from DCPDS extracts."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, BATCH_SIZE, DATA_DIR

logger = logging.getLogger(__name__)
TARGET_TABLE = "load_inventory.wass_raw"
SOURCE_PATTERNS = ["**/DCPDS/BoBI*.csv", "**/DCPDS/*.csv"]


def transform_dcpds(df: pd.DataFrame, version_id: str, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["amcos_version_id"] = str(version_id)
    working["source_file"] = source_name
    lower_name = source_name.lower()
    if "appr" in lower_name:
        working["source_variant"] = "APPR"
    elif "naf" in lower_name:
        working["source_variant"] = "NAF"
    elif "ln" in lower_name:
        working["source_variant"] = "LN"
    else:
        working["source_variant"] = Path(source_name).stem.upper()
    return working.dropna(how="all")


def load_dcpds(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    sources = find_all_existing(data_dir, SOURCE_PATTERNS)
    if not sources:
        raise FileNotFoundError("Could not locate DCPDS input files beneath AMCOS_DATA_DIR.")
    transformed = pd.concat(
        [transform_dcpds(read_csv_flexible(source), version_id, source.name) for source in sources],
        ignore_index=True,
    )
    rows = load_dataframe(
        transformed,
        TARGET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
        chunk_size=BATCH_SIZE,
    )
    logger.info("Loaded %s DCPDS rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_dcpds()
