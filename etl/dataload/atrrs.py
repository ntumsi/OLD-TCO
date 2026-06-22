"""Load ATRRS crosswalk and course-type reference files from legacy SSIS inputs."""

from __future__ import annotations

import logging
from pathlib import Path

import pandas as pd

from common.db import load_dataframe
from common.file_utils import find_all_existing, find_first_existing, normalize_columns, read_csv_flexible
from common.logging_utils import configure_logging
from config.settings import AMCOS_VERSION_ID, DATA_DIR

logger = logging.getLogger(__name__)
CROSSWALK_TABLE = "xwalk.atrrsatrmcrosswalk"
COURSE_TYPE_TABLE = "lookup.atrrscoursetypemos"
CROSSWALK_PATTERNS = ["**/ATRM-ATRRS Crosswalk/xwalk.ATRRSATRMCrosswalk.csv"]
COURSE_TYPE_PATTERNS = ["**/ATRRS Course Type/ATRRSCourseTypeMOS*.csv"]


def transform_atrrs_crosswalk(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    rename_map = {
        "atrrsschoolcode": "atrrs_schoolcode",
        "schoolcode": "atrrs_schoolcode",
        "atrrscoursenumber": "atrrs_coursenumber",
        "coursenumber": "atrrs_coursenumber",
        "atrmcourseid": "atrm_course_id",
        "atrmcourse": "atrm_course_id",
        "courseid": "atrm_course_id",
        "coursetitle": "course_title",
        "title": "course_title",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    if "atrrs_schoolcode" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "atrrs_schoolcode"})
    if "atrrs_coursenumber" not in working.columns and len(working.columns) >= 2:
        working = working.rename(columns={working.columns[1]: "atrrs_coursenumber"})
    working["amcos_version_id"] = str(version_id)
    return working.dropna(subset=[column for column in ["atrrs_schoolcode", "atrrs_coursenumber"] if column in working.columns])


def transform_atrrs_course_type(df: pd.DataFrame, version_id: str) -> pd.DataFrame:
    working = normalize_columns(df)
    working = working.drop(columns=[column for column in working.columns if column.startswith("unnamed")], errors="ignore")
    rename_map = {
        "schoolcode": "atrrs_schoolcode",
        "atrrsschoolcode": "atrrs_schoolcode",
        "coursenumber": "atrrs_coursenumber",
        "atrrscoursenumber": "atrrs_coursenumber",
        "crstypeo": "crs_type_o",
        "crstypee": "crs_type_e",
        "weaponsystem": "weaponsystemname",
        "weaponsystem_name": "weaponsystemname",
        "ogradelevelfloor": "o_gradelevel_floor",
        "ogradelevelceiling": "o_gradelevel_ceiling",
        "wgradelevelfloor": "w_gradelevel_floor",
        "wgradelevelceiling": "w_gradelevel_ceiling",
        "egradelevelfloor": "e_gradelevel_floor",
        "egradelevelceiling": "e_gradelevel_ceiling",
    }
    working = working.rename(columns={column: rename_map[column] for column in working.columns if column in rename_map})
    numeric_columns = [
        "o_gradelevel_floor",
        "o_gradelevel_ceiling",
        "w_gradelevel_floor",
        "w_gradelevel_ceiling",
        "e_gradelevel_floor",
        "e_gradelevel_ceiling",
    ]
    for column in numeric_columns:
        if column in working.columns:
            working[column] = pd.to_numeric(working[column], errors="coerce").astype("Int64")
    if "atrrs_schoolcode" not in working.columns and len(working.columns) >= 1:
        working = working.rename(columns={working.columns[0]: "atrrs_schoolcode"})
    if "atrrs_coursenumber" not in working.columns and len(working.columns) >= 2:
        working = working.rename(columns={working.columns[1]: "atrrs_coursenumber"})
    working["amcos_version_id"] = str(version_id)
    return working.dropna(subset=[column for column in ["atrrs_schoolcode", "atrrs_coursenumber"] if column in working.columns])


def load_atrrs(data_dir: Path | str = DATA_DIR, version_id: str = AMCOS_VERSION_ID) -> dict[str, int]:
    data_root = Path(data_dir)
    crosswalk_source = find_first_existing(data_root, CROSSWALK_PATTERNS)
    course_type_sources = find_all_existing(data_root, COURSE_TYPE_PATTERNS)
    if not crosswalk_source and not course_type_sources:
        raise FileNotFoundError("Could not locate ATRRS input files beneath AMCOS_DATA_DIR.")

    results = {"crosswalk": 0, "course_type": 0}
    if crosswalk_source:
        transformed = transform_atrrs_crosswalk(read_csv_flexible(crosswalk_source), version_id)
        results["crosswalk"] = load_dataframe(
            transformed,
            CROSSWALK_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    if course_type_sources:
        transformed = pd.concat(
            [transform_atrrs_course_type(read_csv_flexible(source), version_id) for source in course_type_sources],
            ignore_index=True,
        )
        results["course_type"] = load_dataframe(
            transformed,
            COURSE_TYPE_TABLE,
            delete_where_clause="amcosversionid = %s",
            delete_params=(version_id,),
        )

    logger.info("Loaded ATRRS datasets: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    load_atrrs()
