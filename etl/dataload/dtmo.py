"""Load DTMO-provided military compensation, BAH, COLA, ZIP, and OHA files."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
SPENDABLE_INCOME_TABLE = "dataload.militaryspendableincome"
BAH_TABLE = "dataload.bahrates"
NON_LOCALITY_BAH_TABLE = "dataload.nonlocalitybahrates"
CONUS_COLA_TABLE = "dataload.conuscola"
CONUS_COLA_LOCATION_TABLE = "dataload.conuscolalocations"
ZIP_TO_MHA_TABLE = "xwalk.ziptomha"
OHA_TABLE = "dataload.militaryoverseashousingallowance"


def _with_version(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    working["amcos_version_id"] = str(version_id)
    return working.dropna(how="all")


def transform_conus_cola(df: pd.DataFrame, version_id: str, with_dependents: bool) -> pd.DataFrame:
    working = _with_version(df, version_id)
    working["with_dependents"] = with_dependents
    return working


def load_dtmo(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    results = {
        "military_spendable_income": 0,
        "bah_rates": 0,
        "non_locality_bah_rates": 0,
        "conus_cola": 0,
        "conus_cola_locations": 0,
        "zip_to_mha": 0,
        "oha": 0,
    }

    spendable_income = find_first_existing(data_root, ["**/DTMO/dataload.MilitarySpendableIncome.csv"])
    bah_rates = find_first_existing(data_root, ["**/DTMO/dataload.BAHRates.csv"])
    non_locality_bah = find_first_existing(data_root, ["**/DTMO/dataload.NonLocalityBAHRates.csv"])
    zip_to_mha = find_first_existing(data_root, ["**/DTMO/*ZIP*to*MHA*.csv", "**/DTMO/*ziptomha*.csv"])
    conus_locations = find_first_existing(data_root, ["**/DTMO/*cczips*.txt", "**/DTMO/*ConusCola*Locations*.csv"])
    conus_with_dep = find_all_existing(data_root, ["**/DTMO/*ccwd*.txt", "**/DTMO/*ConusCola*With*.csv"])
    conus_without_dep = find_all_existing(data_root, ["**/DTMO/*ccwod*.txt", "**/DTMO/*ConusCola*Without*.csv"])
    oha_sources = find_all_existing(data_root, ["**/DTMO/*OHA*.csv", "**/*MilitaryOverseasHousingAllowance*.csv"])

    if spendable_income:
        results["military_spendable_income"] = load_dataframe(
            _with_version(read_csv_flexible(spendable_income), version_id),
            SPENDABLE_INCOME_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if bah_rates:
        results["bah_rates"] = load_dataframe(
            _with_version(read_csv_flexible(bah_rates), version_id),
            BAH_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if non_locality_bah:
        results["non_locality_bah_rates"] = load_dataframe(
            _with_version(read_csv_flexible(non_locality_bah), version_id),
            NON_LOCALITY_BAH_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if zip_to_mha:
        results["zip_to_mha"] = load_dataframe(
            _with_version(read_csv_flexible(zip_to_mha), version_id),
            ZIP_TO_MHA_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if conus_locations:
        results["conus_cola_locations"] = load_dataframe(
            _with_version(read_csv_flexible(conus_locations), version_id),
            CONUS_COLA_LOCATION_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    rate_frames = [transform_conus_cola(read_csv_flexible(source), version_id, True) for source in conus_with_dep]
    rate_frames.extend(transform_conus_cola(read_csv_flexible(source), version_id, False) for source in conus_without_dep)
    if rate_frames:
        results["conus_cola"] = load_dataframe(
            pd.concat(rate_frames, ignore_index=True),
            CONUS_COLA_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
    if oha_sources:
        results["oha"] = load_dataframe(
            pd.concat([_with_version(read_csv_flexible(source), version_id) for source in oha_sources], ignore_index=True),
            OHA_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    if not any(results.values()):
        raise FileNotFoundError("Could not locate DTMO source files beneath AMCOS_DATA_DIR.")
    logger.info("Loaded DTMO datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_dtmo()
