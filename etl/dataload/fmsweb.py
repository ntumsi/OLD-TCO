"""Load FMSWeb SACS, lockpoint, UIC, and UIC-location files."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
SACS_HEADER_TABLE = "data.fmswebsacsheader"
SACS_PERSONNEL_TABLE = "data.fmswebsacspersonnel"
LOCKPOINT_TABLE = "data.fmsweblockpointtdochdr"
LOCKPOINT_PERDET_TABLE = "data.fmsweblockpointtperdet"
UIC_TABLE = "lookup.uic"
UIC_LOCATION_TABLE = "lookup.uiclocation"


def transform_sacs_header(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    for column in [column for column in ["runid", "edatei", "tdate"] if column in working.columns]:
        working[column] = pd.to_numeric(working[column], errors="coerce").astype("Int64")
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def transform_sacs_personnel(df: pd.DataFrame, source_name: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working["source_file"] = source_name
    working["row_number"] = range(1, len(working) + 1)
    for column in [column for column in ["runid", "edatei", "rqboi", "auboi", "sorce", "rqstr", "austr"] if column in working.columns]:
        working[column] = pd.to_numeric(working[column], errors="coerce").astype("Int64")
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def transform_lockpoint(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working["amcos_version_id"] = str(version_id)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def transform_uic(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def transform_uic_locations(df: pd.DataFrame) -> pd.DataFrame:
    working = normalize_columns(df)
    return working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")


def load_sacs(data_dir: Path | str = DATA_DIR) -> dict[str, int]:
    data_root = Path(data_dir)
    header_source = find_first_existing(data_root, ["**/FMSWeb/sacs/cla_header*.txt"])
    personnel_source = find_first_existing(data_root, ["**/FMSWeb/sacs/cla_perdet*.txt"])
    if not header_source and not personnel_source:
        raise FileNotFoundError("Could not locate FMSWeb SACS files beneath AMCOS_DATA_DIR.")
    results = {"header": 0, "personnel": 0}
    if header_source:
        transformed = transform_sacs_header(read_csv_flexible(header_source))
        results["header"] = load_dataframe(transformed, SACS_HEADER_TABLE, conflict_columns=[column for column in ["runid", "uic", "edatei"] if column in transformed.columns] or list(transformed.columns[:1]))
    if personnel_source:
        transformed = transform_sacs_personnel(read_csv_flexible(personnel_source), personnel_source.name)
        results["personnel"] = load_dataframe(transformed, SACS_PERSONNEL_TABLE, conflict_columns=[column for column in ["source_file", "row_number"] if column in transformed.columns])
    logger.info("Loaded FMSWeb SACS datasets: %s", results)
    return results


def load_lockpoint(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    source = find_first_existing(Path(data_dir), ["**/FMSWeb/lockpoint/TDA/TDOCHDR.txt"])
    if not source:
        raise FileNotFoundError("Could not locate the FMSWeb lockpoint TDOCHDR source file.")
    transformed = transform_lockpoint(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        LOCKPOINT_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s FMSWeb lockpoint rows", rows)
    return rows


def load_lockpoint_perdet(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    """Load the lockpoint personnel-detail (TPERDET) extract into data.fmsweblockpointtperdet."""
    source = find_first_existing(
        Path(data_dir),
        ["**/FMSWeb/lockpoint/TDA/TPERDET.txt", "**/FMSWeb/lockpoint/**/TPERDET*.txt"],
    )
    if not source:
        raise FileNotFoundError("Could not locate the FMSWeb lockpoint TPERDET source file.")
    transformed = transform_lockpoint(read_csv_flexible(source), version_id)
    rows = load_dataframe(
        transformed,
        LOCKPOINT_PERDET_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
    )
    logger.info("Loaded %s FMSWeb lockpoint personnel-detail rows", rows)
    return rows


def load_uic(data_dir: Path | str = DATA_DIR) -> int:
    source = find_first_existing(Path(data_dir), ["**/FMSWeb/*uic*.txt"])
    if not source:
        raise FileNotFoundError("Could not locate an FMSWeb UIC source file.")
    transformed = transform_uic(read_csv_flexible(source))
    rows = load_dataframe(
        transformed,
        UIC_TABLE,
        conflict_columns=[column for column in ["uic"] if column in transformed.columns] or list(transformed.columns[:1]),
    )
    logger.info("Loaded %s UIC rows", rows)
    return rows


def load_uic_locations(data_dir: Path | str = DATA_DIR) -> int:
    source = find_first_existing(Path(data_dir), ["**/FMSWeb/*uic*locations*.txt"])
    if not source:
        raise FileNotFoundError("Could not locate an FMSWeb UIC-location source file.")
    transformed = transform_uic_locations(read_csv_flexible(source))
    rows = load_dataframe(
        transformed,
        UIC_LOCATION_TABLE,
        conflict_columns=[column for column in ["uic", "geloc", "arloc"] if column in transformed.columns] or list(transformed.columns[:1]),
    )
    logger.info("Loaded %s UIC location rows", rows)
    return rows


def load_fmsweb(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, object]:
    results = {
        "sacs": load_sacs(data_dir=data_dir),
        "lockpoint": load_lockpoint(data_dir=data_dir, version_id=version_id),
        "lockpoint_perdet": load_lockpoint_perdet(data_dir=data_dir, version_id=version_id),
        "uic": load_uic(data_dir=data_dir),
        "uic_locations": load_uic_locations(data_dir=data_dir),
    }
    logger.info("Loaded FMSWeb datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_fmsweb()
