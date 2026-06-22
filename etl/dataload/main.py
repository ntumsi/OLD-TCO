"""Ordered orchestrator that replaces the SSIS DataLoad Main package."""

from __future__ import annotations

import logging

from common.logging_utils import configure_logging
from dataload.bah_rates import load_bah_rates
from dataload.bls_oes import load_bls_oes
from dataload.dcips import load_dcips
from dataload.dmdc_inventory import load_dmdc_inventory
from dataload.jic_inflation_rates import load_jic_inflation_rates
from dataload.locations import load_locations
from dataload.lookup_tables import load_lookup_tables
from dataload.opm import load_opm
from dataload.pay_schedule_fws import load_pay_schedule_fws
from dataload.pay_schedule_gs import load_pay_schedule_gs
from dataload.pay_schedule_military import load_pay_schedule_military

logger = logging.getLogger(__name__)


def run_all() -> dict[str, object]:
    """Run the primary Python ETL replacements in dependency order."""
    results = {
        "lookup_tables": load_lookup_tables(),
        "opm": load_opm(),
        "locations": load_locations(),
        "gs_pay": load_pay_schedule_gs(),
        "military_pay": load_pay_schedule_military(),
        "fws_pay": load_pay_schedule_fws(),
        "bah_rates": load_bah_rates(),
        "jic_inflation_rates": load_jic_inflation_rates(),
        "dcips": load_dcips(),
        "dmdc_inventory": load_dmdc_inventory(),
        "bls_oes": load_bls_oes(),
    }
    logger.info("AMCOS dataload orchestration complete: %s", results)
    return results


if __name__ == "__main__":
    configure_logging()
    run_all()
