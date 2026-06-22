"""Load G-1 PAM position files from TXT extracts."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import DATA_DIR

logger = logging.getLogger(__name__)
BRPEXP_TABLE = "pos.brpexp"
CMF_TABLE = "pos.cmf"
DATA711_TABLE = "pos.711"


def _transform_position_file(df: pd.DataFrame, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["source_file"] = source_name
    working["row_number"] = range(1, len(working) + 1)
    return working.dropna(how="all")


def load_g1pam(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    data_root = Path(data_dir)
    sources = {
        "brpexp": find_first_existing(data_root, ["**/G1 PAM/*BRPEXP*.TXT"]),
        "cmf": find_first_existing(data_root, ["**/G1 PAM/*CMFEXPIP*.TXT"]),
        "data711": find_first_existing(data_root, ["**/G1 PAM/*DATA711*.TXT"]),
    }
    if not any(sources.values()):
        raise FileNotFoundError("Could not locate any G1 PAM source files beneath AMCOS_DATA_DIR.")
    results = {"brpexp": 0, "cmf": 0, "data711": 0}
    if sources["brpexp"]:
        transformed = _transform_position_file(read_csv_flexible(sources["brpexp"]), sources["brpexp"].name)
        results["brpexp"] = load_dataframe(transformed, BRPEXP_TABLE, conflict_columns=["source_file", "row_number"])
    if sources["cmf"]:
        transformed = _transform_position_file(read_csv_flexible(sources["cmf"]), sources["cmf"].name)
        results["cmf"] = load_dataframe(transformed, CMF_TABLE, conflict_columns=["source_file", "row_number"])
    if sources["data711"]:
        transformed = _transform_position_file(read_csv_flexible(sources["data711"]), sources["data711"].name)
        results["data711"] = load_dataframe(transformed, DATA711_TABLE, conflict_columns=["source_file", "row_number"])
    logger.info("Loaded G1 PAM datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_g1pam()
