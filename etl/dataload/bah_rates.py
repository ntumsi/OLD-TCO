"""Load BAH rates, ZIP-to-MHA mappings, and MHA names from SSIS BAHRates inputs."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
BAH_RATE_TABLE = "dataload.bah_rates"
MHA_TABLE = "lookup.militaryhousingarea"
ZIP_TABLE = "xwalk.ziptomha"
GRADE_PATTERN = re.compile(r"^(?:[EWO]\d+|O\d+E)$", re.IGNORECASE)


def _grade_parts(grade: str) -> tuple[str, int | None]:
    text = str(grade).strip().upper()
    letters = "".join(character for character in text if character.isalpha())
    digits = "".join(character for character in text if character.isdigit())
    return letters, int(digits) if digits else None


def transform_bah_rate_matrix(df: pd.DataFrame, *, with_dependents: bool, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    if "mha" not in working.columns:
        working = working.rename(columns={working.columns[0]: "mha"})
    grade_columns = [column for column in working.columns if GRADE_PATTERN.match(column.upper())]
    melted = working.melt(id_vars=["mha"], value_vars=grade_columns, var_name="grade", value_name="amount")
    melted["amount"] = pd.to_numeric(melted["amount"], errors="coerce")
    melted = melted.dropna(subset=["amount"])
    melted["grade"] = melted["grade"].str.upper()
    melted["grade_type"] = melted["grade"].map(lambda value: _grade_parts(value)[0])
    melted["grade_level"] = melted["grade"].map(lambda value: _grade_parts(value)[1])
    melted["with_dependents"] = bool(with_dependents)
    melted["amcos_version_id"] = str(version_id)
    return melted[["amcos_version_id", "mha", "grade", "grade_type", "grade_level", "with_dependents", "amount"]]


def transform_zip_to_mha(df: pd.DataFrame, *, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    rename_map = {}
    for column in working.columns:
        if column in {"zip", "zipcode"}:
            rename_map[column] = "zip_code"
        elif column in {"mha", "military_housing_area"}:
            rename_map[column] = "mha"
    working = working.rename(columns=rename_map)
    if "zip_code" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "zip_code"})
    if "mha" not in working.columns and len(working.columns) >= 2:
        working = working.rename(columns={working.columns[1]: "mha"})
    working["amcos_version_id"] = str(version_id)
    return working[["amcos_version_id", "zip_code", "mha"]].dropna(subset=["zip_code", "mha"])


def transform_military_housing_areas(df: pd.DataFrame, *, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    if "mha" not in working.columns:
        working = working.rename(columns={working.columns[0]: "mha"})
    if "name" not in working.columns:
        second = working.columns[1] if len(working.columns) > 1 else "description"
        working = working.rename(columns={second: "name"})
    working["amcos_version_id"] = str(version_id)
    return working[["amcos_version_id", "mha", "name"]].dropna(subset=["mha"])


def _discover_inputs(data_dir: Path) -> dict[str, Path | None]:
    return {
        "with_dependents": find_first_existing(data_dir, ["**/bahw*.txt", "**/bahw*.csv"]),
        "without_dependents": find_first_existing(data_dir, ["**/bahwo*.txt", "**/bahwo*.csv"]),
        "mha_names": find_first_existing(data_dir, ["**/mhanames*.txt", "**/mhanames*.csv"]),
        "zip_to_mha": find_first_existing(data_dir, ["**/*zipmha*.txt", "**/*zipmha*.csv"]),
    }


def load_bah_rates(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    """Load BAH rate-related files used by the BAHRates SSIS package."""
    data_root = Path(data_dir)
    sources = _discover_inputs(data_root)
    results = {"bah_rates": 0, "zip_to_mha": 0, "military_housing_areas": 0}

    if sources["with_dependents"]:
        transformed = transform_bah_rate_matrix(read_csv_flexible(sources["with_dependents"]), with_dependents=True, version_id=version_id)
        results["bah_rates"] += load_dataframe(
            transformed,
            BAH_RATE_TABLE,
            conflict_columns=["amcos_version_id", "mha", "grade", "with_dependents"],
            delete_where_clause="amcosversionid = %s AND withdependents = %s",
            delete_params=(version_id, True),
        )

    if sources["without_dependents"]:
        transformed = transform_bah_rate_matrix(read_csv_flexible(sources["without_dependents"]), with_dependents=False, version_id=version_id)
        results["bah_rates"] += load_dataframe(
            transformed,
            BAH_RATE_TABLE,
            conflict_columns=["amcos_version_id", "mha", "grade", "with_dependents"],
            delete_where_clause="amcosversionid = %s AND withdependents = %s",
            delete_params=(version_id, False),
        )

    if sources["zip_to_mha"]:
        transformed = transform_zip_to_mha(read_csv_flexible(sources["zip_to_mha"]), version_id=version_id)
        results["zip_to_mha"] = load_dataframe(
            transformed,
            ZIP_TABLE,
            conflict_columns=["amcos_version_id", "zip_code"],
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    if sources["mha_names"]:
        transformed = transform_military_housing_areas(read_csv_flexible(sources["mha_names"]), version_id=version_id)
        results["military_housing_areas"] = load_dataframe(
            transformed,
            MHA_TABLE,
            conflict_columns=["amcos_version_id", "mha"],
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    logger.info("Loaded BAH package results: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_bah_rates()
