"""Load legacy DMDC flat files that fed multiple SSIS staging packages."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, BATCH_SIZE, DATA_DIR

logger = logging.getLogger(__name__)
AMOSTABS_TABLE = "dmdc.amostabs"
CONTINUATION_PROMOTED_TABLE = "dmdc.continuationrates_promoted"
CONTINUATION_NOT_PROMOTED_TABLE = "dmdc.continuationrates_notpromoted"
BASE_POPULATION_TABLE = "dmdc.basepopulation"
ETS_POPULATION_TABLE = "dmdc.ets_population"
ETS_RATES_TABLE = "dmdc.ets_rates"
OFBYMOS_TABLE = "dmdc.ofbypmos"
RAR2409_TABLE = "dmdc.rar2409"
TABMOS_TABLE = "dmdc.tabmos"


def _read_many(data_dir: Path | str, patterns: list[str], version_id: str, *, source_kind: str | None = None) -> pd.DataFrame:
    sources = find_all_existing(data_dir, patterns)
    if not sources:
        return pd.DataFrame()
    frames: list[pd.DataFrame] = []
    for source in sources:
        working = normalize_columns(read_csv_flexible(source))
        working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
        working["amcos_version_id"] = str(version_id)
        working["source_file"] = source.name
        if source_kind:
            working["source_kind"] = source_kind
        frames.append(working)
    return pd.concat(frames, ignore_index=True)


def load_amostabs(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    enlisted = _read_many(data_dir, ["**/AMOSTABS/*.Grd.Enl*"], version_id, source_kind="ENLISTED")
    officer = _read_many(data_dir, ["**/AMOSTABS/*.Grd.Off*"], version_id, source_kind="OFFICER")
    transformed = pd.concat([frame for frame in [enlisted, officer] if not frame.empty], ignore_index=True) if not enlisted.empty or not officer.empty else pd.DataFrame()
    if transformed.empty:
        raise FileNotFoundError("Could not locate AMOSTABS legacy files beneath AMCOS_DATA_DIR.")
    rows = load_dataframe(
        transformed,
        AMOSTABS_TABLE,
        delete_where_clause="amcosversionid = %s",
        delete_params=(version_id,),
        chunk_size=BATCH_SIZE,
    )
    logger.info("Loaded %s AMOSTABS rows", rows)
    return rows


def load_continuation_rates(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    promoted = _read_many(data_dir, ["**/CMF/*PROMOTED*", "**/CMF/*Promoted*", "**/CMF/*PRO*"], version_id)
    not_promoted = _read_many(data_dir, ["**/CMF/*NOT*PROMOT*", "**/CMF/*NotPromoted*", "**/CMF/*NONPROMOT*"], version_id)
    base_population = _read_many(data_dir, ["**/CMF/*BASE*"], version_id)
    if promoted.empty and not_promoted.empty and base_population.empty:
        raise FileNotFoundError("Could not locate DMDC continuation-rate files beneath AMCOS_DATA_DIR.")
    results = {
        "promoted": load_dataframe(promoted, CONTINUATION_PROMOTED_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE) if not promoted.empty else 0,
        "not_promoted": load_dataframe(not_promoted, CONTINUATION_NOT_PROMOTED_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE) if not not_promoted.empty else 0,
        "base_population": load_dataframe(base_population, BASE_POPULATION_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE) if not base_population.empty else 0,
    }
    logger.info("Loaded continuation-rate datasets: %s", results)
    return results


def load_ets(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    population = _read_many(data_dir, ["**/ETS/ETS.OVER12*", "**/ETS/ETS.UNDER12*"], version_id)
    if not population.empty:
        population = population[~population["source_file"].str.contains("RATES", case=False, na=False)]
    rates = _read_many(data_dir, ["**/ETS/ETS.OVER12RATES*"], version_id)
    if population.empty and rates.empty:
        raise FileNotFoundError("Could not locate DMDC ETS files beneath AMCOS_DATA_DIR.")
    results = {
        "population": load_dataframe(population, ETS_POPULATION_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE) if not population.empty else 0,
        "rates": load_dataframe(rates, ETS_RATES_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE) if not rates.empty else 0,
    }
    logger.info("Loaded ETS datasets: %s", results)
    return results


def load_ofbymos(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    transformed = _read_many(data_dir, ["**/OFBYMOS/OFBYPMOS*"], version_id)
    if transformed.empty:
        raise FileNotFoundError("Could not locate OFBYMOS files beneath AMCOS_DATA_DIR.")
    rows = load_dataframe(transformed, OFBYMOS_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE)
    logger.info("Loaded %s OFBYMOS rows", rows)
    return rows


def load_rar2409(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    transformed = _read_many(data_dir, ["**/RAR2409/RAR2409*"], version_id)
    if transformed.empty:
        raise FileNotFoundError("Could not locate RAR2409 files beneath AMCOS_DATA_DIR.")
    rows = load_dataframe(transformed, RAR2409_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE)
    logger.info("Loaded %s RAR2409 rows", rows)
    return rows


def load_tabmos(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> int:
    transformed = _read_many(data_dir, ["**/TABMOS/TABMOS*"], version_id)
    if transformed.empty:
        raise FileNotFoundError("Could not locate TABMOS files beneath AMCOS_DATA_DIR.")
    rows = load_dataframe(transformed, TABMOS_TABLE, delete_where_clause="amcosversionid = %s", delete_params=(version_id,), chunk_size=BATCH_SIZE)
    logger.info("Loaded %s TABMOS rows", rows)
    return rows


def load_dmdc_legacy(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, object]:
    results = {
        "amostabs": load_amostabs(data_dir=data_dir, version_id=version_id),
        "continuation_rates": load_continuation_rates(data_dir=data_dir, version_id=version_id),
        "ets": load_ets(data_dir=data_dir, version_id=version_id),
        "ofbymos": load_ofbymos(data_dir=data_dir, version_id=version_id),
        "rar2409": load_rar2409(data_dir=data_dir, version_id=version_id),
        "tabmos": load_tabmos(data_dir=data_dir, version_id=version_id),
    }
    logger.info("Loaded legacy DMDC datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_dmdc_legacy()
