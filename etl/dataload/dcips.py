"""Load DCIPS cyber wage-rate tables and GG base pay from the SSIS DCIPS package."""

from __future__ import annotations

import logging
import re
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
CYBER_TABLE = "payschedule.cyberexceptedservice"
GG_TABLE = "payschedule.payschedule_g_series_raw"


def transform_cyber_rate_table(df: pd.DataFrame, version_id: str, schedule_code: str) -> pd.DataFrame:
    working = normalize_columns(df)
    supplement_column = "supplement" if "supplement" in working.columns else None
    step_columns = [column for column in working.columns if re.fullmatch(r"step\d+", column)]
    melted = working.melt(id_vars=["grade"] + ([supplement_column] if supplement_column else []), value_vars=step_columns, var_name="step", value_name="salary")
    melted["salary"] = pd.to_numeric(melted["salary"], errors="coerce")
    melted = melted.dropna(subset=["salary"])
    melted["grade"] = pd.to_numeric(melted["grade"], errors="coerce").astype("Int64")
    melted["step"] = melted["step"].str.replace("step", "", regex=False).astype(int)
    melted["salary_schedule"] = schedule_code
    melted["amcos_version_id"] = str(version_id)
    columns = ["amcos_version_id", "salary_schedule", "grade", "step", "salary"]
    if supplement_column:
        melted["supplement"] = pd.to_numeric(melted[supplement_column], errors="coerce")
        columns.append("supplement")
    return melted[columns]


def load_dcips(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    results = {"cyber": 0, "gg_base_pay": 0}
    for source in find_all_existing(data_root, ["**/*Cyber WR A*.csv"]):
        schedule_code = source.stem.split()[-1].upper()
        transformed = transform_cyber_rate_table(read_csv_flexible(source), version_id, schedule_code)
        results["cyber"] += load_dataframe(
            transformed,
            CYBER_TABLE,
            conflict_columns=["amcos_version_id", "salary_schedule", "grade", "step"],
            delete_where_clause="amcosversionid = %s AND salaryschedule = %s",
            delete_params=(version_id, schedule_code),
        )

    gg_source = find_first_existing(data_root, ["**/*GG Base Pay Rate*.csv"])
    if gg_source:
        working = normalize_columns(read_csv_flexible(gg_source))
        working["pay_plan"] = "GG"
        working["amcos_version_id"] = str(version_id)
        results["gg_base_pay"] = load_dataframe(
            working,
            GG_TABLE,
            conflict_columns=["amcos_version_id", "pay_plan", "grade", "step"],
            delete_where_clause="amcosversionid = %s AND payplan = %s",
            delete_params=(version_id, "GG"),
        )

    logger.info("Loaded DCIPS datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_dcips()
