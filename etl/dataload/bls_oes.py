"""Load BLS OES metro, national, and area-definition data."""

from __future__ import annotations

import logging
from pathlib import Path

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)


def _prepare(df, version_id: str, area_type: str | None = None):
    working = normalize_columns(df)
    working["amcos_version_id"] = str(version_id)
    if area_type:
        working["area_type"] = area_type
    return working


def load_bls_oes(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    results = {"metro": 0, "national": 0, "area_xwalk": 0, "msa_lookup": 0}

    for pattern in ["**/BOS_M*_dl.csv", "**/MSA_M*_dl.csv"]:
        for source in find_all_existing(data_root, [pattern]):
            area_type = source.stem.split("_", 1)[0]
            results["metro"] += load_dataframe(
                _prepare(read_csv_flexible(source), version_id, area_type),
                "bls_oes.occupationalemploymentstatisticsmetro",
                delete_where_clause="amcosversionid = %s",
                delete_params=(version_id,),
            )

    national_source = find_first_existing(data_root, ["**/national_M*_dl.csv"])
    if national_source:
        results["national"] = load_dataframe(
            _prepare(read_csv_flexible(national_source), version_id, "NATIONAL"),
            "bls_oes.occupationalemploymentstatisticsnational",
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    area_source = find_first_existing(data_root, ["**/area_definitions_*.csv"])
    if area_source:
        area_df = _prepare(read_csv_flexible(area_source), version_id)
        results["area_xwalk"] = load_dataframe(
            area_df,
            "xwalk.metropolitanstatisticalareatofips",
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )
        results["msa_lookup"] = load_dataframe(
            area_df,
            "lookup.metropolitanstatisticalarea",
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    logger.info("Loaded BLS OES datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_bls_oes()
