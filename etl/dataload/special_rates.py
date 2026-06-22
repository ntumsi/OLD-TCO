"""Load OPM special-rate raw files, crosswalks, and final lookup datasets."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
SPECIAL_RATE_FILES = {
    "opm_special_rates_raw": (
        ["**/OPM/PaySchedule.OpmSpecialRates_raw.csv"],
        "payschedule.opmspecialrates",
        ["amcos_version_id", "table_number", "grade", "step"],
    ),
    "special_rates_by_agency": (
        ["**/OPM/xwalk.SpecialRateTablesByAgency.csv"],
        "xwalk.specialratetablesbyagency",
        ["amcos_version_id", "table_number", "agency"],
    ),
    "special_rates_by_location": (
        ["**/OPM/xwalk.SpecialRateTablesByLocation.csv"],
        "xwalk.specialratetablesbylocation",
        ["amcos_version_id", "table_number", "location"],
    ),
    "special_rates_by_occupation": (
        ["**/xwalk.SpecialRateTablesByOccupation.csv", "**/OPM/xwalk.SpecialRateTablesByOccupation.csv"],
        "xwalk.specialratetablesbyoccupation",
        ["amcos_version_id", "table_number", "occupation"],
    ),
}
FINAL_SPECIAL_RATES_TABLE = "lookup.opm_specialrate"


def transform_special_rate_rows(df: pd.DataFrame, version_id: str, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working = working.rename(
        columns={
            "specialratetablenumber": "table_number",
            "special_rate_table_number": "table_number",
            "localityid": "locality_id",
            "locationid": "locality_id",
            "occupationalseriesnumber": "occupational_series_number",
            "occupationname": "occupation_name",
        }
    )
    working["amcos_version_id"] = str(version_id)
    working["source_file"] = source_name
    return working


def transform_final_special_rates(df: pd.DataFrame, version_id: str, source_name: str) -> pd.DataFrame:
    working = transform_special_rate_rows(df, version_id, source_name)
    working = working.rename(
        columns={
            "table_number": "special_rate_table_number",
            "agencyname": "agency_name",
            "locality_id": "location_id",
        }
    )
    return working


def _load_versioned_table(df: pd.DataFrame, table_name: str, conflict_columns: list[str], version_id: str) -> int:
    return load_dataframe(
        df,
        table_name,
        conflict_columns=conflict_columns,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )


def load_special_rates(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    results: dict[str, int] = {}

    for result_key, (patterns, table_name, conflicts) in SPECIAL_RATE_FILES.items():
        source = find_first_existing(data_root, patterns)
        if not source:
            logger.warning("Skipping missing special-rate source for %s", result_key)
            continue
        transformed = transform_special_rate_rows(read_csv_flexible(source), version_id, source.name)
        results[result_key] = _load_versioned_table(transformed, table_name, conflicts, version_id)

    final_sources = find_all_existing(data_root, ["**/*Final_Special*Rate*.csv"])
    if final_sources:
        transformed = pd.concat(
            [transform_final_special_rates(read_csv_flexible(source), version_id, source.name) for source in final_sources],
            ignore_index=True,
            sort=False,
        )
        results["opm_special_rate"] = _load_versioned_table(
            transformed,
            FINAL_SPECIAL_RATES_TABLE,
            ["amcos_version_id", "special_rate_table_number", "occupational_series_number", "location_id"],
            version_id,
        )
    else:
        logger.warning("Skipping missing final special-rate reference files")

    logger.info("Loaded special-rate datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_special_rates()
