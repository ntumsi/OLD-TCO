"""Load OPM locality, COLA, GS/GL raw schedules, and special-rate crosswalks.

Covers:
  - AMCOS.SSIS.DataLoad.OPM.dtsx
  - AMCOS.SSIS.DataLoad.LookupLocalityRates.dtsx
"""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)

FILE_TARGETS = {
    "lookup.LocalityPayArea.csv": ("lookup.localitypayarea", ["amcos_version_id", "locality_pay_area"]),
    "PaySchedule.LocalityPay.csv": ("payschedule.localitypay", ["amcos_version_id", "locality_pay_area"]),
    "xwalk.LocalityPayAreaToFips.csv": ("xwalk.localitypayareatofips", ["amcos_version_id", "locality_pay_area", "fips"]),
    "PaySchedule.NonforeignAreaCostOfLivingAllowances.csv": ("payschedule.nonforeignareacostoflivingallowances", ["amcos_version_id", "nonforeign_cola_area"]),
    "PaySchedule.PaySchedule_G_Series_raw-GL.csv": ("payschedule.payschedule_g_series_raw", ["amcos_version_id", "pay_plan", "grade", "step"]),
    "PaySchedule.PaySchedule_G_Series_raw-GS.csv": ("payschedule.payschedule_g_series_raw", ["amcos_version_id", "pay_plan", "grade", "step"]),
    "PaySchedule.OpmSpecialRates_raw.csv": ("payschedule.opmspecialrates", ["amcos_version_id", "table_number", "grade", "step"]),
    "xwalk.SpecialRateTablesByAgency.csv": ("xwalk.specialratetablesbyagency", ["amcos_version_id", "table_number", "agency"]),
    "xwalk.SpecialRateTablesByLocation.csv": ("xwalk.specialratetablesbylocation", ["amcos_version_id", "table_number", "location"]),
    "xwalk.SpecialRateTablesByOccupation.csv": ("xwalk.specialratetablesbyoccupation", ["amcos_version_id", "table_number", "occupation"]),
}

LOCALITY_RATES_TABLE = "lookup.localityrates"


def _generic_transform(df, version_id: str, file_name: str):
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["amcos_version_id"] = str(version_id)
    if file_name.endswith("-GL.csv"):
        working["pay_plan"] = "GL"
    elif file_name.endswith("-GS.csv"):
        working["pay_plan"] = "GS"
    return working


def load_opm(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    results: dict[str, int] = {}
    for file_name, (table_name, conflicts) in FILE_TARGETS.items():
        source = find_first_existing(data_root, [f"**/{file_name}"])
        if not source:
            logger.warning("Skipping missing OPM source %s", file_name)
            continue
        skiprows = 2 if "NonforeignAreaCostOfLivingAllowances" in file_name else 0
        transformed = _generic_transform(read_csv_flexible(source, skiprows=skiprows), version_id, file_name)
        results[file_name] = load_dataframe(
            transformed,
            table_name,
            conflict_columns=conflicts,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    logger.info("Loaded OPM datasets: %s", results)
    return results


def load_locality_rates(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    """Load LocalityRates.csv into lookup.LocalityRates.

    Replaces AMCOS.SSIS.DataLoad.LookupLocalityRates.dtsx.
    """
    data_root = Path(data_dir)
    source = find_first_existing(
        data_root,
        ["**/LocalityRates.csv", "**/LookupTables/LocalityRates.csv", "**/OPM/LocalityRates.csv"],
    )
    if not source:
        logger.warning("LocalityRates.csv not found; skipping.")
        return 0
    logger.info("Loading locality rates from %s", source)
    working = normalize_columns(read_csv_flexible(source))
    working["amcos_version_id"] = str(version_id)
    rows = load_dataframe(
        working,
        LOCALITY_RATES_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s locality rate rows", rows)
    return rows


if __name__ == "__main__":
    configure_logging()
    load_opm()
