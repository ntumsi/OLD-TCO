"""Ordered orchestrator that replaces the SSIS DataLoad Main package."""

from __future__ import annotations

import logging

from common.logging_utils import configure_logging

# --- core reference data ---
from dataload.lookup_tables import load_lookup_tables
from dataload.lookup_gs_occupations import load_lookup_gs_occupations
from dataload.single_values import load_single_values
from dataload.cost_element import load_cost_element

# --- OPM / pay locality ---
from dataload.opm import load_opm, load_locality_rates
from dataload.special_rates import load_special_rates
from dataload.locations import load_locations

# --- pay schedules ---
from dataload.pay_schedule_gs import load_pay_schedule_gs
from dataload.pay_schedule_military import load_pay_schedule_military
from dataload.pay_schedule_fws import load_pay_schedule_fws
from dataload.pay_schedule_ses import load_pay_schedule_ses
from dataload.dcips import load_dcips
from dataload.dfas import load_dfas

# --- BAH / COLA ---
from dataload.bah_rates import load_bah_rates
from dataload.non_locality_bah import load_non_locality_bah
from dataload.conus_cola import load_conus_cola
from dataload.dtmo import load_dtmo

# --- inflation / BLS ---
from dataload.jic_inflation_rates import load_jic_inflation_rates
from dataload.bls_oes import load_bls_oes
from dataload.bls_ecec import load_bls_ecec

# --- geographic / reference crosswalks ---
from dataload.fips_zip import load_fips_zip
from dataload.census_zip import load_census_zip
from dataload.military_installations import load_military_installations, load_military_base
from dataload.career_program import load_career_program
from dataload.atrrs import load_atrrs
from dataload.wage_areas import load_wage_areas

# --- DMDC inventory ---
from dataload.inventory import load_inventory
from dataload.dmdc_inventory import load_dmdc_inventory, load_civilian_inventory, load_military_inventory
from dataload.dmdc_pay import load_dmdc_pay
from dataload.dmdc_members import load_dmdc_members
from dataload.dmdc_source_of_commission import load_dmdc_source_of_commission
from dataload.dmdc_legacy import (
    load_amostabs,
    load_continuation_rates,
    load_ets,
    load_ofbymos,
    load_rar2409,
    load_tabmos,
)

# --- workforce / WASS / G1 PAM ---
from dataload.wass import load_wass
from dataload.dcpds import load_dcpds
from dataload.g1pam import load_g1pam
from dataload.gfebs import load_gfebs
from dataload.fmsweb import load_fmsweb

# --- budget / training ---
from dataload.army_budget import load_army_budget
from dataload.army_pay_type import load_army_pay_type
from dataload.training import load_training
from dataload.table_values import load_table_values

logger = logging.getLogger(__name__)


def run_all() -> dict[str, object]:
    """Run the complete Python ETL pipeline in dependency order."""
    results: dict[str, object] = {}

    # 1. Core reference / lookup data
    results["lookup_tables"] = load_lookup_tables()
    results["lookup_gs_occupations"] = load_lookup_gs_occupations()
    results["single_values"] = load_single_values()
    results["cost_element"] = load_cost_element()
    results["army_pay_type"] = load_army_pay_type()
    results["career_program"] = load_career_program()
    results["atrrs"] = load_atrrs()
    results["wage_areas"] = load_wage_areas()

    # 2. OPM / locality
    results["opm"] = load_opm()
    results["locality_rates"] = load_locality_rates()
    results["special_rates"] = load_special_rates()
    results["locations"] = load_locations()
    results["fips_zip"] = load_fips_zip()
    results["census_zip"] = load_census_zip()
    results["military_installations"] = load_military_installations()
    results["military_base"] = load_military_base()

    # 3. Pay schedules
    results["gs_pay"] = load_pay_schedule_gs()
    results["military_pay"] = load_pay_schedule_military()
    results["fws_pay"] = load_pay_schedule_fws()
    results["ses_pay"] = load_pay_schedule_ses()
    results["dcips"] = load_dcips()
    results["dfas"] = load_dfas()

    # 4. BAH / COLA / allowances
    results["bah_rates"] = load_bah_rates()
    results["non_locality_bah"] = load_non_locality_bah()
    results["conus_cola"] = load_conus_cola()
    results["dtmo"] = load_dtmo()

    # 5. Inflation / BLS
    results["jic_inflation_rates"] = load_jic_inflation_rates()
    results["bls_oes"] = load_bls_oes()
    results["bls_ecec"] = load_bls_ecec()

    # 6. DMDC inventory
    results["dmdc_inventory"] = load_dmdc_inventory()
    results["civilian_inventory"] = load_civilian_inventory()
    results["military_inventory"] = load_military_inventory()
    results["dmdc_pay"] = load_dmdc_pay()
    results["dmdc_members"] = load_dmdc_members()
    results["dmdc_source_of_commission"] = load_dmdc_source_of_commission()

    # 7. Legacy DMDC tables
    results["amostabs"] = load_amostabs()
    results["continuation_rates"] = load_continuation_rates()
    results["ets"] = load_ets()
    results["ofbymos"] = load_ofbymos()
    results["rar2409"] = load_rar2409()
    results["tabmos"] = load_tabmos()

    # 8. Workforce / position data
    results["wass"] = load_wass()
    results["dcpds"] = load_dcpds()
    results["g1pam"] = load_g1pam()
    results["gfebs"] = load_gfebs()
    results["fmsweb"] = load_fmsweb()

    # 9. Budget / training
    results["army_budget"] = load_army_budget()
    results["training"] = load_training()
    results["table_values"] = load_table_values()

    logger.info("AMCOS dataload orchestration complete: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    run_all()
